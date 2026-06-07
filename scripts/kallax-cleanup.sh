#!/usr/bin/env bash
# KALLAX cleanup — one-shot清理 stale instances + orphan heartbeat daemons
# Usage: bash scripts/kallax-cleanup.sh [--dry-run] [--force]
#   --dry-run: report only, no modifications
#   --force:   actually kill orphans + mark STALE → ZOMBIE
#              (without --force, only the report runs)
# Symmetric semantics (B MEDIUM fix): both orphan-kill and STALE-mark
# require --force. Without --force → dry-run mode.
set -euo pipefail

DRY_RUN="false"
FORCE="false"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    --force) FORCE="true" ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
LOG_DIR="${KALLAX_ROOT}/logs"
ORPHAN_AUDIT="${LOG_DIR}/orphan_kills.jsonl"

# Dry-run unless --force is explicitly given
if [ "$DRY_RUN" = "false" ] && [ "$FORCE" = "true" ]; then
  DRY_RUN="false"
else
  DRY_RUN="true"
fi

mkdir -p "${LOG_DIR}"

echo "── KALLAX cleanup $([ "$DRY_RUN" = "true" ] && echo "(DRY RUN)" || echo "(FORCE: modifying)") ──"

# etime_to_seconds "01:23:45" -> 5025 (or "1-02:03:04" -> 93784)
etime_to_seconds() {
  local e="$1" days=0 rest="" h=0 m=0 s=0
  case "$e" in
    *-*) days="${e%%-*}"; rest="${e#*-}" ;;
    *)   days=0; rest="$e" ;;
  esac
  local IFS=':'
  local parts=($rest)
  case "${#parts[@]}" in
    3) h="${parts[0]}"; m="${parts[1]}"; s="${parts[2]}" ;;
    2) m="${parts[0]}"; s="${parts[1]}" ;;
    *) echo 0; return ;;
  esac
    local dh=${days#0}; dh=${dh:-0}; local hh=${h#0}; hh=${hh:-0}; local mm=${m#0}; mm=${mm:-0}; local ss=${s#0}; ss=${ss:-0}; echo $(( dh * 86400 + hh * 3600 + mm * 60 + ss ))
}

# pid_belongs_to_kallax: returns 0 if pid's instance_dir still exists (ACTIVE)
# Cross-platform: /proc on Linux, ps -o command on macOS
pid_belongs_to_kallax() {
  local _pid="$1"
  local _cmdline=""
  if [ -r "/proc/${_pid}/cmdline" ]; then
    _cmdline=$(tr '\0' ' ' < "/proc/${_pid}/cmdline" 2>/dev/null) || return 1
  else
    _cmdline=$(ps -o command= -p "$_pid" 2>/dev/null) || return 1
  fi
  echo "$_cmdline" | grep -q "heartbeat-daemon" || return 1
  local _instance_id
  _instance_id=$(echo "$_cmdline" | awk '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /heartbeat-daemon\.sh$/) { print $(i+1); exit }
    }
  }' 2>/dev/null) || return 1
  [ -z "$_instance_id" ] && return 1
  [ -d "${INSTANCES_DIR}/${_instance_id}" ] || return 1
  return 0
}

# 1. 清理 STALE state.json (last_beat > 5min ago) — symmetric with orphan kill
STALE_COUNT=0
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  LAST_BEAT=$(jq -r '.heartbeat.last_beat // empty' "$sf" 2>/dev/null || true)
  if [ -z "$LAST_BEAT" ]; then continue; fi
  # Portable timestamp parser (Linux + macOS)
_last_beat_ts=$(date -u -d "$LAST_BEAT" +%s 2>/dev/null) || \
_last_beat_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_BEAT" +%s 2>/dev/null) || \
_last_beat_ts=0
_AGE_SEC=$(($(date +%s) - _last_beat_ts))
  if [ "$_AGE_SEC" -gt 300 ]; then
    INSTANCE_ID=$(jq -r '.instance_id // "unknown"' "$sf" 2>/dev/null || echo "unknown")
    echo "  STALE  ${INSTANCE_ID} (last_beat ${_AGE_SEC}s ago)"
    if [ "$DRY_RUN" = "false" ]; then
      jq '.status = "ZOMBIE"' "$sf" > "$sf.tmp" && mv "$sf.tmp" "$sf"
      STALE_COUNT=$((STALE_COUNT + 1))
    fi
  fi
done

# 2. Kill orphan heartbeat daemons (instance_dir missing + etime > 1h)
#    Instance guard (B CRITICAL fix): only kill if instance_dir no longer exists
ORPHAN_COUNT=0
for pid in $(pgrep -f "heartbeat-daemon" 2>/dev/null || true); do
  [ -z "$pid" ] && continue
  if [ ! -d "/proc/${pid}" ]; then continue; fi
  # Instance guard: skip if instance_dir still exists
  if pid_belongs_to_kallax "$pid"; then continue; fi
  _etime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || true)
  [ -z "$_etime" ] && continue
  _etime_sec=$(etime_to_seconds "$_etime" 2>/dev/null || echo 0)
  if [ "$_etime_sec" -le 3600 ]; then continue; fi  # Only > 1h orphans
  echo "  ORPHAN pid=${pid} etime=${_etime} (heartbeat-daemon.sh, no instance_dir)"
  if [ "$DRY_RUN" = "false" ]; then
    if kill "$pid" 2>/dev/null; then
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
      # Global audit log
      printf '{"ts":"%s","event":"orphan_kill","pid":%s,"etime":"%s","etime_sec":%s,"killer":"cleanup.sh"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pid" "$_etime" "$_etime_sec" \
        >> "$ORPHAN_AUDIT" 2>/dev/null || true
    fi
  fi
done

echo "── done: ${STALE_COUNT} stale marked ZOMBIE, ${ORPHAN_COUNT} orphans killed ──"
