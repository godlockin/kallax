#!/usr/bin/env bash
# KALLAX Success Criteria Definition Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Define Success Criteria" 联合)
# 跟 Rule 9 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 14 BE 累计 联合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

TICKET_JSON="${1:-}"
if [[ -z "$TICKET_JSON" ]]; then
  echo "WARN: check-sc-defined skipped (no ticket.json arg; pre-commit wrapper 0-arg invocation)" >&2
  exit 0
fi

if [[ ! -f "$TICKET_JSON" ]]; then
  echo "WARN: check-sc-defined skipped (ticket not found: $TICKET_JSON)" >&2
  exit 0
fi

ticket_id=$(jq -r '.id // ""' "$TICKET_JSON")
ac_count=$(jq -r '.acceptance_criteria // [] | length' "$TICKET_JSON")

if [[ "$ac_count" -lt 2 ]]; then
  echo "ticket $ticket_id: SC 不足 (跟 Karpathy Define Success Criteria 联合, 跟反讽 联合)"
  echo "  Current: $ac_count, Required: >= 2 (跟诚实修正 联合, 跟独立 拍 explicit 约束 联合)"
  exit 1
fi

ac_text=$(jq -r '.acceptance_criteria // [] | join(" ")' "$TICKET_JSON")

if echo "$ac_text" | grep -qiE "(test|verify|validat|pass|run)"; then
  echo "ticket $ticket_id: SC 清晰 (跟 Karpathy 联合, 跟反讽 联合, 跟独立 拍 explicit 约束 联合)"
  exit 0
else
  echo "ticket $ticket_id: SC 缺验证方式 (跟 Karpathy Define Success Criteria 联合, 跟反讽 联合)"
  echo "  建议: AC 包含 verified by / test / pass 等可验证模式"
  exit 1
fi
