#!/usr/bin/env bash
# tests/integration/check-rule-of-500-test.sh — TDD tests for Rule of 500 (EPIC-059-B)
# 跟 eket template/docs/MASTER-RULES.md §6 Rule 8 (Rule of 500) + Rule 9 (PR ~100 行) 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules 模式 一致)
#
# Test cases (5):
#   TC1: 净变更 100 行 → PASS (跟 EPIC-059-C PR ~100 行 联合, 期望 0 100 行 silent pass)
#   TC2: 净变更 500 行 → PASS (临界, 跟 eket 阈值 一致)
#   TC3: 净变更 600 行 → FAIL + 提示 'codemod or Approved-Large-PR-By' (跟 AC #3 联合)
#   TC4: 净变更 1000 行 → FAIL + 拒绝 (跟 eket Rule 8 '禁止逐行手改' 联合)
#   TC5: 净变更 2000 行 → FAIL + 拒绝 + 推荐 EPIC 拆分 (跟 AC #5 联合)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-059-A check-9-hard-rules-test.sh 模式 一致
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CHECK_SCRIPT="$KALLAX_ROOT/scripts/check-pr-size.sh"
readonly PRE_COMMIT="$KALLAX_ROOT/scripts/hooks/pre-commit"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
readonly TICKET_DIR="$KALLAX_ROOT/jira/tickets/EPIC-059-B"

# Constants (Rule 4: no magic numbers, name all)
readonly SMALL_PASS_THRESHOLD=100
readonly EKET_THRESHOLD=500
readonly CODEMOD_HINT_THRESHOLD=1000
readonly EPIC_SPLIT_THRESHOLD=1000

echo "=========================================="
echo "Rule of 500 — Integration Tests (5/5)"
echo "EPIC-059-B | 跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码"
echo "=========================================="
echo ""

# TDD red phase: verify script exists
if [ ! -f "$CHECK_SCRIPT" ]; then
    echo "FAIL: $CHECK_SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5

# bash 3.2 compat: use parallel variables instead of declare -A
TC1_PASS=0; TC1_FAIL=0
TC2_PASS=0; TC2_FAIL=0
TC3_PASS=0; TC3_FAIL=0
TC4_PASS=0; TC4_FAIL=0
TC5_PASS=0; TC5_FAIL=0
TC6_PASS=0; TC6_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); eval "TC${1}_PASS=\$((TC${1}_PASS+1))"; }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); eval "TC${1}_FAIL=\$((TC${1}_FAIL+1))"; }

# Helper: invoke the script's rule-of-500 evaluator for N lines
# Output format: status=PASS|FAIL reason=<message>
invoke_rule_of_500() {
    local lines="$1"
    bash "$CHECK_SCRIPT" --check-rule-of-500 --lines "$lines" 2>&1 || true
}

# ----------------------------------------
# TC1: 净变更 100 行 → PASS (跟 EPIC-059-C PR ~100 行 联合)
# ----------------------------------------
echo ">>> TC1: 净变更 100 行 → PASS — 跟 EPIC-059-C PR ~100 行 联合"
echo "=========================================="
TC1_RESULT=0

OUTPUT_100=$(invoke_rule_of_500 100)
if echo "$OUTPUT_100" | grep -qE "status=PASS"; then
    pass 1 "净变更 100 行 → PASS (跟 EPIC-059-C 联合)"
else
    fail 1 "净变更 100 行 → 非 PASS (output: $OUTPUT_100)"
    TC1_RESULT=1
fi

# 验证 exit code = 0 (pass 不阻止 commit)
EXIT_100=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 100 >/dev/null 2>&1; echo $?)
if [ "$EXIT_100" = "0" ]; then
    pass 1 "净变更 100 行 exit code = 0 (allow commit)"
else
    fail 1 "净变更 100 行 exit code = $EXIT_100 (期望 0)"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: 净变更 500 行 → PASS (临界, 跟 eket 阈值 一致)
# ----------------------------------------
echo ">>> TC2: 净变更 500 行 → PASS — 临界, 跟 eket 阈值 一致"
echo "=========================================="
TC2_RESULT=0

OUTPUT_500=$(invoke_rule_of_500 500)
if echo "$OUTPUT_500" | grep -qE "status=PASS"; then
    pass 2 "净变更 500 行 → PASS (临界, 跟 eket MASTER-RULES.md §6 Rule 9 一致)"
else
    fail 2 "净变更 500 行 → 非 PASS (output: $OUTPUT_500)"
    TC2_RESULT=1
fi

# 验证 ≤ 500 行 都 pass, 边界检查
OUTPUT_499=$(invoke_rule_of_500 499)
if echo "$OUTPUT_499" | grep -qE "status=PASS"; then
    pass 2 "净变更 499 行 → PASS (临界前, ≤500 全 pass)"
else
    fail 2 "净变更 499 行 → 非 PASS"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: 净变更 600 行 → FAIL + 提示 'codemod or Approved-Large-PR-By'
# ----------------------------------------
echo ">>> TC3: 净变更 600 行 → FAIL + 提示 codemod or Approved-Large-PR-By"
echo "=========================================="
TC3_RESULT=0

OUTPUT_600=$(invoke_rule_of_500 600)
if echo "$OUTPUT_600" | grep -qE "status=FAIL"; then
    pass 3 "净变更 600 行 → FAIL (跟 eket Rule 8 联合)"
else
    fail 3 "净变更 600 行 → 非 FAIL (output: $OUTPUT_600)"
    TC3_RESULT=1
fi

