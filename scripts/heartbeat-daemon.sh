#!/usr/bin/env bash
# KALLAX Heartbeat Daemon -- EPIC-015 Phase 1.5
# Governance layer: periodic heartbeat tick, independent of LLM.
# Pure bash + jq, no Python/Node dependency.
#
# Usage: heartbeat-daemon.sh <instance_id> [instances_dir] [interval_seconds] [--headless|--stdio]
#   --headless: CI/scripting mode, JSON-only output, no TTY
#   --stdio:     piping mode, JSON in/out over stdin/stdout
#
# Schema for state.json heartbeat fields:
#   heartbeat.last_beat            -- ISO 8601 timestamp of last heartbeat tick
#   heartbeat.missed_count         -- consecutive missed beats (reset to 0 on tick)
#   heartbeat.heartbeat_daemon_pid -- PID of the running heartbeat daemon process
set -euo pipefail

# EPIC-122-C: Parse optional mode flags
MODE="interactive"
_remaining_args=()
for arg in "$@"; do
  case "$arg" in
    --headless|--stdio) MODE="${arg#--}"; shift ;;
    *) _remaining_args+=("$arg"); shift ;;
  esac
done
set -- "${_remaining_args[@]}"

INSTANCE_ID="${1:?Usage: heartbeat-daemon.sh <instance_id> [instances_dir] [interval_seconds] [--headless|--stdio]}"
INSTANCES_DIR="${2:-.kallax/instances}"
INTERVAL="${3:-60}"
STATE_FILE="${INSTANCES_DIR}/${INSTANCE_ID}/state.json"

# EPIC-122-C: headless mode — suppress all TTY output
if [[ "$MODE" == "headless" ]]; then
  exec 1>/dev/null 2>/dev/null
fi

if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: state.json not found at ${STATE_FILE}" >&2
  exit 1
fi

# EPIC-122-D: atomic_write_with_fsync — crash-safe state update
# Grok-build CheckpointStore pattern: temp-file + fsync + rename + dir-fsync
# Args: STATE_FILE, jq_expr, [jq_args...]
atomic_write_with_fsync() {
  local state_file="$1"; shift
  local jq_expr="$1"; shift

  local tmp="${state_file}.tmp.$$"
  local dir
  dir=$(dirname "$state_file")

  if ! jq "$jq_expr" "$state_file" > "$tmp" 2>/dev/null; then
    echo "[heartbeat] jq update failed for ${INSTANCE_ID}" >&2
    rm -f "$tmp"
    return 1
  fi

  # EPIC-122-D: fsync the file before rename (grok-build CheckpointStore pattern)
  if command -v sync &>/dev/null; then
    sync "$tmp" 2>/dev/null || true
  fi

  if ! mv "$tmp" "$state_file" 2>/dev/null; then
    echo "[heartbeat] atomic write failed for ${INSTANCE_ID}" >&2
    rm -f "$tmp"
    return 1
  fi

  # EPIC-122-D: fsync the containing directory (makes rename durable)
  if command -v sync &>/dev/null; then
    sync "$dir" 2>/dev/null || true
  fi

  return 0
}

# Trap cleanup on exit -- mark session as CLOSING (pure jq)
# NOTE: bash resumes execution after a trapped signal unless we exit explicitly.
# EXIT trap handles cleanup; INT/TERM traps just trigger exit to avoid resume.
cleanup() {
  if [ -f "${STATE_FILE}" ]; then
    jq '.status = "CLOSING"' "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null && \
      mv "${STATE_FILE}.tmp" "${STATE_FILE}" 2>/dev/null || true
  fi
  echo "[heartbeat] daemon stopped for ${INSTANCE_ID}"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# Write own PID into state.json on startup
if ! jq --argjson pid "$$" '.heartbeat.heartbeat_daemon_pid = $pid' "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null; then
  echo "[heartbeat] failed to write PID to state.json" >&2
  exit 1
fi
mv "${STATE_FILE}.tmp" "${STATE_FILE}"

echo "[heartbeat] daemon started for ${INSTANCE_ID} (interval=${INTERVAL}s, pid=$$)"

while true; do
  sleep "${INTERVAL}"

  if [ ! -f "${STATE_FILE}" ]; then
    echo "[heartbeat] state.json missing, exiting" >&2
    exit 1
  fi

  # EPIC-122-D: Atomic heartbeat update via jq -- reset missed_count, set last_beat, revive from STALE
  # Now uses fsync for crash safety
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if ! atomic_write_with_fsync "${STATE_FILE}" \
    --arg now "${NOW}" \
    '.heartbeat.last_beat = $now |
     .heartbeat.missed_count = 0 |
     if .status == "STALE" then .status = "ACTIVE" else . end'; then
    echo "[heartbeat] atomic write failed for ${INSTANCE_ID}" >&2
  fi

  # EPIC-021-F: expert_invocations tracking -- emit invocation on each heartbeat
  # EPIC-026-A Fix #4: dual-write (state.json + queue).
  # emit() internally calls write_state_invocations() for state.json,
  # AND the degradation chain (redis/sqlite/file) for the queue.
  # Queue is the upgrade path; disk persistence is the default.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  QUEUE_LIB="${SCRIPT_DIR}/lib/expert-invocation-queue.sh"
  if [ -f "${QUEUE_LIB}" ]; then
    source "${QUEUE_LIB}"
    MY_EXPERT_ID="$(jq -r '.expert_id // empty' "${STATE_FILE}" 2>/dev/null || echo '')"
    LAST_TICKET="$(jq -r '.ticket_id // empty' "${STATE_FILE}" 2>/dev/null || echo '')"
    if [ -n "$MY_EXPERT_ID" ] && [ -n "$LAST_TICKET" ]; then
      if ! emit "$MY_EXPERT_ID" "$LAST_TICKET" 2>/dev/null; then
        echo "[heartbeat] emit failed for ${MY_EXPERT_ID}:${LAST_TICKET}, continuing" >&2
      fi
    fi

    # LRU 1000 -- trim expert_invocations array in state.json
    # EPIC-122-D: now uses atomic_write_with_fsync for crash safety
    if ! atomic_write_with_fsync "${STATE_FILE}" \
      'if .expert_invocations then [.expert_invocations[0:1000]] else . end |
       .expert_invocations = (if .expert_invocations then .expert_invocations else [] end)'; then
      echo "[heartbeat] LRU trim failed for ${INSTANCE_ID}" >&2
    fi
  fi
done
