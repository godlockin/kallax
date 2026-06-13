#!/usr/bin/env bash
# tests/integration/review-flow-test.sh — Integration test for review.sh
# Tests 4 scenarios: 3 anti-fab FAIL / amend-verify FAIL / all PASS
# EPIC-039-B: Rule 8 L4 verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REVIEW_SCRIPT="$KALLAX_ROOT/scripts/conductor/review.sh"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=========================================="
echo "review-flow Integration Test (4 cases)"
echo "=========================================="
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0

run_review() {
    bash "$REVIEW_SCRIPT" >/dev/null 2>&1
    echo $?
}

# ============================================================
# CASE 1: kpi-precision FAIL (Rule 9a)
# ============================================================
echo "--- Case 1: kpi-precision FAIL (Rule 9a) ---"

TEST_BRANCH="test/review-flow-kpi-fail-$$"
git branch "$TEST_BRANCH" HEAD 2>/dev/null || true
git checkout "$TEST_BRANCH" 2>/dev/null || true

echo "kpi test" >> "$KALLAX_ROOT/.kallax/.test-kpi-$$" 2>/dev/null || true
git add "$KALLAX_ROOT/.kallax/.test-kpi-$$" 2>/dev/null || true
git commit -m "test: EPIC-039-B kpi check ~70% estimate" --allow-empty 2>/dev/null || true

RESULT=$(run_review)
if [ "$RESULT" -ne 0 ]; then
    pass "Case 1: review.sh exits non-zero when kpi-precision FAIL"
    TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "Case 1: review.sh exits zero but should reject kpi-precision FAIL"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

git checkout - 2>/dev/null || true
git branch -D "$TEST_BRANCH" 2>/dev/null || true
rm -f "$KALLAX_ROOT/.kallax/.test-kpi-$$" 2>/dev/null || true
echo ""

# ============================================================
# CASE 2: scope-creep FAIL (Rule 9c) — ticket ID in scope
# ============================================================
echo "--- Case 2: scope-creep FAIL (Rule 9c) ---"

TEST_BRANCH="test/review-flow-scope-fail-$$"
git branch "$TEST_BRANCH" HEAD 2>/dev/null || true
git checkout "$TEST_BRANCH" 2>/dev/null || true

# Change a file outside any plausible scope
echo "scope test" >> "$KALLAX_ROOT/src/unrelated-file-$$" 2>/dev/null || true
git add "$KALLAX_ROOT/src/unrelated-file-$$" 2>/dev/null || true
git commit -m "feat(EPIC-039-B): unrelated change" 2>/dev/null || true

# Run scope-creep check directly to see if it fails
SCOPE_RESULT=0
bash "$VERIFY_DIR/check-scope-creep.sh" "EPIC-039-B" >/dev/null 2>&1 || SCOPE_RESULT=$?

if [ "$SCOPE_RESULT" -ne 0 ]; then
    pass "Case 2: scope-creep detects out-of-scope change"
    TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "Case 2: scope-creep should detect out-of-scope change"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

git checkout - 2>/dev/null || true
git branch -D "$TEST_BRANCH" 2>/dev/null || true
rm -f "$KALLAX_ROOT/src/unrelated-file-$$" 2>/dev/null || true
echo ""

# ============================================================
# CASE 3: amend-verify FAIL (Rule 9d)
# ============================================================
echo "--- Case 3: amend-verify FAIL (Rule 9d) ---"

TEST_BRANCH="test/review-flow-amend-fail-$$"
git branch "$TEST_BRANCH" HEAD 2>/dev/null || true
git checkout "$TEST_BRANCH" 2>/dev/null || true

echo "amend test" >> "$KALLAX_ROOT/.kallax/.test-amend-$$" 2>/dev/null || true
git add "$KALLAX_ROOT/.kallax/.test-amend-$$" 2>/dev/null || true
git commit -m "fix: EPIC-039-B [amend] test" --allow-empty 2>/dev/null || true
git commit --amend -m "fix: EPIC-039-B [amend] test" --allow-empty 2>/dev/null || true

RESULT=$(run_review)
if [ "$RESULT" -ne 0 ]; then
    pass "Case 3: review.sh exits non-zero when amend-verify FAIL"
    TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "Case 3: review.sh exits zero but should reject amend-verify FAIL"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

git checkout - 2>/dev/null || true
git branch -D "$TEST_BRANCH" 2>/dev/null || true
rm -f "$KALLAX_ROOT/.kallax/.test-amend-$$" 2>/dev/null || true
echo ""

# ============================================================
# CASE 4: All PASS (happy path)
# ============================================================
echo "--- Case 4: All PASS — merge allowed ---"

TEST_BRANCH="test/review-flow-all-pass-$$"
git branch "$TEST_BRANCH" HEAD 2>/dev/null || true
git checkout "$TEST_BRANCH" 2>/dev/null || true

# Use KALLAX_BYPASS_SCOPE_CHECK=1 since we create a test file outside scope
# (The test file .kallax/.test-allpass-$$ is for test purposes only)
# No ticket ID in commit message → scope-creep SKIP
KALLAX_BYPASS_SCOPE_CHECK=1 git commit -m "feat: implement review flow

M1: 4/4 = 100.0%
AC1: PASS
AC2: PASS" --allow-empty 2>/dev/null || true

RESULT=$(run_review)
if [ "$RESULT" -eq 0 ]; then
    pass "Case 4: review.sh exits zero when all checks PASS"
    TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "Case 4: review.sh exits non-zero but all checks should PASS"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

git checkout - 2>/dev/null || true
git branch -D "$TEST_BRANCH" 2>/dev/null || true
rm -f "$KALLAX_ROOT/.kallax/.test-allpass-$$" 2>/dev/null || true
echo ""

# ============================================================
# Summary
# ============================================================
echo "=========================================="
echo "REVIEW-FLOW TEST SUMMARY"
echo "=========================================="
echo "Total: $((TOTAL_PASS + TOTAL_FAIL)) cases"
echo -e "Passed: ${GREEN}$TOTAL_PASS${NC}"
echo -e "Failed: ${RED}$TOTAL_FAIL${NC}"
echo ""

if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo -e "${RED}REVIEW-FLOW TEST: FAIL${NC}"
    exit 1
else
    echo -e "${GREEN}REVIEW-FLOW TEST: PASS${NC}"
    exit 0
fi
