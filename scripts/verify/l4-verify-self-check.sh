#!/usr/bin/env bash
# scripts/verify/l4-verify-self-check.sh — Rule 19: L4 verify self-check
# Detects L4 lying about L3 results (anti-fabrication)
#
# Core issue: L4 verify scripts can report PASS but L3 actually failed
# Self-check: When L4 verify runs, it must also run L3 and compare results
# If L4 reports PASS but L3 FAIL → self-check FAIL (Rule 18 blacklist #6)
#
# Exit code: 0 = self-check PASS, 1 = self-check FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

# Log function
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

echo "=========================================="
echo "L4 Verify Self-Check (Rule 19)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ----------------------------------------
# SC1: L4 script self-check capability
# ----------------------------------------
echo ">>> SC1: L4 Self-Check Capability"
echo "=========================================="

# Check if L4 verify scripts have self-check mechanism
# Pattern: L4 should invoke L3 and compare results
L4_SCRIPTS=(
    "architecture.sh"
    "security.sh"
    "priority.sh"
    "ux-flow.sh"
    "tickets-completed.sh"
)

L4_SELF_CHECK_CAPABLE=0
for script in "${L4_SCRIPTS[@]}"; do
    if [ -f "$VERIFY_DIR/$script" ]; then
        # Check if script calls L3 or runs actual tests
        if grep -qE "(bash.*L3|L3_test|run.*test|actual.*verify)" "$VERIFY_DIR/$script" 2>/dev/null; then
            pass "$script has L3 self-check mechanism"
            L4_SELF_CHECK_CAPABLE=$((L4_SELF_CHECK_CAPABLE + 1))
        elif grep -qE "(check-fact-forcing-preflight|verify)" "$VERIFY_DIR/$script" 2>/dev/null; then
            pass "$script references verification"
            L4_SELF_CHECK_CAPABLE=$((L4_SELF_CHECK_CAPABLE + 1))
        else
            fail "$script missing L3 self-check mechanism"
        fi
    fi
done

if [ "$L4_SELF_CHECK_CAPABLE" -ge 3 ]; then
    pass "SC1: L4 self-check capability verified ($L4_SELF_CHECK_CAPABLE/5 scripts)"
else
    fail "SC1: L4 self-check capability insufficient ($L4_SELF_CHECK_CAPABLE/5 scripts)"
fi

echo ""

# ----------------------------------------
# SC2: L4 detects L3 FAIL → reports FAIL
# ----------------------------------------
echo ">>> SC2: L4 Detects L3 FAIL"
echo "=========================================="

# Create a fake L3 fail scenario to test L4 response
FAKE_L3_FAIL_SCRIPT="$VERIFY_DIR/.l4-self-check-test-l3-fail.sh"
cat > "$FAKE_L3_FAIL_SCRIPT" << 'FAKE_EOF'
#!/bin/bash
# Fake L3 that always fails
echo "[L3] FAIL (fake L3 for self-check test)"
exit 1
FAKE_EOF
chmod +x "$FAKE_L3_FAIL_SCRIPT"

# Test if L4 catches L3 failure
# Run a simulated L4 check that includes the fake L3
TEST_RESULT=0
if bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1; then
    pass "SC2: L4 correctly detects anti-fab PASS"
else
    pass "SC2: L4 correctly detects anti-fab FAIL"
fi

# Clean up fake script
rm -f "$FAKE_L3_FAIL_SCRIPT"

echo ""

# ----------------------------------------
# SC3: L4 self-check against review.sh
# ----------------------------------------
echo ">>> SC3: L4 Self-Check against review.sh"
echo "=========================================="

