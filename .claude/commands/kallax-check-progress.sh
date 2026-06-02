#!/usr/bin/env bash
# /kallax-check-progress — Check team progress and milestone status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Progress Check"

require_git_repo

echo ""

if command -v kallax &>/dev/null; then
  kallax task status 2>/dev/null | head -40
else
  TASKS=$(api_call "GET" "/api/tasks" 2>/dev/null || echo "[]")
  echo "$TASKS" | head -30
fi

echo ""
echo "  ${BOLD}Completion Rate${NC}"
echo ""

# Count tasks by status
if command -v kallax &>/dev/null; then
  TOTAL=$(kallax task status 2>/dev/null | grep -c "task_" || echo "0")
  DONE=$(kallax task status --status completed 2>/dev/null | grep -c "task_" || echo "0")
  IN_PROGRESS=$(kallax task status --status in_progress 2>/dev/null | grep -c "task_" || echo "0")
fi

COMPLETION=0
if [ "${TOTAL:-0}" -gt 0 ]; then
  COMPLETION=$(( (DONE * 100) / TOTAL ))
fi

echo "  Total:       ${TOTAL:-0}"
echo "  Completed:   ${DONE:-0}"
echo "  In Progress: ${IN_PROGRESS:-0}"
echo "  Rate:        ${COMPLETION}%"
echo ""

# Show progress bar
BAR_LENGTH=40
FILLED=$(( COMPLETION * BAR_LENGTH / 100 ))
printf "  ["
printf "=%.0s" $(seq 1 "$FILLED")
printf " %.0s" $(seq $((FILLED + 1)) "$BAR_LENGTH")
printf "] ${COMPLETION}%%\n"

echo ""
echo "  /kallax-board           — Detailed ticket view"
echo "  /kallax-instances       — Check performer status"
echo ""
