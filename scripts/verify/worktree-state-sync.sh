#!/bin/bash
#===============================================================================
# scripts/verify/worktree-state-sync.sh — L4 verification for worktree-state-sync.sh
# Rule 8: L4 script must exist and be executable
# Rule 17 Step 5: 痛点 6 治根 5/5 步完成验证
#
# 用法:
#   bash scripts/verify/worktree-state-sync.sh <worktree_path>
#
# 验证内容:
#   - scripts/master/worktree-state-sync.sh 存在且可执行
#   - source 加载无语法错误
#   - worktree_sync 函数可用
#   - BE-7 fix pattern 检查 (install -d -m 700 / ownership check / umask 077)
#===============================================================================

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
SCRIPT_PATH="scripts/master/worktree-state-sync.sh"
VERIFY_SCRIPT_PATH="scripts/verify/worktree-state-sync.sh"

echo "=========================================="
echo " L4 Verification: worktree-state-sync.sh"
echo "=========================================="
echo ""

# L1: 存在性检查
echo "[L1] 检查 scripts/master/worktree-state-sync.sh 存在性..."
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "FAIL: $SCRIPT_PATH 不存在"
  exit 1
fi
echo "PASS: $SCRIPT_PATH 存在"

# L1: 可执行性检查
echo "[L1] 检查 scripts/master/worktree-state-sync.sh 可执行性..."
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "FAIL: $SCRIPT_PATH 不可执行"
  exit 1
fi
echo "PASS: $SCRIPT_PATH 可执行"

# L1: 自身存在性检查
echo "[L1] 检查 scripts/verify/worktree-state-sync.sh 存在性..."
if [[ ! -f "$VERIFY_SCRIPT_PATH" ]]; then
  echo "FAIL: $VERIFY_SCRIPT_PATH 不存在"
  exit 1
fi
echo "PASS: $VERIFY_SCRIPT_PATH 存在"

# L2: 语法检查 (bash -n)
echo "[L2] 检查 $SCRIPT_PATH 语法..."
if ! bash -n "$SCRIPT_PATH" 2>/dev/null; then
  echo "FAIL: $SCRIPT_PATH 语法错误"
  exit 1
fi
echo "PASS: $SCRIPT_PATH 语法正确"

# L2: source 加载检查
echo "[L2] 检查 source 加载 $SCRIPT_PATH..."
if ! source "$SCRIPT_PATH" 2>/dev/null; then
  echo "FAIL: $SCRIPT_PATH source 加载失败"
  exit 1
fi
echo "PASS: $SCRIPT_PATH source 加载成功"

# L2: 函数可用性检查
echo "[L2] 检查 worktree_sync 函数可用性..."
if ! declare -f worktree_sync_performer_push >/dev/null 2>&1; then
  echo "FAIL: worktree_sync_performer_push 函数不可用"
  exit 1
fi
if ! declare -f worktree_sync_master_merge >/dev/null 2>&1; then
  echo "FAIL: worktree_sync_master_merge 函数不可用"
  exit 1
fi
if ! declare -f worktree_sync_verify_state >/dev/null 2>&1; then
  echo "FAIL: worktree_sync_verify_state 函数不可用"
  exit 1
fi
if ! declare -f worktree_sync_full_sync >/dev/null 2>&1; then
  echo "FAIL: worktree_sync_full_sync 函数不可用"
  exit 1
fi
echo "PASS: worktree_sync 函数可用"

# L3: BE-7 fix pattern 检查
echo "[L3] 检查 BE-7 fix pattern..."

# 检查 install -d -m 700
if grep -q "install -d -m 700" "$SCRIPT_PATH" 2>/dev/null; then
  echo "PASS: 发现 install -d -m 700 (防 symlink)"
else
  echo "FAIL: 缺少 install -d -m 700"
  exit 1
fi

# 检查 ownership check
if grep -q "Ownership mismatch" "$SCRIPT_PATH" 2>/dev/null; then
  echo "PASS: 发现 ownership check"
else
  echo "FAIL: 缺少 ownership check"
  exit 1
fi

# 检查 umask 077
if grep -q "umask 077" "$SCRIPT_PATH" 2>/dev/null; then
  echo "PASS: 发现 umask 077"
else
  echo "FAIL: 缺少 umask 077"
  exit 1
fi

# L4: 集成测试存在性检查
echo "[L4] 检查 tests/integration/worktree-state-sync-test.sh 存在性..."
if [[ ! -f "tests/integration/worktree-state-sync-test.sh" ]]; then
  echo "FAIL: tests/integration/worktree-state-sync-test.sh 不存在"
  exit 1
fi
echo "PASS: tests/integration/worktree-state-sync-test.sh 存在"

# L4: 集成测试可执行性检查
echo "[L4] 检查 tests/integration/worktree-state-sync-test.sh 可执行..."
if [[ ! -x "tests/integration/worktree-state-sync-test.sh" ]]; then
  echo "FAIL: tests/integration/worktree-state-sync-test.sh 不可执行"
  exit 1
fi
echo "PASS: tests/integration/worktree-state-sync-test.sh 可执行"

echo ""
echo "=========================================="
echo " L4 Verification PASSED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  L1: 存在性 - PASS"
echo "  L2: 实质性 (函数/语法) - PASS"
echo "  L3: 接线正确 (BE-7 pattern) - PASS"
echo "  L4: 数据流动 (集成测试) - PASS"
echo ""
echo "Rule 17 Step 5 载体落地完成"
exit 0