# 验证提示含 codemod 或 Approved-Large-PR-By
if echo "$OUTPUT_600" | grep -qiE "codemod"; then
    pass 3 "净变更 600 行 提示含 'codemod' (跟 eket 模式 一致)"
else
    fail 3 "净变更 600 行 缺 'codemod' 提示 (output: $OUTPUT_600)"
    TC3_RESULT=1
fi

if echo "$OUTPUT_600" | grep -qiE "Approved-Large-PR-By"; then
    pass 3 "净变更 600 行 提示含 'Approved-Large-PR-By' (跟 eket MASTER-RULES.md §6 Rule 8 一致)"
else
    fail 3 "净变更 600 行 缺 'Approved-Large-PR-By' 提示 (output: $OUTPUT_600)"
    TC3_RESULT=1
fi

# 验证 exit code != 0 (阻止 commit)
EXIT_600=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 600 >/dev/null 2>&1; echo $?)
if [ "$EXIT_600" != "0" ]; then
    pass 3 "净变更 600 行 exit code = $EXIT_600 (拒绝 commit)"
else
    fail 3 "净变更 600 行 exit code = 0 (期望 ≠0)"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: 净变更 1000 行 → FAIL + 拒绝 (跟 eket Rule 8 联合)
# ----------------------------------------
echo ">>> TC4: 净变更 1000 行 → FAIL + 拒绝 — 跟 eket Rule 8 联合"
echo "=========================================="
TC4_RESULT=0

OUTPUT_1000=$(invoke_rule_of_500 1000)
if echo "$OUTPUT_1000" | grep -qE "status=FAIL"; then
    pass 4 "净变更 1000 行 → FAIL (跟 eket Rule 8 '禁止逐行手改' 联合)"
else
    fail 4 "净变更 1000 行 → 非 FAIL (output: $OUTPUT_1000)"
    TC4_RESULT=1
fi

# 验证拒绝信息
if echo "$OUTPUT_1000" | grep -qiE "reject|拒绝|拒绝 commit"; then
    pass 4 "净变更 1000 行 含拒绝信息"
else
    fail 4 "净变更 1000 行 缺拒绝信息 (output: $OUTPUT_1000)"
    TC4_RESULT=1
fi

EXIT_1000=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 1000 >/dev/null 2>&1; echo $?)
if [ "$EXIT_1000" != "0" ]; then
    pass 4 "净变更 1000 行 exit code = $EXIT_1000 (拒绝 commit)"
else
    fail 4 "净变更 1000 行 exit code = 0 (期望 ≠0)"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: 净变更 2000 行 → FAIL + 拒绝 + 推荐 EPIC 拆分
# ----------------------------------------
echo ">>> TC5: 净变更 2000 行 → FAIL + 拒绝 + 推荐 EPIC 拆分"
echo "=========================================="
TC5_RESULT=0

OUTPUT_2000=$(invoke_rule_of_500 2000)
if echo "$OUTPUT_2000" | grep -qE "status=FAIL"; then
    pass 5 "净变更 2000 行 → FAIL"
else
    fail 5 "净变更 2000 行 → 非 FAIL (output: $OUTPUT_2000)"
    TC5_RESULT=1
fi

# 验证推荐 EPIC 拆分
if echo "$OUTPUT_2000" | grep -qiE "EPIC 拆分|EPIC split|拆分 EPIC"; then
    pass 5 "净变更 2000 行 推荐 EPIC 拆分 (跟 AC #5 联合)"
else
    fail 5 "净变更 2000 行 缺 EPIC 拆分推荐 (output: $OUTPUT_2000)"
    TC5_RESULT=1
fi

EXIT_2000=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 2000 >/dev/null 2>&1; echo $?)
if [ "$EXIT_2000" != "0" ]; then
    pass 5 "净变更 2000 行 exit code = $EXIT_2000 (拒绝 commit)"
else
    fail 5 "净变更 2000 行 exit code = 0 (期望 ≠0)"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# TC6 (bonus): pre-commit 集成 + CLAUDE.md 章节 验证
# ----------------------------------------
echo ">>> TC6 (bonus): pre-commit 集成 + CLAUDE.md 'Rule of 500' 章节"
echo "=========================================="
TC6_RESULT=0

# 验证 pre-commit 调用 check-pr-size.sh --check-rule-of-500
if [ -f "$PRE_COMMIT" ] && grep -qE "check-pr-size\.sh" "$PRE_COMMIT" && grep -qE "\-\-check-rule-of-500" "$PRE_COMMIT"; then
    pass 6 "pre-commit 调用 scripts/check-pr-size.sh --check-rule-of-500 (跟 Rule 13 decision-gate 联合)"
else
    fail 6 "pre-commit 缺 check-pr-size.sh --check-rule-of-500 集成"
    TC6_RESULT=1
fi

# 验证 CLAUDE.md 含 "Rule of 500" 章节
if grep -qE "Rule of 500" "$CLAUDE_MD"; then
    SECTION_LINE=$(grep -n "Rule of 500" "$CLAUDE_MD" | head -1 | cut -d: -f1 || echo "0")
    pass 6 "CLAUDE.md 含 'Rule of 500' 章节 (line $SECTION_LINE, 跟 EPIC-059-A 联合)"
else
    fail 6 "CLAUDE.md 缺 'Rule of 500' 章节"
    TC6_RESULT=1
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
TOTAL=$((TOTAL + 1))
if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ Rule of 500 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS (100.0%)"
    echo "=========================================="
    exit 0
else
    echo "✗ Rule of 500 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS"
    echo "=========================================="
    exit 1
fi