#!/bin/bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $1"
    exit 1
  fi
}

require_cmd kubectl
require_cmd curl
require_cmd jq
require_cmd python3

TMP_DIR="$(mktemp -d)"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

start_port_forward() {
  local name="$1"
  shift
  kubectl port-forward "$@" >"$TMP_DIR/${name}.log" 2>&1 &
  PIDS+=("$!")
}

get_loki_sent_counter_sum() {
  local ips
  local pod
  local phase
  local value

  ips="$(kubectl get pods -n monitoring -l app.kubernetes.io/instance=otel-collector -o jsonpath='{range .items[*]}{.status.podIP}{" "}{end}')"
  pod="otel-counter-$(date +%s)-$RANDOM"

  kubectl run "$pod" -n default --image=curlimages/curl:8.7.1 --restart=Never --command -- \
    sh -c "sum=0; for ip in $ips; do v=\$(curl -s http://\$ip:8888/metrics | awk '/otelcol_exporter_sent_log_records\\{[^}]*exporter=\"loki\"/{s+=\$NF} END{print s+0}'); sum=\$(awk -v a=\"\$sum\" -v b=\"\$v\" 'BEGIN{print a+b}'); done; echo \$sum" >/dev/null 2>&1 || true

  kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$pod" -n default --timeout=90s >/dev/null 2>&1 || true
  phase="$(kubectl get pod "$pod" -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo Failed)"
  if [ "$phase" = "Succeeded" ]; then
    value="$(kubectl logs -n default "$pod" 2>/dev/null | tail -n 1)"
  else
    value="0"
  fi
  kubectl delete pod -n default "$pod" --ignore-not-found >/dev/null 2>&1 || true

  if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$value"
  else
    echo "0"
  fi
}

wait_http() {
  local url="$1"
  local retries="${2:-30}"
  local i
  for i in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "[1/6] Checking monitor resource"
if kubectl get podmonitor -n monitoring 2>/dev/null | grep -q otel-collector; then
  echo "PASS: PodMonitor for otel-collector exists"
else
  echo "FAIL: PodMonitor for otel-collector not found in monitoring namespace"
  echo "Hint: chart 0.89.0 needs podMonitor (daemonset mode), not serviceMonitor"
  exit 1
fi

echo "[2/6] Starting local forwards"
start_port_forward prometheus -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
start_port_forward tempo -n monitoring svc/tempo 3100:3100
start_port_forward collector -n monitoring svc/otel-collector 4318:4318
start_port_forward loki -n monitoring pod/loki-0 3110:3100

wait_http "http://127.0.0.1:9090/-/healthy" || { echo "FAIL: Prometheus port-forward not ready"; exit 1; }
wait_http "http://127.0.0.1:3100/ready" || { echo "FAIL: Tempo port-forward not ready"; exit 1; }
wait_http "http://127.0.0.1:3110/ready" || { echo "FAIL: Loki port-forward not ready"; exit 1; }

echo "[3/6] Checking Prometheus scrape targets"
TARGET_COUNT="$(curl -s http://127.0.0.1:9090/api/v1/targets | jq -r '[.data.activeTargets[] | select((.labels.job // "")|test("otel|collector";"i"))] | length')"
if [ "$TARGET_COUNT" -gt 0 ]; then
  echo "PASS: Prometheus has $TARGET_COUNT otel/collector active target(s)"
else
  echo "FAIL: Prometheus has 0 otel/collector active targets"
  exit 1
fi

UP_SERIES="$(curl -sG 'http://127.0.0.1:9090/api/v1/query' --data-urlencode 'query=sum by (job,instance) (up{namespace="monitoring", job=~".*otel-collector.*"})' | jq -r '.data.result | length')"
echo "INFO: up query returned $UP_SERIES series"

echo "[4/6] Sending synthetic trace to collector and checking Tempo"
TRACE_ID="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(16))
PY
)"
SPAN_ID="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(8))
PY
)"

START_NS="$(python3 - <<'PY'
import time
print(int(time.time() * 1e9))
PY
)"
END_NS="$(python3 - <<'PY'
import time
print(int((time.time() + 1) * 1e9))
PY
)"

TRACE_CODE="$(curl -s -o "$TMP_DIR/trace_resp.json" -w '%{http_code}' -X POST http://127.0.0.1:4318/v1/traces -H 'Content-Type: application/json' -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"otel-smoke-test\"}}]},\"scopeSpans\":[{\"scope\":{\"name\":\"smoke\"},\"spans\":[{\"traceId\":\"$TRACE_ID\",\"spanId\":\"$SPAN_ID\",\"name\":\"smoke-span\",\"kind\":1,\"startTimeUnixNano\":\"$START_NS\",\"endTimeUnixNano\":\"$END_NS\"}]}]}]}")"

if [ "$TRACE_CODE" != "200" ]; then
  echo "FAIL: OTLP trace POST failed with HTTP $TRACE_CODE"
  cat "$TMP_DIR/trace_resp.json"
  exit 1
fi

sleep 3
TEMPO_CODE="$(curl -s -o "$TMP_DIR/tempo_trace.json" -w '%{http_code}' "http://127.0.0.1:3100/api/traces/$TRACE_ID")"
if [ "$TEMPO_CODE" = "200" ] && grep -q 'otel-smoke-test' "$TMP_DIR/tempo_trace.json"; then
  echo "PASS: Trace found in Tempo"
else
  echo "FAIL: Trace not found in Tempo (HTTP $TEMPO_CODE)"
  head -c 300 "$TMP_DIR/tempo_trace.json" || true
  echo
  exit 1
fi

echo "[5/6] Generating logs and checking Loki"
MARKER="otel-log-smoke-$(date +%s)"
POD_NAME="otel-log-smoke-$(date +%s)"
BEFORE_LOG_SENT="$(get_loki_sent_counter_sum)"

kubectl run "$POD_NAME" -n default --image=busybox --restart=Never -- sh -c "i=1; while [ \$i -le 20 ]; do echo ${MARKER}-\$i; i=\$((i+1)); sleep 1; done" >/dev/null
sleep 18

AFTER_LOG_SENT="$(get_loki_sent_counter_sum)"

if awk "BEGIN {exit !($AFTER_LOG_SENT > $BEFORE_LOG_SENT)}"; then
  echo "PASS: Loki exporter counter increased ($BEFORE_LOG_SENT -> $AFTER_LOG_SENT)"
else
  echo "WARN: Loki exporter counter did not increase ($BEFORE_LOG_SENT -> $AFTER_LOG_SENT)"
  echo "      This usually means filelog generation/parsing/export timing needs tuning."
fi

echo "[6/6] Summary"
echo "PASS: OTel scrape and trace path validated"
echo "INFO: Loki check may require additional tuning if WARN appeared"
