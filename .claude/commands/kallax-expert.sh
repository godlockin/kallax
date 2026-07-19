#!/usr/bin/env bash
# /kallax-expert — Summon a specific expert for analysis.
# Loads an expert profile (core: architect / backend / frontend / ux /
# product; extended: auditor / compliance / decision-gate / process /
# security) and prints the analysis context. Use this for deep
# analysis from one specific role. Run `/kallax-expert --help`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-expert — Summon a specific expert for analysis

USAGE:
  /kallax-expert <role> [context]

ARGS:
  role              Expert role name (required). Core: architect / backend
                    / frontend / ux / product. Extended: auditor /
                    compliance / decision-gate / process-engineering /
                    security.
  context           Optional question or context to feed the expert.

DESCRIPTION:
  Locates the expert profile file under .claude/skills/kallax/default/
  or .claude/skills/kallax/extended/ and prints the analysis context
  plus a prompt to feed the user-specific details.

EXAMPLES:
  /kallax-expert backend
  /kallax-expert security "Should we use JWT or session cookies for auth?"

RELATED:
  /kallax-ask, /kallax-panel, /kallax-list
EOF
  exit 0
fi

EXPERT="${1:-}"
CONTEXT="${2:-}"

log_title "Expert Summon"

if [ -z "$EXPERT" ]; then
  echo "  Available core experts:"
  echo "    architect     — System architecture, tech decisions"
  echo "    backend       — API design, data models, performance"
  echo "    frontend      — Component design, state management"
  echo "    ux            — User experience, interaction design"
  echo "    product       — Requirements, priorities, ROI"
  echo ""
  echo "  Extended experts (50+):"
  echo "    AI:     aiml, bigdata, cv, data-analyst, mlops, nlp"
  echo "    Biz:    business, compliance, finance, legal, strategy"
  echo "    Ops:    devops, sre, infra"
  echo "    Tech:   security, performance, database"
  echo "    Design: brand, industrial, motion, ux-research, visual"
  echo ""
  echo "  Usage: /kallax-expert <role> [context]"
  echo ""
  exit 0
fi

log_info "Summoning expert: ${EXPERT}"

# Check expert exists — try both layouts (legacy `experts/default/` and current `default/`)
EXPERT_FILE="${KALLAX_ROOT}/.claude/skills/kallax/default/${EXPERT}.md"
if [ ! -f "$EXPERT_FILE" ]; then
  EXPERT_FILE="${KALLAX_ROOT}/.claude/skills/kallax/experts/default/${EXPERT}.md"
fi
if [ ! -f "$EXPERT_FILE" ]; then
  EXPERT_FILE="${KALLAX_ROOT}/.claude/skills/kallax/extended/${EXPERT}.md"
fi
if [ ! -f "$EXPERT_FILE" ]; then
  log_error "Expert not found: ${EXPERT}"
  echo "  Run /kallax-list to see available roles"
  exit 2  # Distinct code so LLM can detect "not found" vs generic error
fi

echo ""
echo "  Expert:    ${EXPERT}"
echo "  Context:   ${CONTEXT:-General analysis}"
echo ""
echo "  The expert will analyze from their domain perspective."
echo "  Provide detailed context for best results."
echo ""
echo "  Expert profile: ${EXPERT_FILE}"
echo ""
