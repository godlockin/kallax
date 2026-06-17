#!/usr/bin/env bash
# /kallax-phase-review — Phase-based project review

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-phase-review — Phase-based project review

USAGE:
  /kallax-phase-review [PHASE]

ARGS:
  PHASE             Phase id to review (default: all). Example:
                    PHASE-011.

DESCRIPTION:
  Shows completed tasks and open PR counts for the given phase, then
  prints a 5-point review checklist (scope drift / KPI falsification /
  anti-patterns / test coverage / process adherence). Saves a
  phase_review_<timestamp>.md template in .kallax/inbox/.

EXAMPLES:
  /kallax-phase-review
  /kallax-phase-review PHASE-011

RELATED:
  /kallax-check-progress, /kallax-review-pr
EOF
  exit 0
fi

log_title "Phase Review"

PHASE="${1:-all}"

echo "  Reviewing phase: ${PHASE}"
echo ""

echo "  ${BOLD}Phase Checklist${NC}"
echo ""

# Check completed tasks
if command -v kallax &>/dev/null; then
  COMPLETED=$(kallax task status --status completed 2>/dev/null | grep -c "task_" || echo "0")
  echo "  Completed:    ${COMPLETED}"
fi

# Check open PRs
if command -v gh &>/dev/null; then
  OPEN_PRS=$(gh pr list --state open --limit 100 2>/dev/null | wc -l | tr -d ' ')
  echo "  Open PRs:     ${OPEN_PRS}"
fi

# Check milestone
echo ""
echo "  ${BOLD}Review Points${NC}"
echo "  1. Deliverables — are all planned items complete?"
echo "  2. Quality     — test coverage, lint compliance, performance"
echo "  3. Debt        — any tech debt or TODOs introduced?"
echo "  4. Docs        — are docs and ADRs up to date?"
echo "  5. Lessons     — what did we learn? Add to confluence/memory/"
echo ""

PHASE_DIR="${KALLAX_DIR}/inbox"
mkdir -p "$PHASE_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REVIEW_FILE="${PHASE_DIR}/phase_review_${TIMESTAMP}.md"

cat > "$REVIEW_FILE" <<EOF
# Phase Review: ${PHASE}
> Date: $(date -Iseconds)

## Deliverables
- [ ] All planned tasks complete
- [ ] Acceptance criteria met

## Quality
- [ ] Tests passing
- [ ] Lint clean
- [ ] Forbidden patterns scan clean

## Debt
- [ ] No new TODOs without tracking ticket
- [ ] Architecture decisions documented

## Lessons Learned
-

## Next Phase
-
EOF

echo "  Review template: ${REVIEW_FILE}"
echo ""
