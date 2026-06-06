#!/usr/bin/env bash
# KALLAX Heartbeat Integration Test -- EPIC-015 Card B
# End-to-end verification: start daemon -- heartbeat tick -- stale detection -- revival
# Usage: heartbeat-test.sh [temp_dir]
set -euo pipefail

# --- Config ---
INTERVAL=2       # daemon tick interval in seconds
MAX_MISSED=3     # missed threshold
INSTANCE_ID="test-agent-01"
ROLE="test"

# --- Temp dir ---
USER_DIR="${1:-}"
CLEANUP_DIR=""
if [ -n "${USER_DIR}" ]; then
  TEST_DIR="${USER_DIR}"
else
  TEST_DIR="$(mktemp -d)"
  CLEANUP_DIR="${TEST_DIR}"
fi

INSTANCE_DIR="${TEST_DIR}/instances/${INSTANCE_ID}"
STATE_FILE="${INSTANCE_DIR}/state.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_PID=""
PASS_COUNT=0
FAIL_COUNT=0

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}[FAIL]${NC} $*"; }

# --- Cleanup ---
cleanup() {
  echo ""
  echo "=== Test Results ==="
  echo "  Passed: ${PASS_COUNT}"
  echo "  Failed: ${FAIL_COUNT}"
  if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo "  Result: FAILED"
  else
    echo "  Result: ALL PASSED"
  fi

  # Kill daemon if still running
  if [ -n "${DAEMON_PID}" ] && kill -0 "${DAEMON_PID}" 2>/dev/null; then
    kill "${DAEMON_PID}" 2>/dev/null || true
    wait "${DAEMON_PID}" 2>/dev/null || true
  fi

  # Clean up temp dir only if we created it
  if [ -n "${CLEANUP_DIR}" ] && [ -d "${CLEANUP_DIR}" ]; then
    rm -rf "${CLEANUP_DIR}"
  fi

  exit "${FAIL_COUNT}"
}
trap cleanup EXIT INT TERM

# --- Setup ---
mkdir -p "${INSTANCE_DIR}"
cat > "${STATE_FILE}" <<JSONEOF
{
  "instance_id": "${INSTANCE_ID}",
  "role": "${ROLE}",
  "status": "ACTIVE",
  "heartbeat": {
    "last_beat": "2024-01-01T00:00:00Z",
    "missed_count": 0
  }
}
JSONEOF

echo "== KALLAX Heartbeat Integration Test =="
echo "  Instance: ${INSTANCE_ID}"
echo "  State:    ${STATE_FILE}"
echo "  Interval: ${INTERVAL}s | Max missed: ${MAX_MISSED}"
echo ""

# --- Test 0: syntax check on all three scripts ---
echo "--- Test 0: Shell syntax check (bash -n) ---"
for s in heartbeat-daemon.sh check-stale.sh heartbeat-test.sh; do
  if bash -n "${SCRIPT_DIR}/${s}" 2>/dev/null; then
    pass "${s}: syntax OK"
  else
    fail "${s}: syntax error"
  fi
done

# --- Test 1: state.json is valid JSON ---
echo "--- Test 1: state.json valid ---"
jq -e '.' "${STATE_FILE}" >/dev/null 2>&1 && \
  pass "state.json is valid JSON" || \
  fail "state.json is not valid JSON"

# --- Test 2: Start heartbeat daemon ---
echo "--- Test 2: Start heartbeat daemon ---"
"${SCRIPT_DIR}/heartbeat-daemon.sh" "${INSTANCE_ID}" "${TEST_DIR}/instances" "${INTERVAL}" &
DAEMON_PID=$!
sleep 1

kill -0 "${DAEMON_PID}" 2>/dev/null && \
  pass "heartbeat daemon started (pid=${DAEMON_PID})" || \
  fail "heartbeat daemon failed to start"

# --- Test 3: Daemon PID written to state.json ---
echo "--- Test 3: PID registration ---"
STORED_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // 0' "${STATE_FILE}")
[ "${STORED_PID}" = "${DAEMON_PID}" ] && \
  pass "PID ${DAEMON_PID} registered in state.json" || \
  fail "PID mismatch: stored=${STORED_PID}, actual=${DAEMON_PID}"

