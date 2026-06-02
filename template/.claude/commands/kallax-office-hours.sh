#!/usr/bin/env bash
# /kallax-office-hours — Requirements analysis (6 questions method)
# Helps clarify ambiguous requirements before development starts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Office Hours — Requirements Analysis"

TOPIC="${1:-}"

if [ -z "$TOPIC" ]; then
  echo "  Describe what you want to build:"
  echo ""
  read -r -p "  > " TOPIC
fi

if [ -z "$TOPIC" ]; then
  log_error "No topic provided"
  exit 1
fi

echo ""
echo "  Analyzing: ${TOPIC}"
echo ""
print_separator

# Six Questions Method
echo ""
echo "  ${BOLD}Q1: What problem does this solve?${NC}"
echo "  ─────────────────────────────────────"
echo "  - Who is the user?"
echo "  - What pain point does it address?"
echo "  - What is the success metric?"
echo ""
echo "  ${BOLD}Q2: What are the constraints?${NC}"
echo "  ─────────────────────────────────────"
echo "  - Technology constraints (language, framework, platform)?"
echo "  - Time constraints (deadline, dependency)?"
echo "  - Resource constraints (team, budget, infra)?"
echo ""
echo "  ${BOLD}Q3: What are the risks?${NC}"
echo "  ─────────────────────────────────────"
echo "  - Technical risks (complexity, unknowns)?"
echo "  - Dependency risks (external APIs, other teams)?"
echo "  - Operational risks (deployment, rollback, monitoring)?"
echo ""
echo "  ${BOLD}Q4: What are the alternatives?${NC}"
echo "  ─────────────────────────────────────"
echo "  - Build vs buy vs integrate?"
echo "  - Simpler approach that achieves 80%?"
echo "  - Phased rollout strategy?"
echo ""
echo "  ${BOLD}Q5: How do we verify success?${NC}"
echo "  ─────────────────────────────────────"
echo "  - Acceptance criteria (measurable)?"
echo "  - Test strategy (unit, integration, e2e)?"
echo "  - Monitoring and alerting plan?"
echo ""
echo "  ${BOLD}Q6: What's the minimum viable scope?${NC}"
echo "  ─────────────────────────────────────"
echo "  - MVP features vs nice-to-have?"
echo "  - Can we split into smaller tickets?"
echo "  - What's the dependency order?"
echo ""
print_separator

# Save analysis
ANALYSIS_DIR="${KALLAX_DIR}/inbox"
mkdir -p "$ANALYSIS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ANALYSIS_FILE="${ANALYSIS_DIR}/requirements_${TIMESTAMP}.md"

cat > "$ANALYSIS_FILE" <<EOF
# Requirements Analysis: ${TOPIC}
> Generated: $(date -Iseconds)

## Q1: Problem & Users
[To be filled]

## Q2: Constraints
[To be filled]

## Q3: Risks
[To be filled]

## Q4: Alternatives
[To be filled]

## Q5: Success Criteria
[To be filled]

## Q6: MVP Scope
[To be filled]

## Action Items
- [ ] Create EPIC ticket
- [ ] Break down into tasks
- [ ] Assign to performers
- [ ] Set milestones
EOF

echo ""
log_info "Analysis template saved: ${ANALYSIS_FILE}"
echo ""
echo "  Next:"
echo "    Fill in answers to the 6 questions"
echo "    /kallax-analyze          — Analyze codebase context"
echo "    /kallax-panel \"${TOPIC}\"  — Launch expert panel for this topic"
echo ""
