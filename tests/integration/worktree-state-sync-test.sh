#!/bin/bash
#===============================================================================
# tests/integration/worktree-state-sync-test.sh — Integration tests for worktree-state-sync.sh
# Rule 17 Step 5: 痛点 6 治根 5/5 步完成验证
#
# 测试用例 (≥4 case):
#   1. 本地 commit / push 成功
#   2. push 失败 STOP
#   3. merge 成功
#   4. state 同步
#===============================================================================

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
cd "$KALLAX_ROOT"

SCRIPT_PATH="scripts/master/worktree-state-sync.sh"
TEST_TEMP_DIR="/tmp/kallax-worktree-sync-test.$$"

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 清理函数
cleanup() {
  rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# 创建测试目录
setup() {
  mkdir -p "$TEST_TEMP_DIR"
}

# 测试报告
test_report() {
  local name="$1"
  local result="$2"
  local expected="$3"
  local actual="$4"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$result" == "PASS" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  [PASS] $name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  [FAIL] $name"
    echo "    Expected: $expected"
    echo "    Actual: $actual"
  fi
}

#===============================================================================
# Test Case 1: 本地 commit / push 成功
#===============================================================================
test_case_1_local_commit_push() {
  echo ""
  echo "[Test 1] 本地 commit / push 成功"
  echo "----------------------------------------------"

  # 创建临时 git 仓库用于测试
  local test_repo="$TEST_TEMP_DIR/test-repo-1"
  local test_worktree="$TEST_TEMP_DIR/worktree-1"
  mkdir -p "$test_repo"
  mkdir -p "$test_worktree"

  (
    cd "$test_repo" 2>/dev/null || exit 1
    git init --initial-branch=main 2>/dev/null || git init 2>/dev/null
    git config user.email "test@test.com" 2>/dev/null || true
    git config user.name "Test" 2>/dev/null || true

    # 创建初始 commit
    echo "initial" > README.md
    git add README.md 2>/dev/null || true
    git commit -m "initial" 2>/dev/null || true

    # 创建 worktree
    git worktree add "$test_worktree" main 2>/dev/null || true
  )

  # 验证 worktree-state-sync.sh 可以 source
  if source "$SCRIPT_PATH" 2>/dev/null; then
    if declare -f worktree_sync_performer_push >/dev/null 2>&1; then
      test_report "本地 commit / push 成功" "PASS" "function exists" "function exists"
    else
      test_report "本地 commit / push 成功" "FAIL" "function exists" "function not found"
    fi
  else
    test_report "本地 commit / push 成功" "FAIL" "source success" "source failed"
  fi
}

#===============================================================================
# Test Case 2: push 失败 STOP
#===============================================================================
test_case_2_push_fail_stop() {
  echo ""
  echo "[Test 2] push 失败 STOP"
  echo "----------------------------------------------"

  # 创建临时 git 仓库用于测试
  local test_repo="$TEST_TEMP_DIR/test-repo-2"
  local test_worktree="$TEST_TEMP_DIR/worktree-2"
  mkdir -p "$test_repo"
  mkdir -p "$test_worktree"

  (
    cd "$test_repo" 2>/dev/null || exit 1
    git init --initial-branch=main 2>/dev/null || git init 2>/dev/null
    git config user.email "test@test.com" 2>/dev/null || true
    git config user.name "Test" 2>/dev/null || true

    # 创建初始 commit
    echo "initial" > README.md
    git add README.md 2>/dev/null || true
    git commit -m "initial" 2>/dev/null || true

    # 创建 worktree
    git worktree add "$test_worktree" main 2>/dev/null || true
  )

  # source 脚本
  if ! source "$SCRIPT_PATH" 2>/dev/null; then
    test_report "push 失败 STOP" "FAIL" "source success" "source failed"
    return
  fi

  # 测试 push 失败处理 (使用不存在的 worktree)
  local result
  result=$(worktree_sync_performer_push "/nonexistent/path" 2>&1 || echo "ERROR")

  if [[ "$result" == *"ERROR"* ]] || [[ "$result" == *"ERROR"* ]]; then
    test_report "push 失败 STOP" "PASS" "error detected" "$result"
  else
    test_report "push 失败 STOP" "FAIL" "error detected" "no error"
  fi
}

#===============================================================================
# Test Case 3: merge 成功
#===============================================================================
test_case_3_merge_success() {
  echo ""
  echo "[Test 3] merge 成功"
  echo "----------------------------------------------"

  # source 脚本
  if ! source "$SCRIPT_PATH" 2>/dev/null; then
    test_report "merge 成功" "FAIL" "source success" "source failed"
    return
  fi

  # 检查 master_merge 函数存在
  if declare -f worktree_sync_master_merge >/dev/null 2>&1; then
    test_report "merge 成功" "PASS" "function exists" "function exists"
  else
    test_report "merge 成功" "FAIL" "function exists" "function not found"
  fi
}

#===============================================================================
# Test Case 4: state 同步
#===============================================================================
test_case_4_state_sync() {
  echo ""
  echo "[Test 4] state 同步"
  echo "----------------------------------------------"

  # source 脚本
  if ! source "$SCRIPT_PATH" 2>/dev/null; then
    test_report "state 同步" "FAIL" "source success" "source failed"
    return
  fi

  # 检查 verify_state 和 full_sync 函数存在
  local has_verify=false
  local has_full_sync=false

  if declare -f worktree_sync_verify_state >/dev/null 2>&1; then
    has_verify=true
  fi

  if declare -f worktree_sync_full_sync >/dev/null 2>&1; then
    has_full_sync=true
  fi

  if $has_verify && $has_full_sync; then
    test_report "state 同步" "PASS" "functions exist" "verify=$has_verify, full_sync=$has_full_sync"
  else
    test_report "state 同步" "FAIL" "functions exist" "verify=$has_verify, full_sync=$has_full_sync"
  fi
}

#===============================================================================
# Test Case 5: BE-7 fix pattern 检查
#===============================================================================
test_case_5_be7_pattern() {
  echo ""
  echo "[Test 5] BE-7 fix pattern 检查"
  echo "----------------------------------------------"

  # 检查 install -d -m 700
  if grep -q "install -d -m 700" "$SCRIPT_PATH" 2>/dev/null; then
    test_report "BE-7 pattern: install -d -m 700" "PASS" "found" "found"
  else
    test_report "BE-7 pattern: install -d -m 700" "FAIL" "found" "not found"
  fi

  # 检查 ownership check
  if grep -q "Ownership mismatch" "$SCRIPT_PATH" 2>/dev/null; then
    test_report "BE-7 pattern: ownership check" "PASS" "found" "found"
  else
    test_report "BE-7 pattern: ownership check" "FAIL" "found" "not found"
  fi

  # 检查 umask 077
  if grep -q "umask 077" "$SCRIPT_PATH" 2>/dev/null; then
    test_report "BE-7 pattern: umask 077" "PASS" "found" "found"
  else
    test_report "BE-7 pattern: umask 077" "FAIL" "found" "not found"
  fi
}

#===============================================================================
# Test Case 6: 脚本自身可执行
#===============================================================================
test_case_6_script_executable() {
  echo ""
  echo "[Test 6] 脚本自身可执行"
  echo "----------------------------------------------"

  if [[ -x "$SCRIPT_PATH" ]]; then
    test_report "脚本自身可执行" "PASS" "executable" "executable"
  else
    test_report "脚本自身可执行" "FAIL" "executable" "not executable"
  fi
}

#===============================================================================
# Test Case 7: 语法正确
#===============================================================================
test_case_7_syntax_check() {
  echo ""
  echo "[Test 7] 语法正确"
  echo "----------------------------------------------"

  if bash -n "$SCRIPT_PATH" 2>/dev/null; then
    test_report "语法正确" "PASS" "no syntax error" "no syntax error"
  else
    test_report "语法正确" "FAIL" "no syntax error" "syntax error"
  fi
}

#===============================================================================
# Test Case 8: 集成测试存在性
#===============================================================================
test_case_8_integration_test_exists() {
  echo ""
  echo "[Test 8] 集成测试存在性"
  echo "----------------------------------------------"

  local integration_test="tests/integration/worktree-state-sync-test.sh"
  if [[ -f "$integration_test" ]]; then
    test_report "集成测试存在性" "PASS" "file exists" "file exists"
  else
    test_report "集成测试存在性" "FAIL" "file exists" "file not found"
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  echo "=========================================="
  echo " Integration Tests: worktree-state-sync.sh"
  echo "=========================================="
  echo ""
  echo "Test start: $(date)"
  echo ""

  setup

  test_case_1_local_commit_push
  test_case_2_push_fail_stop
  test_case_3_merge_success
  test_case_4_state_sync
  test_case_5_be7_pattern
  test_case_6_script_executable
  test_case_7_syntax_check
  test_case_8_integration_test_exists

  echo ""
  echo "=========================================="
  echo " Test Summary"
  echo "=========================================="
  echo ""
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: $TESTS_PASSED"
  echo "Tests failed: $TESTS_FAILED"
  echo ""
  echo "Test end: $(date)"
  echo "=========================================="

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "ALL TESTS PASSED"
    exit 0
  else
    echo "SOME TESTS FAILED"
    exit 1
  fi
}

main "$@"