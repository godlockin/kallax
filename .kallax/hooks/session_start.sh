#!/usr/bin/env bash
# KALLAX Session Start Hook — EPIC-015 Phase 1.1
# Governance layer: identity init, directory setup, worktree guide, heartbeat.
# Runs on every new session. Failure does NOT block session.
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
INBOX_DIR="${KALLAX_ROOT}/queue/inbox"
LOG_DIR="${KALLAX_ROOT}/logs"

HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
PID="${$}"

# ============================================================
# Role Detection (priority: env > CLI arg > config file > branch)
# ============================================================
ROLE=""

# 1. Environment variable
if [ -n "${KALLAX_ROLE:-}" ]; then
  ROLE="$KALLAX_ROLE"
fi

# 2. CLI args: session_start.sh --role <role>
if [ -z "$ROLE" ]; then
  _args=("$@")
  _i=0
  while [ $_i -lt ${#_args[@]} ]; do
    case "${_args[$_i]}" in
      --role|-r)
        _i=$((_i + 1))
        if [ $_i -lt ${#_args[@]} ]; then
          ROLE="${_args[$_i]}"
        fi
        ;;
    esac
    _i=$((_i + 1))
  done
  unset _args _i
fi

# 3. instance_config.yml
if [ -z "$ROLE" ] && [ -f "${KALLAX_ROOT}/state/instance_config.yml" ]; then
  ROLE=$(grep '^role:' "${KALLAX_ROOT}/state/instance_config.yml" | head -1 | awk '{print $2}' | tr -d ' ')
fi

# 4. Branch fallback
if [ -z "$ROLE" ]; then
  _branch=$(git branch --show-current 2>/dev/null || echo '')
  case "$_branch" in
    feature/*|fix/*|chore/*) ROLE="performer" ;;
    *) ROLE="conductor" ;;
  esac
  unset _branch
fi

INSTANCE_ID="${KALLAX_INSTANCE_ID:-${ROLE}_${HOSTNAME}_${PID}}"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
CWD="$(pwd)"

# ============================================================
# Worktree detection
# ============================================================
IN_WORKTREE="false"
WORKTREE_PATH="null"
if git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees'; then
  IN_WORKTREE="true"
  WT=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  WORKTREE_PATH="\"${WT}\""
fi

# ============================================================
# ── Master Health Check ──────────────────────────────────────────────────
MASTER_STATE="${INSTANCES_DIR}/master_main/state.json"
MASTER_NEEDS_TAKEOVER="false"
if [ -f "${MASTER_STATE}" ]; then
  MASTER_STATUS=$(jq -r '.status // "unknown"' "${MASTER_STATE}" 2>/dev/null || echo "unknown")
  if [ "${MASTER_STATUS}" = "STALE" ] || [ "${MASTER_STATUS}" = "CLOSING" ]; then
    MASTER_NEEDS_TAKEOVER="true"
  fi
else
  # No master state at all — first boot
  MASTER_NEEDS_TAKEOVER="true"
fi

# Auto-promote: if no explicit role and master needs takeover, suggest becoming master
if [ "${MASTER_NEEDS_TAKEOVER}" = "true" ] && [ -z "${ROLE}" ]; then
  cat << MASTER_PROMPT

╔════════════════════════════════════════════════════╗
║  ⚠ NO ACTIVE MASTER DETECTED                       ║
╠════════════════════════════════════════════════════╣
║  Previous master is STALE or absent.               ║
║  Run: KALLAX_ROLE=master bash session_start.sh     ║
║  Or:   session_start.sh --role master              ║
╚════════════════════════════════════════════════════╝
MASTER_PROMPT
fi

# ── Master Resume: detect previous master handoff ──────────────────────────
if [ "${ROLE}" = "master" ]; then
  PREV_HANDOFF="${INSTANCES_DIR}/master_main/handoff.json"
  if [ -f "${PREV_HANDOFF}" ]; then
    PREV_STATUS=$(jq -r '.handoff_time // "unknown"' "${PREV_HANDOFF}" 2>/dev/null || echo "unknown")
    PREV_PHASE=$(jq -r '.phase // "unknown"' "${PREV_HANDOFF}" 2>/dev/null || echo "unknown")
    PREV_EPIC=$(jq -r '.epic // "unknown"' "${PREV_HANDOFF}" 2>/dev/null || echo "unknown")
    PREV_OPEN=$(jq -r '.open_tickets // "none"' "${PREV_HANDOFF}" 2>/dev/null || echo "none")
    PREV_REVIEWS=$(jq -r '.pending_reviews // "0"' "${PREV_HANDOFF}" 2>/dev/null || echo "0")
    cat << RESUME

╔════════════════════════════════════════════════════╗
║  MASTER RESUME — Previous session handoff found    ║
╠════════════════════════════════════════════════════╣
║  Handoff at   ▸ ${PREV_STATUS}                     ║
║  Phase        ▸ ${PREV_PHASE}                      ║
║  Epic         ▸ ${PREV_EPIC}                       ║
║  Open Tickets ▸ ${PREV_OPEN}                       ║
║  Reviews      ▸ ${PREV_REVIEWS} pending            ║
╠════════════════════════════════════════════════════╣
║  NEXT: check inbox → review performers → continue  ║
╚════════════════════════════════════════════════════╝
RESUME
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | RESUME | prev=master_main | phase=${PREV_PHASE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
    RESUME_MODE="true"
  else
    RESUME_MODE="false"
  fi
fi

# Create directories
# ============================================================
mkdir -p "${INSTANCES_DIR}/${INSTANCE_ID}"
mkdir -p "${INBOX_DIR}/${INSTANCE_ID}"
mkdir -p "${KALLAX_ROOT}/queue/outbox/${INSTANCE_ID}"
mkdir -p "${LOG_DIR}"

# ============================================================
# Write state.json
# ============================================================
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

# ============================================================
# Start heartbeat daemon (multi-path fallback)
# ============================================================
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
HEARTBEAT_SCRIPT=""
for candidate in \
  "${KALLAX_ROOT}/../scripts/heartbeat-daemon.sh" \
  "${REPO_ROOT:+${REPO_ROOT}/scripts/heartbeat-daemon.sh}" \
  "${KALLAX_ROOT}/hooks/heartbeat-daemon.sh"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    HEARTBEAT_SCRIPT="$candidate"
    break
  fi
done
# PATH fallback
if [ -z "$HEARTBEAT_SCRIPT" ]; then
  HEARTBEAT_SCRIPT="$(command -v heartbeat-daemon.sh 2>/dev/null || echo '')"
fi
if [ -n "$HEARTBEAT_SCRIPT" ] && [ -x "$HEARTBEAT_SCRIPT" ]; then
  "${HEARTBEAT_SCRIPT}" "${INSTANCE_ID}" "${INSTANCES_DIR}" &
fi

# ============================================================
# Team count (jq preferred, grep fallback — no python3)
# ============================================================
CONDUCTOR_COUNT=0
PERFORMER_COUNT=0
if command -v jq &>/dev/null; then
  for sf in "${INSTANCES_DIR}"/*/state.json; do
    [ -f "${sf}" ] || continue
    r=$(jq -r '.role // ""' "${sf}" 2>/dev/null || echo '')
    case "${r}" in master|conductor) CONDUCTOR_COUNT=$((CONDUCTOR_COUNT+1)) ;; performer) PERFORMER_COUNT=$((PERFORMER_COUNT+1)) ;; esac
  done
else
  for sf in "${INSTANCES_DIR}"/*/state.json; do
    [ -f "${sf}" ] || continue
    r=$(grep -o '"role"[[:space:]]*:[[:space:]]*"[^"]*"' "${sf}" | head -1 | sed 's/.*"\(.*\)"/\1/')
    case "${r}" in master|conductor) CONDUCTOR_COUNT=$((CONDUCTOR_COUNT+1)) ;; performer) PERFORMER_COUNT=$((PERFORMER_COUNT+1)) ;; esac
  done
fi

# ============================================================
# Inbox count
# ============================================================
INBOX_COUNT=0
if [ -d "${INBOX_DIR}/${INSTANCE_ID}" ]; then
  INBOX_COUNT=$(ls -1 "${INBOX_DIR}/${INSTANCE_ID}/" 2>/dev/null | wc -l | tr -d ' ')
fi

# ============================================================
# Next action
# ============================================================
case "${ROLE}" in
  master)
    NEXT="kallax status / review PRs / approve"
    ;;
  conductor)
    if [ "${IN_WORKTREE}" = "false" ]; then
      NEXT="EnterWorktree / status / team overview"
    else
      NEXT="status / team check / task dispatch"
    fi
    ;;
  performer)
    NEXT="inbox check / claim card / EnterWorktree"
    ;;
  *)
    NEXT="kallax start --role conductor|performer"
    ;;
esac

WT_DISPLAY="$([ "${IN_WORKTREE}" = "true" ] && echo "${WORKTREE_PATH}" | tr -d '"' || echo "NOT ISOLATED")"

# Shorten worktree path for display (last 2 components)
WT_SHORT="${WT_DISPLAY}"
if [ "${IN_WORKTREE}" = "true" ] && [ "${#WT_DISPLAY}" -gt 35 ]; then
  _p1="${WT_DISPLAY%/*}"
  _p2="${_p1##*/}"
  _p3="${WT_DISPLAY##*/}"
  WT_SHORT="...${_p2}/${_p3}"
  unset _p1 _p2 _p3
