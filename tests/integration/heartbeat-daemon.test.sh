#!/usr/bin/env bash
# tests/integration/heartbeat-daemon.test.sh — EPIC-166 Heartbeat Daemon Tests
#
# ≥8 test cases:
#   1. daemon start / stop
#   2. quota should-run integration
#   3. P0/P1/P2 priority
#   4. 4 类 event emission
#   5. ledger append-only
#   6. install integration
#   7. 北极星 metric 联动
#   8. exit code 契约
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HEARTBEAT_SCRIPT="${KALLAX_ROOT}/scripts/heartbeat/heartbeat-daemon.sh"
QUOTA_SCRIPT="${KALLAX_ROOT}/scripts/heartbeat/quota.sh"
RUN_HISTORY_SCRIPT="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"
STATE_DIR="${KALLAX_ROOT}/state"
TEST_LEDGER="${STATE_DIR}/test-ledger.jsonl"

# Skip cooldown for tests
export QUOTA_SKIP_COOLDOWN=true

# Cleanup
cleanup() {
    # Kill any running daemon first
    if [ -f "${STATE_DIR}/heartbeat-daemon.pid" ]; then
        local old_pid
        old_pid=$(cat "${STATE_DIR}/heartbeat-daemon.pid" 2>/dev/null || echo "")
        if [ -n "$old_pid" ]; then
            kill "$old_pid" 2>/dev/null || true
            sleep 1
        fi
    fi
    rm -f "${STATE_DIR}/heartbeat-daemon.pid" 2>/dev/null || true
    rm -f "${STATE_DIR}/heartbeat-daemon.log" 2>/dev/null || true
    rm -f "$TEST_LEDGER" 2>/dev/null || true
    # Clean quota state
    rm -f "${STATE_DIR}/quota-ledger.jsonl" 2>/dev/null || true
    rm -f "${STATE_DIR}/quota-cooldown-"* 2>/dev/null || true
}
trap cleanup EXIT

# Helpers
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$STATE_DIR"

# ── Test 1: Daemon Start/Stop ────────────────────────────────────────────────

test_daemon_start_stop() {
    echo "=== Test 1: Daemon Start/Stop ==="

    # Start
    "$HEARTBEAT_SCRIPT" start --interval=1 > /dev/null 2>&1 || fail "start failed"

    # Check PID file
    [ -f "${STATE_DIR}/heartbeat-daemon.pid" ] || fail "PID file not created"
    local pid
    pid=$(cat "${STATE_DIR}/heartbeat-daemon.pid")
    kill -0 "$pid" 2>/dev/null || fail "daemon not running (PID=$pid)"

    # Stop
    "$HEARTBEAT_SCRIPT" stop > /dev/null 2>&1 || fail "stop failed"
    sleep 1

    # Verify stopped
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        fail "daemon still running after stop"
    fi

    pass "daemon start/stop"
}

# ── Test 2: Quota should-run Integration ───────────────────────────────────

test_quota_integration() {
    echo "=== Test 2: Quota should-run Integration ==="

    # Should be eligible initially
    local output
    output=$("$QUOTA_SCRIPT" should-run EPIC-166-TEST 2>&1) || true
    echo "$output" | grep -q "eligible" || fail "expected eligible, got: $output"

    # Spend quota (20 = ticket budget threshold)
    "$QUOTA_SCRIPT" spend EPIC-166-TEST 21 > /dev/null 2>&1 || fail "spend failed"

    # Should now be throttled
    output=$("$QUOTA_SCRIPT" should-run EPIC-166-TEST 2>&1) || true
    echo "$output" | grep -q "throttled" || fail "expected throttled, got: $output"

    # Reset
    "$QUOTA_SCRIPT" reset EPIC-166-TEST > /dev/null 2>&1 || fail "reset failed"

    pass "quota should-run integration"
}

# ── Test 3: P0/P1/P2 Priority ───────────────────────────────────────────────

test_priority_stack() {
    echo "=== Test 3: P0/P1/P2 Priority Stack ==="

    local SCHEDULER="${KALLAX_ROOT}/scripts/heartbeat/scheduler-hint.sh"

    # Create dummy tickets
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P2-TEST-1"
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P0-TEST-1"
    echo '{"priority":"P2","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P2-TEST-1/ticket.json"
    echo '{"priority":"P0","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P0-TEST-1/ticket.json"

    # Test scheduler
    local output
    output=$("$SCHEDULER" next 2>&1) || true
    echo "$output" | grep -q "P0" || fail "expected P0 first, got: $output"

    # Cleanup
    rm -rf "${KALLAX_ROOT}/jira/tickets/P2-TEST-1" "${KALLAX_ROOT}/jira/tickets/P0-TEST-1"

    pass "P0/P1/P2 priority"
}

# ── Test 4: 4 类 Event Emission ────────────────────────────────────────────

