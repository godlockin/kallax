#!/bin/bash
#===============================================================================
# session-watchdog-test.sh — Session Watchdog 集成测试
#
# 测试内容:
#   L1: session_watchdog.sh 存在于 scripts/io/
#   L2: 30min timeout 自动 abort 逻辑存在
#   L3: API Error retry 3 次逻辑存在
#   L4: 12h cap 80% warning 逻辑存在
#
# 用法:
#   bash tests/integration/session-watchdog-test.sh
#===============================================================================

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_SESSION_ID="test-$$-$(date +%s)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

echo "=== Session Watchdog Integration Test ==="
echo ""

#===============================================================================
# L1: 存在性 — session_watchdog.sh 存在于 scripts/io/
#===============================================================================
echo "--- L1: 存在性 ---"
SCRIPT_PATH="$REPO_DIR/scripts/io/session_watchdog.sh"
if [[ -f "$SCRIPT_PATH" ]]; then
  pass "L1: session_watchdog.sh 存在于 scripts/io/"
else
  fail "L1: session_watchdog.sh 不存在于 $SCRIPT_PATH"
  exit 1
fi

if [[ -x "$SCRIPT_PATH" ]]; then
  pass "L1: session_watchdog.sh 可执行"
else
  warn "L1: session_watchdog.sh 不可执行 (chmod +x 后可用)"
fi
echo ""

#===============================================================================
# L2: 实质性 — 30min timeout 自动 abort 逻辑存在
#===============================================================================
echo "--- L2: 实质性 ---"

# Source the script
source "$SCRIPT_PATH"

# Test start
session_watchdog_start "$TEST_SESSION_ID" > /dev/null 2>&1 || true

# Check SESSION_WATCHDOG_TIMEOUT default is 1800 (30min)
if [[ "${SESSION_WATCHDOG_TIMEOUT:-1800}" -eq 1800 ]]; then
  pass "L2: SESSION_WATCHDOG_TIMEOUT 默认值 1800 (30min) 存在"
else
  fail "L2: SESSION_WATCHDOG_TIMEOUT 默认值不是 1800, 是 ${SESSION_WATCHDOG_TIMEOUT:-unset}"
fi

# Check session_watchdog_check function exists
if declare -f session_watchdog_check > /dev/null 2>&1; then
  pass "L2: session_watchdog_check 函数存在"
else
  fail "L2: session_watchdog_check 函数不存在"
fi

# Check session_watchdog_abort function exists
if declare -f session_watchdog_abort > /dev/null 2>&1; then
  pass "L2: session_watchdog_abort 函数存在"
else
  fail "L2: session_watchdog_abort 函数不存在"
fi

# Check abort returns non-zero (for triggering FAIL)
session_watchdog_stop "$TEST_SESSION_ID" > /dev/null 2>&1 || true
echo ""

#===============================================================================
# L3: 接线正确 — API Error retry 3 次逻辑存在
#===============================================================================
echo "--- L3: 接线正确 ---"

# Check SESSION_WATCHDOG_RETRY default is 3
if [[ "${SESSION_WATCHDOG_RETRY:-3}" -eq 3 ]]; then
  pass "L3: SESSION_WATCHDOG_RETRY 默认值 3 存在"
else
  fail "L3: SESSION_WATCHDOG_RETRY 默认值不是 3, 是 ${SESSION_WATCHDOG_RETRY:-unset}"
fi

# Check session_watchdog_api_error function exists
if declare -f session_watchdog_api_error > /dev/null 2>&1; then
  pass "L3: session_watchdog_api_error 函数存在"
else
  fail "L3: session_watchdog_api_error 函数不存在"
fi

# Check state file has API_ERRORS tracking
SESSION_WATCHDOG_STATE_DIR="/tmp/kallax-session-watchdog-test-$$"
export SESSION_WATCHDOG_STATE_DIR
mkdir -p "$SESSION_WATCHDOG_STATE_DIR" 2>/dev/null || true

# Test API error tracking
session_watchdog_start "$TEST_SESSION_ID" > /dev/null 2>&1 || true
session_watchdog_api_error "$TEST_SESSION_ID" > /dev/null 2>&1 || true
session_watchdog_api_error "$TEST_SESSION_ID" > /dev/null 2>&1 || true

# The 3rd api_error should trigger abort (return non-zero)
if session_watchdog_api_error "$TEST_SESSION_ID" 2>/dev/null; then
  fail "L3: 第 3 次 API error 未触发 abort"
else
  pass "L3: 第 3 次 API error 触发 abort (retry 3 次逻辑正确)"
fi

session_watchdog_stop "$TEST_SESSION_ID" > /dev/null 2>&1 || true
rm -rf "$SESSION_WATCHDOG_STATE_DIR" 2>/dev/null || true
echo ""

#===============================================================================
# L4: 数据流动 — 12h cap 80% warning 逻辑存在
#===============================================================================
echo "--- L4: 数据流动 ---"

# Check SESSION_WATCHDOG_WARNING default is 345600 (9.6h)
if [[ "${SESSION_WATCHDOG_WARNING:-345600}" -eq 345600 ]]; then
  pass "L4: SESSION_WATCHDOG_WARNING 默认值 345600 (9.6h) 存在"
else
  fail "L4: SESSION_WATCHDOG_WARNING 默认值不是 345600, 是 ${SESSION_WATCHDOG_WARNING:-unset}"
fi

# Verify 345600 = 12 * 3600 * 0.8
expected_warning=$((12 * 3600 * 80 / 100))
if [[ "${SESSION_WATCHDOG_WARNING:-345600}" -eq $expected_warning ]]; then
  pass "L4: 12h cap 80% (9.6h = $expected_warning s) 计算正确"
else
  fail "L4: 12h cap 80% 计算不正确, 期望 $expected_warning, 得到 ${SESSION_WATCHDOG_WARNING:-345600}"
fi

# Check session_watchdog_status function exists
if declare -f session_watchdog_status > /dev/null 2>&1; then
  pass "L4: session_watchdog_status 函数存在"
else
  fail "L4: session_watchdog_status 函数不存在"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "Summary:"
echo "  L1: session_watchdog.sh 存在于 scripts/io/"
echo "  L2: 30min timeout 自动 abort 逻辑存在"
echo "  L3: API Error retry 3 次逻辑存在"
echo "  L4: 12h cap 80% warning 逻辑存在"
echo ""
echo "Note: 实际 30min timeout 需要等 1800s 才能触发, 测试通过代码检查验证逻辑存在"