fi

# ============================================================
# ASCII Card (CJK-aware alignment)
# ============================================================
# visible_width: approximate display width (CJK=2, ASCII=1)
_visible_width() {
  local s="$1" bytes="" chars=""
  bytes=$(printf '%s' "$s" | wc -c | tr -d ' ')
  chars=$(printf '%s' "$s" | wc -m | tr -d ' ')
  echo $(( (${bytes:-0} + ${chars:-0}) / 2 ))
}

# card_line: right-padded content, truncated to fit 54-char box
_card_line() {
  local content="$1" vw="" pad=""
  vw=$(_visible_width "$content")
  # Truncate with ellipsis if content exceeds available width
  while [ $vw -gt 50 ] && [ ${#content} -gt 4 ]; do
    content="${content:0:$((${#content} - 1))}..."
    vw=$(_visible_width "$content")
  done
  pad=$((50 - vw))
  [ $pad -lt 0 ] && pad=0
  printf '║  %s%*s║\n' "$content" "$pad" ""
}

cat << "CARD_TOP"
╔════════════════════════════════════════════════════╗
║  KALLAX Session Start                       v1.0.0 ║
╠════════════════════════════════════════════════════╣
CARD_TOP
_card_line "ROLE     ▸ ${ROLE}"
_card_line "INSTANCE ▸ ${ROLE}@${BRANCH}"
_card_line "WORKTREE ▸ ${WT_SHORT}"
_card_line "TEAM     ▸ ${CONDUCTOR_COUNT} conductor / ${PERFORMER_COUNT} performer"
printf '╠════════════════════════════════════════════════════╣\n'
if [ "${INBOX_COUNT}" -eq 0 ]; then
  _card_line "INBOX      [ ${INBOX_COUNT} ]   ← No pending items"
else
  _card_line "INBOX      [ ${INBOX_COUNT} ]   ← Pending!"
fi
printf '╠════════════════════════════════════════════════════╣\n'
_card_line "NEXT: ${NEXT}"
printf '╚════════════════════════════════════════════════════╝\n'

# ============================================================
# Logging
# ============================================================
echo "${NOW} | START | role=${ROLE} | instance=${INSTANCE_ID} | branch=${BRANCH} | worktree=${IN_WORKTREE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
echo "SESSION_START_OK instance_id=${INSTANCE_ID} role=${ROLE}"

exit 0
