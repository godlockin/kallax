#!/bin/bash
# task-claim-2026-06-12.sh — Performer 领任务 (claim 流程)
# 主公 2026-06-12 拍"你来召唤团队拆卡领任务开工"
# Performer 容器起来后跑: 拉 dispatch → claim ticket → 跑 worktree
set -euo pipefail

KALLAX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KALLAX_ROOT"

INSTANCE_ID="${KALLAX_INSTANCE_ID:-performer_$(hostname)_$$}"
INSTANCE_DIR=".kallax/instances/${INSTANCE_ID}"
mkdir -p "${INSTANCE_DIR}"

TICKET_ID="${1:-}"
if [[ -z "$TICKET_ID" ]]; then
  echo "Usage: $0 <TICKET_ID>"
  echo "       e.g. $0 EPIC-034-C"
  echo ""
  echo "可领任务列表 (9 dispatch):"
  for f in .kallax/queue/inbox/conductor_main/dispatch-*.json; do
    [[ "$f" == *.disabled ]] && continue
    python3 -c "
import json
d = json.load(open('$f'))
print(f'  📋 {d[\"ticket_id\"]:18} | {d[\"priority\"]} | {d[\"estimated_hours\"]}h | blocked:{d[\"blocked_by\"] or \"none\"} | handoff_depth:{d.get(\"handoff_depth\", \"n/a\")} | expertise:{d[\"expertise_required\"]}')
"
  done
  exit 1
fi

# 1. 验证 ticket 存在
TICKET_PATH="jira/tickets/${TICKET_ID}/ticket.json"
if [[ ! -f "$TICKET_PATH" ]]; then
  echo "ERROR: ticket not found: $TICKET_PATH"
  exit 1
fi

# 2. 验证 blocked_by 状态
BLOCKED_BY=$(python3 -c "import json; print(json.load(open('$TICKET_PATH'))['blocked_by'] or 'none')")
if [[ "$BLOCKED_BY" != "none" ]] && [[ -n "$BLOCKED_BY" ]]; then
  echo "ERROR: ticket blocked_by=$BLOCKED_BY, 需等上游完"
  echo "Blocked ticket status:"
  python3 -c "
import json
d = json.load(open('jira/tickets/${BLOCKED_BY}/ticket.json'))
print(f'  📋 {d[\"id\"]} status: {d.get(\"status\", \"unknown\")}')
"
  exit 1
fi

# 3. 拉 dispatch 验证
DISPATCH_FILE=".kallax/queue/inbox/conductor_main/dispatch-20260612-${TICKET_ID}.json"
if [[ ! -f "$DISPATCH_FILE" ]]; then
  echo "WARN: dispatch not found: $DISPATCH_FILE (可能 Master 没写)"
fi

# 4. Claim ticket (更新状态 pending → in_progress)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -c "
import json
ticket = json.load(open('$TICKET_PATH'))
ticket['status'] = 'in_progress'
ticket['claimed_by'] = '${INSTANCE_ID}'
ticket['claimed_at'] = '${NOW}'
json.dump(ticket, open('$TICKET_PATH', 'w'), indent=2, ensure_ascii=False)
"

# 5. 更新 instance state.json
STATE_FILE="${INSTANCE_DIR}/state.json"
python3 -c "
import json
state = {
  'instance_id': '${INSTANCE_ID}',
  'role': 'performer',
  'status': 'active',
  'claimed_ticket': '${TICKET_ID}',
  'claimed_at': '${NOW}',
  'last_beat': '${NOW}'
}
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
"

# 6. 写 handoff (Performer 续接管用)
HANDOFF_FILE="${INSTANCE_DIR}/handoff.json"
python3 -c "
import json
handoff = {
  'instance_id': '${INSTANCE_ID}',
  'ticket': '${TICKET_ID}',
  'claimed_at': '${NOW}',
  'worktree': '$(jq -r '.worktree_role' $TICKET_PATH 2>/dev/null)',
  'handoff_depth': '$(jq -r '.handoff_depth // "L2"' $TICKET_PATH 2>/dev/null)',
  'resume_instructions': [
    '1. cd .kallax/worktrees/performer-* (or new worktree)',
    '2. cat jira/tickets/${TICKET_ID}/ticket.json 看 AC',
    '3. 跑 anti-fab 3 工具 + 4 anti-fab',
    '4. 拆 commit 为单 prompt (L1 战术, 防 hang)',
    '5. 写 commit + 跑 Rule 8 L4 验证',
    '6. 报 PASS, Conductor merge → testing'
  ]
}
json.dump(handoff, open('$HANDOFF_FILE', 'w'), indent=2, ensure_ascii=False)
"

echo "=========================================="
echo " ✅ Performer Claim 成功"
echo "=========================================="
echo ""
echo "  Instance: ${INSTANCE_ID}"
echo "  Ticket: ${TICKET_ID}"
echo "  Claimed at: ${NOW}"
echo "  Worktree: $(jq -r '.worktree_role // "n/a"' $TICKET_PATH)"
echo "  Handoff depth: $(jq -r '.handoff_depth // "L2"' $TICKET_PATH)"
echo ""
echo "  State file: ${STATE_FILE}"
echo "  Handoff file: ${HANDOFF_FILE}"
echo ""
echo "=========================================="
echo " Performer 跑任务 (L1 战术):"
echo "=========================================="
echo ""
echo "  1. cd 到 worktree (或新 worktree)"
echo "  2. 读 AC: cat $TICKET_PATH"
echo "  3. 拆 commit 为单 prompt (L1 战术, 防 R2/R4/R5b hang)"
echo "  4. 跑 4 anti-fab (test-case-isolation / kpi-precision / scope-creep / commit-amend-verify)"
echo "  5. 跑 Rule 8 L4 验证 (handoff-depth.sh / worktree-role.sh 等)"
echo "  6. 写 commit, push feature branch"
echo "  7. 报 PASS, Conductor merge"
echo ""
echo "=========================================="
echo " Master 强验证 (Performer 报 PASS 后):"
echo "=========================================="
echo ""
echo "  L1 git log --oneline -1 看 SHA 真变"
echo "  L2 git show HEAD:file | grep 看内容真改"
echo "  L3 跑全量 E2E (跟 ticket AC 逐条)"
echo "  L4 check-fact-forcing-preflight.sh + 4 anti-fab + Rule 14/15"
echo "  L5 任何边界事件标 + 留 LESSONS-LEARNED 草稿"
echo "  L6 报假 PASS = FAIL (Rule 9e)"
echo ""
echo "=========================================="
echo " Conductor 拉: 报 PASS 后, Conductor merge feature → testing"
echo "=========================================="
