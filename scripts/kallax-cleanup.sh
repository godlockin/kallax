#!/usr/bin/env bash
# KALLAX cleanup — one-shot清理 stale instances + orphan heartbeat daemons
# Usage: bash scripts/kallax-cleanup.sh [--dry-run] [--force]
set -uo pipefail

DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    --force) FORCE="true" ;;
  esac
done

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
LOG_DIR="${KALLAX_ROOT}/logs"

echo "── KALLAX cleanup $([ "$DRY_RUN" = "true" ] && echo "(DRY RUN)" || echo "") ──"

# 1. 清理 STALE state.json (last_beat > 5min ago)
STALE_COUNT=0
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  LAST_BEAT=$(jq -r '.heartbeat.last_beat // empty' "$sf" 2>/dev/null || true)
  if [ -z "$LAST_BEAT" ]; then continue; fi
  # Parse ISO timestamp
  _AGE_SEC=$(($(date +%s) - $(date -u -d "$LAST_BEAT" +%s 2>/dev/null || echo 0)))
  if [ "$_AGE_SEC" -gt 300 ]; then  # 5 min threshold
    INSTANCE_ID=$(jq -r '.instance_id // "unknown"' "$sf" 2>/dev/null || echo "unknown")
    echo "  STALE  ${INSTANCE_ID} (last_beat ${_AGE_SEC}s ago)"
    if [ "$DRY_RUN" = "false" ] && [ "$FORCE" = "true" ]; then
      # Mark as ZOMBIE instead of deleting
      jq '.status = "ZOMBIE"' "$sf" > "$sf.tmp" && mv "$sf.tmp" "$sf"
      STALE_COUNT=$((STALE_COUNT + 1))
    fi
  fi
done

# 2. Kill orphan heartbeat daemons (etime > 1h)
ORPHAN_COUNT=0
for pid in $(pgrep -f "heartbeat-daemon" 2>/dev/null || true); do
  [ -z "$pid" ] && continue
  if [ -d "/proc/${pid}" ]; then
    _etime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || true)
    echo "  ORPHAN pid=${pid} etime=${_etime:-unknown} (heartbeat-daemon.sh)"
    if [ "$DRY_RUN" = "false" ]; then
      kill "${pid}" 2>/dev/null && ORPHAN_COUNT=$((ORPHAN_COUNT + 1)) || true
    fi
  fi
done

echo "── done: ${STALE_COUNT} stale marked ZOMBIE, ${ORPHAN_COUNT} orphans killed ──"