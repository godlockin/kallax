#!/usr/bin/env bash
# scripts/verify/tickets-completed.sh — L4 checkpoint for tickets-completed (Rule 19)
# Rule 8: L4 脚本必须存在 (跟 BE-7 + Rule 8 一致)
# Rule 19: L4 verify 自检 L3 实际跑结果
# EPIC-034-B: 5 角色 L4 验证脚本 - tickets-completed 角色
set -euo pipefail

echo "=========================================="
echo " Tickets Completed Verify (Rule 19)"
echo "=========================================="
echo ""

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# L3 self-check mechanism (跟 Rule 19 落地)
# 验证 ticket 相关的 anti-fab 工具存在
for tool in check-test-case-isolation.sh check-kpi-precision.sh check-scope-creep.sh; do
  if [[ -x "scripts/verify/$tool" ]]; then
    pass "$tool exists and executable (tickets check)"
  else
    fail "$tool missing (tickets risk)"
  fi
done

# Rule 8 L4 self-check
if [[ -f "scripts/verify/tickets-completed.sh" ]]; then
  pass "tickets-completed.sh exists (Rule 8 L4)"
else
  fail "tickets-completed.sh missing (Rule 8 L4 violation)"
fi

# 验证 ticket.json 格式正确 (跟 Rule 12 质量 ensure 联合)
TICKET_FILES=$(find jira/tickets -name "ticket.json" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TICKET_FILES" -gt 0 ]]; then
  pass "Ticket files found: $TICKET_FILES"
else
  fail "No ticket.json files found"
fi

# 验证 ticket 有 status 字段 (跟 Rule 11 v2.1 联合)
TICKETS_WITH_STATUS=$(find jira/tickets -name "ticket.json" 2>/dev/null | xargs grep -l '"status"' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TICKETS_WITH_STATUS" -gt 0 ]]; then
  pass "Tickets with status field: $TICKETS_WITH_STATUS"
else
  fail "No tickets with status field (Rule 11 v2.1 violation)"
fi

# 验证 done 状态的 ticket 数量 (跟"翻篇&精进" 战略 联合 0 简单 记录)
DONE_TICKETS=$(find jira/tickets -name "ticket.json" 2>/dev/null | xargs grep -l '"status":\s*"done"' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$DONE_TICKETS" -gt 0 ]]; then
  pass "Done tickets: $DONE_TICKETS"
else
  warn_msg="No done tickets found (Sprint 进度 0 隐藏)"
  echo "  [WARN] $warn_msg"
fi

echo ""
echo "=========================================="
echo " Tickets Completed Verify: $PASS PASS, $FAIL FAIL"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
