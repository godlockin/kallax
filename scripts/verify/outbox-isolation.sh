#!/bin/bash
#===============================================================================
# scripts/verify/outbox-isolation.sh — L4 verification for outbox-isolation.sh
# Rule 8: L4 script must exist and be executable
# Rule 17 Step 4: outbox-isolation 验证载体
#
# 验证内容:
#   L1: scripts/io/outbox-isolation.sh 存在
#   L2: tests/integration/outbox-isolation-test.sh 存在且可执行
#   L3: 脚本包含所需函数 (outbox_init, outbox_check_ownership, etc.)
#   L4: 测试可运行 (dry-run 模式)
#===============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly OUTBOX_IO_SCRIPT="$WORKTREE_ROOT/scripts/io/outbox-isolation.sh"
readonly OUTBOX_TEST_SCRIPT="$WORKTREE_ROOT/tests/integration/outbox-isolation-test.sh"

# 计数器
PASS_COUNT=0
FAIL_COUNT=0

# 辅助函数
log_pass() {
  echo "[PASS] L$1: $2"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
  echo "[FAIL] L$1: $2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

#===============================================================================
# L1: scripts/io/outbox-isolation.sh 存在
#===============================================================================
verify_l1() {
  echo ""
  echo "=== L1: outbox-isolation.sh 存在性 ==="

  if [[ -f "$OUTBOX_IO_SCRIPT" ]]; then
    log_pass 1 "outbox-isolation.sh 存在: $OUTBOX_IO_SCRIPT"
    return 0
  else
    log_fail 1 "outbox-isolation.sh 不存在: $OUTBOX_IO_SCRIPT"
    return 1
  fi
}

#===============================================================================
# L2: tests/integration/outbox-isolation-test.sh 存在且可执行
#===============================================================================
verify_l2() {
  echo ""
  echo "=== L2: outbox-isolation-test.sh 存在且可执行 ==="

  if [[ ! -f "$OUTBOX_TEST_SCRIPT" ]]; then
    log_fail 2 "outbox-isolation-test.sh 不存在: $OUTBOX_TEST_SCRIPT"
    return 1
  fi

  if [[ ! -x "$OUTBOX_TEST_SCRIPT" ]]; then
    log_fail 2 "outbox-isolation-test.sh 不可执行: $OUTBOX_TEST_SCRIPT"
    return 1
  fi

  log_pass 2 "outbox-isolation-test.sh 存在且可执行: $OUTBOX_TEST_SCRIPT"
  return 0
}

#===============================================================================
# L3: 脚本包含所需函数
#===============================================================================
verify_l3() {
  echo ""
  echo "=== L3: 所需函数完整性 ==="

  if [[ ! -f "$OUTBOX_IO_SCRIPT" ]]; then
    log_fail 3 "outbox-isolation.sh 不存在, 无法验证函数"
    return 1
  fi

  local required_functions=(
    "outbox_init"
    "outbox_check_ownership"
    "outbox_resolve_path"
    "outbox_validate_write"
    "outbox_list"
    "outbox_cleanup"
  )

  local all_present=true
  for func in "${required_functions[@]}"; do
    if grep -q "^${func}()" "$OUTBOX_IO_SCRIPT" 2>/dev/null; then
      echo "  [OK] $func"
    else
      echo "  [MISSING] $func"
      all_present=false
    fi
  done

  if $all_present; then
    log_pass 3 "所需函数完整 (6/6)"
    return 0
  else
    log_fail 3 "缺少所需函数"
    return 1
  fi
}

#===============================================================================
# L4: 测试可运行 (dry-run: 检查语法)
#===============================================================================
verify_l4() {
  echo ""
  echo "=== L4: 测试可运行 (dry-run) ==="

  if [[ ! -f "$OUTBOX_TEST_SCRIPT" ]]; then
    log_fail 4 "outbox-isolation-test.sh 不存在"
    return 1
  fi

  # bash -n 语法检查
  if bash -n "$OUTBOX_TEST_SCRIPT" 2>/dev/null; then
    log_pass 4 "outbox-isolation-test.sh 语法正确 (dry-run PASS)"
    return 0
  else
    log_fail 4 "outbox-isolation-test.sh 语法错误"
    return 1
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  echo "========================================"
  echo "outbox-isolation.sh L4 Verification"
  echo "========================================"

  verify_l1 || true
  verify_l2 || true
  verify_l3 || true
  verify_l4 || true

  echo ""
  echo "========================================"
  echo "L4 Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "4/4 PASS"
    exit 0
  else
    echo "$PASS_COUNT/4 PASS"
    exit 1
  fi
}

main "$@"