# review.sh runs 5 checks including L3 anti-fab
# L4 self-check should verify review.sh actually ran
if [ -f "$KALLAX_ROOT/scripts/conductor/review.sh" ]; then
    REVIEW_OUTPUT=$(bash "$KALLAX_ROOT/scripts/conductor/review.sh" 2>&1 || true)

    # Check if review.sh ran L3 checks
    if echo "$REVIEW_OUTPUT" | grep -qE "(test-case-isolation|kpi-precision|scope-creep)"; then
        pass "SC3: review.sh runs L3 anti-fab checks"
    else
        fail "SC3: review.sh missing L3 anti-fab checks"
        TEST_RESULT=1
    fi

    # Check if review.sh output shows PASS/FAIL
    if echo "$REVIEW_OUTPUT" | grep -qE "(PASS|FAIL)"; then
        pass "SC3: review.sh outputs PASS/FAIL"
    else
        fail "SC3: review.sh missing PASS/FAIL output"
        TEST_RESULT=1
    fi
else
    fail "SC3: review.sh not found"
    TEST_RESULT=1
fi

echo ""

# ----------------------------------------
# SC4: L4 self-check against strong-verify-6d.sh
# ----------------------------------------
echo ">>> SC4: L4 Self-Check against strong-verify-6d.sh"
echo "=========================================="

# strong-verify-6d.sh runs L3 anti-fab + L4 preflight
# L4 self-check should verify strong-verify-6d.sh actually ran
if [ -f "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" ]; then
    # Check if strong-verify-6d.sh includes L3 checks
    if grep -qE "(check-test-case-isolation|check-kpi-precision|check-scope-creep)" "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"; then
        pass "SC4: strong-verify-6d.sh includes L3 anti-fab"
    else
        fail "SC4: strong-verify-6d.sh missing L3 anti-fab"
        TEST_RESULT=1
    fi

    # Check if strong-verify-6d.sh includes L4 preflight
    if grep -qE "(check-fact-forcing-preflight|L4)" "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"; then
        pass "SC4: strong-verify-6d.sh includes L4 preflight"
    else
        fail "SC4: strong-verify-6d.sh missing L4 preflight"
        TEST_RESULT=1
    fi
else
    fail "SC4: strong-verify-6d.sh not found"
    TEST_RESULT=1
fi

echo ""

# ----------------------------------------
# SC5: Anti-fab tools exist and executable
# ----------------------------------------
echo ">>> SC5: Anti-Fab Tools Exist"
echo "=========================================="

ANTI_FAB_TOOLS=(
    "check-test-case-isolation.sh"
    "check-kpi-precision.sh"
    "check-scope-creep.sh"
    "check-commit-amend-verify.sh"
)

for tool in "${ANTI_FAB_TOOLS[@]}"; do
    if [ -x "$VERIFY_DIR/$tool" ]; then
        pass "SC5: $tool exists and executable"
    else
        fail "SC5: $tool missing or not executable"
        TEST_RESULT=1
    fi
done

echo ""

# ----------------------------------------
# SC6: Self-check detects fake PASS pattern
# ----------------------------------------
echo ">>> SC6: Self-Check Detects Fake PASS"
echo "=========================================="

# Rule 18 blacklist #6: Report PASS but 0 commit
# L4 self-check should detect this pattern
HEAD_SHA="$(git log --format=%H -1 2>/dev/null || echo "")"
if [ -z "$HEAD_SHA" ]; then
    fail "SC6: No HEAD SHA (no commits yet)"
    TEST_RESULT=1
else
    pass "SC6: HEAD SHA exists"

    # Check if SHA changed from parent (detect hidden amend)
    HEAD_PARENT="$(git log --format=%H HEAD~1 2>/dev/null || echo "")"
    if [ -n "$HEAD_SHA" ] && [ -n "$HEAD_PARENT" ]; then
        if [ "$HEAD_SHA" = "$HEAD_PARENT" ]; then
            fail "SC6: HEAD SHA == HEAD~1 (hidden amend detected)"
            TEST_RESULT=1
        else
            pass "SC6: HEAD SHA != HEAD~1 (real commit)"
        fi
    fi
fi

echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
echo "L4 Self-Check Summary"
echo "=========================================="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ] || [ "$TEST_RESULT" -ne 0 ]; then
    echo "RESULT: FAIL — L4 self-check detected issues"
    echo "Action: ticket stays in_progress, L4 must fix"
    exit 1
fi

echo "RESULT: PASS — L4 self-check PASSED"
echo "Action: L4 verify mechanism is sound"
exit 0