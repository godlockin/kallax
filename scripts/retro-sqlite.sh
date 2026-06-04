#!/usr/bin/env bash
# KALLAX SQLite Retro — generate database statistics report for retrospectives
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"

if [ ! -f "$DB_PATH" ]; then
  echo "No database found at $DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
  echo "sqlite3 CLI required but not found" >&2
  exit 1
fi

echo "=== KALLAX SQLite Retrospective Report ==="
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Database:  $DB_PATH"
echo ""

# 1. Ticket summary by status
echo "--- Tickets by Status ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT status, COUNT(*) AS count,
         ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tickets), 1) AS pct
  FROM tickets GROUP BY status ORDER BY count DESC;
SQL

echo ""

# 2. Task summary by status
echo "--- Tasks by Status ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT status, COUNT(*) AS count,
         ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tasks), 1) AS pct
  FROM tasks GROUP BY status ORDER BY count DESC;
SQL

echo ""

# 3. Priority distribution
echo "--- Priority Distribution ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT priority, COUNT(*) AS count
  FROM tickets GROUP BY priority ORDER BY
    CASE priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 WHEN 'P3' THEN 3 ELSE 4 END;
SQL

echo ""

# 4. Average completion time by task type
echo "--- Avg Completion Time (minutes) by Type ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT type, COUNT(*) AS done,
         ROUND(AVG((completed_at - started_at) / 60000.0), 1) AS avg_minutes,
         ROUND(MIN((completed_at - started_at) / 60000.0), 1) AS min_minutes,
         ROUND(MAX((completed_at - started_at) / 60000.0), 1) AS max_minutes
  FROM tasks
  WHERE status = 'completed' AND started_at IS NOT NULL AND completed_at IS NOT NULL
  GROUP BY type ORDER BY avg_minutes DESC;
SQL

echo ""

# 5. Conductor/performer activity
echo "--- Instance Activity ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT role, status, COUNT(*) AS count,
         ROUND(AVG((? - last_heartbeat) / 60000.0), 1) AS avg_idle_minutes
  FROM instances GROUP BY role, status ORDER BY role, status;
SQL

echo ""

# 6. Recent tickets (last 7 days)
echo "--- Tickets Created in Last 7 Days ---"
sqlite3 -header -column "$DB_PATH" <<'SQL'
  SELECT substr(id, 1, 12) AS id, title, status, priority,
         datetime(created_at / 1000, 'unixepoch') AS created
  FROM tickets
  WHERE created_at >= (? - 604800000)
  ORDER BY created_at DESC LIMIT 20;
SQL

echo ""

# 7. Database size
echo "--- Database Stats ---"
DB_SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null)
echo "File size: $(numfmt --to=iec-i 2>/dev/null <<<"$DB_SIZE" || echo "${DB_SIZE} bytes")"

TICKET_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tickets;")
TASK_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks;")
INSTANCE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM instances;")

echo "Tickets:   $TICKET_COUNT"
echo "Tasks:     $TASK_COUNT"
echo "Instances: $INSTANCE_COUNT"
echo ""
echo "=== Report Complete ==="
