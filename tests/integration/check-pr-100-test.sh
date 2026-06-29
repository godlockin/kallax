#!/usr/bin/env bash
# tests/integration/check-pr-100-test.sh — TDD tests for PR ~100 行上限 (EPIC-059-C)
# 跟 eket template/docs/MASTER-RULES.md §6 Rule 9 联合, 借方法论 不借代码
# 跟 EPIC-059-A 5 levels 模式 + EPIC-059-B Rule of 500 模式 一致
#
# Test cases (5):
#   TC1: PR 50 行   → PASS silent (跟 EPIC-059-C 联合)
#   TC2: PR 100 行  → PASS 临界 (≤100 silent)
#   TC3: PR 200 行  → WARN (100-300 档)
#   TC4: PR 400 行  → WARN-STRONG (300-500 档)
#   TC5: PR 600 行  → FAIL (跟 EPIC-059-B Rule of 500 联合, >500 fail)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-059-A check-9-hard-rules-test.sh 模式 一致
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CHECK_SCRIPT="$KALLAX_ROOT/scripts/check-pr-size.sh"
readonly WORKFLOW_FILE="$KALLAX_ROOT/.github/workflows/pr-size-check.yml"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"

# Constants (Rule 4: no magic numbers, name all)
readonly PR_100_SILENT_PASS=100
readonly PR_100_WARN_THRESHOLD=300
readonly PR_100_WARN_STRONG_THRESHOLD=500
readonly RULE_OF_500_FAIL_THRESHOLD=500

echo "=========================================="
echo "PR ~100 行上限 — Integration Tests (5/5)"
echo "EPIC-059-C | 跟 eket MASTER-RULES.md §6 Rule 9 联合, 互为 EPIC-059-B 互补"
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

pass() { echo "  [PASS] $1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Helper: invoke the script's pr-100 evaluator for N lines
# Output format: status=PASS|WARN|WARN-STRONG|FAIL reason=<message>
invoke_pr_100() {
    local lines="$1"
    bash "$CHECK_SCRIPT" --check-pr-100 --lines "$lines" 2>&1 || true
}

# ----------------------------------------
# TC1: PR 50 行 → PASS silent (跟 EPIC-059-C 联合)
# ----------------------------------------
echo ">>> TC1: PR 50 行 → PASS silent — 跟 EPIC-059-C PR ~100 行上限 联合"
echo "=========================================="
TC1_RESULT=0

OUTPUT_50=$(invoke_pr_100 50)
if echo "$OUTPUT_50" | grep -qE "status=PASS"; then
    pass TC1 "PR 50 行 → PASS (silent, ≤100 跟 eket Rule 9 silent 联合)"
else
    fail TC1 "PR 50 行 → 非 PASS (output: $OUTPUT_50)"
    TC1_RESULT=1
fi

# 验证 exit code = 0 (pass 不阻止 commit)
EXIT_50=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 50 >/dev/null 2>&1; echo $?)
if [ "$EXIT_50" = "0" ]; then
    pass TC1 "PR 50 行 exit code = 0 (allow commit)"
else
    fail TC1 "PR 50 行 exit code = $EXIT_50 (期望 0)"
    TC1_RESULT=1
fi

# 验证 silent tier
if echo "$OUTPUT_50" | grep -qiE "silent"; then
    pass TC1 "PR 50 行 tier=silent (≤100 silent pass)"
else
    fail TC1 "PR 50 行 tier 不含 silent (output: $OUTPUT_50)"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: PR 100 行 → PASS 临界 (≤100 silent)
# ----------------------------------------
echo ">>> TC2: PR 100 行 → PASS 临界 — ≤100 silent, 跟 eket Rule 9 阈值 一致"
echo "=========================================="
TC2_RESULT=0

OUTPUT_100=$(invoke_pr_100 100)
if echo "$OUTPUT_100" | grep -qE "status=PASS"; then
    pass TC2 "PR 100 行 → PASS (临界, ≤100 silent 跟 eket Rule 9 阈值 一致)"
else
    fail TC2 "PR 100 行 → 非 PASS (output: $OUTPUT_100)"
    TC2_RESULT=1
fi

# 验证 exit code = 0
EXIT_100=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 100 >/dev/null 2>&1; echo $?)
if [ "$EXIT_100" = "0" ]; then
    pass TC2 "PR 100 行 exit code = 0 (临界允许 commit)"
else
    fail TC2 "PR 100 行 exit code = $EXIT_100 (期望 0)"
    TC2_RESULT=1
fi

# 验证 PR 100 行临界 silent
if echo "$OUTPUT_100" | grep -qiE "silent"; then
    pass TC2 "PR 100 行 tier=silent (≤100 silent)"
