#!/usr/bin/env bash
# /kallax-board — Show interactive ticket board

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-board — Show interactive ticket board

USAGE:
  /kallax-board

DESCRIPTION:
  Lists P0 / P1 / in-progress / in-review (open PRs) / recently
  completed tickets in kanban-style groups. Prints total ticket count
  and the next command hints for the active role.

EXAMPLES:
  /kallax-board

RELATED:
  /kallax-check-progress, /kallax-status
EOF
  exit 0
fi

log_title "Ticket Board"

require_git_repo

echo ""
echo "  ${BOLD}P0 — Critical${NC}"
echo ""

if command -v kallax &>/dev/null; then
  kallax task status --status todo --priority P0 2>/dev/null | head -10 || echo "  (no P0 tasks)"
else
  api_call "GET" "/api/tasks?status=todo&priority=P0" 2>/dev/null | head -10 || echo "  (no P0 tasks)"
fi

echo ""
echo "  ${BOLD}P1 — High${NC}"
echo ""

if command -v kallax &>/dev/null; then
  kallax task status --status todo --priority P1 2>/dev/null | head -10 || echo "  (no P1 tasks)"
fi

echo ""
echo "  ${BOLD}In Progress${NC}"
echo ""

if command -v kallax &>/dev/null; then
  kallax task status --status in_progress 2>/dev/null | head -10 || echo "  (no tasks in progress)"
fi

echo ""
echo "  ${BOLD}In Review${NC}"
echo ""

if command -v gh &>/dev/null; then
  gh pr list --state open --limit 5 2>/dev/null || echo "  (no open PRs)"
fi

echo ""
echo "  ${BOLD}Recently Completed${NC}"
echo ""

if command -v kallax &>/dev/null; then
  kallax task status --status completed 2>/dev/null | head -5 || echo "  (no completed tasks)"
fi

echo ""

# Show summary stats
if command -v kallax &>/dev/null; then
  echo "  ${BOLD}Summary${NC}"
  echo ""
  TICKETS_TOTAL=$(find "${KALLAX_ROOT}/jira/tickets" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Total tickets: ${TICKETS_TOTAL}"
  echo ""
fi

echo "  Commands:"
echo "    /kallax-claim            — Claim next available task"
echo "    /kallax-status           — Detailed status"
echo "    /kallax-check-progress   — Team progress overview"
echo ""
