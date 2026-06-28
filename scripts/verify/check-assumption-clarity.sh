#!/usr/bin/env bash
# KALLAX Assumption Clarity Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Stop When Confused" + "Surface Ambiguity" 联合)
# 跟 Rule 17 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 14 BE 累计 联合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

declare -a AMBIGUITY_PATTERNS=(
  "(vague|maybe|perhaps|possibly|might|should|probably|大概|也许|可能|或许|应该|恐怕)"
  "(modify|update|fix|change|改|修改|更新|修复|变更).*\\?$"
  "(all|everything|entire|whole|所有|全部|整个|整体)"
  "(but don't|but do|然而|但是).*\\?$"
  "(or|either|或者|要么).*\\?$"
)

TICKET_JSON="${1:?usage: check-assumption-clarity.sh <ticket.json>}"

if [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket not found: $TICKET_JSON" >&2
  exit 2
fi

ticket_id=$(jq -r '.id // ""' "$TICKET_JSON")
ticket_title=$(jq -r '.title // ""' "$TICKET_JSON")
ticket_desc=$(jq -r '.description // ""' "$TICKET_JSON")
ticket_ac=$(jq -r '.acceptance_criteria // [] | join(" ")' "$TICKET_JSON")
ticket_text="$ticket_title $ticket_desc $ticket_ac"

ambiguities=()
for pattern in "${AMBIGUITY_PATTERNS[@]}"; do
  if echo "$ticket_text" | grep -qiE "$pattern"; then
    ambiguities+=("$pattern")
  fi
done

if [[ ${#ambiguities[@]} -eq 0 ]]; then
  echo "ticket $ticket_id: clarity OK (跟 Karpathy 联合, 跟反讽 联合)"
  exit 0
else
  echo "ticket $ticket_id: ambiguity detected (跟反讽 联合, 跟诚实修正 联合, 跟 Karpathy Stop When Confused 联合)"
  echo "  Detected patterns: ${ambiguities[*]}"
  echo "  跟独立 拍 explicit 约束 联合: Performer 必问主公 clarification 后再开工"
  exit 1
fi
