#!/usr/bin/env bash
# tests/integration/quota-scheduler.test.sh — EPIC-166 Quota Scheduler Tests
#
# ≥5 test cases:
#   1. eligible state
#   2. throttled state
#   3. paused state
#   4. spend ledger
#   5. priority stack
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUOTA_SCRIPT="${KALLAX_ROOT}/scripts/heartbeat/quota.sh"
SCHEDULER_SCRIPT="${KALLAX_ROOT}/scripts/heartbeat/scheduler-hint.sh"
STATE_DIR="${KALLAX_ROOT}/state"

# Skip cooldown for tests
export QUOTA_SKIP_COOLDOWN=true

# Cleanup
cleanup() {
    rm -f "${STATE_DIR}/quota-ledger.jsonl" 2>/dev/null || true
    rm -f "${STATE_DIR}/quota-paused.json" 2>/dev/null || true
    rm -f "${STATE_DIR}/quota-cooldown-"* 2>/dev/null || true
    rm -rf "${KALLAX_ROOT}/jira/tickets/P0-TEST-Q" "${KALLAX_ROOT}/jira/tickets/P1-TEST-Q" "${KALLAX_ROOT}/jira/tickets/P2-TEST-Q" 2>/dev/null || true
}
trap cleanup EXIT

# Helpers
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$STATE_DIR"

# Initial cleanup
cleanup

# ── Test 1: Eligible State ───────────────────────────────────────────────────

test_eligible() {
    echo "=== Test 1: Eligible State ==="

    # New ticket should be eligible
    local output
    output=$("$QUOTA_SCRIPT" should-run EPIC-166-ELIGIBLE 2>&1) || true
    echo "$output" | grep -q "eligible" || fail "expected eligible, got: $output"

    # Exit code should be 0
    if ! "$QUOTA_SCRIPT" should-run EPIC-166-ELIGIBLE > /dev/null 2>&1; then
        fail "eligible should exit 0"
    fi

    pass "eligible state"
}

# ── Test 2: Throttled State ─────────────────────────────────────────────────

test_throttled() {
    echo "=== Test 2: Throttled State ==="

    # Spend budget
    "$QUOTA_SCRIPT" spend EPIC-166-THROTTLE 20 > /dev/null 2>&1 || fail "spend failed"

    # Should be throttled
    local output
    output=$("$QUOTA_SCRIPT" should-run EPIC-166-THROTTLE 2>&1) || true
    echo "$output" | grep -q "throttled" || fail "expected throttled, got: $output"

    # Exit code should be 1
    if "$QUOTA_SCRIPT" should-run EPIC-166-THROTTLE > /dev/null 2>&1; then
        fail "throttled should exit non-zero"
    fi

    pass "throttled state"
}

# ── Test 3: Paused State ────────────────────────────────────────────────────

test_paused() {
    echo "=== Test 3: Paused State ==="

    # Create a P1 test ticket to avoid P2 budget conflict
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P1-PAUSED"
    echo '{"priority":"P1","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P1-PAUSED/ticket.json"

    # Pause P1-PAUSED (not EPIC-166-PAUSED which defaults to P2)
    "$QUOTA_SCRIPT" pause P1-PAUSED > /dev/null 2>&1 || fail "pause failed"

    # Should be paused
    local output
    output=$("$QUOTA_SCRIPT" should-run P1-PAUSED 2>&1) || true
    echo "$output" | grep -q "paused" || fail "expected paused, got: $output"

    # Exit code should be 2
    if "$QUOTA_SCRIPT" should-run P1-PAUSED > /dev/null 2>&1; then
        fail "paused should exit non-zero"
    fi

    # Resume
    "$QUOTA_SCRIPT" resume P1-PAUSED > /dev/null 2>&1 || fail "resume failed"

    # Should be eligible now (P1 budget should still be available)
    output=$("$QUOTA_SCRIPT" should-run P1-PAUSED 2>&1) || true
    echo "$output" | grep -q "eligible" || fail "expected eligible after resume, got: $output"

    # Cleanup
    rm -rf "${KALLAX_ROOT}/jira/tickets/P1-PAUSED"

    pass "paused state"
}

# ── Test 4: Spend Ledger ────────────────────────────────────────────────────

test_spend_ledger() {
    echo "=== Test 4: Spend Ledger ==="

    # Spend some quota
    "$QUOTA_SCRIPT" spend EPIC-166-LEDGER 5 > /dev/null 2>&1 || fail "spend failed"
    "$QUOTA_SCRIPT" spend EPIC-166-LEDGER 3 > /dev/null 2>&1 || fail "spend failed"

    # Check ledger
    local ledger_output
    ledger_output=$("$QUOTA_SCRIPT" ledger EPIC-166-LEDGER 2>&1) || true
    echo "$ledger_output" | grep -q "EPIC-166-LEDGER" || fail "ledger missing entries"

    # Status shows spent
    local status
    status=$("$QUOTA_SCRIPT" status EPIC-166-LEDGER 2>&1) || true
    echo "$status" | grep -q "spent" || fail "status missing spent"

    pass "spend ledger"
}

# ── Test 5: Priority Stack ──────────────────────────────────────────────────

test_priority_stack() {
    echo "=== Test 5: Priority Stack ==="

    # Create test tickets
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P0-TEST-Q"
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P1-TEST-Q"
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P2-TEST-Q"

    echo '{"priority":"P0","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P0-TEST-Q/ticket.json"
    echo '{"priority":"P1","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P1-TEST-Q/ticket.json"
    echo '{"priority":"P2","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P2-TEST-Q/ticket.json"

    # Get stats
    local stats
    stats=$("$SCHEDULER_SCRIPT" stats 2>&1) || true
    echo "$stats" | grep -q "P0" || fail "stats missing P0"
    echo "$stats" | grep -q "P1" || fail "stats missing P1"
    echo "$stats" | grep -q "P2" || fail "stats missing P2"

    # Next should be P0
    local next
    next=$("$SCHEDULER_SCRIPT" next 2>&1) || true
    echo "$next" | grep -q "P0" || fail "expected P0 next, got: $next"

    pass "priority stack"
}

# ── Run All Tests ───────────────────────────────────────────────────────────

echo "═══════════════════════════════════════"
echo "EPIC-166 Quota Scheduler Test Suite"
echo "═══════════════════════════════════════"

test_eligible
test_throttled
test_paused
test_spend_ledger
test_priority_stack

echo "═══════════════════════════════════════"
echo "All tests PASSED (5/5)"
echo "═══════════════════════════════════════"
exit 0
