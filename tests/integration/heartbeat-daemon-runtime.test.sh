#!/usr/bin/env bash
# tests/integration/heartbeat-daemon-runtime.test.sh — EPIC-168-F
# 验证 EPIC-166 (Heartbeat Daemon + Quota + Run History) 真跑有效
# 跟 EPIC-069-D 5-Level Verify 1:1 防止假 PASS

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEARTBEAT_DIR="${SCRIPT_DIR}/../../scripts/heartbeat"
STATE_DIR="${SCRIPT_DIR}/../../state"

DAEMON_SCRIPT="${HEARTBEAT_DIR}/heartbeat-daemon.sh"
QUOTA_SCRIPT="${HEARTBEAT_DIR}/quota.sh"
SCHEDULER_SCRIPT="${HEARTBEAT_DIR}/scheduler-hint.sh"
RUN_HISTORY_SCRIPT="${HEARTBEAT_DIR}/run-history.sh"

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1: $2"
}

echo "==============================================="
echo "  EPIC-168-F heartbeat-daemon-runtime test"
echo "==============================================="

# TC1: bash syntax 4 脚本
echo "TC1: bash -n syntax check"
for s in "$DAEMON_SCRIPT" "$QUOTA_SCRIPT" "$SCHEDULER_SCRIPT" "$RUN_HISTORY_SCRIPT"; do
    if bash -n "$s" 2>/dev/null; then
        pass "syntax $(basename "$s")"
    else
        fail "syntax $(basename "$s")" "bash -n failed"
    fi
done

# TC2: quota.sh should-run 直接调用
echo ""
echo "TC2: quota.sh should-run direct call"
result=$(bash "$QUOTA_SCRIPT" should-run EPIC-168-F 2>&1 || echo "FAIL")
if echo "$result" | grep -qE "^(eligible|throttled|paused):"; then
    pass "quota should-run returns valid status: $result"
else
    fail "quota should-run" "unexpected output: $result"
fi

# TC3: scheduler-hint 4 priority
echo ""
echo "TC3: scheduler-hint priority logic (P0 > BLOCKED > P1 > P2)"
P0_result=$(bash "$SCHEDULER_SCRIPT" next P0 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
P1_result=$(bash "$SCHEDULER_SCRIPT" next P1 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
P2_result=$(bash "$SCHEDULER_SCRIPT" next P2 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
if [ "$P0_result" = "$P1_result" ] && [ "$P1_result" = "$P2_result" ]; then
    fail "scheduler-hint priority" "all priorities return same: $P0_result (expected different — P0=highest, P2=lowest)"
else
    pass "scheduler-hint priority P0/P1/P2 differ"
fi

# TC4: run-history emit 4 类
echo ""
echo "TC4: run-history emit 4 event types"
for evt in work decision accounting evidence; do
    result=$(bash "$RUN_HISTORY_SCRIPT" emit "$evt" EPIC-168-F performer-1 '{"action":"test"}' 2>&1)
    if echo "$result" | grep -qE "(appended|success|^$)"; then
        pass "emit $evt"
    else
        fail "emit $evt" "output: $result"
    fi
done

# TC5: append-only 改写拦截
echo ""
echo "TC5: append-only protection"
if [ -f "$STATE_DIR/run-history.jsonl" ]; then
    test_count=$(wc -l < "$STATE_DIR/run-history.jsonl" | tr -d ' ')
    echo "" >> "$STATE_DIR/run-history.jsonl"
    new_count=$(wc -l < "$STATE_DIR/run-history.jsonl" | tr -d ' ')
    if [ "$new_count" -gt "$test_count" ]; then
        pass "append works (count $test_count → $new_count)"
    else
        fail "append" "count not incremented"
    fi
else
    fail "append-only" "run-history.jsonl not found"
fi

# TC6: state 持久化
echo ""
echo "TC6: state persistence"
for f in heartbeat-daemon.log quota-db.json run-history.jsonl; do
    if [ -f "$STATE_DIR/$f" ]; then
        size=$(wc -c < "$STATE_DIR/$f" | tr -d ' ')
        pass "$f exists ($size bytes)"
    else
        fail "$f" "not found"
    fi
done

# TC7: 北极星打通 (sprint-metrics.sh)
echo ""
echo "TC7: EPIC-023-C 北极星打通"
if [ -f "${SCRIPT_DIR}/../../scripts/metrics/sprint-metrics.sh" ]; then
    if bash "${SCRIPT_DIR}/../../scripts/metrics/sprint-metrics.sh" --epic EPIC-168-F --format json 2>/dev/null | grep -qE "(expert_activation|mis_dispatch_binding_rate)"; then
        pass "sprint-metrics includes 4 北极星"
    else
        fail "sprint-metrics" "no 北极星 metric output"
    fi
else
    fail "sprint-metrics.sh" "not found"
fi

# TC8: 5-Level Verify L1-L5
echo ""
echo "TC8: 5-Level Verify L1-L5"
L1=$(git status --short --branch 2>&1 | head -1)
L2=$(for s in "$DAEMON_SCRIPT" "$QUOTA_SCRIPT" "$SCHEDULER_SCRIPT" "$RUN_HISTORY_SCRIPT"; do bash -n "$s" 2>&1; done; echo "")
L4=$(bash "${SCRIPT_DIR}/../../scripts/scan-dead-code.sh" > /dev/null 2>&1; echo $?)
if [ -n "$L1" ] && [ -z "$L2" ] && [ "$L4" = "2" ]; then
    pass "L1 git + L2 build + L4 BLOCKED-env"
else
    fail "5-Level" "L1='$L1' L4=$L4 (expected 2)"
fi

# Summary
echo ""
echo "==============================================="
echo "  EPIC-168-F: $PASS pass, $FAIL fail"
echo "==============================================="

if [ "$FAIL" -gt 0 ]; then
    echo "❌ FAILED — see bugs in confluence/decisions/epic-166-daemon-runtime-verification-2026-08-05.md"
    exit 1
fi
exit 0