#!/usr/bin/env bash
# /kallax-panel — Launch full expert panel (5 experts + Conductor)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-panel — Launch full expert panel (5 experts + Conductor)

USAGE:
  /kallax-panel [TOPIC]

ARGS:
  TOPIC             The topic to review (optional, prompts if missing)

DESCRIPTION:
  Prints the 5-expert + Conductor panel member list and the 3-phase
  execution flow (independent analysis, Conductor synthesis, Master
  approval). Saves an expert_panel_<timestamp>.md template in
  .kallax/inbox/.

EXAMPLES:
  /kallax-panel "Evaluate the hybrid flag-controlled install design"

RELATED:
  /kallax-expert, /kallax-ask, /kallax-office-hours
EOF
  exit 0
fi

TOPIC="${1:-}"

log_title "Expert Panel"

if [ -z "$TOPIC" ]; then
  read -r -p "  Topic for expert panel review: " TOPIC
fi

if [ -z "$TOPIC" ]; then
  log_error "No topic provided"
  exit 1
fi

echo ""
echo "  Topic: ${TOPIC}"
echo ""
echo "  ${BOLD}Panel Members (5 Core Experts):${NC}"
echo "    🏗️  Architect   — System design, trade-offs, constraints"
echo "    💻 Backend     — API design, data models, performance"
echo "    🎨 Frontend    — Component architecture, UX implementation"
echo "    🖌️  UX Researcher — User flows, accessibility, interaction"
echo "    📋 Product     — Requirements, priorities, business value"
echo ""
echo "  ${BOLD}Execution Flow:${NC}"
echo "    Phase 1: Architect scans codebase → architecture context"
echo "    Phase 2: 4 experts analyze in parallel (isolated)"
echo "    Phase 3: Conductor aggregates → unified recommendation"
echo ""
echo "  Launch with:"
echo "    /kallax-expert architect \"${TOPIC}\""
echo "    /kallax-expert backend \"${TOPIC}\""
echo "    /kallax-expert frontend \"${TOPIC}\""
echo "    /kallax-expert ux \"${TOPIC}\""
echo "    /kallax-expert product \"${TOPIC}\""
echo ""

# Save panel request
PANEL_DIR="${KALLAX_DIR}/inbox"
mkdir -p "$PANEL_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PANEL_FILE="${PANEL_DIR}/expert_panel_${TIMESTAMP}.md"

cat > "$PANEL_FILE" <<EOF
# Expert Panel Review: ${TOPIC}
> Requested: $(date -Iseconds)

## Panel Members
- 🏗️ Architect
- 💻 Backend
- 🎨 Frontend
- 🖌️ UX Researcher
- 📋 Product

## Context
${TOPIC}

## Phase 1: Architecture Context
[Architect output]

## Phase 2: Parallel Analysis
[4 expert outputs]

## Phase 3: Conductor Summary
### Recommendation
### Implementation Path
### Risks & Mitigations
### Action Items
- [ ] Item 1
- [ ] Item 2
EOF

echo ""
log_info "Panel template saved: ${PANEL_FILE}"
echo ""
