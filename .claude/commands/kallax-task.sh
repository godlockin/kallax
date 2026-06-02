#!/usr/bin/env bash
# /kallax-task — Quick task management shortcut

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

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
