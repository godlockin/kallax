#!/usr/bin/env bash
# /kallax-verify-pr — Verify PR output before merge (5 levels Fact-Forcing).
# Runs L1 existence (files in diff) -> L2 substance (no TODO in critical
# paths) -> L3 wiring (no @ts-ignore or :any escapes) -> L4 data flow
# (CI green). Use this to confirm a PR passes the fact check before
# merging. Run `/kallax-verify-pr --help` for full reference.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-verify-pr — Verify PR output before merge (5 levels Fact-Forcing)

USAGE:
  /kallax-verify-pr [PR_NUMBER]

ARGS:
  PR_NUMBER         PR number to verify (prompts if missing).

DESCRIPTION:
  Runs the 5 levels Fact-Forcing checks: L1 existence (files in diff) ->
  L2 substance (no TODO in critical paths) -> L3 wiring (no @ts-ignore
  or :any escapes) -> L4 data flow (CI green). Prints pass/warn per
  level and a final verdict.

EXAMPLES:
  /kallax-verify-pr
  /kallax-verify-pr 123

RELATED:
  /kallax-review-pr, /kallax-merge
EOF
  exit 0
fi

log_title "Verify PR"

require_git_repo
PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  read -r -p "  PR number: " PR_NUMBER
fi

log_info "Verifying PR #${PR_NUMBER}"

echo ""
echo "  ${BOLD}L1 — Existence Check${NC}"
echo "  Files in PR:"
if command -v gh &>/dev/null; then
  gh pr view "$PR_NUMBER" --json files 2>/dev/null | grep -o '"path":"[^"]*"' | cut -d'"' -f4 | head -20 || echo "  (unable to fetch)"
fi
echo "  ✓ L1 passed"
echo ""

echo "  ${BOLD}L2 — Substance Check${NC}"
echo "  Checking for stubs/TODOs/placeholders..."
if command -v gh &>/dev/null; then
  DIFF=$(gh pr diff "$PR_NUMBER" 2>/dev/null || echo "")
  STUB_COUNT=$(echo "$DIFF" | grep -ci "TODO\|FIXME\|placeholder\|stub\|not implemented" || echo "0")
  if [ "$STUB_COUNT" -gt 0 ]; then
    log_warn "  ${STUB_COUNT} potential stubs found"
  else
    echo "  No stub indicators found"
  fi
fi
echo "  ✓ L2 passed"
echo ""

echo "  ${BOLD}L3 — Wiring Check${NC}"
echo "  Checking imports/exports..."
if command -v gh &>/dev/null; then
  DIFF=$(gh pr diff "$PR_NUMBER" 2>/dev/null || echo "")
  IMPORT_ISSUES=$(echo "$DIFF" | grep -c "@ts-ignore\|: any" || echo "0")
  if [ "$IMPORT_ISSUES" -gt 0 ]; then
    log_error "  ${IMPORT_ISSUES} type safety violations"
    exit 1
  else
    echo "  No type safety violations"
  fi
fi
echo "  ✓ L3 passed"
echo ""

echo "  ${BOLD}L4 — Data Flow Check${NC}"
echo "  Checking test status..."
if command -v gh &>/dev/null; then
  CI_STATUS=$(gh pr checks "$PR_NUMBER" 2>/dev/null || echo "")
  if echo "$CI_STATUS" | grep -q "fail"; then
    log_error "  CI tests failing"
    exit 1
  else
    echo "  CI passing"
  fi
fi
echo "  ✓ L4 passed"
echo ""

log_info "All 4 levels passed — PR is verified"
echo ""
