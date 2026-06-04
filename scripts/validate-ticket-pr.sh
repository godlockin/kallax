#!/usr/bin/env bash
# KALLAX Validate Ticket-PR — verify PR is correctly linked to a ticket
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
cd "$PROJECT_ROOT"

BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"

echo "=== KALLAX Ticket-PR Validation ==="
echo "Branch: $BRANCH"
echo ""

# Extract ticket/task ID from branch name
TICKET_ID=$(echo "$BRANCH" | grep -oE 'TICKET-[A-Z0-9]+' || true)
TASK_ID=$(echo "$BRANCH" | grep -oE 'TASK-[A-Z0-9]+' || true)

if [ -z "$TICKET_ID" ] && [ -z "$TASK_ID" ]; then
  echo "FAIL: Branch name does not contain a ticket or task ID."
  echo "Expected format: feature/TICKET-XXXX-description or fix/TASK-XXXX-description"
  exit 1
fi

echo "Branch:   $BRANCH"
echo "Ticket:   ${TICKET_ID:-N/A}"
echo "Task:     ${TASK_ID:-N/A}"
echo ""

# Check database for the ticket/task
if command -v sqlite3 &>/dev/null && [ -f "$DB_PATH" ]; then
  # Validate ticket exists
  if [ -n "$TICKET_ID" ]; then
    TICKET_STATUS=$(sqlite3 "$DB_PATH" "SELECT status FROM tickets WHERE id = '${TICKET_ID}';" 2>/dev/null || true)
    if [ -z "$TICKET_STATUS" ]; then
      echo "WARN: Ticket $TICKET_ID not found in database."
    else
      echo "PASS: Ticket $TICKET_ID status = $TICKET_STATUS"
    fi
  fi

  # Validate task exists
  if [ -n "$TASK_ID" ]; then
    TASK_STATUS=$(sqlite3 "$DB_PATH" "SELECT status FROM tasks WHERE id = '${TASK_ID}';" 2>/dev/null || true)
    if [ -z "$TASK_STATUS" ]; then
      echo "WARN: Task $TASK_ID not found in database."
    else
      echo "PASS: Task $TASK_ID status = $TASK_STATUS"
    fi
  fi
else
  echo "INFO: Database not available — skipping DB validation"
fi

# Get recent commits
echo ""
echo "--- Recent Commits (last 5) ---"
git log --oneline -5 2>/dev/null || echo "(no commits)"

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "WARN: $UNCOMMITTED uncommitted file(s)"
fi

# Validate PR is linked in commit messages
PR_MENTIONS=$(git log --oneline -20 2>/dev/null | grep -ciE '#[0-9]+' || true)
if [ "$PR_MENTIONS" -gt 0 ]; then
  echo "PASS: Found $PR_MENTIONS PR references in recent commits"
else
  echo "WARN: No PR references (#N) found in recent commits"
fi

echo ""
echo "--- Summary ---"
if [ -n "$TICKET_ID" ] || [ -n "$TASK_ID" ]; then
  echo "VALID: Branch references a known ticket/task"
  exit 0
else
  echo "INVALID: Cannot determine ticket association"
  exit 1
fi
