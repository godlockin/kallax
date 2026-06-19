#!/usr/bin/env bash
# KALLAX Performer Session Init -- EPIC-016-R AC12
# 4-step state-check on startup: project → session → candidates → claim+EnterWorktree.
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
EPICS_DIR="jira/epics"
TICKETS_DIR="jira/tickets"
LOG_DIR="${KALLAX_ROOT}/logs"

INSTANCE_ID="${KALLAX_INSTANCE_ID:-performer_$(hostname)}_$$"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ============================================================
# Step 1/4: Project state scan
# ============================================================
echo ""
echo "─── Step 1/4: Project State ───"

MASTER_STATE="${INSTANCES_DIR}/master_main/state.json"
if [ -f "${MASTER_STATE}" ]; then
  MASTER_STATUS=$(jq -r '.status // "unknown"' "${MASTER_STATE}" 2>/dev/null || echo "unknown")
  echo "  Master: ${MASTER_STATUS}"
else
  echo "  ⚠ No master detected — consider initializing one first"
fi

# Active EPICs
ACTIVE_EPICS=$(find "${EPICS_DIR}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
  while read dir; do
    epic_id=$(basename "$dir")
    epic_file="${dir}/epic.json"
    if [ -f "$epic_file" ]; then
      has_tickets=$(jq '[.tickets[] | select(.status != "done")] | length' "$epic_file" 2>/dev/null || echo 0)
      if [ "$has_tickets" -gt 0 ]; then
        echo "$epic_id"
      fi
    fi
  done | head -5)
echo "  Active EPICs: ${ACTIVE_EPICS:-none}"
if [ "${ACTIVE_EPICS:-none}" = "none" ]; then
  echo "  ⚠ 请先由 master 初始化一个 EPIC"
fi

# Ready tickets
echo "  Ready tickets:"
READY_TICKETS=$(find "${TICKETS_DIR}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
  while read dir; do
    ticket_file="${dir}/ticket.json"
    if [ -f "$ticket_file" ]; then
      status=$(jq -r '.status // "unknown"' "$ticket_file" 2>/dev/null || echo "unknown")
      assignee=$(jq -r '.assignee // empty' "$ticket_file" 2>/dev/null || echo "")
      if [ "$status" = "ready" ] && [ -z "$assignee" ]; then
        priority=$(jq -r '.priority // "P3"' "$ticket_file" 2>/dev/null | head -c2)
        ticket_id=$(basename "$dir")
        title=$(jq -r '.title // "untitled"' "$ticket_file" 2>/dev/null)
        echo " [${ticket_id}] ${title} [${priority}]"
      fi
    fi
  done | head -10)
if [ -n "$READY_TICKETS" ]; then
  echo "${READY_TICKETS}"
else
  echo "    (none)"
fi

# ============================================================
# Step 2/4: Session state scan
# ============================================================
echo ""
echo "─── Step 2/4: Session State ───"

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "  Branch: ${BRANCH}"

IN_WORKTREE="no"
if git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees'; then
  IN_WORKTREE="yes"
fi
echo "  In worktree: ${IN_WORKTREE}"

# Current in-progress task
CURRENT_TASK=""
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  this_instance=$(basename "$(dirname "$sf")")
  # Only check performers
  role=$(jq -r '.role // ""' "$sf" 2>/dev/null || echo "")
  [ "$role" = "performer" ] || continue
  task_id=$(jq -r '.current_task.ticket_id // empty' "$sf" 2>/dev/null || echo "")
  if [ -n "$task_id" ] && [ "$task_id" != "null" ]; then
    CURRENT_TASK="$task_id"
    CURRENT_INSTANCE="$this_instance"
    break
  fi
done

if [ -n "$CURRENT_TASK" ]; then
  echo "  Current task: ${CURRENT_TASK} (${CURRENT_INSTANCE})"
else
  echo "  Current task: none"
fi

# Performer should not be on miao/testing
if [ "$BRANCH" = "miao" ] || [ "$BRANCH" = "testing" ]; then
  echo ""
  echo "  ⚠ WARNING: Performer should not work on main branch '${BRANCH}'"
  echo "  ⚠ Claim a ticket first to create a feature worktree"
fi

# ============================================================
# Step 3/4: Candidate ticket ranking
# ============================================================
echo ""
echo "─── Step 3/4: Candidate Tickets ───"

