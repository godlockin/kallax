#!/usr/bin/env bash
# /kallax-expert — Summon a specific expert for analysis

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

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

# Check expert exists
EXPERT_FILE="${KALLAX_ROOT}/.claude/skills/kallax/experts/default/${EXPERT}.md"
if [ ! -f "$EXPERT_FILE" ]; then
  EXPERT_FILE="${KALLAX_ROOT}/.claude/skills/kallax/experts/extended/*/${EXPERT}.md"
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
