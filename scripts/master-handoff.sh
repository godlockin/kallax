#!/usr/bin/env bash
# KALLAX Master Handoff Protocol
# Saves complete Master state before session ends.
# Next session: session_start.sh --role master detects previous state and resumes.
set -uo pipefail

INSTANCE_ID="${KALLAX_INSTANCE_ID:-master_main}"
INSTANCE_DIR=".kallax/instances/${INSTANCE_ID}"
STATE_FILE="${INSTANCE_DIR}/state.json"
HANDOFF_FILE="${INSTANCE_DIR}/handoff.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "${INSTANCE_DIR}"

# ── 1. Collect current state ────────────────────────────────────────────────
CURRENT_PHASE=$(jq -r '.id // "unknown"' jira/phases/phase_index.json 2>/dev/null | head -1 || echo "PHASE-001")
ACTIVE_EPIC=$(jq -r '.epics[] | select(.status=="active") | .id' jira/epics/epic_index.json 2>/dev/null || echo "EPIC-015")
OPEN_TICKETS=$(jq -r '[.tickets[] | select(.status!="done") | .id] | join(", ")' "jira/epics/${ACTIVE_EPIC}/epic.json" 2>/dev/null || echo "none")
DONE_TICKETS=$(jq -r '[.tickets[] | select(.status=="done") | .id] | join(", ")' "jira/epics/${ACTIVE_EPIC}/epic.json" 2>/dev/null || echo "none")

# ── 2. Update state.json → CLOSING ──────────────────────────────────────────
cat > "${STATE_FILE}" << STATE
{
  "instance_id": "${INSTANCE_ID}",
  "role": "master",
  "status": "CLOSING",
  "closed_at": "${NOW}",
  "current_phase": "${CURRENT_PHASE}",
  "active_epic": "${ACTIVE_EPIC}",
  "open_tickets": "${OPEN_TICKETS}",
  "done_tickets": "${DONE_TICKETS}"
}
STATE

# ── 3. Write handoff.json for next Master ───────────────────────────────────
cat > "${HANDOFF_FILE}" << HANDOFF
{
  "previous_master": "${INSTANCE_ID}",
  "handoff_time": "${NOW}",
  "phase": "${CURRENT_PHASE}",
  "epic": "${ACTIVE_EPIC}",
  "open_tickets": "${OPEN_TICKETS}",
  "done_tickets": "${DONE_TICKETS}",
  "pending_reviews": "$(ls .kallax/queue/inbox/conductor_main/ 2>/dev/null | wc -l | tr -d ' ')",
  "active_worktrees": "$(git worktree list 2>/dev/null | grep -v 'kallax$' | wc -l | tr -d ' ')",
  "resume_instructions": [
    "1. Run: bash .kallax/hooks/session_start.sh --role master",
    "2. Check: cat .kallax/instances/master_main/handoff.json",
    "3. Resume: Review open tickets, check performer status, continue PHASE"
  ]
}
HANDOFF

# ── 4. Print handoff summary ────────────────────────────────────────────────
cat << SUMMARY

╔════════════════════════════════════════════════════╗
║  MASTER HANDOFF COMPLETE                     v1.0.0 ║
╠════════════════════════════════════════════════════╣
║  Instance  ▸ ${INSTANCE_ID}                        ║
║  Phase     ▸ ${CURRENT_PHASE}                      ║
║  Epic      ▸ ${ACTIVE_EPIC}                        ║
║  Open      ▸ ${OPEN_TICKETS}                       ║
║  Done      ▸ ${DONE_TICKETS}                       ║
║  Reviews   ▸ $(ls .kallax/queue/inbox/conductor_main/ 2>/dev/null | wc -l | tr -d ' ') pending                        ║
╠════════════════════════════════════════════════════╣
║  Next Master: session_start.sh --role master       ║
║  Resume: cat ${HANDOFF_FILE}                       ║
╚════════════════════════════════════════════════════╝
SUMMARY

echo ""
echo "HANDOFF_OK instance_id=${INSTANCE_ID} status=CLOSING"