# If already on feature branch with in-progress task, skip ranking
if [ "$IN_WORKTREE" = "yes" ] && [ -n "$CURRENT_TASK" ]; then
  echo "  (Already on feature branch with active task: ${CURRENT_TASK})"
  echo "  Use 'kallax task:complete' to finish, or continue working."
  echo ""
  echo"╔════════════════════════════════════════════════════╗"
  echo "║  SESSION READY                                   ║"
  echo "╠════════════════════════════════════════════════════╣"
  echo "║  TASK    ▸ ${CURRENT_TASK}                       ║"
  echo "║  BRANCH  ▸ ${BRANCH}                             ║"
  echo "║  WORKTREE▸ ${IN_WORKTREE}                        ║"
  echo "╚════════════════════════════════════════════════════╝"
  exit 0
fi

# Rank candidates by priority
CANDIDATES=$(find "${TICKETS_DIR}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
  while read dir; do
    ticket_file="${dir}/ticket.json"
    if [ -f "$ticket_file" ]; then
      status=$(jq -r '.status // "unknown"' "$ticket_file" 2>/dev/null || echo "unknown")
      assignee=$(jq -r '.assignee // empty' "$ticket_file" 2>/dev/null || echo "")
      if [ "$status" = "ready" ] && [ -z "$assignee" ]; then
        priority=$(jq -r '.priority // "P3"' "$ticket_file" 2>/dev/null)
        priority_num=$(echo "$priority" | tail -c1)
        ticket_id=$(basename "$dir")
        title=$(jq -r '.title // "untitled"' "$ticket_file" 2>/dev/null)
        echo "${priority_num}:${ticket_id}:${title}"
      fi
    fi
  done | sort -t: -k1,1n | head -5)

if [ -z "$CANDIDATES" ]; then
  echo "  No ready tickets found. Run 'kallax inbox' for details."
  echo ""
  echo "╔════════════════════════════════════════════════════╗"
  echo "║  NO READY TICKETS ║"
  echo "╠════════════════════════════════════════════════════╣"
  echo "║  NEXT: Wait for Conductor to dispatch a ticket   ║"
  echo "╚════════════════════════════════════════════════════╝"
  exit 0
fi

echo "  Top candidates:"
echo "$CANDIDATES" | while IFS=: read -r prio tid title; do
  star=""
  [ "$prio" = "1" ] && star=" ★ recommended"
  echo "    [$tid] ${title} [P${prio}]${star}"
done

# ============================================================
# Step 4/4: User confirmation + claim + EnterWorktree
# ============================================================
echo ""
echo "─── Step 4/4: Claim Ticket ───"

echo "Select ticket to claim (or 'q' to skip):"
select tid in $(echo "$CANDIDATES" | cut -d: -f2 | tr '\n' ' '); do
  case "$tid" in
    q|Q) echo "Skipped."; exit 0 ;;
    EPIC-*) break ;;
    *) echo "Invalid selection." ;;
  esac
done

# Auto-claim: update ticket.json
TICKET_FILE="${TICKETS_DIR}/${tid}/ticket.json"
if [ ! -f "$TICKET_FILE" ]; then
  echo "ERROR: ticket file not found: ${TICKET_FILE}"
  exit 1
fi

jq ".status = \"in_progress\" | .performer = \"${INSTANCE_ID}\"" "$TICKET_FILE" \
  > "${TICKET_FILE}.tmp" && mv "${TICKET_FILE}.tmp" "$TICKET_FILE"
echo "  ✓ Claimed ${tid}"

# Enter worktree
WORKTREE_NAME="performer-${tid}"
WORKTREE_PATH="${REPO_ROOT}/.kallax/worktrees/${WORKTREE_NAME}"
FEATURE_BRANCH="feature/${tid}-$(echo "$tid" | tr 'A-Z' 'a-z')"

# Create worktree if not exists
if [ ! -d "$WORKTREE_PATH" ]; then
  git worktree add "$WORKTREE_PATH" -b "$FEATURE_BRANCH" 2>/dev/null || \
    git worktree add "$WORKTREE_PATH" "$FEATURE_BRANCH" 2>/dev/null || true
fi
echo "  ✓ Worktree: ${WORKTREE_PATH}"

# Write state.json current_task
STATE_FILE="${INSTANCES_DIR}/${INSTANCE_ID}/state.json"
mkdir -p "$(dirname "$STATE_FILE")"
jq ".current_task = {ticket_id: \"${tid}\", worktree_path: \"${WORKTREE_PATH}\"}" \
  "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
echo "  ✓ State updated"

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  READY TO WORK                                      ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  TICKET  ▸ ${tid}                                   ║"
echo "║  WORKTREE▸ ${WORKTREE_PATH}        ║"
echo "║  BRANCH  ▸ ${FEATURE_BRANCH}                       ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  NEXT: cd ${WORKTREE_PATH} && implement ACs ║"
echo "╚════════════════════════════════════════════════════╝"