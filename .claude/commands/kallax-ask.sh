#!/usr/bin/env bash
# /kallax-ask — Ask a question to the expert panel.
# Auto-routes a question to relevant experts (architect / backend /
# frontend / ux / product / security / performance) based on detected
# keywords. Use this when you want a single question answered by the
# most relevant expert. Run `/kallax-ask --help` for full reference.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-ask — Ask a question to the expert panel

USAGE:
  /kallax-ask "<question>"

ARGS:
  question          The question to route (optional, shows help if missing)

DESCRIPTION:
  Keyword-routes a question to relevant experts based on detected
  keywords (architect / backend / frontend / ux / product / security /
  performance). Falls back to the core panel
  (architect backend ux product) if no keyword matches. Prints a
  per-expert /kallax-expert invocation suggestion for each match.

EXAMPLES:
  /kallax-ask "How should we structure the WebSocket reconnection logic?"

RELATED:
  /kallax-expert, /kallax-panel
EOF
  exit 0
fi

log_title "Ask Expert Panel"

QUESTION="${1:-}"

# No question provided -> show help (don't silently fail or prompt)
if [ -z "$QUESTION" ]; then
  echo ""
  log_warn "No question provided. Showing help:"
  echo ""
  show_help <<'EOF'
/kallax-ask — Ask a question to the expert panel

USAGE:
  /kallax-ask "<question>"

ARGS:
  question          The question to route (optional, shows help if missing)

DESCRIPTION:
  Keyword-routes a question to relevant experts based on detected
  keywords (architect / backend / frontend / ux / product / security /
  performance). Falls back to the core panel
  (architect backend ux product) if no keyword matches. Prints a
  per-expert /kallax-expert invocation suggestion for each match.

EXAMPLES:
  /kallax-ask "How should we structure the WebSocket reconnection logic?"

RELATED:
  /kallax-expert, /kallax-panel
EOF
  exit 0
fi

echo ""
echo "  Question: ${QUESTION}"
echo ""

# Automatically detect the best experts for the question
echo "  ${BOLD}Routing question to relevant experts...${NC}"
echo ""

QUESTION_LOWER=$(echo "$QUESTION" | tr '[:upper:]' '[:lower:]')

EXPERTS=""
if echo "$QUESTION_LOWER" | grep -q "architect\|design\|system\|structure\|pattern"; then
  EXPERTS="$EXPERTS architect"
fi
if echo "$QUESTION_LOWER" | grep -q "api\|backend\|database\|data\|server\|endpoint"; then
  EXPERTS="$EXPERTS backend"
fi
if echo "$QUESTION_LOWER" | grep -q "frontend\|ui\|component\|react\|vue\|css\|style"; then
  EXPERTS="$EXPERTS frontend"
fi
if echo "$QUESTION_LOWER" | grep -q "ux\|user\|usability\|accessib\|interact"; then
  EXPERTS="$EXPERTS ux"
fi
if echo "$QUESTION_LOWER" | grep -q "product\|requirement\|priority\|roadmap\|milestone"; then
  EXPERTS="$EXPERTS product"
fi
if echo "$QUESTION_LOWER" | grep -q "security\|vuln\|auth\|penetrat\|exploit"; then
  EXPERTS="$EXPERTS security"
fi
if echo "$QUESTION_LOWER" | grep -q "performance\|slow\|optimize\|latency\|throughput"; then
  EXPERTS="$EXPERTS performance"
fi

# Default to core panel if no match
if [ -z "$EXPERTS" ]; then
  EXPERTS="architect backend ux product"
fi

echo "  Experts selected:"
for e in $EXPERTS; do
  echo "    - ${e}"
done

echo ""
echo "  Ask each expert individually:"
for e in $EXPERTS; do
  echo "    /kallax-expert ${e} \"${QUESTION}\""
done
echo ""
