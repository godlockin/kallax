#!/usr/bin/env bash
# tests/integration/rule-35.test.sh — Rule 35 Sprint 规划时间盒 集成测试 (EPIC-190)
#
# 验证:
#   T1. CLAUDE.md 含 Rule 35 标题
#   T2. Rule 35 含 4 个 sub-rule (Sprint 容量 / 0 超大任务 / 时间盒 / 0 跨 Sprint 累积)
#   T3. Rule 35 跟 6 个现有 Rule 联合 (Rule 4/5/8/9/13/34)
#   T4. CLAUDE.md 总行数 ≤ 200 行 (跟 CLAUDE.md 治理 2.0 EPIC-159 联合)
#   T5. Rule 35 在 §3.1 位置 (Rule 34 之后, §4 之前)
#   T6. frame-task --self-test 仍 10/10 (无回归)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
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

echo "=== rule-35.test.sh (≥6 用例, EPIC-190) ==="

# ── T1: Rule 35 标题存在 ──
echo ""
echo "T1: CLAUDE.md 含 Rule 35 标题"
out=$(grep -E "^## 3\.1\. Rule 35" "$CLAUDE_MD")
if [ -n "$out" ]; then
    echo "  PASS: T1.1 Rule 35 标题存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T1.1 Rule 35 标题缺失"
    FAIL=$((FAIL + 1))
fi

# ── T2: 4 个 sub-rule ──
echo ""
echo "T2: Rule 35 含 4 个 sub-rule"
assert_contains "T2.1 Sprint 容量上限" "Sprint 容量上限" "$(cat $CLAUDE_MD)"
assert_contains "T2.2 0 超大任务" "0 超大任务" "$(cat $CLAUDE_MD)"
assert_contains "T2.3 时间盒 4-PR" "时间盒" "$(cat $CLAUDE_MD)"
assert_contains "T2.4 0 跨 Sprint 累积" "0 跨 Sprint 累积" "$(cat $CLAUDE_MD)"

# ── T3: 6 个现有 Rule 联合 ──
echo ""
echo "T3: Rule 35 跟 6 个现有 Rule 联合"
out=$(cat "$CLAUDE_MD")
assert_contains "T3.1 Rule 4 联合" "Rule 4 \\(4-branch" "$out"
assert_contains "T3.2 Rule 5 联合" "Rule 5 \\(DRY" "$out"
assert_contains "T3.3 Rule 8 联合" "Rule 8 \\(Rule-of-500" "$out"
assert_contains "T3.4 Rule 9 联合" "Rule 9 \\(KPI" "$out"
assert_contains "T3.5 Rule 13 联合" "Rule 13 \\(3 模式" "$out"
assert_contains "T3.6 Rule 34 联合" "Rule 34 \\(Bugfix" "$out"

# ── T4: 总行数 ≤ 200 ──
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

# ── T5: Rule 35 位置正确 (§3.1 Rule 34 之后, §4 之前) ──
echo ""
echo "T5: Rule 35 位置 (Rule 34 之后, §4 之前)"
r34_line=$(grep -n "^## 3\. Rule 34" "$CLAUDE_MD" | head -1 | cut -d: -f1)
r35_line=$(grep -n "^## 3\.1\. Rule 35" "$CLAUDE_MD" | head -1 | cut -d: -f1)
r4_line=$(grep -n "^## 4\. Branch" "$CLAUDE_MD" | head -1 | cut -d: -f1)
if [ -n "$r34_line" ] && [ -n "$r35_line" ] && [ -n "$r4_line" ]; then
    if [ "$r34_line" -lt "$r35_line" ] && [ "$r35_line" -lt "$r4_line" ]; then
        echo "  PASS: T5.1 Rule 35 ($r35_line) 在 Rule 34 ($r34_line) 之后 §4 ($r4_line) 之前"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T5.1 位置错 (R34=$r34_line R35=$r35_line §4=$r4_line)"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL: T5.1 行号解析失败"
    FAIL=$((FAIL + 1))
fi

# ── T6: frame-task self-test 仍 PASS ──
echo ""
echo "T6: frame-task --self-test 仍 10/10"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T6.1 self-test 10/10" "10/10" "$out"

# ── 总结 ──
echo ""
echo "=== rule-35.test.sh 总结 ==="
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