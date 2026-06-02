#!/usr/bin/env bash
# /kallax-ask — Ask a question to the expert panel

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Ask Expert Panel"

QUESTION="${1:-}"

if [ -z "$QUESTION" ]; then
  read -r -p "  Your question: " QUESTION
fi

if [ -z "$QUESTION" ]; then
  log_error "No question provided"
  exit 1
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
