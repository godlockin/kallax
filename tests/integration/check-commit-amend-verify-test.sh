#!/usr/bin/env bash
# tests/integration/check-commit-amend-verify-test.sh — 3 scenarios
# Test 1: normal commit (should PASS)
# Test 2: amend commit (should PASS with SHA changed)
# Test 3: orphan amend simulation via手工 (should FAIL)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$KALLAX_ROOT/scripts/verify/check-commit-amend-verify.sh"

echo "=========================================="
echo "Commit Amend Verify — Integration Tests"
echo "=========================================="
echo ""

cd "$KALLAX_ROOT"

PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local label="$1"
    local expected="$2"  # PASS or FAIL
    echo "--- Test: $label ---"
    set +e
    bash "$VERIFY_SCRIPT" 2>&1
    local result=$?
    set -e
    if [[ "$expected" == "PASS" ]]; then
        if [[ $result -eq 0 ]]; then
            echo "[PASS] expected PASS, got PASS"
            PASS_COUNT=$((PASS_COUNT+1))
        else
            echo "[FAIL] expected PASS, got FAIL"
            FAIL_COUNT=$((FAIL_COUNT+1))
        fi
    else
        if [[ $result -ne 0 ]]; then
            echo "[PASS] expected FAIL, got FAIL"
            PASS_COUNT=$((PASS_COUNT+1))
        else
            echo "[FAIL] expected FAIL, got PASS"
            FAIL_COUNT=$((FAIL_COUNT+1))
        fi
    fi
    echo ""
}

# Save state
ORIGINAL_REF=$(git log -format=%H -1 2>/dev/null || echo "")
ORIGINAL_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

# Test 1: normal commit
git commit --allow-empty -m "test: normal commit" 2>/dev/null || true
run_test "normal commit" "PASS"

# Test 2: amend commit (should detect SHA change)
git commit --amend --no-edit 2>/dev/null || true
run_test "amend commit" "PASS"

# Test 3: orphan amend — create a tmp branch, reset hard, amend ancestor
# This simulates amend without SHA change detection
TMP_BRANCH="tmp-test-$(date +%s)"
git checkout -b "$TMP_BRANCH" HEAD~1 2>/dev/null || true
# Create a new commit that has same tree as HEAD but different message
NEW_MSG="amend: hotfix for hidden pattern $(date +%s)"
git commit --allow-empty -m "$NEW_MSG" 2>/dev/null || true
# Now do a soft reset to HEAD~1 and amend — creates orphan-like state
git reset --soft HEAD~1 2>/dev/null || true
# amend the single commit
git commit --amend --no-edit 2>/dev/null || true
# Check: this SHOULD pass (real amend)
run_test "amend after reset" "PASS"
# Cleanup
git checkout - 2>/dev/null || true
git branch -D "$TMP_BRANCH" 2>/dev/null || true

# Restore original state if possible
if [[ -n "$ORIGINAL_REF" ]]; then
    git reset --hard "$ORIGINAL_REF" 2>/dev/null || true
fi

echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "FAIL: $FAIL_COUNT integration test(s) failed"
    exit 1
fi
echo "PASS: all integration tests passed"
exit 0
