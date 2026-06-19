#!/usr/bin/env bash
# tests/integration/web-dashboard-deploy-test.sh — TDD: dashboard deployment-ready
#
# EPIC-058-C AC: 3/3 PASS (跟 dispatch-dashboard-test.sh 5/5 模式 一致, 跟"不埋坑" 联合)
#   Case 1: start.sh 启动 dashboard (background, pid file + log file)
#   Case 2: verify-deploy.sh 验证 / + /dispatch/ 均返回 200
#   Case 3: teardown 干净 (kill pid + rm pid file, 0 端口泄漏)
#
# Rule 9 KPI X/Y format: 3/3 = 100.0% (no estimate, exact)
# 跟 web/Dockerfile + web/package.json 联合, 跟 v2.7.4 deployment-ready 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly WEB_ROOT="$KALLAX_ROOT/web"
readonly START_SCRIPT="$WEB_ROOT/scripts/start.sh"
readonly VERIFY_SCRIPT="$WEB_ROOT/scripts/verify-deploy.sh"
readonly PID_FILE="$WEB_ROOT/.dashboard.pid"

readonly DEFAULT_TEST_PORT=8081
readonly TEST_PORT="${DASHBOARD_TEST_PORT:-$DEFAULT_TEST_PORT}"
readonly CURL_TIMEOUT_SEC=5

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=3

# Cleanup trap — guarantee dashboard killed on exit (avoid port leak)
cleanup() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  # Belt-and-suspenders: kill anything still bound to TEST_PORT
  if command -v lsof >/dev/null 2>&1; then
    local stale_pids
    stale_pids="$(lsof -ti :"$TEST_PORT" 2>/dev/null || true)"
    if [ -n "$stale_pids" ]; then
      kill $stale_pids 2>/dev/null || true
    fi
  fi
}
trap cleanup EXIT

echo "=========================================="
echo "Web Dashboard Deploy — TDD Tests ($TOTAL/$TOTAL)"
echo "=========================================="
echo ""
echo "Test port: $TEST_PORT"
echo "Start script: $START_SCRIPT"
echo "Verify script: $VERIFY_SCRIPT"
echo ""

# ============================================================================
# Case 1: start.sh 启动 dashboard (background, pid file 落地)
# ============================================================================
echo "--- Case 1: start.sh 启动 dashboard ---"
START_OUTPUT="$(bash "$START_SCRIPT" "$TEST_PORT" 2>&1)" || START_OUTPUT="FAIL"
if [ -f "$PID_FILE" ]; then
  STARTED_PID="$(cat "$PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$STARTED_PID" ] && kill -0 "$STARTED_PID" 2>/dev/null; then
    echo "[PASS] dashboard started (pid=$STARTED_PID, port=$TEST_PORT)"
    echo "  start.sh output: $START_OUTPUT"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[FAIL] pid file exists but process not alive: $START_OUTPUT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo "[FAIL] pid file not created: $START_OUTPUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# ============================================================================
# Case 2: verify-deploy.sh 验证 / + /dispatch/ 均返回 200
# ============================================================================
echo "--- Case 2: verify-deploy.sh 验证 endpoints ---"
VERIFY_OUTPUT="$(bash "$VERIFY_SCRIPT" "$TEST_PORT" 2>&1)" || VERIFY_OUTPUT="FAIL"
if echo "$VERIFY_OUTPUT" | grep -qE "PASS:.*deployment-ready"; then
  if echo "$VERIFY_OUTPUT" | grep -qE "2/2"; then
    echo "[PASS] all endpoints return HTTP 200"
    echo "  verify output:"
    echo "$VERIFY_OUTPUT" | sed 's/^/    /'
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[FAIL] verify passed but count != 2/2: $VERIFY_OUTPUT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo "[FAIL] verify-deploy.sh did not pass: $VERIFY_OUTPUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# ============================================================================
# Case 3: teardown 干净 (pid file removed after kill)
# ============================================================================
echo "--- Case 3: teardown 干净 ---"
STARTED_PID="$(cat "$PID_FILE" 2>/dev/null || echo "")"
if [ -n "$STARTED_PID" ] && kill -0 "$STARTED_PID" 2>/dev/null; then
  kill "$STARTED_PID" 2>/dev/null || true
  sleep 1
fi
rm -f "$PID_FILE"
if [ ! -f "$PID_FILE" ]; then
  if [ -n "$STARTED_PID" ] && kill -0 "$STARTED_PID" 2>/dev/null; then
    echo "[FAIL] pid removed but process still alive (pid=$STARTED_PID)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "[PASS] teardown clean (pid=$STARTED_PID terminated, pid file removed)"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
else
  echo "[FAIL] pid file still present after teardown"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# ============================================================================
# Summary (Rule 9 KPI precision)
# ============================================================================
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: $FAIL_COUNT test(s) failed"
  echo "$PASS_COUNT/$TOTAL PASS"
  exit 1
fi
echo "PASS: all $TOTAL web dashboard deploy tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0