# --- Test 4: Heartbeat tick updates last_beat ---
echo "--- Test 4: Heartbeat tick ---"
LAST_BEAT_BEFORE=$(jq -r '.heartbeat.last_beat' "${STATE_FILE}")
sleep $((INTERVAL + 1))
LAST_BEAT_AFTER=$(jq -r '.heartbeat.last_beat' "${STATE_FILE}")
if [ "${LAST_BEAT_BEFORE}" != "${LAST_BEAT_AFTER}" ]; then
  pass "Heartbeat tick detected (updated timestamp)"
else
  fail "Heartbeat did not update (still: ${LAST_BEAT_BEFORE})"
fi

# --- Test 5: missed_count reset to 0 after tick ---
echo "--- Test 5: Missed count reset ---"
MISSED=$(jq -r '.heartbeat.missed_count' "${STATE_FILE}")
[ "${MISSED}" = "0" ] && \
  pass "missed_count is 0 after heartbeat" || \
  fail "missed_count is ${MISSED}, expected 0"

# --- Prepare for stale tests: kill daemon, reset state ---
echo ""
echo "--- (stopping daemon for stale tests) ---"
kill "${DAEMON_PID}" 2>/dev/null || true
wait "${DAEMON_PID}" 2>/dev/null || true
DAEMON_PID=""
# Reset state to ACTIVE with missed_count = MAX_MISSED (daemon trap may have set CLOSING)
jq \
  --argjson missed "${MAX_MISSED}" \
  '.heartbeat.missed_count = $missed | .status = "ACTIVE"' \
  "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"

# --- Test 6: check-stale marks instance STALE ---
echo "--- Test 6: Stale detection ---"
CHECK_OUTPUT=$("${SCRIPT_DIR}/check-stale.sh" "${TEST_DIR}/instances" "${MAX_MISSED}" 2>&1 || true)
echo "check-stale output:"
echo "${CHECK_OUTPUT}"

FINAL_STATUS=$(jq -r '.status' "${STATE_FILE}")
[ "${FINAL_STATUS}" = "STALE" ] && \
  pass "Instance marked STALE after missed=${MAX_MISSED}+1 heartbeats" || \
  fail "Instance status is ${FINAL_STATUS}, expected STALE"

# --- Test 7: check-stale exits 1 when stale found ---
echo "--- Test 7: Exit code check ---"
set +e
"${SCRIPT_DIR}/check-stale.sh" "${TEST_DIR}/instances" "${MAX_MISSED}" >/dev/null 2>&1
EC=$?
set -e
[ "${EC}" -eq 1 ] && \
  pass "check-stale exit code 1 (stale found)" || \
  fail "check-stale exit code ${EC}, expected 1"

# --- Test 8: cron mode output format ---
echo "--- Test 8: Cron mode ---"
CRON_OUTPUT=$("${SCRIPT_DIR}/check-stale.sh" "${TEST_DIR}/instances" "${MAX_MISSED}" --cron 2>&1 || true)
echo "cron output: ${CRON_OUTPUT}"
# Check for STALE|instance_id|role|count|timestamp format
if echo "${CRON_OUTPUT}" | grep -qE '^STALE\|[^|]+\|[^|]+\|[0-9]+\|.+'; then
  pass "Cron mode produces STALE|instance_id|role|missed|last_beat format"
else
  fail "Cron mode output unexpected: ${CRON_OUTPUT}"
fi

# --- Test 9: Revival from STALE to ACTIVE ---
echo "--- Test 9: Stale revival ---"
"${SCRIPT_DIR}/heartbeat-daemon.sh" "${INSTANCE_ID}" "${TEST_DIR}/instances" "${INTERVAL}" &
DAEMON_PID=$!
sleep $((INTERVAL + 1))

REVIVED_STATUS=$(jq -r '.status' "${STATE_FILE}")
[ "${REVIVED_STATUS}" = "ACTIVE" ] && \
  pass "Instance revived from STALE to ACTIVE after heartbeat" || \
  fail "Instance status is ${REVIVED_STATUS}, expected ACTIVE"

# --- Done -- trap handles cleanup and summary ---
echo ""
echo "--- All tests complete ---"
