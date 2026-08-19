#!/usr/bin/env bash
# ticket-status-sync.sh — Step 1 of Subagent 5-step flow (Rule 16)
# Sync ticket.json status field with observed state (worktree/branch/commit).
#
# 未实现. 退出码 2 = NOT_IMPLEMENTED (不是 0).
#
# EPIC-259 改动: 原先 print "PASS: stub-ok" 然后 exit 0, 对所有输入返回成功.
# ticket status 漂移已发生 2 次 (13 张卡 / EPIC-254+255) — 任何调用方看到
# exit 0 都会认为同步成功了. 一个永远返回成功的验证脚本比没有更危险.
# 实现在 EPIC-261.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_ID="${1:-}"

if [[ -z "$TICKET_ID" ]]; then
  echo "Usage: $0 <TICKET-ID>"
  echo "Example: $0 TASK-001"
  exit 2
fi

TICKET_FILE="$PROJECT_ROOT/jira/tickets/$TICKET_ID/ticket.json"
if [[ ! -f "$TICKET_FILE" ]]; then
  echo "FAIL: ticket not found: $TICKET_FILE"
  exit 1
fi

echo "NOT_IMPLEMENTED: ticket-status-sync.sh $TICKET_ID"
echo "  ticket file: $TICKET_FILE"
echo "  未实现: status 字段同步 + claimed_at/in_progress_at/done_at 时间戳"
echo ""
echo "  原先此处 print 'PASS: stub-ok' 然后 exit 0. 已改 exit 2 (EPIC-259)."
echo "  需要改 status 请手工编辑 ticket.json — 且必须在 worktree 内改,"
echo "  在主仓副本改会漏进 commit (这正是漂移 2 次的直接原因)."
exit 2
