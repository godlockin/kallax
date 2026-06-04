#!/usr/bin/env bash
# KALLAX Recommend Tasks — recommend a performer for a task via CLI
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
cd "$PROJECT_ROOT"

KALLAX_BIN="${KALLAX_BIN:-$(command -v kallax 2>/dev/null || echo 'npx tsx node/src/index.ts')}"
TOP_N="${2:-10}"
TASK_ID="${3:-}"

usage() {
  echo "Usage: $0 [project-root] [top-n] [task-id]" >&2
  echo "" >&2
  echo "  project-root   KALLAX project root (default: auto-detect)" >&2
  echo "  top-n          Number of recommendations (default: 10)" >&2
  echo "  task-id        Specific task to match (optional, interactive if omitted)" >&2
  exit 1
}

# Validate project root
if [ ! -f "${PROJECT_ROOT}/.kallax/config.yml" ]; then
  echo "Not a KALLAX project root (missing .kallax/config.yml)" >&2
  exit 1
fi

# Check database
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"
if [ ! -f "$DB_PATH" ]; then
  echo "Database not found at $DB_PATH — run 'kallax system:doctor'" >&2
  exit 1
fi

# List available tasks if no task ID given
if [ -z "$TASK_ID" ]; then
  echo "Available pending tasks:" >&2
  if command -v sqlite3 &>/dev/null; then
    sqlite3 -header -column "$DB_PATH" <<'SQL'
      SELECT t.id, t.title FROM tasks t WHERE t.status = 'pending' ORDER BY t.created_at DESC LIMIT 20;
SQL
  fi
  echo "" >&2
  read -r -p "Enter task ID: " TASK_ID </dev/tty
  if [ -z "$TASK_ID" ]; then
    echo "No task ID provided." >&2
    exit 1
  fi
fi

echo "=== KALLAX Recommend Tasks ==="
echo "Task: $TASK_ID"
echo "Top-N: $TOP_N"
echo ""

# Run CLI recommend command
if ! $KALLAX_BIN recommend match "$TASK_ID" --top "$TOP_N" 2>&1; then
  echo ""
  echo "Recommendation failed. Ensure the task exists and performers are registered." >&2
  echo "Fallback: listing available performer instances..." >&2

  if command -v sqlite3 &>/dev/null; then
    sqlite3 -header -column "$DB_PATH" <<'SQL'
      SELECT id, role, status, capabilities FROM instances WHERE status = 'active' ORDER BY last_heartbeat DESC;
SQL
  fi
  exit 1
fi
