#!/usr/bin/env bash
# /kallax-task — Quick task management shortcut

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-task — Quick task management shortcut

USAGE:
  /kallax-task [action] [TASK_ID]

ARGS:
  action            One of: claim, complete, status, list (default: status)
  TASK_ID           Optional ticket id (required for claim / complete).

DESCRIPTION:
  Wraps the kallax task <action> CLI subcommand for in-tool
  convenience. Default action is "status" which shows the active
  task on the current branch.

EXAMPLES:
  /kallax-task
  /kallax-task list
  /kallax-task claim TICKET-123
  /kallax-task complete TICKET-123

RELATED:
  /kallax-claim, /kallax-submit-pr
EOF
  exit 0
fi

ACTION="${1:-status}"
TASK_ID="${2:-}"

case "$ACTION" in
  status)
    if command -v kallax &>/dev/null; then
      kallax task status "$TASK_ID" 2>/dev/null
    else
      api_call "GET" "/api/tasks/${TASK_ID}" 2>/dev/null
    fi
    ;;
  create)
    TICKET="${2:-}"
    if [ -z "$TICKET" ]; then
      read -r -p "  Ticket ID: " TICKET
    fi
    if command -v kallax &>/dev/null; then
      kallax task create "$TICKET"
    else
      api_call "POST" "/api/tasks" "{\"ticketId\":\"${TICKET}\"}"
    fi
    ;;
  progress)
    PROGRESS="${3:-}"
    if [ -z "$PROGRESS" ]; then
      read -r -p "  Progress (0-100): " PROGRESS
    fi
    if command -v kallax &>/dev/null; then
      kallax task progress "$TASK_ID" "$PROGRESS"
    fi
    ;;
  resume)
    if command -v kallax &>/dev/null; then
      kallax task resume "$TASK_ID"
    fi
    ;;
  *)
    echo "  Usage:"
    echo "    /kallax-task status [taskId]"
    echo "    /kallax-task create <ticketId>"
    echo "    /kallax-task progress <taskId> <0-100>"
    echo "    /kallax-task resume <taskId>"
    ;;
esac
echo ""