else
    fail TC2 "PR 100 行 tier 不含 silent (output: $OUTPUT_100)"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: PR 200 行 → WARN (100-300 档)
# ----------------------------------------
echo ">>> TC3: PR 200 行 → WARN — 100-300 档 跟 Rule 9 阈值 一致"
echo "=========================================="
TC3_RESULT=0

OUTPUT_200=$(invoke_pr_100 200)
if echo "$OUTPUT_200" | grep -qE "status=WARN\b"; then
    pass TC3 "PR 200 行 → WARN (100-300 档, 跟 eket Rule 9 阈值 一致)"
else
    fail TC3 "PR 200 行 → 非 WARN (output: $OUTPUT_200)"
    TC3_RESULT=1
fi

# 验证 exit code = 0 (warn 不阻止 commit, 仅警告)
EXIT_200=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 200 >/dev/null 2>&1; echo $?)
if [ "$EXIT_200" = "0" ]; then
    pass TC3 "PR 200 行 exit code = 0 (warn 不阻止 commit)"
else
    fail TC3 "PR 200 行 exit code = $EXIT_200 (warn 应不阻止 commit)"
    TC3_RESULT=1
fi

# 验证提示建议拆分
if echo "$OUTPUT_200" | grep -qiE "拆分|split"; then
    pass TC3 "PR 200 行 含拆分建议 (跟 EPIC-059-C PR ~100 联合)"
else
    fail TC3 "PR 200 行 缺拆分建议 (output: $OUTPUT_200)"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: PR 400 行 → WARN-STRONG (300-500 档)
# ----------------------------------------
echo ">>> TC4: PR 400 行 → WARN-STRONG — 300-500 档"
echo "=========================================="
TC4_RESULT=0

OUTPUT_400=$(invoke_pr_100 400)
if echo "$OUTPUT_400" | grep -qE "status=(WARN-STRONG|FAIL)"; then
    pass TC4 "PR 400 行 → WARN-STRONG/FAIL (300-500 档)"
else
    fail TC4 "PR 400 行 → 非 WARN-STRONG/FAIL (output: $OUTPUT_400)"
    TC4_RESULT=1
fi

# 验证 WARN-STRONG 不阻止 commit (exit 0) 或 阻止 (exit 1)
EXIT_400=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 400 >/dev/null 2>&1; echo $?)
if [ "$EXIT_400" = "0" ]; then
    pass TC4 "PR 400 行 exit code = 0 (WARN-STRONG 不阻止 commit)"
elif [ "$EXIT_400" = "1" ]; then
    pass TC4 "PR 400 行 exit code = 1 (WARN-STRONG 阻止 commit, 跟 Rule 13 decision-gate 联合)"
else
    fail TC4 "PR 400 行 exit code = $EXIT_400 (期望 0 或 1)"
    TC4_RESULT=1
fi

# 验证强警告提示 (含 codemod 或 Approved-Large-PR-By)
if echo "$OUTPUT_400" | grep -qiE "codemod|Approved-Large-PR-By|warn-strong"; then
    pass TC4 "PR 400 行 含强警告提示 (codemod / Approved-Large-PR-By)"
else
    fail TC4 "PR 400 行 缺强警告提示 (output: $OUTPUT_400)"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: PR 600 行 → FAIL (跟 EPIC-059-B Rule of 500 联合, >500 fail)
# ----------------------------------------
echo ">>> TC5: PR 600 行 → FAIL — 跟 EPIC-059-B Rule of 500 联合, >500 fail"
echo "=========================================="
TC5_RESULT=0

OUTPUT_600=$(invoke_pr_100 600)
if echo "$OUTPUT_600" | grep -qE "status=FAIL"; then
    pass TC5 "PR 600 行 → FAIL (跟 EPIC-059-B Rule of 500 联合, >500 fail)"
else
    fail TC5 "PR 600 行 → 非 FAIL (output: $OUTPUT_600)"
    TC5_RESULT=1
fi

# 验证 exit code = 1 (阻止 commit)
EXIT_600=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 600 >/dev/null 2>&1; echo $?)
if [ "$EXIT_600" = "1" ]; then
    pass TC5 "PR 600 行 exit code = 1 (拒绝 commit, 跟 Rule of 500 联合)"
else
    fail TC5 "PR 600 行 exit code = $EXIT_600 (期望 1)"
    TC5_RESULT=1
fi

# 验证拒绝信息 (跟 EPIC-059-B Rule of 500 一致)
if echo "$OUTPUT_600" | grep -qiE "codemod|拒绝|split|拆分"; then
    pass TC5 "PR 600 行 含拒绝信息 (codemod/split, 跟 Rule of 500 联合)"
