#!/usr/bin/env bash
# KALLAX Session Start Hook — EPIC-015 Phase 1.1
# Governance layer: identity init, directory setup, worktree guide, heartbeat.
# Runs on every new session. Failure does NOT block session.
set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
INBOX_DIR="${KALLAX_ROOT}/queue/inbox"
LOG_DIR="${KALLAX_ROOT}/logs"

HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
PID="${$}"
ROLE="${KALLAX_ROLE:-$(git branch --show-current 2>/dev/null | grep -q 'feature/' && echo 'performer' || echo 'conductor')}"
INSTANCE_ID="${KALLAX_INSTANCE_ID:-${ROLE}_${HOSTNAME}_${PID}}"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
CWD="$(pwd)"

# Detect worktree
IN_WORKTREE="false"
WORKTREE_PATH="null"
if git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees'; then
  IN_WORKTREE="true"
  WT=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  WORKTREE_PATH="\"${WT}\""
fi

# Create directories
mkdir -p "${INSTANCES_DIR}/${INSTANCE_ID}"
mkdir -p "${INBOX_DIR}/${INSTANCE_ID}"
mkdir -p "${KALLAX_ROOT}/queue/outbox/${INSTANCE_ID}"
mkdir -p "${LOG_DIR}"

# Write state.json
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" << STATE
{
  "instance_id": "${INSTANCE_ID}",
  "role": "${ROLE}",
  "pid": ${PID},
  "status": "ACTIVE",
  "branch": "${BRANCH}",
  "cwd": "${CWD}",
  "in_worktree": ${IN_WORKTREE},
  "worktree_path": ${WORKTREE_PATH},
  "created_at": "${NOW}",
  "started_at": "${NOW}",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "${NOW}",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null,
    "progress_pct": null
  }
}
STATE

# Start heartbeat daemon
HEARTBEAT_SCRIPT="${KALLAX_ROOT}/../scripts/heartbeat-daemon.sh"
if [ -x "${HEARTBEAT_SCRIPT}" ]; then
  "${HEARTBEAT_SCRIPT}" "${INSTANCE_ID}" "${INSTANCES_DIR}" &
fi

# Count team
CONDUCTOR_COUNT=0
PERFORMER_COUNT=0
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "${sf}" ] || continue
  r=$(python3 -c "import json;print(json.load(open('${sf}')).get('role',''))" 2>/dev/null || echo "")
  case "${r}" in master|conductor) CONDUCTOR_COUNT=$((CONDUCTOR_COUNT+1)) ;; performer) PERFORMER_COUNT=$((PERFORMER_COUNT+1)) ;; esac
done

# Count inbox
INBOX_COUNT=$(ls -1 "${INBOX_DIR}/${INSTANCE_ID}/" 2>/dev/null | wc -l | tr -d ' ')

# Next action
case "${ROLE}" in
  master)   NEXT="kallax status → review PRs → approve/reject" ;;
  conductor)
    if [ "${IN_WORKTREE}" = "false" ]; then NEXT="EnterWorktree → kallax status → 检查团队"
    else NEXT="kallax status → 检查团队 → 分配任务"; fi ;;
  performer) NEXT="kallax inbox → 领卡 → EnterWorktree" ;;
esac

WT_DISPLAY="$([ "${IN_WORKTREE}" = "true" ] && echo "${WORKTREE_PATH}" | tr -d '"' || echo "NOT ISOLATED")"

# ASCII Card
cat << CARD

╔════════════════════════════════════════════════════╗
║  KALLAX Session Start                       v1.0.0 ║
╠════════════════════════════════════════════════════╣
║  ROLE       ▸ ${ROLE}                              ║
║  INSTANCE   ▸ ${INSTANCE_ID} @ ${BRANCH}          ║
║  WORKTREE   ▸ ${WT_DISPLAY}  ║
║  TEAM       ▸ ${CONDUCTOR_COUNT} conductor · ${PERFORMER_COUNT} performers   ║
╠════════════════════════════════════════════════════╣
║  INBOX      [ ${INBOX_COUNT} ]   ← $([ "${INBOX_COUNT}" -eq 0 ] && echo "No pending items" || echo "Pending!")         ║
╠════════════════════════════════════════════════════╣
║  NEXT: ${NEXT}  ║
╚════════════════════════════════════════════════════╝
CARD

echo "${NOW} | START | role=${ROLE} | instance=${INSTANCE_ID} | branch=${BRANCH} | worktree=${IN_WORKTREE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
echo "SESSION_START_OK instance_id=${INSTANCE_ID} role=${ROLE}"
