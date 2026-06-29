#!/usr/bin/env bash
# ticket-status-sync.sh — Step 1 of Subagent 5-step flow (Rule 16)
# Sync ticket.json status field with observed state (worktree/branch/commit).
# Stub (Iter 5 will replace with full logic).

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

echo "[STUB] ticket-status-sync.sh $TICKET_ID"
echo "[STUB] Ticket file: $TICKET_FILE"
echo "[STUB] Iter 5 will implement: status field sync + claimed_at/in_progress_at/done_at timestamps"
echo "PASS: stub-ok (Iter 5 will replace)"
exit 0
