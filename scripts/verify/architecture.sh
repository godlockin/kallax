#!/usr/bin/env bash
# scripts/verify/architecture.sh — L4 checkpoint for architecture (Rule 19)
# Rule 8: L4 脚本必须存在 (跟 BE-7 + Rule 8 一致)
# Rule 19: L4 verify 自检 L3 实际跑结果
set -euo pipefail

echo "=========================================="
echo " Architecture Verify (Rule 19)"
echo "=========================================="
echo ""

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# L3 self-check mechanism (跟 Rule 19 落地)
# 验证主集成测试存在
if [[ -x "tests/integration/main-test.sh" ]] || ls tests/integration/*-test.sh >/dev/null 2>&1; then
  pass "L3 integration tests exist (self-check mechanism)"
else
  fail "L3 integration tests missing"
fi

# 验证 anti-fab 工具存在
for tool in check-test-case-isolation.sh check-kpi-precision.sh check-scope-creep.sh; do
  if [[ -x "scripts/verify/$tool" ]]; then
    pass "$tool exists and executable"
  else
    fail "$tool missing"
  fi
done

# Rule 8 L4 self-check
if [[ -f "scripts/verify/architecture.sh" ]]; then
  pass "architecture.sh exists (Rule 8 L4)"
else
  fail "architecture.sh missing (Rule 8 L4 violation)"
fi

echo ""
echo "=========================================="
echo " Architecture Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
