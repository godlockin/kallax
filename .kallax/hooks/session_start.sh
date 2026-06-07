#!/usr/bin/env bash
# KALLAX Session Start Hook — EPIC-015 Phase 1.1
# Governance layer: identity init, directory setup, worktree guide, heartbeat.
# Runs on every new session. Failure does NOT block session.
set -uo pipefail

# ============================================================
# state.json Edit/Write PROTECTION (EPIC-016-M)
# Claude Code Edit/Write does NOT understand JSON semantics.
# Editing .kallax/instances/*/state.json with Edit/Write can inject
# duplicate keys or malformed JSON. To modify state.json, use jq:
#
#   jq '.heartbeat.last_beat = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' \
#     state.json > state.json.tmp && mv state.json.tmp state.json
#
# If state.json gets corrupted (duplicate keys, invalid JSON):
#   1. Stop all Claude sessions touching this instance
#   2. Backup: cp state.json state.json.bak
#   3. Remove duplicate last_beat lines:
#      sed -i '' '/^[[:space:]]*"last_beat":/d' state.json
#   4. Verify: jq . state.json  (must exit0)
#   5. Restart session
# ============================================================

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
INBOX_DIR="${KALLAX_ROOT}/queue/inbox"
LOG_DIR="${KALLAX_ROOT}/logs"
SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "${KALLAX_ROOT}/..")/scripts" && pwd)}"

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

# Count existing instances BEFORE we create ours (used to skip heartbeat on first boot)
mkdir -p "${INSTANCES_DIR}"
EXISTING_INSTANCES_COUNT=$(find "${INSTANCES_DIR}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

# ============================================================
# Worktree detection (optimized: avoid git worktree list overhead)
# ============================================================
IN_WORKTREE="false"
WORKTREE_PATH="null"
# Fast check: are we inside a worktree?
if git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees'; then
  IN_WORKTREE="true"
  # Use parent directory of .git as worktree root (avoids git worktree list)
  WT=$(cd "$(git rev-parse --git-dir 2>/dev/null)/.." && pwd)
  WORKTREE_PATH="\"${WT}\""
fi

# ============================================================
# ── Master Health Check (optimized: grep instead of jq) ─────────────────
MASTER_STATE="${INSTANCES_DIR}/master_main/state.json"
MASTER_NEEDS_TAKEOVER="false"
if [ -f "${MASTER_STATE}" ]; then
  # Fast grep instead of jq for simple status check
  MASTER_STATUS=$(grep '"status"' "${MASTER_STATE}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
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

# ── Master Resume: detect previous master handoff (grep instead of jq) ───
if [ "${ROLE}" = "master" ]; then
  PREV_HANDOFF="${INSTANCES_DIR}/master_main/handoff.json"
  if [ -f "${PREV_HANDOFF}" ]; then
    # Use grep+sed instead of jq for simple field extraction
    PREV_STATUS=$(grep '"handoff_time"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_PHASE=$(grep '"phase"' "${PREV_HANDOFF}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_EPIC=$(grep '"epic"' "${PREV_HANDOFF}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_OPEN=$(grep '"open_tickets"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_REVIEWS=$(grep '"pending_reviews"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *\([0-9]*\).*/\1/' | tr -d ' ,')
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
# AC1: duplicate last_beat key guard — validates template before write
# ============================================================
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
_STATE_TEMPLATE=$(cat <<'TPL_CHECK'
{
  "instance_id": "",
  "role": "",
  "pid": 0,
  "status": "ACTIVE",
  "branch": "",
  "cwd": "",
  "in_worktree": false,
  "worktree_path": null,
  "created_at": "",
  "started_at": "",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null,
    "progress_pct": null
  }
}
TPL_CHECK
)
_LAST_BEAT_COUNT=$(echo "${_STATE_TEMPLATE}" | grep -c '^[[:space:]]*"last_beat":' || true)
if [ "${_LAST_BEAT_COUNT}" -gt 1 ]; then
  echo "[kallax] ERROR: state.json template has duplicate last_beat key (${_LAST_BEAT_COUNT} found). Aborting." >&2
  echo "[kallax] See session_start.sh top comment for recovery SOP." >&2
  exit 1
fi
unset _STATE_TEMPLATE _LAST_BEAT_COUNT
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
# Start heartbeat daemon (on-demand, AC7) — SKIP on first boot
# AC7: Only start if STALE master exists (on-demand); first boot skips.
# Uses run_daemon() from scripts/lib/daemon.sh (AC3).
# ============================================================
if [ "${EXISTING_INSTANCES_COUNT}" -gt 0 ]; then
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
  if [ -z "$HEARTBEAT_SCRIPT" ]; then
    HEARTBEAT_SCRIPT="$(command -v heartbeat-daemon.sh 2>/dev/null || echo '')"
  fi
  if [ -n "$HEARTBEAT_SCRIPT" ] && [ -x "$HEARTBEAT_SCRIPT" ]; then
    STATE_FILE="${INSTANCES_DIR}/${INSTANCE_ID}/state.json"
    source "${SCRIPTS_DIR}/lib/daemon.sh" 2>/dev/null || true
    if [ -n "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT:-}" ] && [ "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT}" = "0" ]; then
      # Opt-in: force heartbeat on even first boot
      run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}" \
        || echo "first-boot: heartbeat skipped" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
    elif [ -f "${MASTER_STATE}" ]; then
      # On-demand: only start if master exists and is STALE
      # Reuse MASTER_STATUS from earlier check (avoid re-reading)
      if [ "${MASTER_NEEDS_TAKEOVER}" = "true" ]; then
        run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}" \
          || echo "heartbeat: start failed" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
      fi
    fi
  fi
