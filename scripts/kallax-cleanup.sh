#!/usr/bin/env bash
# KALLAX cleanup — one-shot清理 stale instances + orphan heartbeat daemons
# Usage: bash scripts/kallax-cleanup.sh [--dry-run] [--force]
#          [--age-days N] [--include-status S1,S2] [--archive-dir DIR]
#   --dry-run:           report only, no modifications
#   --force:             actually kill orphans + mark STALE → ZOMBIE
#                        + archive CLOSING/ZOMBIE instances (Phase 0.3)
#                        (without --force, only the report runs)
#   --age-days N:        Phase 0.3 age threshold (default 30, EPIC-027-B AC2)
#   --include-status S:  comma-separated statuses to pre-clean (default CLOSING,ZOMBIE)
#   --archive-dir DIR:   Phase 0.3 archive target (default .kallax/instances/.archive)
#   --help|-h:           this help
# Symmetric semantics (B MEDIUM fix): both orphan-kill and STALE-mark
# require --force. Without --force → dry-run mode.
# Phase 0.3 (EPIC-027-B): pre-clean 21 CLOSING instances older than N days
# Phase 0.4 (EPIC-027-B): rollback SOP via .archive/YYYYMMDD_HHMMSS_INSTANCE_ID/
set -euo pipefail

DRY_RUN="false"
FORCE="false"
AGE_DAYS="30"
ARCHIVE_DIR_DEFAULT="${KALLAX_ROOT:-.kallax}/instances/.archive"
ARCHIVE_DIR="${ARCHIVE_DIR_DEFAULT}"
INCLUDE_STATUSES="CLOSING,ZOMBIE"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --force) FORCE="true"; shift ;;
    --age-days) AGE_DAYS="${2:-30}"; shift 2 ;;
    --age-days=*) AGE_DAYS="${1#--age-days=}"; shift ;;
    --include-status) INCLUDE_STATUSES="${2:-CLOSING,ZOMBIE}"; shift 2 ;;
    --include-status=*) INCLUDE_STATUSES="${1#--include-status=}"; shift ;;
    --archive-dir) ARCHIVE_DIR="${2:-${ARCHIVE_DIR_DEFAULT}}"; shift 2 ;;
    --archive-dir=*) ARCHIVE_DIR="${1#--archive-dir=}"; shift ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
LOG_DIR="${KALLAX_ROOT}/logs"
ORPHAN_AUDIT="${LOG_DIR}/orphan_kills.jsonl"
PRE_CLEAN_AUDIT="${LOG_DIR}/pre_clean.jsonl"

STALE_HEARTBEAT_THRESHOLD_SEC="300"
ORPHAN_ETIME_THRESHOLD_SEC="3600"
TODAY_EPOCH="$(date +%s)"
AGE_SEC_THRESHOLD="$(( AGE_DAYS * 86400 ))"

# Dry-run unless --force is explicitly given
if [ "$DRY_RUN" = "false" ] && [ "$FORCE" = "true" ]; then
  DRY_RUN="false"
else
  DRY_RUN="true"
fi

mkdir -p "${LOG_DIR}"

MODE_LABEL=$([ "$DRY_RUN" = "true" ] && echo "(DRY RUN)" || echo "(FORCE: modifying)")
echo "── KALLAX cleanup ${MODE_LABEL} ──"
echo "  Phase 0.3 age threshold: ${AGE_DAYS}d (--age-days)"
echo "  Phase 0.3 include statuses: ${INCLUDE_STATUSES}"

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

# state_mtime_epoch: returns the latest state-change epoch from state.json
# Sources (priority order):
#   1. .state.last_state_change (ISO8601, written on status transitions)
#   2. .heartbeat.last_beat     (ISO8601, falls back when no transitions recorded)
#   3. stat mtime of state.json (last resort)
# Echoes 0 when state.json unreadable.
state_mtime_epoch() {
  local sf="$1"
  local last_change last_beat parsed=0
  last_change=$(jq -r '.state.last_state_change // .last_state_change // empty' "$sf" 2>/dev/null || true)
  if [ -n "$last_change" ]; then
    parsed=$(date -u -d "$last_change" +%s 2>/dev/null || echo 0)
    if [ "${parsed}" != "0" ]; then echo "${parsed}"; return; fi
  fi
  last_beat=$(jq -r '.heartbeat.last_beat // empty' "$sf" 2>/dev/null || true)
  if [ -n "$last_beat" ]; then
    parsed=$(date -u -d "$last_beat" +%s 2>/dev/null || echo 0)
    if [ "${parsed}" != "0" ]; then echo "${parsed}"; return; fi
  fi
  if [ -r "$sf" ]; then
    if stat -c %Y "$sf" >/dev/null 2>&1; then
      stat -c %Y "$sf"
    else
      stat -f %m "$sf"
    fi
  else
    echo 0
  fi
}

