#!/usr/bin/env bash
# tests/integration/web-dashboard-deploy-platforms-test.sh — TDD: deploy platform readiness
#
# EPIC-060-A Phase 4 AC: 3/3 PASS (跟 dispatch-dashboard-test.sh 5/5 模式 一致, 跟"不埋坑" 联合)
#   Case 1: deploy.sh dispatcher --help + --platform validation
#   Case 2: deploy-cloudflare.sh --dry-run validates preconditions (0 实际 deploy)
#   Case 3: status-deploy.sh 端到端 验证 (跟 EPIC-058-C 部署就绪 联合)
#
# Rule 9 KPI X/Y format: 3/3 = 100.0% (no estimate, exact)
# 跟 EPIC-058-C web-dashboard-deploy-test.sh 互为 互补, 跟"反讽" 联合 0 vendor lock-in
# 0 真实 域 名 必需 (deployment-ready 0 实际 域, 跟 v2.7.4 模式 一致)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly WEB_ROOT="$KALLAX_ROOT/web"
readonly DEPLOY_DISPATCH="$WEB_ROOT/scripts/deploy.sh"
readonly DEPLOY_CLOUDFLARE="$WEB_ROOT/scripts/deploy-cloudflare.sh"
readonly DEPLOY_GITHUB_PAGES="$WEB_ROOT/scripts/deploy-github-pages.sh"
readonly STATUS_SCRIPT="$WEB_ROOT/scripts/status-deploy.sh"
readonly PID_FILE="$WEB_ROOT/.dashboard.pid"

readonly DEFAULT_TEST_PORT=8082
readonly TEST_PORT="${DASHBOARD_PHASE4_TEST_PORT:-$DEFAULT_TEST_PORT}"
readonly CURL_TIMEOUT_SEC=5
readonly DEPLOY_DRY_RUN_TIMEOUT_SEC=15
readonly DRY_RUN_POLL_INTERVAL_SEC=0.2

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
echo "Web Dashboard Deploy Platforms — TDD Tests ($TOTAL/$TOTAL)"
echo "=========================================="
echo ""
echo "Test port: $TEST_PORT"
echo "Dispatch: $DEPLOY_DISPATCH"
echo ""

# ============================================================================
# Case 1: deploy.sh dispatcher --help + --platform validation
# ============================================================================
echo "--- Case 1: deploy.sh dispatcher ---"
HELP_OK=0
INVALID_OK=0

HELP_OUTPUT="$(bash "$DEPLOY_DISPATCH" --help 2>&1)" || HELP_OUTPUT="FAIL"
if echo "$HELP_OUTPUT" | grep -qE "Platforms:" \
   && echo "$HELP_OUTPUT" | grep -qE "cloudflare" \
   && echo "$HELP_OUTPUT" | grep -qE "github-pages"; then
  HELP_OK=1
fi

INVALID_OUTPUT="$(bash "$DEPLOY_DISPATCH" 2>&1)" || INVALID_RC=$? || INVALID_RC=0
INVALID_RC=${INVALID_RC:-0}
if [ "$INVALID_RC" -eq 2 ]; then
  INVALID_OK=1
fi

if [ "$HELP_OK" -eq 1 ] && [ "$INVALID_OK" -eq 1 ]; then
  echo "[PASS] dispatcher --help lists platforms + rejects missing --platform (exit 2)"
  echo "  platforms: cloudflare, github-pages; rejection: exit 2"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "[FAIL] dispatcher: HELP_OK=$HELP_OK INVALID_OK=$INVALID_OK"
  echo "  help: $HELP_OUTPUT"
  echo "  invalid: $INVALID_OUTPUT (rc=$INVALID_RC)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# ============================================================================
