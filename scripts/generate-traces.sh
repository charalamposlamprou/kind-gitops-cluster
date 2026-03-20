#!/bin/bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $1"
    exit 1
  fi
}

require_cmd curl

A_BASE_URL="${A_BASE_URL:-http://microservice-a.127.0.0.1.nip.io}"
B_BASE_URL="${B_BASE_URL:-http://microservice-b.127.0.0.1.nip.io}"
ITERATIONS="${ITERATIONS:-30}"
DELAY_SECONDS="${DELAY_SECONDS:-0.3}"

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [ "$ITERATIONS" -le 0 ]; then
  echo "ERROR: ITERATIONS must be a positive integer"
  exit 1
fi

echo "Generating traces against:"
echo "  microservice-a: $A_BASE_URL"
echo "  microservice-b: $B_BASE_URL"
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
