#!/usr/bin/env bash
# KALLAX Zombie Instance Archive -- EPIC-016-R AC9
# Archives (does NOT delete) zombie/stale instances to .archive/ for traceability.
set -uo pipefail

INSTANCES_DIR="${1:-.kallax/instances}"
ARCHIVE_DIR="${INSTANCES_DIR}/.archive"
DRY_RUN="${DRY_RUN:-false}"

mkdir -p "${ARCHIVE_DIR}"

COUNT=0
for state_file in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "${state_file}" ] || continue
  INSTANCE_DIR="$(dirname "$state_file")"
  INSTANCE_ID="$(basename "$INSTANCE_DIR")"

  # Skip .archive itself
  [ "$INSTANCE_ID" = ".archive" ] && continue

  STATUS=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")
  DAEMON_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' "$state_file" 2>/dev/null || true)

  # Criteria: ZOMBIE or STALE, or daemon dead
  IS_ZOMBIE=false
  if [ "$STATUS" = "ZOMBIE" ] || [ "$STATUS" = "STALE" ]; then
    IS_ZOMBIE=true
  elif [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
    IS_ZOMBIE=true
  fi

  if [ "$IS_ZOMBIE" = true ]; then
    ARCHIVE_SUBDIR="${ARCHIVE_DIR}/$(date +%Y%m%d_%H%M%S)_${INSTANCE_ID}"
    if [ "$DRY_RUN" = true ]; then
      echo "[dry-run] would archive: $INSTANCE_ID (status=$STATUS, daemon=$DAEMON_PID)"
    else
      mkdir -p "$ARCHIVE_SUBDIR"
      mv "$INSTANCE_DIR"/* "$ARCHIVE_SUBDIR/" 2>/dev/null || true
      rmdir "$INSTANCE_DIR" 2>/dev/null || true
      echo "archived: $INSTANCE_ID -> $ARCHIVE_SUBDIR"
    fi
    COUNT=$((COUNT + 1))
  fi
done

echo "Zombie archive complete: $COUNT instance(s) processed"
[ "$DRY_RUN" = true ] && echo "(dry-run mode)"