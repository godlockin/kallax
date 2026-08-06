#!/usr/bin/env bash
# tests/integration/lint-fix-shellcheck.test.sh — EPIC-191 shellcheck 修复合测
#
# 验证:
#   T1. scripts/frame-task.sh 不再含 KALLAX_ROOT (删了未使用变量)
#   T2. scripts/frame-task.sh 不再含 SCORE_SIMPLE_MIN (重复值已删)
#   T3. exit "$EXIT_PASS" 引号包裹 (SC2086 修)
#   T4. frame-task --self-test 仍 10/10 (无回归)
#   T5. frame-task 4 档阈值仍工作 (1+4+1 测试覆盖)
#   T6. shellcheck warnings 数量 ≤ 3 (含 SC2034 SCRIPT_DIR 误报)

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

assert_not_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -Eq "$pattern"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (不该含: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== lint-fix-shellcheck.test.sh (≥6 用例, EPIC-191) ==="

# ── T1: KALLAX_ROOT 删了 ──
echo ""
echo "T1: KALLAX_ROOT 删了 (SC2034 unused)"
assert_not_contains "T1.1 frame-task.sh 不再含 'KALLAX_ROOT='" "KALLAX_ROOT=" "$(cat $FRAME_TASK)"

# ── T2: SCORE_SIMPLE_MIN 删了 (重复值) ──
echo ""
echo "T2: SCORE_SIMPLE_MIN 删了 (重复 SCORE_TRIVIAL)"
assert_not_contains "T2.1 frame-task.sh 不再含 SCORE_SIMPLE_MIN" "SCORE_SIMPLE_MIN" "$(cat $FRAME_TASK)"

# ── T3: exit "$EXIT_PASS" 引号 ──
echo ""
echo "T3: SC2086 exit 引号包裹"
assert_contains "T3.1 exit \"\$EXIT_PASS\" 已加引号" 'exit "\$EXIT_PASS"' "$(cat $FRAME_TASK)"

# ── T4: self-test 10/10 ──
echo ""
echo "T4: frame-task --self-test 仍 10/10 (无回归)"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T4.1 self-test PASS" "10/10" "$out"

# ── T5: 4 档阈值仍工作 ──
echo ""
echo "T5: 4 档阈值仍工作"
assert_contains "T5.1 SCORE_TRIVIAL=2" "SCORE_TRIVIAL=2" "$(cat $FRAME_TASK)"
assert_contains "T5.2 SCORE_MEDIUM_MIN=5" "SCORE_MEDIUM_MIN=5" "$(cat $FRAME_TASK)"
assert_contains "T5.3 SCORE_COMPLEX_MIN=8" "SCORE_COMPLEX_MIN=8" "$(cat $FRAME_TASK)"

# ── T6: shellcheck warnings ≤ 3 ──
echo ""
echo "T6: shellcheck warnings 数量 ≤ 3"
if command -v shellcheck >/dev/null 2>&1; then
    warnings=$(shellcheck "$FRAME_TASK" 2>&1 | grep -c "warning\|error")
    if [ "$warnings" -le 3 ]; then
        echo "  PASS: T6.1 shellcheck warnings ≤ 3 (当前 $warnings)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T6.1 warnings > 3 (当前 $warnings)"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  SKIP: T6 shellcheck 未安装"
fi

# ── 总结 ──
echo ""
echo "=== lint-fix-shellcheck.test.sh 总结 ==="
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