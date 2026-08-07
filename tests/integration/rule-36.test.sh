#!/usr/bin/env bash
# tests/integration/rule-36.test.sh — Rule 36 Sprint 结束 4 北极星 metric 集成测试
#
# 验证:
#   T1. CLAUDE.md 含 Rule 36 标题 (§3.2)
#   T2. Rule 36 含 4 北极星指标 (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch)
#   T3. Rule 36 跟现有 Rule 联合 (Rule 5/9/13/35)
#   T4. CLAUDE.md 总行数 ≤ 200 (跟 EPIC-159 治理 2.0 联合)
#   T5. scripts/metrics/sprint-metrics.sh 存在且可执行
#   T6. frame-task --self-test 仍 10/10 (无回归)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
SPRINT_METRICS="$KALLAX_ROOT/scripts/metrics/sprint-metrics.sh"
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

echo "=== rule-36.test.sh (≥6 用例, EPIC-194) ==="

# ── T1: Rule 36 标题 (§3.2) ──
echo ""
echo "T1: CLAUDE.md 含 Rule 36 (§3.2)"
out=$(grep -E "^## 3\.2\. Rule 36" "$CLAUDE_MD")
if [ -n "$out" ]; then
    echo "  PASS: T1.1 Rule 36 标题存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T1.1 Rule 36 标题缺失"
    FAIL=$((FAIL + 1))
fi

# ── T2: 4 北极星指标 ──
echo ""
echo "T2: 4 北极星指标 (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch)"
out=$(cat "$CLAUDE_MD")
assert_contains "T2.1 expert_activation_rate ≥ 5" "expert_activation_rate" "$out"
assert_contains "T2.2 cross_epic_reuse_rate ≥ 60%" "cross_epic_reuse_rate.*60" "$out"
assert_contains "T2.3 ab_hit_rate < 15%" "ab_hit_rate" "$out"
assert_contains "T2.4 mis_dispatch_rate < 10%" "mis_dispatch_rate" "$out"

# ── T3: 联合 4 个 Rule (5/9/13/35) ──
echo ""
echo "T3: 联合 Rule 5/9/13/35"
out=$(cat "$CLAUDE_MD")
assert_contains "T3.1 Rule 5 联合" "Rule 5 \\(DRY" "$out"
assert_contains "T3.2 Rule 9 联合" "Rule 9 \\(KPI" "$out"
assert_contains "T3.3 Rule 13 联合" "Rule 13 \\(3 模式" "$out"
assert_contains "T3.4 Rule 35 联合" "Rule 35 \\(Sprint" "$out"

# ── T4: CLAUDE.md ≤ 200 行 ──
echo ""
echo "T4: CLAUDE.md 总行数 ≤ 200"
total_lines=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
echo "  current: $total_lines lines"
if [ "$total_lines" -le 200 ]; then
    echo "  PASS: T4.1 ≤ 200 行 ($total_lines)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T4.1 > 200 行 ($total_lines) — 违反 CLAUDE.md 治理 2.0"
    FAIL=$((FAIL + 1))
fi

# ── T5: sprint-metrics.sh 存在 + 可执行 ──
echo ""
echo "T5: scripts/metrics/sprint-metrics.sh 存在且可执行"
if [ -x "$SPRINT_METRICS" ]; then
    echo "  PASS: T5.1 sprint-metrics.sh 可执行"
    PASS=$((PASS + 1))

    # 验证 script 含 4 指标 (comment 或 --help)
    script_content=$(cat "$SPRINT_METRICS")
    if echo "$script_content" | grep -qE "expert_activation.*5" && \
       echo "$script_content" | grep -qE "cross_epic_reuse.*60" && \
       echo "$script_content" | grep -qE "ab_hit.*15" && \
       echo "$script_content" | grep -qE "mis_dispatch.*10"; then
        echo "  PASS: T5.2 sprint-metrics.sh 含 4 指标"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T5.2 sprint-metrics.sh 缺 4 指标"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL: T5.1 sprint-metrics.sh 不存在或不可执行"
    FAIL=$((FAIL + 1))
fi

# ── T6: frame-task self-test 仍 PASS ──
echo ""
echo "T6: frame-task --self-test 仍 10/10 (无回归)"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T6.1 self-test 10/10" "10/10" "$out"

# ── 总结 ──
echo ""
echo "=== rule-36.test.sh 总结 ==="
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