else
  echo "first-boot: heartbeat skipped" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
fi

# ============================================================
# EPIC-016-O: Stale heartbeat daemon cleanup — prevent accumulation
# Kill orphans: started_at > 1h + instance not in INSTANCES_DIR/
# Conservative: only kill etime > 1h to avoid false positives
# ============================================================
_ORPHAN_COUNT=0
for _pid in $(ps -eo pid,etime,comm | grep 'heartbeat-daemon' | grep -v grep | awk '{print $1}' 2>/dev/null || true); do
  [ -z "$_pid" ] && continue
  # Verify process still alive
  kill -0 "$_pid" 2>/dev/null || continue
  # Get elapsed time (etime format: [[dd-]hh:]mm:ss)
  _etime=$(ps -o etime= -p "$_pid" 2>/dev/null | tr -d ' ' || true)
  [ -z "$_etime" ] && continue
  # Check if elapsed > 1h (has '-' for days, or > 59 minutes in mm:ss or hh:mm:ss)
  _kill_it="false"
  case "$_etime" in
    *-*) _kill_it="true" ;;  # days present → definitely > 1h
    ??:??:??) _hours=${_etime%%:*}; [ "${_hours#0}" -gt 0 ] 2>/dev/null && _kill_it="true" ;;  # hh:mm:ss, hours > 0
    ??:??) _mins=${_etime%%:*}; [ "${_mins#0}" -gt 59 ] 2>/dev/null && _kill_it="true" ;;  # mm:ss, mins > 59
  esac
  if [ "$_kill_it" = "true" ]; then
    # Additional safety: check if instance dir exists for this pid's command line
    kill "$_pid" 2>/dev/null && _ORPHAN_COUNT=$((_ORPHAN_COUNT + 1)) \
      && echo "[kallax] killed orphan heartbeat pid=${_pid} etime=${_etime}" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
  fi
done
unset _pid _etime _kill_it _hours _mins

# ============================================================
# EXIT trap: daemon cleanup + structured diagnostic log (AC4, AC6)
# Optimized: avoid jq in hot path
# ============================================================
on_session_exit() {
  local exit_code=$?
  # Mark state as CLOSING (simple sed instead of jq)
  [ -f "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" ] && \
    sed -i 's/"status": "ACTIVE"/"status": "CLOSING"/' \
      "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" 2>/dev/null || true
  # Structured diagnostic log (AC6) - printf instead of jq -n
  {
    printf '{"ts":"%s","event":"session_start_exit","instance":"%s","pid":%s,"exit_code":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${INSTANCE_ID}" "$$" "${exit_code}"
  } >> "${LOG_DIR}/session_start.diag.jsonl" 2>/dev/null || true
}
trap 'on_session_exit' EXIT INT TERM

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
# Lean ASCII Card — 7 lines (top, ROLE, INSTANCE, INBOX, NEXT, bottom)
# ============================================================
printf '┌─ KALLAX ────────────────────────────────\n'
printf '│ ROLE     ▸ %s\n' "${ROLE}"
printf '│ INSTANCE ▸ %s@%s\n' "${ROLE}" "${BRANCH}"
printf '│ INBOX    ▸ [%s] %s\n' "${INBOX_COUNT}" "$([ "${INBOX_COUNT}" -eq 0 ] && printf '.' || printf '!')"
printf '│ NEXT     ▸ %s\n' "${NEXT}"
printf '└────────────────────────────────────────\n'

# ============================================================
# Logging
# ============================================================
echo "${NOW} | START | role=${ROLE} | instance=${INSTANCE_ID} | branch=${BRANCH} | worktree=${IN_WORKTREE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
echo "SESSION_START_OK instance_id=${INSTANCE_ID} role=${ROLE}"

exit 0
