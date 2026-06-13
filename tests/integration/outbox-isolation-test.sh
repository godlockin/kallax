#!/bin/bash
#===============================================================================
# outbox-isolation-test.sh — Integration tests for outbox-isolation.sh
# Rule 17 Step 4: 4+ test cases
#   1. 无冲突检测 (no conflict)
#   2. 冲突检测 (conflict detected)
#   3. 冲突 STOP (conflict STOP)
#   4. 跨 role 冲突 (cross-role conflict)
#===============================================================================

set -euo pipefail

readonly TEST_DIR="/tmp/kallax-outbox-test-$$"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 使用独立的 outbox 目录 (避免跟其他测试冲突)
export OUTBOX_BASE="$TEST_DIR/.outbox"

# 计数器
PASS_COUNT=0
FAIL_COUNT=0

# 测试辅助函数
log_pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

cleanup() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# 初始化测试目录
setup() {
  mkdir -p "$TEST_DIR"
  chmod 700 "$TEST_DIR"
}

#===============================================================================
# Test 1: 无冲突检测 (no conflict)
#===============================================================================
test_no_conflict() {
  echo ""
  echo "=== Test 1: 无冲突检测 (no conflict) ==="

  setup

  # Source outbox-isolation.sh
  source "$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"

  # 初始化 conductor 的 outbox
  outbox_init "conductor" "test-$$-conductor"

  # 创建文件
  local test_file
  test_file="$(outbox_resolve_path "test-file.txt")"

  mkdir -p "$(dirname "$test_file")"
  echo "test content" > "$test_file"

  # 验证写操作应该成功 (无冲突)
  if outbox_validate_write "$test_file"; then
    log_pass "test_no_conflict: 无冲突检测通过"
    return 0
  else
    log_fail "test_no_conflict: 预期无冲突但检测到冲突"
    return 1
  fi
}

#===============================================================================
# Test 2: 冲突检测 (conflict detected)
#===============================================================================
test_conflict_detected() {
  echo ""
  echo "=== Test 2: 冲突检测 (conflict detected) ==="

  setup

  # Source outbox-isolation.sh
  source "$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"

  # 初始化 conductor 的 outbox
  outbox_init "conductor" "test-$$-conductor"

  # 创建文件
  local test_file
  test_file="$(outbox_resolve_path "test-conflict.txt")"

  mkdir -p "$(dirname "$test_file")"
  echo "test content" > "$test_file"

  # 初始化另一个 performer 的 outbox (模拟跨 subagent 冲突)
  outbox_init "performer" "test-$$-performer"

  # 尝试写入 conductor 的文件, 应该检测到冲突
  if outbox_validate_write "$test_file" 2>/dev/null; then
    log_fail "test_conflict_detected: 预期检测到冲突但无冲突"
    return 1
  else
    log_pass "test_conflict_detected: 冲突检测通过"
    return 0
  fi
}

#===============================================================================
# Test 3: 冲突 STOP (conflict STOP)
#===============================================================================
test_conflict_stop() {
  echo ""
  echo "=== Test 3: 冲突 STOP (conflict STOP) ==="

  setup

  # Source outbox-isolation.sh
  source "$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"

  # 初始化 conductor 的 outbox
  outbox_init "conductor" "test-$$-conductor"

  # 创建文件
  local test_file
  test_file="$(outbox_resolve_path "test-stop.txt")"

  mkdir -p "$(dirname "$test_file")"
  echo "test content" > "$test_file"

  # 初始化另一个 conductor 的 outbox (同一 role, 不同 instance)
  outbox_init "conductor" "test-$$-conductor-2"

  # 尝试写入第一个 conductor 的文件, 应该 STOP + 报错
  local result=0
  outbox_validate_write "$test_file" 2>/dev/null || result=$?

  if [[ $result -ne 0 ]]; then
    log_pass "test_conflict_stop: 冲突 STOP + 报错通过"
    return 0
  else
    log_fail "test_conflict_stop: 预期冲突 STOP 但未正确处理"
    return 1
  fi
}

#===============================================================================
# Test 4: 跨 role 冲突 (cross-role conflict)
#===============================================================================
test_cross_role_conflict() {
  echo ""
  echo "=== Test 4: 跨 role 冲突 (cross-role conflict) ==="

  setup

  # Source outbox-isolation.sh
  source "$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"

  # 初始化 conductor 的 outbox
  outbox_init "conductor" "test-$$-conductor"

  # 创建 conductor 的文件
  local conductor_file
  conductor_file="$(outbox_resolve_path "cross-role.txt")"
  mkdir -p "$(dirname "$conductor_file")"
  echo "conductor content" > "$conductor_file"

  # 初始化 auditor 的 outbox
  outbox_init "auditor" "test-$$-auditor"

  # 尝试写入 conductor 的文件, 应该检测到跨 role 冲突
  if outbox_validate_write "$conductor_file" 2>/dev/null; then
    log_fail "test_cross_role_conflict: 预期检测到跨 role 冲突但无冲突"
    return 1
  else
    log_pass "test_cross_role_conflict: 跨 role 冲突检测通过"
    return 0
  fi
}

#===============================================================================
# Test 5: 路径遍历攻击防护
#===============================================================================
test_path_traversal_protection() {
  echo ""
  echo "=== Test 5: 路径遍历攻击防护 ==="

  setup

  # Source outbox-isolation.sh
  source "$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"

  # 初始化 conductor 的 outbox
  outbox_init "conductor" "test-$$-conductor"

  # 尝试路径遍历攻击
  local result=0
  outbox_resolve_path "../../../etc/passwd" 2>/dev/null || result=$?

  if [[ $result -ne 0 ]]; then
    log_pass "test_path_traversal_protection: 路径遍历攻击防护通过"
    return 0
  else
    log_fail "test_path_traversal_protection: 预期拒绝路径遍历但未拒绝"
    return 1
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  echo "========================================"
  echo "outbox-isolation-test.sh — 5 Test Cases"
  echo "========================================"

  test_no_conflict
  test_conflict_detected
  test_conflict_stop
  test_cross_role_conflict
  test_path_traversal_protection

  echo ""
  echo "========================================"
  echo "Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "5/5 PASS"
    exit 0
  else
    echo "$PASS_COUNT/5 PASS"
    exit 1
  fi
}

main "$@"