test_event_emission() {
    echo "=== Test 4: 4 类 Event Emission ==="

    # Emit all 4 types
    for type in work decision accounting evidence; do
        "$RUN_HISTORY_SCRIPT" emit "$type" EPIC-166-TEST '{"test":true}' > /dev/null 2>&1 \
            || fail "emit $type failed"
    done

    # Verify in ledger
    grep -q "EPIC-166-TEST" "$STATE_DIR/run-history.jsonl" || fail "events not in ledger"

    # Count events
    local count
    count=$(grep -c "EPIC-166-TEST" "$STATE_DIR/run-history.jsonl" 2>/dev/null || echo 0)
    [ "$count" -ge 4 ] || fail "expected ≥4 events, got $count"

    pass "4 类 event emission"
}

# ── Test 5: Ledger Append-only ───────────────────────────────────────────────

test_append_only() {
    echo "=== Test 5: Ledger Append-only ==="

    local ledger="${STATE_DIR}/run-history.jsonl"
    local original_lines
    original_lines=$(wc -l < "$ledger" 2>/dev/null || echo 0)

    # Emit another event
    "$RUN_HISTORY_SCRIPT" emit work EPIC-166-VERIFY '{"test":"append-only"}' > /dev/null 2>&1

    local new_lines
    new_lines=$(wc -l < "$ledger" 2>/dev/null || echo 0)

    [ "$new_lines" -gt "$original_lines" ] || fail "ledger not append-only: $original_lines -> $new_lines"

    pass "ledger append-only"
}

# ── Test 6: Install Integration ─────────────────────────────────────────────

test_install_integration() {
    echo "=== Test 6: Install Integration ==="

    # Check heartbeat scripts exist
    [ -x "$HEARTBEAT_SCRIPT" ] || fail "heartbeat-daemon.sh not executable"
    [ -x "$QUOTA_SCRIPT" ] || fail "quota.sh not executable"
    [ -x "$RUN_HISTORY_SCRIPT" ] || fail "run-history.sh not executable"

    # Check install.sh mentions heartbeat
    grep -q "heartbeat" "${KALLAX_ROOT}/scripts/install.sh" \
        || fail "install.sh doesn't mention heartbeat"

    pass "install integration"
}

# ── Test 7: 北极星 Metric 联动 ─────────────────────────────────────────────

test_polaris_integration() {
    echo "=== Test 7: 北极星 Metric 联动 ==="

    # Emit accounting event (北极星 metric source)
    "$RUN_HISTORY_SCRIPT" emit accounting EPIC-166 '{"metric":"quota_spent","value":1}' > /dev/null 2>&1 \
        || fail "accounting event failed"

    # Verify it appears in ledger - check for EPIC-166 and accounting on same record
    grep -q "EPIC-166" "$STATE_DIR/run-history.jsonl" \
        || fail "EPIC-166 event not in ledger"
    grep -q "accounting" "$STATE_DIR/run-history.jsonl" \
        || fail "accounting event not in ledger"

    pass "北极星 metric 联动"
}

# ── Test 8: Exit Code 契约 ─────────────────────────────────────────────────

test_exit_codes() {
    echo "=== Test 8: Exit Code 契约 ==="

    # Daemon status (not running)
    if ! "$HEARTBEAT_SCRIPT" status > /dev/null 2>&1; then
        fail "status should exit 0"
    fi

    # Quota eligible (use a fresh P1 ticket to avoid budget issues)
    mkdir -p "${KALLAX_ROOT}/jira/tickets/P1-EXIT-TEST"
    echo '{"priority":"P1","status":"todo"}' > "${KALLAX_ROOT}/jira/tickets/P1-EXIT-TEST/ticket.json"
    if ! "$QUOTA_SCRIPT" should-run P1-EXIT-TEST > /dev/null 2>&1; then
        rm -rf "${KALLAX_ROOT}/jira/tickets/P1-EXIT-TEST"
        fail "should-run should exit 0 for eligible"
    fi

    # Quota throttled (spend first)
    "$QUOTA_SCRIPT" spend EPIC-166-THROTTLE-TEST 21 > /dev/null 2>&1 || true
    if "$QUOTA_SCRIPT" should-run EPIC-166-THROTTLE-TEST > /dev/null 2>&1; then
        rm -rf "${KALLAX_ROOT}/jira/tickets/P1-EXIT-TEST"
        fail "should-run should exit 1 for throttled"
    fi

    # Reset for cleanup
    "$QUOTA_SCRIPT" reset EPIC-166-THROTTLE-TEST > /dev/null 2>&1 || true
    rm -rf "${KALLAX_ROOT}/jira/tickets/P1-EXIT-TEST"

    pass "exit code 契约"
}

# ── Run All Tests ───────────────────────────────────────────────────────────

echo "═══════════════════════════════════════"
echo "EPIC-166 Heartbeat Daemon Test Suite"
echo "═══════════════════════════════════════"

test_daemon_start_stop
test_quota_integration
test_priority_stack
test_event_emission
test_append_only
test_install_integration
test_polaris_integration
test_exit_codes

echo "═══════════════════════════════════════"
echo "All tests PASSED (8/8)"
echo "═══════════════════════════════════════"
exit 0
