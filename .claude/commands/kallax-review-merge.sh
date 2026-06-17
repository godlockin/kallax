#!/usr/bin/env bash
# /kallax-review-merge — Combined review + merge workflow

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-review-merge — Combined review + merge workflow

USAGE:
  /kallax-review-merge [PR_NUMBER]

ARGS:
  PR_NUMBER         PR number (prompts if missing).

DESCRIPTION:
  Sequentially sources verify-pr -> review-pr -> merge sub-scripts.
  Aborts on any step failure. Use this when you want a one-shot
  verify -> review -> merge pipeline without manual orchestration.

EXAMPLES:
  /kallax-review-merge
  /kallax-review-merge 123

RELATED:
  /kallax-verify-pr, /kallax-review-pr, /kallax-merge
EOF
  exit 0
fi

log_title "Review & Merge"

require_git_repo
PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  read -r -p "  PR number: " PR_NUMBER
fi

echo ""
echo "  Step 1: Verify output..."
# shellcheck disable=SC1090
source "${SCRIPT_DIR}/kallax-verify-pr.sh" "$PR_NUMBER" 2>/dev/null || {
  log_error "Verification failed"
  exit 1
}

echo ""
echo "  Step 2: Gate review..."
# shellcheck disable=SC1090
source "${SCRIPT_DIR}/kallax-review-pr.sh" "$PR_NUMBER" 2>/dev/null || {
  log_error "Gate review failed"
  exit 1
}

echo ""
echo "  Step 3: Merge..."
# shellcheck disable=SC1090
source "${SCRIPT_DIR}/kallax-merge.sh" "$PR_NUMBER" 2>/dev/null || {
  log_error "Merge failed"
  exit 1
}

log_info "PR #${PR_NUMBER}: Verified → Reviewed → Merged"
echo ""
