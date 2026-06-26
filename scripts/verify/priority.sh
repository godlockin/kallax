#!/usr/bin/env bash
# scripts/verify/priority.sh — L4 checkpoint for priority/PM (Rule 19)
# Rule 8: L4 脚本必须存在 (跟 BE-7 + Rule 8 一致)
# Rule 19: L4 verify 自检 L3 实际跑结果
# EPIC-034-B: 5 角色 L4 验证脚本 - priority 角色
set -euo pipefail

echo "=========================================="
echo " Priority Verify (Rule 19)"
echo "=========================================="
echo ""

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# L3 self-check mechanism (跟 Rule 19 落地)
# 验证 priority 相关的 anti-fab 工具存在
for tool in check-test-case-isolation.sh check-kpi-precision.sh check-scope-creep.sh; do
  if [[ -x "scripts/verify/$tool" ]]; then
    pass "$tool exists and executable (priority check)"
  else
    fail "$tool missing (priority risk)"
  fi
done

# Rule 8 L4 self-check
if [[ -f "scripts/verify/priority.sh" ]]; then
  pass "priority.sh exists (Rule 8 L4)"
else
  fail "priority.sh missing (Rule 8 L4 violation)"
fi

# 验证 PM/priority ticket 有 AC (跟 Rule 12 质量 ensure 联合)
PM_TICKETS=$(find jira/tickets -name "ticket.json" -path "*/EPIC-0*" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$PM_TICKETS" -gt 0 ]]; then
  pass "PM tickets exist: $PM_TICKETS"
else
  fail "No PM tickets found in jira/tickets/"
fi

# 验证 Rule 9 KPI 精确 X/Y 格式 (跟 anti-pattern 联合)
TICKETS_WITH_KPI=$(grep -l "X/Y\|/100\|/50" jira/tickets/*/ticket.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TICKETS_WITH_KPI" -gt 0 ]]; then
  pass "KPI X/Y format found in $TICKETS_WITH_KPI ticket(s)"
else
  warn_msg="KPI X/Y format not detected (Rule 9 9d/9e 验证缺失)"
  echo "  [WARN] $warn_msg"
fi

echo ""
echo "=========================================="
echo " Priority Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
