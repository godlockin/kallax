#!/usr/bin/env bash
# tests/integration/5-levels-test.sh — TDD tests for 5-Level Fact-Forcing (武器 2 Iter 5)
#
# 验证 5 个 level-*.sh 独立可跑 + preflight wrapper 联动:
#   Case 1: 5 个 level-*.sh 存在 + executable
#   Case 2: L1 真跑 PASS (HEAD SHA 真变, ticket.json exists)
#   Case 3: L2-L5 dry-run PASS (placeholder OK)
#   Case 4: preflight wrapper 5/5 PASS (--original 模式 6/6 PASS)
#   Case 5: bad ticket ID 时, 真跑 L2 = FAIL (negative test)
#
# Rule 9 KPI X/Y 格式: 5/5 = 100.0% PASS (no estimate, exact)
# 跟 docs/5-levels.md 1:1 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly VERIFY_DIR="$KALLAX_ROOT/scripts/verify"
readonly TICKET_ID="EPIC-053-A"

echo "=========================================="
echo "5-Level Fact-Forcing — Integration Tests (5/5)"
echo "武器 2 (Iter 5) — 跟 docs/5-levels.md 1:1 联合"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# -------------------------------------------------------
# Case 1: 5 level-*.sh 存在 + executable
# -------------------------------------------------------
echo ">>> Case 1: 5 level-*.sh exist + executable"
LEVEL_OK=0
for level in 1 2 3 4 5; do
    SCRIPT="$VERIFY_DIR/level-${level}.sh"
    if [ -x "$SCRIPT" ]; then
        echo "    L${level}: $SCRIPT (executable OK)"
        LEVEL_OK=$((LEVEL_OK+1))
    else
        echo "    L${level}: $SCRIPT MISSING or not executable"
    fi
done
if [ "$LEVEL_OK" -eq 5 ]; then
    pass "5/5 level-*.sh exist + executable"
else
    fail "level scripts: $LEVEL_OK/5 OK (expected 5)"
fi
echo ""

# -------------------------------------------------------
# Case 2: L1 真跑 PASS
# -------------------------------------------------------
echo ">>> Case 2: L1 real run (HEAD SHA 真变 + ticket.json exists)"
set +e
L1_OUT=$(bash "$VERIFY_DIR/level-1.sh" "$TICKET_ID" 2>&1)
L1_RC=$?
set -e
if [ "$L1_RC" -eq 0 ] && echo "$L1_OUT" | grep -q "RESULT: PASS"; then
    pass "L1 PASS (raw stdout: $(echo "$L1_OUT" | grep RESULT | head -1))"
else
    fail "L1 FAIL (rc=$L1_RC)"
    echo "$L1_OUT" | tail -5 | sed 's/^/      /'
fi
echo ""

# -------------------------------------------------------
# Case 3: L2-L5 dry-run PASS (placeholder ticket OK)
# -------------------------------------------------------
echo ">>> Case 3: L2-L5 dry-run PASS (placeholder OK)"
LEVEL_OK=0
for level in 2 3 4 5; do
    set +e
    OUT=$(bash "$VERIFY_DIR/level-${level}.sh" PLACEHOLDER --dry-run 2>&1)
    RC=$?
    set -e
    if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "RESULT: PASS"; then
        echo "    L${level} dry-run PASS"
        LEVEL_OK=$((LEVEL_OK+1))
    else
        echo "    L${level} dry-run FAIL (rc=$RC)"
    fi
done
if [ "$LEVEL_OK" -eq 4 ]; then
    pass "4/4 L2-L5 dry-run PASS"
else
    fail "L2-L5 dry-run: $LEVEL_OK/4 OK (expected 4)"
fi
echo ""

# -------------------------------------------------------
# Case 4: preflight wrapper 5/5 PASS (--original 模式 6/6 PASS)
# -------------------------------------------------------
echo ">>> Case 4: preflight wrapper 5/5 PASS + --original 6/6 PASS"
set +e
WRAPPER_OUT=$(bash "$VERIFY_DIR/check-fact-forcing-preflight.sh" "$TICKET_ID" 2>&1)
WRAPPER_RC=$?
set -e
if [ "$WRAPPER_RC" -eq 0 ] && echo "$WRAPPER_OUT" | grep -q "5-Level Summary: 5 PASS, 0 FAIL"; then
    pass "wrapper 5/5 PASS (武器 2 落地)"
else
    fail "wrapper FAIL (rc=$WRAPPER_RC)"
    echo "$WRAPPER_OUT" | tail -5 | sed 's/^/      /'
fi

set +e
ORIG_OUT=$(bash "$VERIFY_DIR/check-fact-forcing-preflight.sh" --original 2>&1)
ORIG_RC=$?
set -e
if [ "$ORIG_RC" -eq 0 ] && echo "$ORIG_OUT" | grep -qE "Preflight Summary: [6-9] PASS, 0 FAIL"; then
    pass "--original 6/6+ PASS (向后兼容)"
else
    fail "--original FAIL (rc=$ORIG_RC)"
fi
echo ""

# -------------------------------------------------------
# Case 5: bad ticket ID 真跑 L2 = FAIL (negative test)
# -------------------------------------------------------
echo ">>> Case 5: bad ticket ID + real L2 run = FAIL (negative test)"
set +e
BAD_OUT=$(bash "$VERIFY_DIR/level-2.sh" NONEXISTENT-TICKET-999 2>&1)
BAD_RC=$?
set -e
if [ "$BAD_RC" -ne 0 ] && echo "$BAD_OUT" | grep -qE "ERROR|FAIL"; then
    pass "bad ticket 真跑 L2 FAIL as expected (rc=$BAD_RC)"
else
    fail "bad ticket should FAIL but got rc=$BAD_RC"
fi
echo ""

# Summary
echo "=========================================="
echo "5-Level Test Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — 武器 2 not ready"
    exit 1
fi
echo "RESULT: PASS — 武器 2 5-Level Fact-Forcing ready (跟 docs/5-levels.md 1:1)"
exit 0
