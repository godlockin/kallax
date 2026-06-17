#!/usr/bin/env bash
# /kallax-review-analysis — Review codebase analysis results

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-review-analysis — Review codebase analysis results

USAGE:
  /kallax-review-analysis

DESCRIPTION:
  Shows the top-10 most-changed files, test-to-source ratio, knowledge
  base size, and a list of code-health warnings. Use this for a
  code-knowledge health audit.

EXAMPLES:
  /kallax-review-analysis

RELATED:
  /kallax-analyze, /kallax-phase-review
EOF
  exit 0
fi

log_title "Review Analysis"

require_git_repo

echo ""
echo "  ${BOLD}Code Health Indicators${NC}"
echo ""

# File change frequency
echo "  Most changed files (last 30 days):"
git log --since="30 days ago" --name-only --oneline 2>/dev/null | grep -E '\.(ts|rs|sh)$' | sort | uniq -c | sort -rn | head -10
echo ""

# Test file ratio
TOTAL_SRC=$(find . -name '*.ts' -o -name '*.rs' 2>/dev/null | grep -v node_modules | grep -v target | grep -v '\.test\.' | wc -l | tr -d ' ')
TOTAL_TEST=$(find . -name '*.test.ts' -o -name '*_test.rs' 2>/dev/null | grep -v node_modules | grep -v target | wc -l | tr -d ' ')
if [ "$TOTAL_SRC" -gt 0 ]; then
  TEST_RATIO=$(( TOTAL_TEST * 100 / TOTAL_SRC ))
  echo "  Test ratio: ${TEST_RATIO}% (${TOTAL_TEST} tests / ${TOTAL_SRC} source files)"
fi
echo ""

echo "  ${BOLD}Knowledge Health${NC}"
echo ""
MEMORY_FILES=$(find "${KALLAX_ROOT}/confluence/memory" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "  Knowledge entries: ${MEMORY_FILES}"
echo ""

echo "  ${BOLD}Recommendations${NC}"
echo ""
if [ "$TEST_RATIO" -lt 20 ] 2>/dev/null; then
  echo "  ⚠ Test coverage may be low — consider adding tests"
fi
if [ "$MEMORY_FILES" -lt 10 ]; then
  echo "  ⚠ Knowledge base is small — document learnings regularly"
fi
echo ""