else
    fail TC5 "PR 600 行 缺拒绝信息 (output: $OUTPUT_600)"
    TC5_RESULT=1
fi

# 跟 Rule of 500 联合验证 (--check-rule-of-500 也 fail)
OUTPUT_600_R500=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 600 2>&1 || true)
if echo "$OUTPUT_600_R500" | grep -qE "status=FAIL"; then
    pass TC5 "PR 600 行 Rule of 500 也 FAIL (PR 100 跟 Rule of 500 互为 互补)"
else
    fail TC5 "PR 600 行 Rule of 500 未 FAIL (互为 互补 验证 失败)"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# 互补 验证: PR ~100 跟 Rule of 500 一起 work (互为 互补)
# ----------------------------------------
echo ">>> 互补 验证: PR ~100 跟 Rule of 500 一起 work"
echo "=========================================="

# PR 100 行: PR ~100 PASS + Rule of 500 PASS (silent tier 互为 一致)
OUTPUT_100_BOTH=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 100 2>&1 || true)
OUTPUT_100_R500=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 100 2>&1 || true)
if echo "$OUTPUT_100_BOTH" | grep -qE "status=PASS" && echo "$OUTPUT_100_R500" | grep -qE "status=PASS"; then
    pass "互为" "PR 100 行: PR ~100 PASS + Rule of 500 PASS (互为 互补 100 行临界 一致)"
else
    fail "互为" "PR 100 行: PR ~100/R500 不一致 (互为 互补 失败)"
fi

# PR 400 行: PR ~100 WARN-STRONG + Rule of 500 PASS (400 < 500 still pass Rule of 500)
OUTPUT_400_BOTH=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 400 2>&1 || true)
OUTPUT_400_R500=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 400 2>&1 || true)
if echo "$OUTPUT_400_BOTH" | grep -qE "status=(WARN-STRONG|FAIL)" && echo "$OUTPUT_400_R500" | grep -qE "status=PASS"; then
    pass "互为" "PR 400 行: PR ~100 WARN-STRONG + Rule of 500 PASS (粒度 分离: PR 粒度 严, 净变更 粒度 松)"
else
    fail "互为" "PR 400 行: PR ~100/R500 不一致 (output: $OUTPUT_400_BOTH / $OUTPUT_400_R500)"
fi

# PR 600 行: PR ~100 FAIL + Rule of 500 FAIL (联合 fail)
OUTPUT_600_BOTH=$(bash "$CHECK_SCRIPT" --check-pr-100 --lines 600 2>&1 || true)
OUTPUT_600_R500=$(bash "$CHECK_SCRIPT" --check-rule-of-500 --lines 600 2>&1 || true)
if echo "$OUTPUT_600_BOTH" | grep -qE "status=FAIL" && echo "$OUTPUT_600_R500" | grep -qE "status=FAIL"; then
    pass "互为" "PR 600 行: PR ~100 FAIL + Rule of 500 FAIL (联合 fail, 跟 EPIC-059-B 互为 互补)"
else
    fail "互为" "PR 600 行: PR ~100/R500 不一致 (互为 互补 失败)"
fi
echo ""

# ----------------------------------------
# 集成 验证: GitHub Actions workflow + CLAUDE.md Rule 9 段
# ----------------------------------------
echo ">>> 集成 验证: GitHub Actions + CLAUDE.md Rule 9"
echo "=========================================="

# 验证 GitHub Actions workflow 包含 PR ~100 行 检查
if [ -f "$WORKFLOW_FILE" ] && grep -qE "PR.*100|pr-100|净变更" "$WORKFLOW_FILE"; then
    pass "集成" ".github/workflows/pr-size-check.yml 含 PR ~100 行 检查"
else
    fail "集成" ".github/workflows/pr-size-check.yml 缺 PR ~100 行 检查"
fi

# 验证 CLAUDE.md 含 PR ~100 行 章节
if grep -qE "PR ~100|PR 100 行|PR.*100.*行.*上限" "$CLAUDE_MD"; then
    SECTION_LINE=$(grep -nE "PR ~100|PR 100 行|PR.*100.*行.*上限" "$CLAUDE_MD" | head -1 | cut -d: -f1 || echo "0")
    pass "集成" "CLAUDE.md 含 PR ~100 行 章节 (line $SECTION_LINE, 跟 Rule 9 file:line 联合)"
else
    fail "集成" "CLAUDE.md 缺 PR ~100 行 章节"
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ PR ~100 行上限 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS (100.0%)"
    echo "=========================================="
    exit 0
else
    echo "✗ PR ~100 行上限 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS"
    echo "=========================================="
    exit 1
fi