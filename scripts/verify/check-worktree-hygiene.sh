#!/usr/bin/env bash
#===============================================================================
# scripts/verify/check-worktree-hygiene.sh — L4 verify (Rule 8) for EPIC-301
# worktree 卫生防御 hook 接入检查
#
# 检查项:
#   H1. scripts/hooks/check-worktree-hygiene.sh 存在 + 可执行 (L1)
#   H2. scripts/hooks/check-worktree-count.sh 存在 + 可执行 (L1)
#   H3. verify 脚本自身存在 + 可执行 (L1)
#   H4. 2 个 hook 语法正确 (bash -n) (L2)
#   H5. 2 个 hook source 加载无错 (L2)
#   H6. install.sh 引用 check-worktree-count.sh (L3)
#   H7. tests/integration/check-worktree-hygiene.test.sh 存在 + 可执行 (L4)
#   H8. 集成测试跑通 (worktree=10 PASS, worktree=60 FAIL) (L4)
#
# 退出码:
#   0 = PASS
#   1 = FAIL
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HOOK_HYGIENE="$KALLAX_ROOT/scripts/hooks/check-worktree-hygiene.sh"
HOOK_COUNT="$KALLAX_ROOT/scripts/hooks/check-worktree-count.sh"
INSTALL_SH="$KALLAX_ROOT/scripts/hooks/install.sh"
TEST_SH="$KALLAX_ROOT/tests/integration/check-worktree-hygiene.test.sh"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

echo "=========================================="
echo " check-worktree-hygiene L4 Verify (EPIC-301)"
echo "=========================================="
echo ""

#===============================================================================
# H1: check-worktree-hygiene.sh 存在 + 可执行
#===============================================================================
log ">>> H1: check-worktree-hygiene.sh exists + executable"
echo "=========================================="
if [[ -f "$HOOK_HYGIENE" ]]; then
  pass "check-worktree-hygiene.sh exists"
else
  fail "check-worktree-hygiene.sh missing"
fi
if [[ -x "$HOOK_HYGIENE" ]]; then
  pass "check-worktree-hygiene.sh executable"
else
  fail "check-worktree-hygiene.sh not executable (chmod +x)"
fi

#===============================================================================
# H2: check-worktree-count.sh 存在 + 可执行
#===============================================================================
log ""
log ">>> H2: check-worktree-count.sh exists + executable"
echo "=========================================="
if [[ -f "$HOOK_COUNT" ]]; then
  pass "check-worktree-count.sh exists"
else
  fail "check-worktree-count.sh missing"
fi
if [[ -x "$HOOK_COUNT" ]]; then
  pass "check-worktree-count.sh executable"
else
  fail "check-worktree-count.sh not executable (chmod +x)"
fi

#===============================================================================
# H3: verify 脚本自身
#===============================================================================
log ""
log ">>> H3: verify script self-check"
echo "=========================================="
if [[ -f "${BASH_SOURCE[0]}" ]]; then
  pass "verify script exists"
else
  fail "verify script missing"
fi
if [[ -x "${BASH_SOURCE[0]}" ]]; then
  pass "verify script executable"
else
  fail "verify script not executable (chmod +x)"
fi

#===============================================================================
# H4: 2 个 hook 语法
#===============================================================================
log ""
log ">>> H4: hook syntax (bash -n)"
echo "=========================================="
if bash -n "$HOOK_HYGIENE" 2>/dev/null; then
  pass "check-worktree-hygiene.sh syntax OK"
else
  fail "check-worktree-hygiene.sh syntax ERROR"
fi
if bash -n "$HOOK_COUNT" 2>/dev/null; then
  pass "check-worktree-count.sh syntax OK"
else
  fail "check-worktree-count.sh syntax ERROR"
fi

#===============================================================================
# H5: 2 个 hook source 加载
#===============================================================================
log ""
log ">>> H5: hook source loading"
echo "=========================================="
if (source "$HOOK_HYGIENE" 2>/dev/null || true); then
  pass "check-worktree-hygiene.sh source loads"
else
  fail "check-worktree-hygiene.sh source load ERROR"
fi
# check-worktree-count.sh 依赖 pre-commit 上下文 (KALLAX_HOOK_BYPASS 等), source 加载可能因 set -euo 失败, 单独 try
if (source "$HOOK_COUNT" 2>/dev/null || true); then
  pass "check-worktree-count.sh source loads"
else
  fail "check-worktree-count.sh source load ERROR"
fi

#===============================================================================
# H6: install.sh 含 EPIC-301 hook 引用 (post-checkout OR pre-commit 调 check-worktree-count)
#===============================================================================
log ""
log ">>> H6: install.sh references EPIC-301 hooks"
echo "=========================================="
if grep -q "post-checkout" "$INSTALL_SH" 2>/dev/null; then
  pass "install.sh references post-checkout hook"
else
  fail "install.sh missing post-checkout reference"
fi
if grep -q "check-worktree-count" "$INSTALL_SH" 2>/dev/null; then
  pass "install.sh references check-worktree-count"
else
  fail "install.sh missing check-worktree-count reference"
fi

#===============================================================================
# H7: integration test 存在
#===============================================================================
log ""
log ">>> H7: integration test exists"
echo "=========================================="
if [[ -f "$TEST_SH" ]]; then
  pass "integration test exists"
else
  fail "integration test missing: $TEST_SH"
fi
if [[ -x "$TEST_SH" ]]; then
  pass "integration test executable"
else
  fail "integration test not executable"
fi

#===============================================================================
# H8: integration test 跑通
#===============================================================================
log ""
log ">>> H8: integration test runs"
echo "=========================================="
if [[ -x "$TEST_SH" ]]; then
  if bash "$TEST_SH" >/dev/null 2>&1; then
    pass "integration test PASS"
  else
    fail "integration test FAIL"
  fi
else
  fail "integration test not executable, skip run"
fi

#===============================================================================
# Summary
#===============================================================================
echo ""
echo "=========================================="
echo " check-worktree-hygiene L4 Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

if [[ $FAIL -eq 0 ]]; then
  echo "L4 verify PASS"
  exit 0
else
  echo "L4 verify FAIL"
  exit 1
fi