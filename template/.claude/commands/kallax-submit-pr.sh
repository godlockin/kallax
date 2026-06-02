#!/usr/bin/env bash
# /kallax-submit-pr — Complete task and submit PR for review
# Runs Saga 5-step: tests → lint → verify → commit → PR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Submit PR"

require_git_repo

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  # Try to detect current task from worktree
  CURRENT_BRANCH=$(current_branch)
  if echo "$CURRENT_BRANCH" | grep -q "kallax/"; then
    TASK_ID=$(echo "$CURRENT_BRANCH" | sed 's/kallax\///')
  fi

  if [ -z "$TASK_ID" ]; then
    read -r -p "  Task ID: " TASK_ID
  fi
fi

if [ -z "$TASK_ID" ]; then
  log_error "No task ID provided"
  exit 1
fi

log_info "Completing task: ${TASK_ID}"

echo ""
echo "  Saga 5-Step Completion:"
echo "    [1/5] Running tests..."
echo "    [2/5] Running lint..."
echo "    [3/5] Verifying output (4-Level Fact-Forcing)..."
echo "    [4/5] Committing changes..."
echo "    [5/5] Creating pull request..."
echo ""

COMPLETE_OPTS=""

read -r -p "  Skip tests? [y/N]: " SKIP
if [ "$SKIP" = "y" ] || [ "$SKIP" = "Y" ]; then
  COMPLETE_OPTS="$COMPLETE_OPTS --skip-tests"
fi

read -r -p "  Skip lint? [y/N]: " SKIP_LINT
if [ "$SKIP_LINT" = "y" ] || [ "$SKIP_LINT" = "Y" ]; then
  COMPLETE_OPTS="$COMPLETE_OPTS --skip-lint"
fi

echo ""

if command -v kallax &>/dev/null; then
  # Run verify first
  log_info "Verifying output..."
  kallax verify:output "$TASK_ID" -v
  VERIFY_EXIT=$?

  if [ $VERIFY_EXIT -ne 0 ]; then
    log_error "Verification failed. Fix issues before submitting."
    echo ""
    echo "  Check:"
    echo "    L1 Existence: Are all expected files present?"
    echo "    L2 Substance: Is the code real (not stubs)?"
    echo "    L3 Wiring:    Are imports/exports correct?"
    echo "    L4 Data Flow: Do integration tests pass?"
    exit 1
  fi

  log_info "Verification passed — submitting..."
  # shellcheck disable=SC2086
  kallax task complete "$TASK_ID" $COMPLETE_OPTS
else
  RESPONSE=$(api_call "PUT" "/api/tasks/${TASK_ID}/complete" "{}" 2>/dev/null || echo "")
  if echo "$RESPONSE" | grep -q "error"; then
    log_error "Failed: $RESPONSE"
    exit 1
  fi
fi

echo ""
log_info "PR submitted for review!"
echo ""
echo "  Conductor will review and provide feedback."
echo "  Wait for:"
echo "    - Code review comments"
echo "    - CI checks (tests, lint, scan)"
echo "    - Gate review approval"
echo ""
echo "  /kallax-status         — Check review status"
echo ""
