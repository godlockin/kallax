#!/bin/bash
# task-claim-brief.sh — 强制 task:claim 后 brief_inference 字段
# 用法: bash scripts/task-claim-brief.sh <ticket.json>
set -euo pipefail

TICKET_JSON="${1:-}"

if [[ -z "$TICKET_JSON" ]] || [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket.json path required"
  exit 1
fi

if ! jq -e '.brief_inference' "$TICKET_JSON" >/dev/null 2>&1; then
  echo "BLOCKED: ticket.json missing brief_inference field"
  echo "Required: 📋 任务理解: [任务类型] | [核心目标] | [技术方案] | [风险点]"
  exit 1
fi

BRIEF=$(jq -r '.brief_inference' "$TICKET_JSON")
echo "✓ Brief Inference: $BRIEF"
exit 0
