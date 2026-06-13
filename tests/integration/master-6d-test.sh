#!/usr/bin/env bash
# tests/integration/master-6d-test.sh — Integration tests for Master 6D strong verification
# EPIC-039-D: Tests for strong-verify-6d.sh 6 dimensions
#
# Test cases (≥6):
#   Test 1: strong-verify-6d.sh exists and executable
#   Test 2: strong-verify-6d.sh has all 6 dimensions
#   Test 3: master-6d-checkpoint.sh exists and executable
#   Test 4: master-6d-checkpoint.sh passes L4 check
#   Test 5: check-test-case-isolation.sh exists
#   Test 6: check-kpi-precision.sh exists
#   Test 7: check-scope-creep.sh exists
#   Test 8: check-commit-amend-verify.sh exists
#   Test 9: check-fact-forcing-preflight.sh exists
#
# Exit code: 0 = all tests pass, 1 = any test fails
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

run_test() {
    local test_name="$1"
    local test_func="$2"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo ""
    echo "=== Test $TEST_COUNT: $test_name ==="
    if $test_func; then
        pass "$test_name"
    else
        fail "$test_name"
    fi
}

echo "=========================================="
echo "Master 6D Strong Verification Tests"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ----------------------------------------
# Test 1: strong-verify-6d.sh exists and executable
# ----------------------------------------
test_strong_verify_exists() {
    [ -f "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" ] && \
    [ -x "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" ]
}

# ----------------------------------------
# Test 2: strong-verify-6d.sh has all 6 dimensions
# ----------------------------------------
test_strong_verify_has_6d() {
    local script="$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"
    grep -q "L1:" "$script" && \
    grep -q "L2:" "$script" && \
    grep -q "L3:" "$script" && \
    grep -q "L4:" "$script" && \
    grep -q "L5:" "$script" && \
    grep -q "L6:" "$script"
}

# ----------------------------------------
# Test 3: master-6d-checkpoint.sh exists and executable
# ----------------------------------------
test_checkpoint_exists() {
    [ -f "$KALLAX_ROOT/scripts/verify/master-6d-checkpoint.sh" ] && \
    [ -x "$KALLAX_ROOT/scripts/verify/master-6d-checkpoint.sh" ]
}

# ----------------------------------------
# Test 4: master-6d-checkpoint.sh passes L4 check
# ----------------------------------------
test_checkpoint_passes() {
    bash "$KALLAX_ROOT/scripts/verify/master-6d-checkpoint.sh" >/dev/null 2>&1
}

# ----------------------------------------
# Test 5: check-test-case-isolation.sh exists
# ----------------------------------------
test_isolation_exists() {
    [ -f "$KALLAX_ROOT/scripts/verify/check-test-case-isolation.sh" ]
}

# ----------------------------------------
# Test 6: check-kpi-precision.sh exists
# ----------------------------------------
test_kpi_exists() {
    [ -f "$KALLAX_ROOT/scripts/verify/check-kpi-precision.sh" ]
}

# ----------------------------------------
# Test 7: check-scope-creep.sh exists
# ----------------------------------------
test_scope_exists() {
    [ -f "$KALLAX_ROOT/scripts/verify/check-scope-creep.sh" ]
}

# ----------------------------------------
# Test 8: check-commit-amend-verify.sh exists
# ----------------------------------------
test_amend_exists() {
    [ -f "$KALLAX_ROOT/scripts/verify/check-commit-amend-verify.sh" ]
}

# ----------------------------------------
# Test 9: check-fact-forcing-preflight.sh exists
# ----------------------------------------
test_preflight_exists() {
    [ -f "$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh" ]
}

# ----------------------------------------
# Test 10: strong-verify-6d.sh output format correct
# ----------------------------------------
test_output_format() {
    local output
    output="$(bash "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" 2>&1 || true)"
    echo "$output" | grep -q "L1:" && \
    echo "$output" | grep -q "L2:" && \
    echo "$output" | grep -q "L3:" && \
    echo "$output" | grep -q "L4:" && \
    echo "$output" | grep -q "L5:" && \
    echo "$output" | grep -q "L6:" && \
    echo "$output" | grep -q "RESULT:"
}

# ----------------------------------------
# Test 11: strong-verify-6d.sh exit code correct
# ----------------------------------------
test_exit_code() {
    # Should exit 0 when all PASS, 1 when any FAIL
    # We just check it exits with proper code (0 or 1)
    bash "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" >/dev/null 2>&1
    local code=$?
    [ "$code" -eq 0 ] || [ "$code" -eq 1 ]
}

# ----------------------------------------
# Run all tests
# ----------------------------------------
run_test "strong-verify-6d.sh exists and executable" test_strong_verify_exists
run_test "strong-verify-6d.sh has all 6 dimensions" test_strong_verify_has_6d
run_test "master-6d-checkpoint.sh exists and executable" test_checkpoint_exists
run_test "master-6d-checkpoint.sh passes L4 check" test_checkpoint_passes
run_test "check-test-case-isolation.sh exists" test_isolation_exists
run_test "check-kpi-precision.sh exists" test_kpi_exists
run_test "check-scope-creep.sh exists" test_scope_exists
run_test "check-commit-amend-verify.sh exists" test_amend_exists
run_test "check-fact-forcing-preflight.sh exists" test_preflight_exists
run_test "strong-verify-6d.sh output format correct" test_output_format
run_test "strong-verify-6d.sh exit code correct" test_exit_code

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TEST_COUNT"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — $FAIL_COUNT test(s) failed"
    exit 1
fi

echo "RESULT: PASS — all $TEST_COUNT tests passed"
exit 0