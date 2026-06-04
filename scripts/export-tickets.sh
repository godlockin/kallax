#!/usr/bin/env bash
# KALLAX Export Tickets — export tickets and tasks to JSON or CSV
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"
FORMAT="${2:-json}"
OUTPUT_DIR="${3:-${PROJECT_ROOT}/output}"

if [ ! -f "$DB_PATH" ]; then
  echo "No database found at $DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
  echo "sqlite3 CLI required but not found" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Helper: export to JSON
export_json() {
  local table="$1"
  local file="${OUTPUT_DIR}/${table}.json"

  sqlite3 "$DB_PATH" <<SQL
.mode json
SELECT * FROM ${table} ORDER BY created_at DESC;
SQL
}

# Helper: export to CSV
export_csv() {
  local table="$1"
  local file="${OUTPUT_DIR}/${table}.csv"

  sqlite3 -header -csv "$DB_PATH" "SELECT * FROM ${table} ORDER BY created_at DESC;" > "$file"
  echo "  $file ($(wc -l < "$file" | tr -d ' ') lines)"
}

echo "=== KALLAX Ticket Export ==="
echo "Format: ${FORMAT}"
echo "Output: ${OUTPUT_DIR}/"
echo ""

case "$FORMAT" in
  json)
    echo "--- Exporting tickets ---"
    sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM tickets ORDER BY created_at DESC;" > "${OUTPUT_DIR}/tickets.json"
    echo "  ${OUTPUT_DIR}/tickets.json ($(wc -c < "${OUTPUT_DIR}/tickets.json" | tr -d ' ') bytes)"

    echo "--- Exporting tasks ---"
    sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM tasks ORDER BY created_at DESC;" > "${OUTPUT_DIR}/tasks.json"
    echo "  ${OUTPUT_DIR}/tasks.json ($(wc -c < "${OUTPUT_DIR}/tasks.json" | tr -d ' ') bytes)"

    echo "--- Exporting instances ---"
    sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM instances ORDER BY started_at DESC;" > "${OUTPUT_DIR}/instances.json"
    echo "  ${OUTPUT_DIR}/instances.json ($(wc -c < "${OUTPUT_DIR}/instances.json" | tr -d ' ') bytes)"

    # Export combined report
    echo "--- Generating combined summary ---"
    sqlite3 "$DB_PATH" <<SQL
.mode json
SELECT
  (SELECT COUNT(*) FROM tickets) AS total_tickets,
  (SELECT COUNT(*) FROM tasks) AS total_tasks,
  (SELECT COUNT(*) FROM instances) AS total_instances,
  (SELECT COUNT(*) FROM tickets WHERE status = 'completed') AS completed_tickets,
  (SELECT COUNT(*) FROM tasks WHERE status = 'completed') AS completed_tasks,
  (SELECT COUNT(*) FROM tickets WHERE status = 'backlog' OR status = 'todo') AS backlog_count;
SQL
    ;;

  csv)
    export_csv tickets
    export_csv tasks
    export_csv instances
    ;;

  *)
    echo "Unsupported format: $FORMAT (use json or csv)" >&2
    exit 1
    ;;
esac

echo ""
echo "Export complete. Files in ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/" 2>/dev/null
