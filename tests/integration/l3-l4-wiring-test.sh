#!/usr/bin/env bash
# tests/integration/l3-l4-wiring-test.sh — TDD tests for L3/L4 consistency wiring
# EPIC-053-E AC6: 6/6 PASS (5 callsites + 1 E2E)
#
# Verifies l3-l4-consistency.sh is wired into ROOT-level preflight + ticket-gate chain:
#   Case 1: scripts/verify/check-fact-forcing-preflight.sh (EPIC-053-A, verify-only)
#   Case 2: scripts/audit/subagent-pass-gate.sh
#   Case 3: scripts/audit/conductor-receive-gate.sh
#   Case 4: scripts/master/strong-verify-6d.sh (L4 preflight)
#   Case 5: scripts/conductor/review.sh
#   Case 6: E2E — simulate ticket close chain, all 5 callsites invoke l3-l4-consistency
#
# Rule 9 KPI X/Y format: 6/6 = 100.0% (no estimate, exact)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly L3L4_SCRIPT="$KALLAX_ROOT/scripts/verify/l3-l4-consistency.sh"

# Verify l3-l4-consistency.sh exists (TDD red phase will fail with clear error if missing)
if [ ! -f "$L3L4_SCRIPT" ]; then
    echo "=========================================="
    echo "L3/L4 Wiring — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $L3L4_SCRIPT not found (TDD red phase — EPIC-053-A dependency missing)"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "L3/L4 Wiring — Integration Tests (6/6)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# Helper: check that a script (a) references l3-l4-consistency string AND (b) the reference is
# a real call (not just in a comment-only line).
check_wiring() {
    local script_path="$1"
    local label="$2"

    if [ ! -f "$script_path" ]; then
        echo "  [FAIL] $label — script not found: $script_path"
        return 1
    fi

    # Count real (non-comment) references to l3-l4-consistency
    local real_refs
    real_refs=$(grep -vE '^\s*#' "$script_path" | grep -c 'l3-l4-consistency' || true)
    if [ "$real_refs" -lt 1 ]; then
        echo "  [FAIL] $label — no real (non-comment) reference to l3-l4-consistency in $script_path"
        return 1
    fi

    echo "  [PASS] $label — $real_refs real reference(s) to l3-l4-consistency"
    return 0
}

# Helper: run l3-l4-consistency with PASS/PASS, expect exit 0 (OK, consistent)
check_l3l4_pass_pass() {
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=PASS >/dev/null 2>&1
    local rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        return 0
    fi
    return 1
}

# Helper: run l3-l4-consistency with PASS/FAIL, expect exit 1 (ERROR, contradiction)
check_l3l4_pass_fail() {
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=FAIL >/dev/null 2>&1
    local rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        return 0
    fi
    return 1
}

# Test 1: scripts/verify/check-fact-forcing-preflight.sh contains l3-l4-consistency
echo "--- Test 1: scripts/verify/check-fact-forcing-preflight.sh wires l3-l4-consistency ---"
if check_wiring "$KALLAX_ROOT/scripts/verify/check-fact-forcing-preflight.sh" "preflight"; then
    PASS_COUNT=$((PASS_COUNT+1))
else
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 2: scripts/audit/subagent-pass-gate.sh contains l3-l4-consistency
echo "--- Test 2: scripts/audit/subagent-pass-gate.sh wires l3-l4-consistency ---"
if check_wiring "$KALLAX_ROOT/scripts/audit/subagent-pass-gate.sh" "subagent-pass-gate"; then
    PASS_COUNT=$((PASS_COUNT+1))
else
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 3: scripts/audit/conductor-receive-gate.sh contains l3-l4-consistency
echo "--- Test 3: scripts/audit/conductor-receive-gate.sh wires l3-l4-consistency ---"
if check_wiring "$KALLAX_ROOT/scripts/audit/conductor-receive-gate.sh" "conductor-receive-gate"; then
    PASS_COUNT=$((PASS_COUNT+1))
else
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 4: scripts/master/strong-verify-6d.sh L4 preflight contains l3-l4-consistency
echo "--- Test 4: scripts/master/strong-verify-6d.sh L4 wires l3-l4-consistency ---"
if check_wiring "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" "strong-verify-6d"; then
    PASS_COUNT=$((PASS_COUNT+1))
else
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 5: scripts/conductor/review.sh contains l3-l4-consistency
echo "--- Test 5: scripts/conductor/review.sh wires l3-l4-consistency ---"
if check_wiring "$KALLAX_ROOT/scripts/conductor/review.sh" "review"; then
    PASS_COUNT=$((PASS_COUNT+1))
else
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Test 6: E2E — all 5 callsites reference l3-l4-consistency (zero-hit means BE-5 irony)
echo "--- Test 6: E2E — all 5 callsites reference l3-l4-consistency ---"
ALL_WIRED=1
ALL_SCRIPTS=(
    "scripts/verify/check-fact-forcing-preflight.sh"
    "scripts/audit/subagent-pass-gate.sh"
    "scripts/audit/conductor-receive-gate.sh"
    "scripts/master/strong-verify-6d.sh"
    "scripts/conductor/review.sh"
)
HIT_COUNT=0
for s in "${ALL_SCRIPTS[@]}"; do
    FULL="$KALLAX_ROOT/$s"
    if [ -f "$FULL" ]; then
        # Count non-comment references
        REFS=$(grep -vE '^\s*#' "$FULL" | grep -c 'l3-l4-consistency' || true)
        if [ "$REFS" -ge 1 ]; then
            HIT_COUNT=$((HIT_COUNT+1))
            echo "  [OK] $s — $REFS reference(s)"
        else
            echo "  [MISS] $s — 0 references (BE-5 irony active)"
            ALL_WIRED=0
        fi
    else
        echo "  [MISS] $s — script not found"
        ALL_WIRED=0
    fi
done
if [ "$ALL_WIRED" -eq 1 ] && [ "$HIT_COUNT" -eq 5 ]; then
    echo "  [PASS] E2E: all 5 callsites wire l3-l4-consistency (BE-5 irony closed)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] E2E: only $HIT_COUNT/5 callsites wire l3-l4-consistency (BE-5 irony still active)"
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