# status_in_include_set: returns 0 when $1 matches one of comma-separated INCLUDE_STATUSES
status_in_include_set() {
  local status="$1"
  local IFS=','
  local candidates=(${INCLUDE_STATUSES})
  for s in "${candidates[@]}"; do
    [ "$s" = "$status" ] && return 0
  done
  return 1
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

# Phase 0.3 (EPIC-027-B): pre-clean CLOSING / ZOMBIE instances older than --age-days
#    MUST run BEFORE Step 1 (STALE → ZOMBIE mark) which mutates state.json mtime.
#    Steps: audit (always) → dry-run preview → --force archives to .archive/YYYYMMDD_HHMMSS_INSTANCE_ID/
#    Rollback: restore .archive/<TS>_<ID>/* back to .kallax/instances/<ID>/ (see docs/SOP-cleanup.md)
PRE_CLEAN_IDENTIFIED=0
PRE_CLEAN_ARCHIVED=0
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
mkdir -p "${ARCHIVE_DIR}"

for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  INSTANCE_DIR="$(dirname "$sf")"
  INSTANCE_ID="$(basename "$INSTANCE_DIR")"
  [ "$INSTANCE_ID" = ".archive" ] && continue

  STATUS=$(jq -r '.status // "unknown"' "$sf" 2>/dev/null || echo "unknown")
  if ! status_in_include_set "$STATUS"; then continue; fi

  MTIME_EPOCH=$(state_mtime_epoch "$sf")
  if [ "${MTIME_EPOCH}" = "0" ]; then continue; fi
  AGE_SEC=$(( TODAY_EPOCH - MTIME_EPOCH ))
  if [ "${AGE_SEC}" -lt "${AGE_SEC_THRESHOLD}" ]; then continue; fi

  AGE_DAYS_ACTUAL=$(( AGE_SEC / 86400 ))
  PRE_CLEAN_IDENTIFIED=$((PRE_CLEAN_IDENTIFIED + 1))

  if [ "$DRY_RUN" = "true" ]; then
    echo "  PRE-CLEAN ${INSTANCE_ID} status=${STATUS} age=${AGE_DAYS_ACTUAL}d (would archive)"
    continue
  fi

  ARCHIVE_TARGET="${ARCHIVE_DIR}/${TIMESTAMP}_${INSTANCE_ID}"
  if [ -e "${ARCHIVE_TARGET}" ]; then
    echo "  PRE-CLEAN ${INSTANCE_ID}: SKIP (archive target ${ARCHIVE_TARGET} exists)"
    continue
  fi

  mkdir -p "${ARCHIVE_TARGET}"
  # Pre-archive safety backup (Phase 0.4 rollback): keep state.json.bak in archive
  cp "${sf}" "${ARCHIVE_TARGET}/state.json.bak" 2>/dev/null || true
  if mv "${INSTANCE_DIR}"/* "${ARCHIVE_TARGET}/" 2>/dev/null; then
    rmdir "${INSTANCE_DIR}" 2>/dev/null || true
    PRE_CLEAN_ARCHIVED=$((PRE_CLEAN_ARCHIVED + 1))
    printf '{"ts":"%s","event":"pre_clean_archive","instance_id":"%s","status":"%s","age_days":%s,"age_threshold_days":%s,"archive_path":"%s","source":"kallax-cleanup.sh"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INSTANCE_ID" "$STATUS" "$AGE_DAYS_ACTUAL" "$AGE_DAYS" "${ARCHIVE_TARGET}" \
      >> "$PRE_CLEAN_AUDIT" 2>/dev/null || true
    echo "  PRE-CLEAN ${INSTANCE_ID} status=${STATUS} age=${AGE_DAYS_ACTUAL}d → archived to ${ARCHIVE_TARGET}"
  else
    echo "  PRE-CLEAN ${INSTANCE_ID}: FAIL (mv error, inspect ${INSTANCE_DIR})"
  fi
done

# 1. 清理 STALE state.json (last_beat > 5min ago) — symmetric with orphan kill
STALE_COUNT=0
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  INSTANCE_DIR="$(dirname "$sf")"
  INSTANCE_ID="$(basename "$INSTANCE_DIR")"
  [ "$INSTANCE_ID" = ".archive" ] && continue
  LAST_BEAT=$(jq -r '.heartbeat.last_beat // empty' "$sf" 2>/dev/null || true)
  if [ -z "$LAST_BEAT" ]; then continue; fi
  _AGE_SEC=$(($(date +%s) - $(date -u -d "$LAST_BEAT" +%s 2>/dev/null || echo 0)))
  if [ "$_AGE_SEC" -gt "${STALE_HEARTBEAT_THRESHOLD_SEC}" ]; then
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
  if [ "$_etime_sec" -le "${ORPHAN_ETIME_THRESHOLD_SEC}" ]; then continue; fi  # Only > 1h orphans
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

echo "── done: ${PRE_CLEAN_IDENTIFIED} pre-clean identified (${PRE_CLEAN_ARCHIVED} archived), ${STALE_COUNT} stale marked ZOMBIE, ${ORPHAN_COUNT} orphans killed ──"