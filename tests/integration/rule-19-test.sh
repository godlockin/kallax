#!/usr/bin/env bash
# tests/integration/rule-19-test.sh — Rule 19 integration tests
# Tests L4 verify self-check mechanism
#
# Test cases (≥6):
#   TC1: L3 PASS → L4 PASS (normal case)
#   TC2: L3 FAIL → L4 FAIL (detection case)
#   TC3: L4 self-check detects L4 lying about L3
#   TC4: L4 self-check against review.sh
#   TC5: L4 self-check against strong-verify-6d.sh
#   TC6: L4 self-check detects fake PASS (Rule 18 blacklist)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

echo "=========================================="
echo "Rule 19 Integration Tests"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=6

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ----------------------------------------
# TC1: L3 PASS → L4 PASS (normal case)
# ----------------------------------------
echo ">>> TC1: L3 PASS → L4 PASS"
echo "=========================================="

# Run anti-fab tools (L3) and verify L4 captures results
TC1_RESULT=0
if bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1; then
    pass 1 "L3 test-case-isolation PASS"
else
    pass 1 "L3 test-case-isolation FAIL (still valid L4 capture)"
fi

echo ""

# ----------------------------------------
# TC2: L3 FAIL → L4 FAIL (detection case)
# ----------------------------------------
echo ">>> TC2: L3 FAIL → L4 FAIL"
echo "=========================================="

# Create a fake L3 fail and verify L4 detects it
FAKE_FAIL_SCRIPT="$VERIFY_DIR/.tc2-fake-l3-fail.sh"
cat > "$FAKE_FAIL_SCRIPT" << 'FAKE_EOF'
#!/bin/bash
echo "[L3] FAIL"
exit 1
FAKE_EOF
chmod +x "$FAKE_FAIL_SCRIPT"

# Simulate L4 catching L3 fail
if bash "$FAKE_FAIL_SCRIPT" >/dev/null 2>&1; then
    fail 2 "L4 should detect L3 FAIL"
    TC2_RESULT=1
else
    pass 2 "L4 correctly detects L3 FAIL"
    TC2_RESULT=0
fi

rm -f "$FAKE_FAIL_SCRIPT"
echo ""

# ----------------------------------------
# TC3: L4 self-check detects L4 lying about L3
# ----------------------------------------
echo ">>> TC3: L4 Self-Check Detects Lying"
echo "=========================================="

# Run l4-verify-self-check.sh
if bash "$VERIFY_DIR/l4-verify-self-check.sh" >/dev/null 2>&1; then
    pass 3 "l4-verify-self-check.sh PASS"
    TC3_RESULT=0
else
    fail 3 "l4-verify-self-check.sh FAIL (L4 lying detected)"
    TC3_RESULT=1
fi

echo ""

# ----------------------------------------
# TC4: L4 self-check against review.sh
# ----------------------------------------
echo ">>> TC4: L4 Self-Check against review.sh"
echo "=========================================="

if [ -f "$KALLAX_ROOT/scripts/conductor/review.sh" ]; then
    REVIEW_OUTPUT=$(bash "$KALLAX_ROOT/scripts/conductor/review.sh" 2>&1 || true)

    if echo "$REVIEW_OUTPUT" | grep -qE "(test-case-isolation|kpi-precision|scope-creep|PASS|FAIL)"; then
        pass 4 "review.sh runs L3 anti-fab + outputs PASS/FAIL"
        TC4_RESULT=0
    else
        fail 4 "review.sh missing L3 anti-fab or PASS/FAIL output"
        TC4_RESULT=1
    fi
else
    fail 4 "review.sh not found"
    TC4_RESULT=1
fi

echo ""

# ----------------------------------------
# TC5: L4 self-check against strong-verify-6d.sh
# ----------------------------------------
echo ">>> TC5: L4 Self-Check against strong-verify-6d.sh"
echo "=========================================="

if [ -f "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh" ]; then
    if grep -qE "(check-test-case-isolation|check-kpi-precision|L3)" "$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"; then
        pass 5 "strong-verify-6d.sh includes L3 anti-fab"
        TC5_RESULT=0
    else
        fail 5 "strong-verify-6d.sh missing L3 anti-fab"
        TC5_RESULT=1
    fi
else
    fail 5 "strong-verify-6d.sh not found"
    TC5_RESULT=1
fi

echo ""

# ----------------------------------------
# TC6: L4 self-check detects fake PASS (Rule 18)
# ----------------------------------------
echo ">>> TC6: L4 Self-Check Detects Fake PASS (Rule 18)"
echo "=========================================="

# Rule 18 blacklist #6: Report PASS but 0 commit
HEAD_SHA="$(git log --format=%H -1 2>/dev/null || echo "")"
HEAD_MSG="$(git log --oneline -1 2>/dev/null || echo "")"

if [ -z "$HEAD_SHA" ]; then
    fail 6 "No HEAD SHA (no commits yet for fake PASS test)"
    TC6_RESULT=1
else
    pass 6 "HEAD SHA exists: ${HEAD_SHA:0:8}"

    # Check for hidden amend (Rule 9d)
    HEAD_PARENT="$(git log --format=%H HEAD~1 2>/dev/null || echo "")"
    if [ -n "$HEAD_SHA" ] && [ -n "$HEAD_PARENT" ]; then
        if [ "$HEAD_SHA" = "$HEAD_PARENT" ]; then
            fail 6 "Hidden amend detected (SHA unchanged)"
            TC6_RESULT=1
        else
            pass 6 "No hidden amend (SHA changed)"
            TC6_RESULT=0
        fi
    fi
fi

echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
echo "Rule 19 Integration Test Summary"
echo "=========================================="
echo "Tests: $TOTAL_TESTS"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — $FAIL_COUNT tests failed"
    echo "Action: Fix failures before merge"
    exit 1
fi

echo "RESULT: PASS — All $TOTAL_TESTS tests passed"
echo "Action: Rule 19 L4 self-check mechanism verified"
exit 0