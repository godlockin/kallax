#!/usr/bin/env bash
# /kallax-list — List all available experts, skills, and resources

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-list — List all available experts, skills, and resources

USAGE:
  /kallax-list

DESCRIPTION:
  Prints a categorized tree of 5 core experts, 5+ extended experts,
  and 16+ skills. Use this to discover what is available before
  summoning an expert or invoking a skill.

EXAMPLES:
  /kallax-list

RELATED:
  /kallax-help, /kallax-expert
EOF
  exit 0
fi

log_title "Available Resources"

echo ""
echo "  ${BOLD}Core Experts (5)${NC}"
echo "  ├── architect      — System architecture, tech decisions"
echo "  ├── backend        — API design, data models, performance"
echo "  ├── frontend       — Component design, state management"
echo "  ├── ux             — User experience, interaction design"
echo "  └── product        — Requirements, priorities, ROI"
echo ""

echo "  ${BOLD}Extended Experts (50+)${NC}"
echo "  ├── AI/ML (6)      — aiml, bigdata, cv, data-analyst, mlops, nlp"
echo "  ├── Business (5)   — business, compliance, finance, legal, strategy"
echo "  ├── Consulting (3) — it-consulting, mgmt, process"
echo "  ├── Design (5)     — brand, industrial, motion, ux-research, visual"
echo "  ├── HR (2)         — recruitment, training"
echo "  ├── Knowledge (2)  — documentation, knowledge-mgmt"
echo "  ├── Marketing (3)  — content, digital, growth"
echo "  ├── Ops (3)        — devops, sre, infra"
echo "  ├── PR (2)         — communications, media"
echo "  └── Tech (3)       — security, performance, database"
echo ""

echo "  ${BOLD}Skills (16)${NC}"
echo "  ├── Algorithm (1)  — algorithm-design"
echo "  ├── Analysis (2)   — code-analysis, requirements-analysis"
echo "  ├── Data (1)       — data-modeling"
echo "  ├── DevOps (2)     — ci-cd, kubernetes"
echo "  ├── Documentation(2) — technical-writing, api-docs"
echo "  ├── Implementation(2) — tdd, refactoring"
echo "  ├── LLM (2)        — prompt-engineering, agent-design"
echo "  ├── Ops (2)        — monitoring, incident-response"
echo "  ├── Security (2)   — security-review, penetration-testing"
echo "  └── UX (2)         — user-research, usability-testing"
echo ""

echo "  ${BOLD}Commands${NC}"
echo "  /kallax-help              — Full command reference"
echo "  /kallax-expert <role>     — Summon expert"
echo "  /kallax-skill <name>      — Execute skill"
echo "  /kallax-panel [topic]     — Full expert panel"
echo ""
