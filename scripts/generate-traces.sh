#!/bin/bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $1"
    exit 1
  fi
}

detect_container_runtime() {
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
    return 0
  fi

  if command -v podman >/dev/null 2>&1; then
    echo "podman"
    return 0
  fi

  return 1
}

detect_envoy_http_port() {
  local runtime container_id port

  runtime="$(detect_container_runtime)" || return 1
  container_id="$($runtime ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2" | head -n 1)"

  if [ -z "$container_id" ]; then
    return 1
  fi

  port="$($runtime port "$container_id" 80/tcp 2>/dev/null | awk -F: '/0.0.0.0:|\[::\]:/ {print $NF; exit}')"

  if [ -z "$port" ]; then
    port="$($runtime port "$container_id" 80/tcp 2>/dev/null | awk -F: 'NR == 1 {print $NF}')"
  fi

  [ -n "$port" ] || return 1
  echo "$port"
}

build_base_url() {
  local host="$1"
  local port="${2:-}"

  if [ -n "$port" ] && [ "$port" != "80" ]; then
    echo "http://$host:$port"
    return 0
  fi

  echo "http://$host"
}

require_cmd curl

INGRESS_PORT="${INGRESS_PORT:-}"

if [ -z "$INGRESS_PORT" ]; then
  INGRESS_PORT="$(detect_envoy_http_port || true)"
fi

A_BASE_URL="${A_BASE_URL:-$(build_base_url "microservice-a.127.0.0.1.nip.io" "$INGRESS_PORT")}"
B_BASE_URL="${B_BASE_URL:-$(build_base_url "microservice-b.127.0.0.1.nip.io" "$INGRESS_PORT")}"
ITERATIONS="${ITERATIONS:-30}"
DELAY_SECONDS="${DELAY_SECONDS:-0.3}"

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [ "$ITERATIONS" -le 0 ]; then
  echo "ERROR: ITERATIONS must be a positive integer"
  exit 1
fi

echo "Generating traces against:"
echo "  microservice-a: $A_BASE_URL"
echo "  microservice-b: $B_BASE_URL"
if [ -n "$INGRESS_PORT" ]; then
  echo "  ingress port: $INGRESS_PORT (auto-detected or overridden)"
fi
echo "  iterations: $ITERATIONS"
echo "  delay: ${DELAY_SECONDS}s"

ok=0
fail=0

for i in $(seq 1 "$ITERATIONS"); do
  if curl -fsS "$A_BASE_URL/call-b?i=$i" >/dev/null; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    echo "WARN: failed request to microservice-a /call-b on iteration $i"
  fi

  if curl -fsS "$A_BASE_URL/?i=$i" >/dev/null; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    echo "WARN: failed request to microservice-a / on iteration $i"
  fi

  if curl -fsS "$B_BASE_URL/?i=$i" >/dev/null; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    echo "WARN: failed request to microservice-b / on iteration $i"
  fi

  sleep "$DELAY_SECONDS"
done

echo "Done. Successful requests: $ok, failed requests: $fail"
echo "Tip: check traces in Tempo and filter by service.name=microservice-a or service.name=microservice-b"
