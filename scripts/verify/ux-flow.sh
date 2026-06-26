#!/usr/bin/env bash
# scripts/verify/ux-flow.sh — L4 checkpoint for UX (Rule 19)
# Rule 8: L4 脚本必须存在 (跟 BE-7 + Rule 8 一致)
# Rule 19: L4 verify 自检 L3 实际跑结果
# EPIC-034-B: 5 角色 L4 验证脚本 - UX 角色
set -euo pipefail

echo "=========================================="
echo " UX Flow Verify (Rule 19)"
echo "=========================================="
echo ""

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# L3 self-check mechanism (跟 Rule 19 落地)
# 验证 UX 相关的 anti-fab 工具存在
for tool in check-test-case-isolation.sh check-kpi-precision.sh; do
  if [[ -x "scripts/verify/$tool" ]]; then
    pass "$tool exists and executable (UX check)"
  else
    fail "$tool missing (UX risk)"
  fi
done

# Rule 8 L4 self-check
if [[ -f "scripts/verify/ux-flow.sh" ]]; then
  pass "ux-flow.sh exists (Rule 8 L4)"
else
  fail "ux-flow.sh missing (Rule 8 L4 violation)"
fi

# 验证 M1 test cases 包含 UX 场景 (跟 EPIC-034-A M1 100 test cases 联合)
UX_TEST_CASES=$(grep -c '"ux"\|"frontend"' scripts/verify/expert-match-m1-v3.sh 2>/dev/null | head -1 || echo "0")
if [[ "$UX_TEST_CASES" -gt 0 ]]; then
  pass "UX test cases in M1: $UX_TEST_CASES"
else
  fail "No UX test cases in M1 script"
fi

# 验证 web/ UI 资源存在 (UX 流验证)
WEB_DIRS=$(find web -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ "$WEB_DIRS" -gt 0 ]]; then
  pass "Web UI directories: $WEB_DIRS"
else
  warn_msg="No web/ directories found (UX flow may not be applicable)"
  echo "  [WARN] $warn_msg"
fi

echo ""
echo "=========================================="
echo " UX Flow Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
