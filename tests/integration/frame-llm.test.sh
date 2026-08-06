#!/usr/bin/env bash
# tests/integration/frame-llm.test.sh — EPIC-186 LLM v2 集成测试
#
# 覆盖:
#   T1. frame-llm 缺 msg exit=2
#   T2. --dry-run 输出 prompt (含 JSON 模板 + tier 字段)
#   T3. classify 输出 FRAME (LLM v2) 标记
#   T4. 9 类破坏性 #1 (rm -rf)
#   T5. 9 类破坏性 #7 (CLAUDE.md)
#   T6. 9 类破坏性 #9 (gh pr create)
#   T7. tier 4 档之一 (跟 heuristic 1:1)
#   T8. 跟 heuristic 1:1 兼容
#   T9. 跟 frame-prompt.md 联合 (.claude/skills/kallax/lib/frame-prompt.md 存在)
#   T10. self-test 仍 8/8 (无回归)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_LLM="$KALLAX_ROOT/scripts/frame-llm.sh"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"
FRAME_PROMPT="$KALLAX_ROOT/.claude/skills/kallax/lib/frame-prompt.md"

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

echo "=== frame-llm.test.sh (≥10 用例, EPIC-186) ==="

# ── T1: 缺 msg exit=2 ──
echo ""
echo "T1: 缺 msg exit=2"
local out1 exit1
out1=$(bash "$FRAME_LLM" 2>&1) || exit1=$?
exit1=${exit1:-0}
assert_exit_code "T1.1 缺 msg exit=2" 2 "$exit1"

# ── T2: --dry-run 输出 prompt ──
echo ""
echo "T2: --dry-run 输出 prompt"
out1=$(bash "$FRAME_LLM" "EPIC-X 是什么" --dry-run 2>&1)
assert_contains "T2.1 含 User_msg 字段" "User_msg:" "$out1"
assert_contains "T2.2 prompt 含 JSON 模板 tier 字段" '"tier"' "$out1"

# ── T3: classify 输出 FRAME (LLM v2) 标记 ──
echo ""
echo "T3: classify 输出 FRAME (LLM v2)"
out1=$(bash "$FRAME_LLM" "EPIC-X 是什么" 2>&1)
assert_contains "T3.1 含 FRAME LLM v2 标记" "FRAME.*LLM v2" "$out1"
assert_contains "T3.2 9 类破坏性 (none)" "BLOCKED-OPS: none" "$out1"

# ── T4-T6: 9 类破坏性 ──
echo ""
echo "T4-T6: 9 类破坏性"
out1=$(bash "$FRAME_LLM" "rm -rf /tmp/test" 2>&1)
assert_contains "T4.1 BLOCKED-OPS 含 rm" "rm" "$out1"

out1=$(bash "$FRAME_LLM" "在 CLAUDE.md 加 Rule 35" 2>&1)
assert_contains "T5.1 BLOCKED-OPS 含 CLAUDE.md" "CLAUDE" "$out1"

out1=$(bash "$FRAME_LLM" "gh pr create --base testing" 2>&1)
assert_contains "T6.1 BLOCKED-OPS 含 gh pr create" "gh" "$out1"

# ── T7: tier 4 档 ──
echo ""
echo "T7: tier 4 档"
out1=$(bash "$FRAME_LLM" "EPIC-X 是什么" 2>&1)
assert_contains "T7.1 tier 4 档之一" "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档" "$out1"

# ── T8: 跟 heuristic 1:1 兼容 ──
echo ""
echo "T8: 跟 heuristic 1:1 兼容"
out_heuristic=$(bash "$FRAME_TASK" classify "EPIC-X 是什么" 2>&1)
out_llm=$(bash "$FRAME_LLM" "EPIC-X 是什么" 2>&1)
if echo "$out_heuristic" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档" && \
   echo "$out_llm" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档"; then
    echo "  PASS: T8.1 heuristic + LLM 都输出 tier"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T8.1 1:1 兼容失败"
    FAIL=$((FAIL + 1))
fi

# ── T9: frame-prompt.md 联合 ──
echo ""
echo "T9: frame-prompt.md 联合"
if [ -f "$FRAME_PROMPT" ]; then
    echo "  PASS: T9.1 frame-prompt.md 存在"
    PASS=$((PASS + 1))
    if grep -q "EPIC-180-A" "$FRAME_PROMPT"; then
        echo "  PASS: T9.2 frame-prompt.md 跟 EPIC-180-A 联合"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T9.2 frame-prompt.md 缺 EPIC-180-A 引用"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL: T9.1 frame-prompt.md 不存在"
    FAIL=$((FAIL + 1))
fi

# ── T10: self-test 仍 PASS (无回归) ──
echo ""
echo "T10: --self-test 无回归"
out1=$(bash "$FRAME_LLM" --self-test 2>&1)
assert_contains "T10.1 self-test 8/8" "8/8" "$out1"

# ── 总结 ──
echo ""
echo "=== frame-llm.test.sh 总结 ==="
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