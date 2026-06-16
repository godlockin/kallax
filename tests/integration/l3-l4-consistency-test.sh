#!/usr/bin/env bash
# tests/integration/l3-l4-consistency-test.sh — TDD tests for L3/L4 consistency check
# EPIC-053-A AC2: 4/4 PASS
#   L3 pass + L4 fail = ERROR (矛盾)
#   L3 fail + L4 pass = ERROR (矛盾)
#   L3 pass + L4 pass = OK
#   L3 fail + L4 fail = OK
#
# Rule 9 KPI X/Y format: 4/4 = 100.0% (no estimate, exact)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly VERIFY_SCRIPT="$KALLAX_ROOT/scripts/verify/l3-l4-consistency.sh"

# Verify script exists (TDD red phase will fail with clear error if missing)
if [ ! -f "$VERIFY_SCRIPT" ]; then
    echo "=========================================="
    echo "L3/L4 Consistency — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $VERIFY_SCRIPT not found (TDD red phase)"
    echo "0/4 PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "L3/L4 Consistency — Integration Tests (4/4)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=4

# Helper: run verify script with L3 + L4 status, return exit code
run_check() {
    local l3="$1"
    local l4="$2"
    bash "$VERIFY_SCRIPT" --l3-status="$l3" --l4-status="$l4" >/dev/null 2>&1
    return $?
}

# Test 1: L3 pass + L4 fail = ERROR (contradiction)
echo "--- Test 1: L3 pass + L4 fail = ERROR ---"
set +e
run_check "PASS" "FAIL"
RESULT1=$?
set -e
# Expected: exit non-zero (ERROR)
if [ "$RESULT1" -ne 0 ]; then
    echo "[PASS] expected ERROR, got ERROR (exit=$RESULT1)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR, got OK (exit=$RESULT1)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 2: L3 fail + L4 pass = ERROR (contradiction)
echo "--- Test 2: L3 fail + L4 pass = ERROR ---"
set +e
run_check "FAIL" "PASS"
RESULT2=$?
set -e
# Expected: exit non-zero (ERROR)
if [ "$RESULT2" -ne 0 ]; then
    echo "[PASS] expected ERROR, got ERROR (exit=$RESULT2)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR, got OK (exit=$RESULT2)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 3: L3 pass + L4 pass = OK (consistent)
echo "--- Test 3: L3 pass + L4 pass = OK ---"
set +e
run_check "PASS" "PASS"
RESULT3=$?
set -e
# Expected: exit 0 (OK)
if [ "$RESULT3" -eq 0 ]; then
    echo "[PASS] expected OK, got OK (exit=$RESULT3)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected OK, got ERROR (exit=$RESULT3)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 4: L3 fail + L4 fail = OK (both honest, no contradiction)
echo "--- Test 4: L3 fail + L4 fail = OK ---"
set +e
run_check "FAIL" "FAIL"
RESULT4=$?
set -e
# Expected: exit 0 (OK)
if [ "$RESULT4" -eq 0 ]; then
    echo "[PASS] expected OK, got OK (exit=$RESULT4)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected OK, got ERROR (exit=$RESULT4)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Summary — exact X/Y format (Rule 9 KPI precision)
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAIL: $FAIL_COUNT test(s) failed"
    echo "$PASS_COUNT/$TOTAL PASS"
    exit 1
fi
echo "PASS: all $TOTAL integration tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0
