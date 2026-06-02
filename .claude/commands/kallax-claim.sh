#!/usr/bin/env bash
# /kallax-claim — Claim an available task (auto-creates worktree)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Claim Task"

require_git_repo

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  # Auto-claim next available task
  log_info "Looking for available tasks..."

  if command -v kallax &>/dev/null; then
    TASKS=$(kallax task status --status pending 2>/dev/null || echo "")
  else
    TASKS=$(api_call "GET" "/api/tasks?status=pending&limit=5" 2>/dev/null || echo "[]")
  fi

  if [ -z "$TASKS" ] || [ "$TASKS" = "[]" ]; then
    log_warn "No pending tasks available"
    echo ""
    echo "  Try:"
    echo "    /kallax-board          — View all tickets"
    echo "    /kallax-analyze        — Analyze requirements"
    exit 0
  fi

  echo ""
  echo "  Available tasks:"
  echo "$TASKS" | head -20
  echo ""
  read -r -p "  Enter task ID to claim (or Enter to auto-claim): " TASK_ID

  if [ -z "$TASK_ID" ]; then
    log_info "Auto-claiming first available task..."
  fi
fi

# Execute claim
log_info "Claiming task: ${TASK_ID:-auto}"

if command -v kallax &>/dev/null; then
  if [ -n "$TASK_ID" ]; then
    kallax task claim "$TASK_ID"
  else
    kallax task claim
  fi
  EXIT_CODE=$?
else
  RESPONSE=$(api_call "PUT" "/api/tasks/${TASK_ID:-next}/claim" "" 2>/dev/null || echo "")
  if echo "$RESPONSE" | grep -q "error"; then
    log_error "Failed to claim task: $RESPONSE"
    exit 1
  fi
  EXIT_CODE=0
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  log_info "Task claimed successfully!"
  echo "  Worktree created — you are now isolated"
  echo ""
  echo "  Next:"
  echo "    Start developing (TDD: write tests first)"
  echo "    /kallax-status         — Check progress"
  echo "    /kallax-submit-pr      — Submit when done"
else
  log_error "Failed to claim task"
fi
echo ""
