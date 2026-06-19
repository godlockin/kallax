#!/usr/bin/env bash
# web/scripts/verify-deploy.sh — verify dashboard returns HTTP 200 on /
#
# EPIC-058-C — web dashboard deployment-ready
# Assumes dashboard already running (start with web/scripts/start.sh)
# Usage: bash web/scripts/verify-deploy.sh [port] [host]
#   port (optional, default 8080)
#   host (optional, default localhost)
# Exit 0 only when / returns 200 AND /src/dashboard/dispatch/ returns 200

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEFAULT_PORT=8080
readonly DEFAULT_HOST=localhost

readonly PORT="${1:-$DEFAULT_PORT}"
readonly HOST="${2:-$DEFAULT_HOST}"
readonly BASE_URL="http://${HOST}:${PORT}"

readonly CURL_TIMEOUT_SEC=5
readonly MAX_RETRIES=3
readonly RETRY_DELAY_SEC=1

# Check a single endpoint with retry; echoes HTTP status
check_endpoint() {
  local url="$1"
  local label="$2"
  local attempt=1
  local status=000

  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    status="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT_SEC" "$url" 2>/dev/null || echo 000)"
    if [ "$status" = "200" ]; then
      echo "  [PASS] $label → HTTP $status"
      return 0
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$MAX_RETRIES" ]; then
      sleep "$RETRY_DELAY_SEC"
    fi
  done

  echo "  [FAIL] $label → HTTP $status (after $MAX_RETRIES retries)"
  return 1
}

echo "=== Web Dashboard Deploy Verify ==="
echo "Base URL: $BASE_URL"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=2

if check_endpoint "${BASE_URL}/" "/ (root)"; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if check_endpoint "${BASE_URL}/dispatch/" "/dispatch/ (EPIC-053-D dashboard)"; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "Result: $PASS_COUNT/$TOTAL endpoints OK"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: dashboard not deployment-ready"
  exit 1
fi
echo "PASS: dashboard deployment-ready ($PASS_COUNT/$TOTAL = 100.0%)"
exit 0