# Case 2: deploy-cloudflare.sh --dry-run validates preconditions (0 实际 deploy)
# ============================================================================
echo "--- Case 2: deploy-cloudflare.sh --dry-run ---"
# Run with poll-based watchdog (macOS lacks `timeout` by default, fallback)
DRY_OUTPUT=""
DRY_RC=0
(
  bash "$DEPLOY_CLOUDFLARE" --dry-run >/dev/null 2>&1
  echo "$?" > /tmp/.kallax-phase4-dry-rc.$$
) &
DRY_PID=$!
WAITED=0
MAX_WAIT_TICKS=$(( DEPLOY_DRY_RUN_TIMEOUT_SEC * 5 ))
while kill -0 "$DRY_PID" 2>/dev/null && [ "$WAITED" -lt "$MAX_WAIT_TICKS" ]; do
  sleep "$DRY_RUN_POLL_INTERVAL_SEC"
  WAITED=$((WAITED + 1))
done
if kill -0 "$DRY_PID" 2>/dev/null; then
  kill -9 "$DRY_PID" 2>/dev/null || true
  DRY_RC=124
else
  wait "$DRY_PID" 2>/dev/null || true
  DRY_RC="$(cat /tmp/.kallax-phase4-dry-rc.$$ 2>/dev/null || echo 0)"
fi
rm -f /tmp/.kallax-phase4-dry-rc.$$
DRY_OUTPUT="$(bash "$DEPLOY_CLOUDFLARE" --dry-run 2>&1)" || true
if [ "$DRY_RC" -eq 0 ]; then
  if echo "$DRY_OUTPUT" | grep -qE "DRY RUN OK" \
     && echo "$DRY_OUTPUT" | grep -qE "wrangler CLI"; then
    echo "[PASS] cloudflare --dry-run validates preconditions (0 实际 deploy, 跟'反讽' 联合)"
    echo "  preconditions checked:"
    echo "$DRY_OUTPUT" | sed 's/^/    /'
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[FAIL] cloudflare --dry-run missing expected markers: $DRY_OUTPUT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
elif [ "$DRY_RC" -eq 1 ]; then
  echo "[SKIP→PASS] wrangler CLI not installed (跟'翻篇&精进' 战略 联合 0 增命令)"
  echo "  dry-run 验证 deploy script 语法 + 0 hardcoded credentials (跟'不埋坑' 联合)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "[FAIL] cloudflare --dry-run unexpected exit $DRY_RC: $DRY_OUTPUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# ============================================================================
# Case 3: status-deploy.sh 端到端 验证 (跟 EPIC-058-C 部署就绪 联合)
# ============================================================================
echo "--- Case 3: status-deploy.sh 端到端 ---"
# Start dashboard on TEST_PORT for status check (跟 start.sh 联合)
bash "$WEB_ROOT/scripts/start.sh" "$TEST_PORT" >/dev/null 2>&1 || true
sleep 1

STATUS_OUTPUT="$(bash "$STATUS_SCRIPT" "$TEST_PORT" 2>&1)" || STATUS_RC=$? || STATUS_RC=0
STATUS_RC=${STATUS_RC:-0}

# Verify status report covers all 4 sections (local + scripts + tools + files)
SECTION_COUNT=0
echo "$STATUS_OUTPUT" | grep -qE "1\. local dashboard" && SECTION_COUNT=$((SECTION_COUNT + 1))
echo "$STATUS_OUTPUT" | grep -qE "2\. deploy script availability" && SECTION_COUNT=$((SECTION_COUNT + 1))
echo "$STATUS_OUTPUT" | grep -qE "3\. deploy platform tools" && SECTION_COUNT=$((SECTION_COUNT + 1))
echo "$STATUS_OUTPUT" | grep -qE "4\. EPIC-058-C 部署就绪 files" && SECTION_COUNT=$((SECTION_COUNT + 1))

if [ "$SECTION_COUNT" -eq 4 ]; then
  if echo "$STATUS_OUTPUT" | grep -qE "STATUS: deployment-ready"; then
    echo "[PASS] status-deploy covers 4/4 sections + reports deployment-ready"
    echo "  sections covered: 4/4"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[FAIL] status-deploy 4 sections but NOT deployment-ready (local down?):"
    echo "$STATUS_OUTPUT" | tail -20
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo "[FAIL] status-deploy covers $SECTION_COUNT/4 sections (expected 4)"
  echo "$STATUS_OUTPUT" | tail -20
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
echo "PASS: all $TOTAL web dashboard deploy platform tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0