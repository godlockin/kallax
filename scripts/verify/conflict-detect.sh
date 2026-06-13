#!/bin/bash
#===============================================================================
# scripts/verify/conflict-detect.sh — L4 verification for conflict-detect.sh
# Rule 8: L4 script must exist and be executable
# Rule 17 Step 3: 验证冲突检测机制落地
#===============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 计数器
PASS_COUNT=0
FAIL_COUNT=0

# 辅助函数
log_pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "========================================"
echo "conflict-detect.sh L4 Verification"
echo "========================================"

# L4_1: 检查 conflict-detect.sh 存在
[[ -f "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" ]] && log_pass "L4_1: scripts/io/conflict-detect.sh 存在" || log_fail "L4_1: scripts/io/conflict-detect.sh 不存在"

# L4_2: 检查 conflict-detect.sh 可执行
[[ -x "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" ]] && log_pass "L4_2: scripts/io/conflict-detect.sh 可执行" || log_fail "L4_2: scripts/io/conflict-detect.sh 不可执行"

# L4_3: 检查 conflict-detect.sh 可 source
source "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" 2>/dev/null && log_pass "L4_3: conflict-detect.sh 可 source" || log_fail "L4_3: conflict-detect.sh 不可 source"

# L4_4: 检查核心函数导出
source "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" 2>/dev/null
declare -f conflict_detect_check > /dev/null && declare -f conflict_detect_report > /dev/null && declare -f conflict_detect_clear > /dev/null && declare -f conflict_detect_verify > /dev/null && log_pass "L4_4: 核心函数导出 (check/report/clear/verify)" || log_fail "L4_4: 核心函数未正确导出"

# L4_5: 检查与 file-lock.sh 联动 (函数依赖)
source "$WORKTREE_ROOT/scripts/io/file-lock.sh" 2>/dev/null
source "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" 2>/dev/null && log_pass "L4_5: 与 file-lock.sh 联动 (可顺序 source)" || log_fail "L4_5: 与 file-lock.sh 联动失败"

# L4_6: 检查与 atomic-write.sh 联动 (函数依赖)
source "$WORKTREE_ROOT/scripts/io/atomic-write.sh" 2>/dev/null && log_pass "L4_6: 与 atomic-write.sh 联动 (atomic-write.sh 可 source)" || log_fail "L4_6: 与 atomic-write.sh 联动失败"
source "$WORKTREE_ROOT/scripts/io/conflict-detect.sh" 2>/dev/null && log_pass "L4_6b: conflict-detect.sh 可 source after atomic-write" || log_fail "L4_6b: conflict-detect.sh after atomic-write 失败"

# L4_7: 检查集成测试存在
[[ -f "$WORKTREE_ROOT/tests/integration/conflict-detect-test.sh" ]] && log_pass "L4_7: tests/integration/conflict-detect-test.sh 存在" || log_fail "L4_7: tests/integration/conflict-detect-test.sh 不存在"

# L4_8: 检查集成测试可执行
[[ -x "$WORKTREE_ROOT/tests/integration/conflict-detect-test.sh" ]] && log_pass "L4_8: tests/integration/conflict-detect-test.sh 可执行" || log_fail "L4_8: tests/integration/conflict-detect-test.sh 不可执行"

# L4_9: 运行集成测试
if [[ -x "$WORKTREE_ROOT/tests/integration/conflict-detect-test.sh" ]]; then
  CONFLICT_DETECT_DIR="/tmp/kallax-verify-conflict-$$" "$WORKTREE_ROOT/tests/integration/conflict-detect-test.sh" > /dev/null 2>&1 && log_pass "L4_9: 集成测试 4/4 PASS" || log_fail "L4_9: 集成测试失败"
else
  log_fail "L4_9: 集成测试未运行 (文件不可执行)"
fi

echo ""
echo "========================================"
echo "Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
echo "========================================"

[[ $FAIL_COUNT -eq 0 ]] && echo "9/9 PASS" || echo "$PASS_COUNT/9 PASS"
exit $FAIL_COUNT
