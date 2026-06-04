#!/usr/bin/env bash
# KALLAX Broadcast Task Reset — batch reset expired/stale tasks
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"
STALE_THRESHOLD_MIN="${2:-30}"   # default: 30 minutes

if [ ! -f "$DB_PATH" ]; then
  echo "No database found at $DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
  echo "sqlite3 CLI required but not found" >&2
  exit 1
fi

echo "=== KALLAX Task Reset Broadcast ==="
echo "Stale threshold: ${STALE_THRESHOLD_MIN} minutes"
echo ""

# 1. Find stale claimed/running tasks
# Tasks claimed but never updated beyond threshold
STALE_MS=$((STALE_THRESHOLD_MIN * 60000))
NOW_MS=$(date +%s000)

echo "--- Stale Tasks (idle > ${STALE_THRESHOLD_MIN}m) ---"
sqlite3 -header -column "$DB_PATH" <<SQL
  SELECT t.id, t.status, t.performer_id,
         ROUND((${NOW_MS} - t.updated_at) / 60000.0, 0) AS idle_minutes,
         i.role AS performer_role
  FROM tasks t
  LEFT JOIN instances i ON t.performer_id = i.id
  WHERE t.status IN ('claimed', 'running')
    AND t.updated_at < (${NOW_MS} - ${STALE_MS})
  ORDER BY t.updated_at ASC;
SQL

# 2. Confirm and reset
echo ""
STALE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE status IN ('claimed', 'running') AND updated_at < (${NOW_MS} - ${STALE_MS});" 2>/dev/null || echo "0")

if [ "$STALE_COUNT" -eq 0 ]; then
  echo "No stale tasks to reset."
  exit 0
fi

echo "Found $STALE_COUNT stale task(s)."
read -r -p "Reset these tasks back to pending? [y/N] " CONFIRM </dev/tty
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

# 3. Perform reset within a transaction
echo "Resetting stale tasks..."

sqlite3 "$DB_PATH" <<SQL
  BEGIN TRANSACTION;

  UPDATE tasks
  SET status = 'pending',
      performer_id = NULL,
      updated_at = ${NOW_MS},
      started_at = NULL,
      error = 'reset: stale timeout'
  WHERE status IN ('claimed', 'running')
    AND updated_at < (${NOW_MS} - ${STALE_MS});

  -- Mark related performer instances as idle
  UPDATE instances
  SET status = 'idle',
      current_task_id = NULL
  WHERE id IN (
    SELECT performer_id FROM tasks
    WHERE status = 'pending'
      AND performer_id IS NOT NULL
      AND updated_at = ${NOW_MS}
  );

  COMMIT;
SQL

echo "Reset complete. $STALE_COUNT task(s) returned to pending."

# 4. Show affected tasks
echo ""
echo "--- Reset Tasks ---"
sqlite3 -header -column "$DB_PATH" <<SQL
  SELECT id, status, error FROM tasks
  WHERE error LIKE 'reset:%' AND updated_at = ${NOW_MS}
  ORDER BY id;
SQL
