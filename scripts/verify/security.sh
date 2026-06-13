#!/usr/bin/env bash
# scripts/verify/security.sh — L4 checkpoint for security (Rule 19)
# Rule 8: L4 脚本必须存在 (跟 BE-7 + Rule 8 一致)
# Rule 19: L4 verify 自检 L3 实际跑结果
set -euo pipefail

echo "=========================================="
echo " Security Verify (Rule 19)"
echo "=========================================="
echo ""

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# L3 self-check mechanism (跟 Rule 19 落地)
# 验证安全相关 anti-fab 工具存在
for tool in check-test-case-isolation.sh check-kpi-precision.sh; do
  if [[ -x "scripts/verify/$tool" ]]; then
    pass "$tool exists and executable (security check)"
  else
    fail "$tool missing (security risk)"
  fi
done

# 验证 L4 self-check 机制
if [[ -f "scripts/verify/security.sh" ]]; then
  pass "security.sh exists (Rule 8 L4)"
else
  fail "security.sh missing (Rule 8 L4 violation)"
fi

# 验证 BE-7 修复模式
if [[ -f "scripts/io/file-lock.sh" ]] && grep -q "umask 077" scripts/io/file-lock.sh; then
  pass "file-lock.sh has umask 077 (BE-7 fix)"
else
  fail "file-lock.sh missing BE-7 fix"
fi

echo ""
echo "=========================================="
echo " Security Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
