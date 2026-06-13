#!/usr/bin/env bash
# scripts/conductor/review.sh — Conductor review flow for merge gate
# Runs 3 anti-fab + preflight + amend-verify before Conductor merge
# EPIC-039-B: Step 4 of Rule 16 5-step flow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

echo "=========================================="
echo "Conductor Review Gate (EPIC-039-B)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# --- 1. test-case-isolation check (Rule 9b) ---
echo "--- 1. Anti-Fab: test-case-isolation ---"
if bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1; then
    pass "test-case-isolation PASS"
else
    fail "test-case-isolation FAIL (Rule 9b: verbatim in trigger)"
fi
echo ""

# --- 2. kpi-precision check (Rule 9a) ---
echo "--- 2. Anti-Fab: kpi-precision ---"
if bash "$VERIFY_DIR/check-kpi-precision.sh" >/dev/null 2>&1; then
    pass "kpi-precision PASS"
else
    fail "kpi-precision FAIL (Rule 9a: estimate/PARTIAL pattern)"
fi
echo ""

# --- 3. scope-creep check (Rule 9c) ---
echo "--- 3. Anti-Fab: scope-creep ---"
# scope-creep needs TICKET_ID arg; use HEAD commit to infer ticket
RECENT_TICKET=$(git log -1 --pretty=%B | grep -oE 'EPIC-[0-9]+-[A-Z]' | head -1 || echo "")
if [ -n "$RECENT_TICKET" ]; then
    if bash "$VERIFY_DIR/check-scope-creep.sh" "$RECENT_TICKET" >/dev/null 2>&1; then
        pass "scope-creep PASS (ticket: $RECENT_TICKET)"
    else
        fail "scope-creep FAIL (Rule 9c: files outside scope)"
    fi
else
    # No ticket ID in commit msg — skip scope check
    pass "scope-creep SKIP (no ticket ID in commit)"
fi
echo ""

# --- 4. check-fact-forcing-preflight.sh (Rule 9 L1-L4) ---
echo "--- 4. Fact-Forcing: preflight 5-tool check ---"
# Run against most recent commit's diff to find expert.md
EXPERT_FILE=$(git diff HEAD~1..HEAD --name-only | grep -E 'expert.*\.md$' | head -1 || echo "")
if [ -n "$EXPERT_FILE" ] && [ -f "$EXPERT_FILE" ]; then
    if bash "$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh" "$EXPERT_FILE" >/dev/null 2>&1; then
        pass "preflight PASS (L1/L2/L3/L4/L4_script)"
    else
        fail "preflight FAIL (L1/L2/L3/L4/L4_script exists)"
    fi
else
    # No expert.md changed — run stub check
    if [ -f "$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh" ]; then
        pass "preflight SKIP (no expert.md in diff)"
    else
        fail "preflight FAIL (check-fact-forcing-preflight.sh missing)"
    fi
fi
echo ""

# --- 5. check-commit-amend-verify.sh (Rule 9d) ---
echo "--- 5. Anti-Fab: commit-amend-verify ---"
if bash "$VERIFY_DIR/check-commit-amend-verify.sh" >/dev/null 2>&1; then
    pass "commit-amend-verify PASS"
else
    fail "commit-amend-verify FAIL (Rule 9d: hidden amend)"
fi
echo ""

# --- Summary ---
echo "=========================================="
echo "REVIEW RESULT: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "GATE: FAIL — Conductor must NOT merge"
    echo "Fix failures before proceeding with merge."
    exit 1
else
    echo "GATE: PASS — Conductor may proceed with merge"
    exit 0
fi