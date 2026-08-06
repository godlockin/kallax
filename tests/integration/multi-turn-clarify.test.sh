#!/usr/bin/env bash
# tests/integration/multi-turn-clarify.test.sh — EPIC-184 多轮澄清集成测试
#
# 覆盖:
#   T1. partial 命令: 输出 Round 1 模板
#   T2. partial --field Q3: 指定字段
#   T3. answer 命令: 合并 Q3 + Q4 答案
#   T4. answer --field 多轮累加
#   T5. complete 命令: 终态输出
#   T6. 真实场景: 复杂任务 "设计 X 系统" → partial → answer × 2 → complete
#   T7. frame-task --self-test 仍 10/10 PASS (无回归)
#   T8. frame-task 4 档阈值 (跟 EPIC-184 联合)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"

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

assert_exit_code() {
    local test_name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $test_name (exit=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected exit=$expected, got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== multi-turn-clarify.test.sh (≥8 用例, EPIC-184) ==="

# ── T1: partial 命令基础 ──
echo ""
echo "T1: partial 命令基础"
out=$(bash "$FRAME_TASK" partial "设计 X 系统" 2>&1)
exit_code=$?
assert_exit_code "T1.1 partial exit=0 (PASS)" 0 "$exit_code"
assert_contains "T1.2 输出 Round 1 模板" "PARTIAL FRAME" "$out"
assert_contains "T1.3 含'待澄清字段'标记" "待澄清字段" "$out"

# ── T2: partial --field 指定字段 ──
echo ""
echo "T2: partial --field Q3"
out=$(bash "$FRAME_TASK" partial "设计 Y 系统" --field Q3 --field Q4 2>&1)
assert_contains "T2.1 --field Q3 Q4 列出" "Q3 Q4" "$out"

# ── T3: answer 命令合并 ──
echo ""
echo "T3: answer 合并 Q3 + Q4"
out=$(bash "$FRAME_TASK" answer /tmp/frame-state.json --field Q3 "API 输出 JSON" --field Q4 "scripts/api/*.sh" 2>&1)
assert_contains "T3.1 ANSWER MERGED 模板" "ANSWER MERGED" "$out"
assert_contains "T3.2 已合并字段标记" "已合并字段" "$out"

# ── T4: answer --field 多轮累加 ──
echo ""
echo "T4: answer 多轮累加"
out=$(bash "$FRAME_TASK" answer /tmp/frame-state.json --field Q5 "Rule 5 DRY" --field Q6 "none" 2>&1)
assert_contains "T4.1 多字段累加" "已合并字段" "$out"

# ── T5: complete 终态 ──
echo ""
echo "T5: complete 终态"
out=$(bash "$FRAME_TASK" complete /tmp/frame-state.json 2>&1)
assert_contains "T5.1 COMPLETE FRAME" "COMPLETE FRAME" "$out"
assert_contains "T5.2 Q1-Q6 全填标记" "Q1-Q6 全填" "$out"

# ── T6: 真实场景端到端 ──
echo ""
echo "T6: 真实场景 (partial → answer × 2 → complete)"
out1=$(bash "$FRAME_TASK" partial "设计 X 系统" 2>&1)
out2=$(bash "$FRAME_TASK" answer /tmp/frame-state.json --field Q3 "API" --field Q4 "scripts/api/*.sh" 2>&1)
out3=$(bash "$FRAME_TASK" answer /tmp/frame-state.json --field Q5 "Rule 5 DRY" --field Q6 "low" 2>&1)
out4=$(bash "$FRAME_TASK" complete /tmp/frame-state.json 2>&1)
assert_contains "T6.1 Round 1 → partial" "PARTIAL FRAME" "$out1"
assert_contains "T6.2 Round 2 → answer" "ANSWER MERGED" "$out2"
assert_contains "T6.3 Round 3 → answer" "ANSWER MERGED" "$out3"
assert_contains "T6.4 Round 4 → complete" "COMPLETE FRAME" "$out4"

# ── T7: 无回归 (frame-task --self-test) ──
echo ""
echo "T7: 无回归 (frame-task --self-test)"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T7.1 --self-test 仍 PASS" "10/10" "$out"

# ── T8: 4 档阈值 + multi-turn 联合 ──
echo ""
echo "T8: 4 档阈值 (跟 EPIC-184 联合)"
out=$(bash "$FRAME_TASK" classify "4-PR 错乱 彻查然后出根因然后写follow-up EPIC-179然后落地再跑测试 涉及 scripts/branch-4pr.sh 和 CLAUDE.md 和多个 EPIC" 2>&1)
assert_contains "T8.1 复杂任务 → COMPLEX 档" "COMPLEX 档" "$out"

# ── 总结 ──
echo ""
echo "=== multi-turn-clarify.test.sh 总结 ==="
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