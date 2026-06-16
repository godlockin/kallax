---
description: KALLAX review-merge command
---
# /kallax-review-merge — Combined review + merge workflow

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

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
