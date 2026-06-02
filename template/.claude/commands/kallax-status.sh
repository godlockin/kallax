#!/usr/bin/env bash
# /kallax-status — Show current system and task status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "KALLAX Status"

require_git_repo
ROLE=$(get_role)

echo "  Role:       ${BOLD}${ROLE}${NC}"
echo "  Project:    $(get_repo_name)"
echo "  Branch:     $(current_branch)"

# Try API first
HEALTH=$(api_call "GET" "/health" 2>/dev/null || echo "")
if [ -n "$HEALTH" ] && echo "$HEALTH" | grep -q "ok"; then
  echo ""
  log_info "Server is running"

  # Get stats
  STATS=$(api_call "GET" "/stats" 2>/dev/null || echo "{}")
  TASKS=$(echo "$STATS" | grep -o '"taskCount":[0-9]*' | grep -o '[0-9]*' || echo "0")
  AGENTS=$(echo "$STATS" | grep -o '"instanceCount":[0-9]*' | grep -o '[0-9]*' || echo "0")

  echo "  Tasks:      ${TASKS}"
  echo "  Agents:     ${AGENTS}"

  # Show agent status if registered
  if [ "$ROLE" != "unset" ]; then
    AGENT=$(api_call "GET" "/api/agents/current" 2>/dev/null || echo "")
    if [ -n "$AGENT" ]; then
      AGENT_STATUS=$(echo "$AGENT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
      CURRENT_TASK=$(echo "$AGENT" | grep -o '"currentTaskId":"[^"]*"' | cut -d'"' -f4 || echo "none")
      echo "  Status:     ${AGENT_STATUS}"
      echo "  Task:       ${CURRENT_TASK}"
    fi
  fi
else
  log_warn "Server not running — showing local state only"
fi

# Show local task state
echo ""
print_divider

if [ "$ROLE" = "conductor" ]; then
  echo "  Conductor Heartbeat Checklist:"
  echo "    Q1: Task priority — check /kallax-board"
  echo "    Q2: Performer status — check /kallax-instances"
  echo "    Q3: Project progress — check /kallax-analyze"
  echo "    Q4: Blocked decisions — check .kallax/inbox/"
  echo "    Q5: Message queue — check .kallax/queue/"
else
  echo "  Performer Checklist:"
  echo "    Available tasks: /kallax-claim"
  echo "    Current work: check git worktree list"
  echo "    Progress: /kallax-status"
fi
echo ""
