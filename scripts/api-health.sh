#!/usr/bin/env bash
# KALLAX API Health Check — wait for API server to be ready and report status
set -euo pipefail

API_URL="${1:-http://localhost:9876}"
TIMEOUT_SEC="${2:-30}"
POLL_INTERVAL="${3:-2}"

echo "=== KALLAX API Health Check ==="
echo "Endpoint: $API_URL"
echo "Timeout:  ${TIMEOUT_SEC}s"
echo ""

# Helper: check a single endpoint
check_endpoint() {
  local url="$1"
  local label="$2"
  local status_code

  status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")

  if [ "$status_code" = "200" ]; then
    echo "  [PASS] $label (HTTP $status_code)"
    return 0
  else
    echo "  [FAIL] $label (HTTP $status_code)"
    return 1
  fi
}

# Health endpoint (no auth)
echo "--- Direct Health Check ---"
check_endpoint "${API_URL}/health" "/health"

if [ $? -ne 0 ]; then
  echo ""
  echo "Server not ready yet. Waiting up to ${TIMEOUT_SEC}s..."
  ELAPSED=0
  while [ $ELAPSED -lt "$TIMEOUT_SEC" ]; do
    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))

    if check_endpoint "${API_URL}/health" "/health" >/dev/null 2>&1; then
      echo "Server ready after ~${ELAPSED}s"
      break
    fi

    if [ $((ELAPSED + POLL_INTERVAL)) -ge "$TIMEOUT_SEC" ]; then
      echo "Timeout reached. Server not responding." >&2
      exit 1
    fi
  done
fi

# Full health details
echo ""
echo "--- Health Details ---"
curl -s --max-time 5 "${API_URL}/health" 2>/dev/null | python3 -m json.tool 2>/dev/null || curl -s --max-time 5 "${API_URL}/health" 2>/dev/null || echo "(unavailable)"

echo ""
echo "--- Version ---"
curl -s --max-time 5 "${API_URL}/version" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(unavailable)"

echo ""
echo "--- System Stats ---"
curl -s --max-time 5 "${API_URL}/stats" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(unavailable)"

echo ""
echo "Health check complete."
