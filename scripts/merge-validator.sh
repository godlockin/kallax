#!/usr/bin/env bash
# KALLAX Merge Validator — pre-merge gate checks
# Checks: CI status, PR description quality, review approvals
# Usage: ./scripts/merge-validator.sh <pr-number>
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

EXIT_CODE=0
PR_NUMBER="${1:-}"

[ -n "$PR_NUMBER" ] || { echo "Usage: $0 <pr-number>"; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "=== KALLAX Merge Validator: PR #${PR_NUMBER} ==="
echo ""

command -v gh &>/dev/null || fail "gh CLI not found — install GitHub CLI first"

# ── 1. PR description quality ───────────────────────────────────

info "Validating PR description..."

PR_BODY=$(gh pr view "$PR_NUMBER" --json body --jq '.body' 2>/dev/null || echo "")

if [ -z "$PR_BODY" ] || [ "$PR_BODY" = "null" ]; then
  fail "PR body is empty"
else
  pass "PR body exists ($(echo "$PR_BODY" | wc -c | tr -d ' ') chars)"

  if ! echo "$PR_BODY" | grep -qiE '(test|PASS|pass|coverage)'; then
    fail "Missing test evidence in PR body"
  fi

  if ! echo "$PR_BODY" | grep -qiE '(TASK|TICKET|ticket|task)-\d+'; then
    fail "Missing ticket reference in PR body"
  fi
fi

# ── 2. Review approvals ─────────────────────────────────────────

info "Checking review status..."

REVIEWS=$(gh pr view "$PR_NUMBER" --json reviews --jq '.reviews' 2>/dev/null || echo "[]")
APPROVALS=$(echo "$REVIEWS" | grep -c '"state":"APPROVED"' 2>/dev/null || echo 0)

if [ "$APPROVALS" -ge 1 ]; then
  pass "Approved by ${APPROVALS} reviewer(s)"
else
  fail "No approvals yet"
fi

# ── 3. CI/Check status ─────────────────────────────────────────

info "Checking CI status..."

CHECKS=$(gh pr view "$PR_NUMBER" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null || echo "[]")
TOTAL=$(echo "$CHECKS" | grep -c '"conclusion"' 2>/dev/null || echo 0)
FAILED=$(echo "$CHECKS" | grep -c '"conclusion":"FAILURE"' 2>/dev/null || echo 0)
PENDING=$(echo "$CHECKS" | grep -c '"conclusion":"null"' 2>/dev/null || echo 0)

[ "$TOTAL" -eq 0 ] && warn "No CI checks found (may still be queued)"
[ "$FAILED" -gt 0 ] && fail "${FAILED} CI check(s) failed"
[ "$PENDING" -gt 0 ] && warn "${PENDING} CI check(s) still pending"

[ "$FAILED" -eq 0 ] && [ "$TOTAL" -gt 0 ] && pass "All ${TOTAL} CI check(s) passed"

# ── 4. Branch protections ───────────────────────────────────────

info "Checking branch target..."

BASE_BRANCH=$(gh pr view "$PR_NUMBER" --json baseRefName --jq '.baseRefName' 2>/dev/null || echo "")
if [ "$BASE_BRANCH" = "main" ] || [ "$BASE_BRANCH" = "master" ]; then
  pass "Targets protected branch: ${BASE_BRANCH}"
else
  warn "Targets branch: ${BASE_BRANCH} (not a protected branch)"
fi

# ── Summary ─────────────────────────────────────────────────────

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}=== Merge validation passed ===${NC}"
else
  echo -e "${RED}=== Merge validation FAILED — fix issues above ===${NC}"
fi
exit $EXIT_CODE
