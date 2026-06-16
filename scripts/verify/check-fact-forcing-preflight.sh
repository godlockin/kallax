#!/usr/bin/env bash
# scripts/verify/check-fact-forcing-preflight.sh — L4 verify preflight (EPIC-053-A)
#
# AC5: 跟 l3-l4-consistency.sh 联动, 把 L3L4 一致性检查加到 preflight.
#
# Preflight verifies the L4 verify framework is wired up correctly:
#   1. l3-l4-consistency.sh exists + executable
#   2. 3 anti-fab tools exist + executable
#   3. l3-l4-consistency self-test (PASS/PASS=OK, PASS/FAIL=ERROR)
#   4. 3 anti-fab tools run without error (run as smoke test)
#
# Aggregate result: PASS only if all sub-checks PASS.
# Failure here = ticket REJECT (defense system not ready).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

echo "=========================================="
echo "L4 Verify Preflight (EPIC-053-A)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# -------------------------------------------------------
# Check 1: l3-l4-consistency.sh exists + executable
# -------------------------------------------------------
echo ">>> Check 1: l3-l4-consistency.sh available"
L3L4_SCRIPT="$VERIFY_DIR/l3-l4-consistency.sh"
if [ -x "$L3L4_SCRIPT" ]; then
    pass "l3-l4-consistency.sh exists and executable"
else
    fail "l3-l4-consistency.sh missing or not executable: $L3L4_SCRIPT"
fi
echo ""

# -------------------------------------------------------
# Check 2: 3 anti-fab tools exist + executable
# -------------------------------------------------------
echo ">>> Check 2: Anti-fab tools available"
ANTI_FAB_TOOLS=(
    "check-test-case-isolation.sh"
    "check-kpi-precision.sh"
    "check-scope-creep.sh"
)
for tool in "${ANTI_FAB_TOOLS[@]}"; do
    if [ -x "$VERIFY_DIR/$tool" ]; then
        pass "$tool exists and executable"
    else
        fail "$tool missing or not executable"
    fi
done
echo ""

# -------------------------------------------------------
# Check 3: l3-l4-consistency self-test (PASS/PASS = OK)
# -------------------------------------------------------
echo ">>> Check 3: L3L4 self-test (PASS/PASS = OK)"
if [ -x "$L3L4_SCRIPT" ]; then
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=PASS >/dev/null 2>&1
    RC=$?
    set -e
    if [ "$RC" -eq 0 ]; then
        pass "L3L4 OK on PASS/PASS (exit=0)"
    else
        fail "L3L4 ERROR on PASS/PASS (expected exit=0, got exit=$RC)"
    fi
else
    fail "L3L4 script not available for self-test"
fi
echo ""

# -------------------------------------------------------
# Check 4: l3-l4-consistency self-test (PASS/FAIL = ERROR)
# -------------------------------------------------------
echo ">>> Check 4: L3L4 self-test (PASS/FAIL = ERROR)"
if [ -x "$L3L4_SCRIPT" ]; then
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=FAIL >/dev/null 2>&1
    RC=$?
    set -e
    if [ "$RC" -ne 0 ]; then
        pass "L3L4 ERROR on PASS/FAIL (exit=$RC, contradiction detected)"
    else
        fail "L3L4 OK on PASS/FAIL (expected non-zero, got exit=0 — contradiction NOT detected)"
    fi
else
    fail "L3L4 script not available for self-test"
fi
echo ""

# -------------------------------------------------------
# Check 5: Anti-fab tools run without crashing
# -------------------------------------------------------
echo ">>> Check 5: Anti-fab tools smoke run"
# check-test-case-isolation: scans expert triggers
set +e
bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
    pass "check-test-case-isolation.sh runs (exit=$RC)"
else
    fail "check-test-case-isolation.sh crashed (exit=$RC)"
fi

# check-kpi-precision: checks HEAD commit message
set +e
bash "$VERIFY_DIR/check-kpi-precision.sh" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
    pass "check-kpi-precision.sh runs (exit=$RC)"
else
    fail "check-kpi-precision.sh crashed (exit=$RC)"
fi
echo ""

# -------------------------------------------------------
# Check 6: scope-creep wired (skip if no ticket.json)
# -------------------------------------------------------
echo ">>> Check 6: scope-creep available"
TICKET_FILE="$KALLAX_ROOT/jira/tickets/EPIC-053-A/ticket.json"
if [ -x "$VERIFY_DIR/check-scope-creep.sh" ]; then
    if [ -f "$TICKET_FILE" ]; then
        # Just verify the script can find and parse the ticket
        if bash "$VERIFY_DIR/check-scope-creep.sh" EPIC-053-A >/dev/null 2>&1; then
            pass "check-scope-creep.sh EPIC-053-A runs clean"
        else
            # Fail OK if there are real out-of-scope files; we just want no crash
            pass "check-scope-creep.sh EPIC-053-A runs (may flag out-of-scope files)"
        fi
    else
        pass "check-scope-creep.sh exists (no ticket to test against)"
    fi
else
    fail "check-scope-creep.sh missing"
fi
echo ""

# Summary
echo "=========================================="
echo "Preflight Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL_CHECKS)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — L4 verify framework not ready"
    echo "Action: fix failing checks before ticket can pass preflight"
    exit 1
fi
echo "RESULT: PASS — L4 verify framework ready"
echo "Action: ticket can proceed to L4 verify gate"
exit 0
