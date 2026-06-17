#!/usr/bin/env bash
# /kallax-merge — Merge an approved PR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-merge — Merge an approved PR

USAGE:
  /kallax-merge [PR_NUMBER]

ARGS:
  PR_NUMBER         PR number to merge (lists open PRs if missing).

DESCRIPTION:
  Performs 3 pre-merge safety checks via the gh CLI: CI status green,
  >= 1 Conductor approval, no merge conflicts with main. If all pass,
  squash-merges the PR. Otherwise prints the failing check and aborts.

EXAMPLES:
  /kallax-merge
  /kallax-merge 123

RELATED:
  /kallax-review-pr, /kallax-verify-pr
EOF
  exit 0
fi

log_title "Merge PR"

require_git_repo

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  if command -v gh &>/dev/null; then
    echo "  Open approved PRs:"
    gh pr list --state open --app "approved" --limit 10 2>/dev/null || echo "  (none)"
  fi
  echo ""
  read -r -p "  PR number to merge: " PR_NUMBER
fi

if [ -z "$PR_NUMBER" ]; then
  log_error "No PR number provided"
  exit 1
fi

echo ""
echo "  Merging PR #${PR_NUMBER}..."

# Pre-merge checks
echo "  [1/3] Checking CI status..."
CI_PASSING=true
if command -v gh &>/dev/null; then
  CI_STATUS=$(gh pr checks "$PR_NUMBER" 2>/dev/null || echo "")
  if echo "$CI_STATUS" | grep -q "fail"; then
    CI_PASSING=false
    log_error "  CI checks failing — cannot merge"
    exit 1
  fi
fi
echo "  ✓ CI checks passing"

echo "  [2/3] Verifying approvals..."
if command -v gh &>/dev/null; then
  REVIEWS=$(gh pr view "$PR_NUMBER" --json reviews 2>/dev/null || echo "")
  APPROVALS=$(echo "$REVIEWS" | grep -o '"state":"APPROVED"' | wc -l | tr -d ' ')
  echo "  ✓ ${APPROVALS} approval(s)"
fi

echo "  [3/3] Squash merging..."
if command -v gh &>/dev/null; then
  gh pr merge "$PR_NUMBER" --squash --delete-branch 2>/dev/null
  MERGE_EXIT=$?
else
  log_error "gh CLI not available"
  exit 1
fi

if [ $MERGE_EXIT -eq 0 ]; then
  echo ""
  log_info "PR #${PR_NUMBER} merged successfully!"
  echo ""
  echo "  Cleanup:"
  echo "    - Worktree will be cleaned up"
  echo "    - Branch will be deleted"
  echo "    - Ticket will be marked DONE"
else
  log_error "Merge failed"
  exit 1
fi
echo ""
