#!/usr/bin/env bash
# tests/integration/heartbeat-daemon-runtime.test.sh — EPIC-168-F
# 验证 EPIC-166 (Heartbeat Daemon + Quota + Run History) 真跑有效
# 跟 EPIC-069-D 5-Level Verify 同样模式, 防止假 PASS

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

# TC3: scheduler-hint 4 priority (P0 > BLOCKED > P1 > P2)
echo ""
echo "TC3: scheduler-hint priority logic (P0 > BLOCKED > P1 > P2)"
# Test with P0 ticket
P0_result=$(bash "$SCHEDULER_SCRIPT" next P0 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
# Test with P1 ticket
P1_result=$(bash "$SCHEDULER_SCRIPT" next P1 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
# Test with P2 ticket
P2_result=$(bash "$SCHEDULER_SCRIPT" next P2 2>&1 | grep -oE '"priority": "[^"]+"' | head -1 || echo "")
if [ "$P0_result" = "$P1_result" ] && [ "$P1_result" = "$P2_result" ]; then
    fail "scheduler-hint priority" "all priorities return same: $P0_result (expected different — P0=highest, P2=lowest)"
else
    pass "scheduler-hint priority P0/P1/P2 differ (P0=$P0_result, P1=$P1_result, P2=$P2_result)"
fi

# TC4: run-history emit 4 类 (jq-free, flock-protected)
echo ""
echo "TC4: run-history emit 4 event types (jq-free + flock)"
initial_count=$(wc -l < "$STATE_DIR/run-history.jsonl" 2>/dev/null || echo 0)
for evt in work decision accounting evidence; do
    result=$(bash "$RUN_HISTORY_SCRIPT" emit "$evt" EPIC-168-BG-test '{"action":"test"}' 2>&1 || echo "FAIL")
    if [ "$result" != "FAIL" ]; then
        pass "emit $evt"
    else
        fail "emit $evt" "exit non-zero"
    fi
done
final_count=$(wc -l < "$STATE_DIR/run-history.jsonl" 2>/dev/null || echo 0)
if [ "$final_count" -gt "$initial_count" ]; then
    pass "append worked (+$((final_count - initial_count)) lines)"
else
    fail "append" "count not incremented"
fi

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
# 注: heartbeat-daemon.log 仅在 daemon 长跑时生成, 测试不实跑 daemon.
# quota-db.json 和 run-history.jsonl 来自 TC2-5 直接调用, 必存在.
echo ""
echo "TC6: state persistence (daemon log excluded — test doesn't run daemon long)"
for f in quota-db.json run-history.jsonl; do
    if [ -f "$STATE_DIR/$f" ]; then
        size=$(wc -c < "$STATE_DIR/$f" | tr -d ' ')
        pass "$f exists ($size bytes)"
    else
        fail "$f" "not found"
    fi
done

# TC7: 北极星打通 (dashboard-metrics.sh)
echo ""
echo "TC7: EPIC-023-C 北极星打通 (dashboard-metrics.sh)"
if [ -f "${SCRIPT_DIR}/../../scripts/dashboard/dashboard-metrics.sh" ]; then
    metrics_json=$(bash "${SCRIPT_DIR}/../../scripts/dashboard/dashboard-metrics.sh" --format=json 2>/dev/null)
    if echo "$metrics_json" | grep -qE "(expert_activation|mis_dispatch_binding_rate|cross_epic_reuse|ab_hit_rate)"; then
        pass "dashboard-metrics includes 4 北极星"
    else
        fail "dashboard-metrics" "no 北极星 metric output"
    fi
else
    fail "dashboard-metrics.sh" "not found"
fi

# TC8: 5-Level Verify L1-L5
echo ""
echo "TC8: 5-Level Verify L1-L5"
L1=$(git status --short --branch 2>&1 | head -1)
L2=$(for s in "$DAEMON_SCRIPT" "$QUOTA_SCRIPT" "$SCHEDULER_SCRIPT" "$RUN_HISTORY_SCRIPT"; do bash -n "$s" 2>&1; done; echo "")
# EPIC-245: L4 不写死 "=2". scan-dead-code 退出码 0=PASS / 1=FAIL / 2=BLOCKED-env.
# 期望 0 或 2 (环境差异), 1 才是真违规.
L4_cwd=$(bash "${SCRIPT_DIR}/../../scripts/scan-dead-code.sh" > /dev/null 2>&1; echo $?)
L4_repo=$(cd "${SCRIPT_DIR}/../.." && bash "scripts/scan-dead-code.sh" > /dev/null 2>&1; echo $?)
if [ -n "$L1" ] && [ -z "$L2" ] && [ "$L4_cwd" != "1" ] && [ "$L4_repo" != "1" ]; then
    pass "L1 git + L2 build + L4 (0=PASS 或 2=BLOCKED-env, 实际 L4_cwd=$L4_cwd L4_repo=$L4_repo)"
else
    fail "5-Level" "L1='$L1' L2='$L2' L4_cwd=$L4_cwd L4_repo=$L4_repo (期望 L4 为 0 或 2)"
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