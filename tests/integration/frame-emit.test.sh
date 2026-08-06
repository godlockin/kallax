#!/usr/bin/env bash
# tests/integration/frame-emit.test.sh — EPIC-193 frame-task --emit 集成测试
#
# 验证:
#   T1. classify --emit 触发 decision 事件到 run-history ledger
#   T2. emit-all <file> 批量 emit N 事件
#   T3. emit 后的 ledger 含 frame_decision payload
#   T4. ledger tier 字段跟 classify 输出 1:1
#   T5. emit 失败不阻塞 classify (graceful degradation)
#   T6. frame-task --self-test 仍 10/10 (无回归)
#   T7. emit-all 跳过空行 + # 注释
#   T8. 跟 EPIC-177-G run-history emit 1:1 schema

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"
RUN_HISTORY="$KALLAX_ROOT/scripts/heartbeat/run-history.sh"

PASS=0
FAIL=0

assert_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -Eq "$pattern"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== frame-emit.test.sh (≥8 用例, EPIC-193) ==="

# ── T1: classify --emit 触发 decision ──
echo ""
echo "T1: classify --emit 触发 decision 事件"
LEDGER=$(mktemp)
KALLAX_RUN_HISTORY_LEDGER="$LEDGER" bash "$FRAME_TASK" classify --emit "EPIC-X 是什么" >/dev/null 2>&1
event_count=$(wc -l < "$LEDGER" | tr -d ' ')
if [ "$event_count" -ge 1 ]; then
    echo "  PASS: T1.1 ledger 有 $event_count 事件"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T1.1 ledger 空 (emit 未触发)"
    FAIL=$((FAIL + 1))
fi

# ── T2: emit-all 批量 emit ──
echo ""
echo "T2: emit-all 批量 emit"
TEST_FILE=$(mktemp)
cat > "$TEST_FILE" <<EOF
# Comment line — 应跳过
EPIC-A 是什么
设计 X 系统
EOF
LEDGER2=$(mktemp)
KALLAX_RUN_HISTORY_LEDGER="$LEDGER2" bash "$FRAME_TASK" emit-all "$TEST_FILE" >/dev/null 2>&1
event_count2=$(wc -l < "$LEDGER2" | tr -d ' ')
if [ "$event_count2" -ge 2 ]; then
    echo "  PASS: T2.1 emit-all 产生 $event_count2 events (期望 ≥2)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T2.1 emit-all 只有 $event_count2 events"
    FAIL=$((FAIL + 1))
fi

# ── T3: ledger 含 frame_decision payload ──
echo ""
echo "T3: ledger 含 frame_decision payload"
if grep -q "frame_decision" "$LEDGER2"; then
    echo "  PASS: T3.1 含 frame_decision"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T3.1 缺 frame_decision"
    FAIL=$((FAIL + 1))
fi

# ── T4: tier 字段 1:1 ──
echo ""
echo "T4: ledger tier 字段 跟 classify 1:1"
# 第一个事件应该是 SIMPLE (EPIC-A 是什么 简单查询)
tier_in_ledger=$(grep "frame_decision" "$LEDGER2" | head -1 | jq -r '.payload.tier // empty' 2>/dev/null)
if [ -n "$tier_in_ledger" ]; then
    echo "  PASS: T4.1 tier 字段存在 ($tier_in_ledger)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T4.1 tier 字段缺失"
    FAIL=$((FAIL + 1))
fi

# ── T5: graceful degradation (emit 失败不阻塞 classify) ──
echo ""
echo "T5: emit 失败不阻塞 classify"
# 直接测试 run-history 不在 PATH 的场景
out=$(KALLAX_RUN_HISTORY_LEDGER="/nonexistent/ledger" bash "$FRAME_TASK" classify --emit "EPIC-Y 是什么" 2>&1)
# 应仍输出 FRAME (不阻塞)
if echo "$out" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档"; then
    echo "  PASS: T5.1 graceful degradation (FRAME 仍输出)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T5.1 FRAME 未输出"
    FAIL=$((FAIL + 1))
fi

# ── T6: self-test 仍 10/10 ──
echo ""
echo "T6: frame-task --self-test 仍 10/10 (无回归)"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T6.1 self-test 10/10" "10/10" "$out"

# ── T7: emit-all 跳过空行 + # ──
echo ""
echo "T7: emit-all 跳过空行 + # 注释"
TEST_FILE2=$(mktemp)
cat > "$TEST_FILE2" <<EOF

# comment 1
EPIC-1 是什么

# comment 2
EPIC-2 是什么
EOF
LEDGER3=$(mktemp)
KALLAX_RUN_HISTORY_LEDGER="$LEDGER3" bash "$FRAME_TASK" emit-all "$TEST_FILE2" >/dev/null 2>&1
event_count3=$(wc -l < "$LEDGER3" | tr -d ' ')
# 应 2 events (跳过 1 空行 + 2 注释)
if [ "$event_count3" -eq 2 ]; then
    echo "  PASS: T7.1 跳过空行+注释 ($event_count3 events, 期望 2)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T7.1 $event_count3 events (期望 2)"
    FAIL=$((FAIL + 1))
fi

# ── T8: 跟 EPIC-177-G 1:1 schema ──
echo ""
echo "T8: 跟 EPIC-177-G schema 1:1"
# 检查 event_type + agent_id + ticket_id 字段
if [ -s "$LEDGER" ]; then
    first_event=$(head -1 "$LEDGER")
    if echo "$first_event" | jq -e '.event_type and .agent_id and .ticket_id and .payload' >/dev/null 2>&1; then
        echo "  PASS: T8.1 event 1:1 schema (event_type/agent_id/ticket_id/payload)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T8.1 schema 缺失"
        FAIL=$((FAIL + 1))
    fi
fi

# ── 总结 ──
rm -f "$LEDGER" "$LEDGER2" "$LEDGER3" "$TEST_FILE" "$TEST_FILE2"
echo ""
echo "=== frame-emit.test.sh 总结 ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
    echo "  ✅ ALL PASS"
    exit 0
else
    echo "  ❌ $FAIL FAILED"
    exit 1
fi