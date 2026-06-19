#!/usr/bin/env bash
# tests/integration/post-process-test.sh — TDD tests for Post-Process 11 步骤 (EPIC-059-E)
# 跟 eket template/docs/MASTER-RULES.md §10 4 步骤 升级 联合
# 跟 PHASE review 10 累计 联合 (PHASE-005 → PHASE-014)
# 借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules + EPIC-059-B Rule of 500 + EPIC-059-C PR ~100 模式 一致)
#
# Test cases (5):
#   TC1: 11 步骤 全部 满足 → 11/11 PASS
#   TC2: GLOSSARY 未 更新 → 10/11 PASS + 1 FAIL (step 5)
#   TC3: ACCUMULATED-LESSONS 未 更新 → 10/11 PASS + 1 FAIL (step 7)
#   TC4: 分支 未 同步 → 10/11 PASS + 1 FAIL (step 2)
#   TC5: 全部 缺失 → 0/11 PASS
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-059-A check-9-hard-rules-test.sh + EPIC-059-B check-rule-of-500-test.sh + EPIC-059-C check-pr-100-test.sh 模式 一致

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly POST_PROCESS_SCRIPT="$KALLAX_ROOT/scripts/post-process.sh"
readonly PHASE_INDEX_FILE="$KALLAX_ROOT/docs/PHASE-INDEX.md"
readonly SKILL_FILE="$KALLAX_ROOT/.claude/skills/kallax/SKILL.md"

# Constants (Rule 4: no magic numbers, name all)
readonly TOTAL_STEPS=11
readonly TOTAL_TESTS=5

echo "=========================================="
echo "Post-Process 11 步骤 — Integration Tests (5/5)"
echo "EPIC-059-E | 跟 eket MASTER-RULES.md §10 4 步骤 升级 联合"
echo "=========================================="
echo ""

# TDD red phase: verify script exists
if [ ! -f "$POST_PROCESS_SCRIPT" ]; then
    echo "FAIL: $POST_PROCESS_SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Helper: invoke post-process.sh --check-all --mock-scenario <name>
invoke_scenario() {
    local scenario="$1"
    bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario "$scenario" 2>&1 || true
}

# Helper: count PASS/FAIL lines from output
count_pass() {
    local output="$1"
    echo "$output" | grep -cE "^status=PASS" || true
}

count_fail() {
    local output="$1"
    echo "$output" | grep -cE "^status=FAIL" || true
}

# ----------------------------------------
# TC1: 11 步骤 全部 满足 → 11/11 PASS
# ----------------------------------------
echo ">>> TC1: 11 步骤 全部 满足 → 11/11 PASS"
echo "=========================================="
TC1_RESULT=0

OUTPUT_1=$(invoke_scenario "all-pass")
PASS_NUM_1=$(count_pass "$OUTPUT_1")
FAIL_NUM_1=$(count_fail "$OUTPUT_1")

if [ "$PASS_NUM_1" -eq "$TOTAL_STEPS" ] && [ "$FAIL_NUM_1" -eq 0 ]; then
    pass TC1 "11 步骤 全部 PASS (${PASS_NUM_1}/${TOTAL_STEPS}, 跟 mock 1 联合)"
else
    fail TC1 "11 步骤 不全 PASS (${PASS_NUM_1} PASS, ${FAIL_NUM_1} FAIL)"
    TC1_RESULT=1
fi

# 验证 Summary 行 11/11
if echo "$OUTPUT_1" | grep -qE "Summary: ${TOTAL_STEPS}/${TOTAL_STEPS} PASS"; then
    pass TC1 "Summary 行 ${TOTAL_STEPS}/${TOTAL_STEPS} PASS (跟 mock 1 KPI 联合)"
else
    fail TC1 "Summary 行 不匹配 ${TOTAL_STEPS}/${TOTAL_STEPS} (mock 1 KPI 失败)"
    TC1_RESULT=1
fi

# 验证 scenario exit code = 0
EXIT_1=$(bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario all-pass >/dev/null 2>&1; echo $?)
if [ "$EXIT_1" = "0" ]; then
    pass TC1 "scenario all-pass exit code = 0 (mock 1 通过)"
else
    fail TC1 "scenario all-pass exit code = $EXIT_1 (期望 0)"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: GLOSSARY 未 更新 → 10/11 PASS + 1 FAIL (step 5)
# ----------------------------------------
echo ">>> TC2: GLOSSARY 未 更新 → 10/11 PASS + 1 FAIL"
echo "=========================================="
TC2_RESULT=0

OUTPUT_2=$(invoke_scenario "glossary-missing")
PASS_NUM_2=$(count_pass "$OUTPUT_2")
FAIL_NUM_2=$(count_fail "$OUTPUT_2")

if [ "$PASS_NUM_2" -eq 10 ] && [ "$FAIL_NUM_2" -eq 1 ]; then
    pass TC2 "GLOSSARY 缺失: 10/11 PASS + 1 FAIL (${PASS_NUM_2} PASS, ${FAIL_NUM_2} FAIL, 跟 mock 2 联合)"
else
    fail TC2 "GLOSSARY 缺失: 计数 不符 (${PASS_NUM_2} PASS, ${FAIL_NUM_2} FAIL, 期望 10/1)"
    TC2_RESULT=1
fi

# 验证 FAIL 在 step 5 (GLOSSARY)
if echo "$OUTPUT_2" | grep -qE "status=FAIL step=5 name=glossary_update"; then
    pass TC2 "FAIL 落在 step=5 (glossary_update, 跟 mock 2 联合)"
else
    fail TC2 "FAIL 不在 step=5 (mock 2 验证 失败)"
    TC2_RESULT=1
fi

# 验证 Summary 行 10/11
if echo "$OUTPUT_2" | grep -qE "Summary: 10/${TOTAL_STEPS} PASS"; then
    pass TC2 "Summary 行 10/${TOTAL_STEPS} PASS (mock 2 KPI 精确)"
else
    fail TC2 "Summary 行 不匹配 10/${TOTAL_STEPS}"
    TC2_RESULT=1
fi

# 验证 scenario exit code = 1 (有 FAIL)
EXIT_2=$(bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario glossary-missing >/dev/null 2>&1; echo $?)
if [ "$EXIT_2" = "1" ]; then
    pass TC2 "scenario glossary-missing exit code = 1 (mock 2 fail 拒绝)"
else
    fail TC2 "scenario glossary-missing exit code = $EXIT_2 (期望 1)"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: ACCUMULATED-LESSONS 未 更新 → 10/11 PASS + 1 FAIL (step 7)
# ----------------------------------------
echo ">>> TC3: ACCUMULATED-LESSONS 未 更新 → 10/11 PASS + 1 FAIL"
echo "=========================================="
TC3_RESULT=0

OUTPUT_3=$(invoke_scenario "accumulated-missing")
PASS_NUM_3=$(count_pass "$OUTPUT_3")
FAIL_NUM_3=$(count_fail "$OUTPUT_3")

if [ "$PASS_NUM_3" -eq 10 ] && [ "$FAIL_NUM_3" -eq 1 ]; then
    pass TC3 "ACCUMULATED 缺失: 10/11 PASS + 1 FAIL (跟 mock 3 联合)"
else
    fail TC3 "ACCUMULATED 缺失: 计数 不符 (${PASS_NUM_3} PASS, ${FAIL_NUM_3} FAIL, 期望 10/1)"
    TC3_RESULT=1
fi

# 验证 FAIL 在 step 7
if echo "$OUTPUT_3" | grep -qE "status=FAIL step=7 name=accumulated_lessons_update"; then
    pass TC3 "FAIL 落在 step=7 (accumulated_lessons_update, 跟 mock 3 联合)"
else
    fail TC3 "FAIL 不在 step=7 (mock 3 验证 失败)"
    TC3_RESULT=1
fi

# 验证 Summary 行 10/11
if echo "$OUTPUT_3" | grep -qE "Summary: 10/${TOTAL_STEPS} PASS"; then
    pass TC3 "Summary 行 10/${TOTAL_STEPS} PASS (mock 3 KPI 精确)"
else
    fail TC3 "Summary 行 不匹配 10/${TOTAL_STEPS}"
    TC3_RESULT=1
fi

# 验证 scenario exit code = 1
EXIT_3=$(bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario accumulated-missing >/dev/null 2>&1; echo $?)
if [ "$EXIT_3" = "1" ]; then
    pass TC3 "scenario accumulated-missing exit code = 1 (mock 3 fail 拒绝)"
else
    fail TC3 "scenario accumulated-missing exit code = $EXIT_3 (期望 1)"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: 分支 未 同步 → 10/11 PASS + 1 FAIL (step 2)
# ----------------------------------------
echo ">>> TC4: 分支 未 同步 → 10/11 PASS + 1 FAIL"
echo "=========================================="
TC4_RESULT=0

OUTPUT_4=$(invoke_scenario "branch-not-synced")
PASS_NUM_4=$(count_pass "$OUTPUT_4")
FAIL_NUM_4=$(count_fail "$OUTPUT_4")

if [ "$PASS_NUM_4" -eq 10 ] && [ "$FAIL_NUM_4" -eq 1 ]; then
    pass TC4 "分支 未 同步: 10/11 PASS + 1 FAIL (跟 mock 4 联合)"
else
    fail TC4 "分支 未 同步: 计数 不符 (${PASS_NUM_4} PASS, ${FAIL_NUM_4} FAIL, 期望 10/1)"
    TC4_RESULT=1
fi

# 验证 FAIL 在 step 2 (branch_sync)
if echo "$OUTPUT_4" | grep -qE "status=FAIL step=2 name=branch_sync"; then
    pass TC4 "FAIL 落在 step=2 (branch_sync, 跟 mock 4 联合)"
else
    fail TC4 "FAIL 不在 step=2 (mock 4 验证 失败)"
    TC4_RESULT=1
fi

# 验证 Summary 行 10/11
if echo "$OUTPUT_4" | grep -qE "Summary: 10/${TOTAL_STEPS} PASS"; then
    pass TC4 "Summary 行 10/${TOTAL_STEPS} PASS (mock 4 KPI 精确)"
else
    fail TC4 "Summary 行 不匹配 10/${TOTAL_STEPS}"
    TC4_RESULT=1
fi

# 验证 scenario exit code = 1
EXIT_4=$(bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario branch-not-synced >/dev/null 2>&1; echo $?)
if [ "$EXIT_4" = "1" ]; then
    pass TC4 "scenario branch-not-synced exit code = 1 (mock 4 fail 拒绝)"
else
    fail TC4 "scenario branch-not-synced exit code = $EXIT_4 (期望 1)"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: 全部 缺失 → 0/11 PASS
# ----------------------------------------
echo ">>> TC5: 全部 缺失 → 0/11 PASS"
echo "=========================================="
TC5_RESULT=0

OUTPUT_5=$(invoke_scenario "all-missing")
PASS_NUM_5=$(count_pass "$OUTPUT_5")
FAIL_NUM_5=$(count_fail "$OUTPUT_5")

if [ "$PASS_NUM_5" -eq 0 ] && [ "$FAIL_NUM_5" -eq "$TOTAL_STEPS" ]; then
    pass TC5 "全部 缺失: 0/11 PASS (跟 mock 5 联合)"
else
    fail TC5 "全部 缺失: 计数 不符 (${PASS_NUM_5} PASS, ${FAIL_NUM_5} FAIL, 期望 0/11)"
    TC5_RESULT=1
fi

# 验证 Summary 行 0/11
if echo "$OUTPUT_5" | grep -qE "Summary: 0/${TOTAL_STEPS} PASS"; then
    pass TC5 "Summary 行 0/${TOTAL_STEPS} PASS (mock 5 KPI 精确)"
else
    fail TC5 "Summary 行 不匹配 0/${TOTAL_STEPS}"
    TC5_RESULT=1
fi

# 验证 scenario exit code = 1 (全 FAIL)
EXIT_5=$(bash "$POST_PROCESS_SCRIPT" --check-all --mock-scenario all-missing >/dev/null 2>&1; echo $?)
if [ "$EXIT_5" = "1" ]; then
    pass TC5 "scenario all-missing exit code = 1 (mock 5 fail 拒绝)"
else
    fail TC5 "scenario all-missing exit code = $EXIT_5 (期望 1)"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# 集成 验证: PHASE-INDEX.md 段 + SKILL.md 段 + default dry-run
# ----------------------------------------
echo ">>> 集成 验证: PHASE-INDEX 段 + SKILL 段 + dry-run 默认"
echo "=========================================="

# 验证 PHASE-INDEX.md 含 Post-Process 11 步骤 段
if [ -f "$PHASE_INDEX_FILE" ] && grep -qE "Post-Process 11 步骤" "$PHASE_INDEX_FILE"; then
    SECTION_LINE=$(grep -nE "Post-Process 11 步骤" "$PHASE_INDEX_FILE" | head -1 | cut -d: -f1 || echo "0")
    pass "集成" "PHASE-INDEX.md 含 Post-Process 11 步骤 段 (line ${SECTION_LINE}, file:line 联合)"
else
    fail "集成" "PHASE-INDEX.md 缺 Post-Process 11 步骤 段"
fi

# 验证 PHASE-INDEX.md 含全部 11 步骤 表格
if grep -qE "^\| [0-9]+ \| \*\*" "$PHASE_INDEX_FILE"; then
    STEP_TABLE_COUNT=$(grep -cE "^\| [0-9]+ \| \*\*回归验证|^\| [0-9]+ \| \*\*分支同步|^\| [0-9]+ \| \*\*经验沉淀|^\| [0-9]+ \| \*\*技术债登记|^\| [0-9]+ \| \*\*GLOSSARY|^\| [0-9]+ \| \*\*PHASE-INDEX|^\| [0-9]+ \| \*\*ACCUMULATED-LESSONS|^\| [0-9]+ \| \*\*CHANGELOG|^\| [0-9]+ \| \*\*CLAUDE.md|^\| [0-9]+ \| \*\*pre-commit|^\| [0-9]+ \| \*\*跨期 review" "$PHASE_INDEX_FILE")
    if [ "$STEP_TABLE_COUNT" -eq "$TOTAL_STEPS" ]; then
        pass "集成" "PHASE-INDEX.md 含 全部 ${TOTAL_STEPS} 步骤 表格 (跟 eket §10 升级 联合)"
    else
        fail "集成" "PHASE-INDEX.md 步骤 表格 仅 ${STEP_TABLE_COUNT}/${TOTAL_STEPS} (缺)"
    fi
else
    fail "集成" "PHASE-INDEX.md 缺 步骤 表格"
fi

# 验证 SKILL.md 含 Post-Process 11 步骤 段
if [ -f "$SKILL_FILE" ] && grep -qE "Post-Process 11 步骤" "$SKILL_FILE"; then
    SECTION_LINE=$(grep -nE "Post-Process 11 步骤" "$SKILL_FILE" | head -1 | cut -d: -f1 || echo "0")
    pass "集成" "SKILL.md 含 Post-Process 11 步骤 段 (line ${SECTION_LINE}, 跟 26 命令 SKILL 模式 联合)"
else
    fail "集成" "SKILL.md 缺 Post-Process 11 步骤 段"
fi

# 验证 default mode = dry-run (跟 Rule 4 "Fail Fast" 联合, 默认安全)
# 检查 默认 行为: 不传 --apply 跑 dry-run, 头部 banner 应含 "DRY-RUN"
DEFAULT_OUTPUT=$(bash "$POST_PROCESS_SCRIPT" 2>&1 | head -8 || true)
if echo "$DEFAULT_OUTPUT" | grep -qE "Mode: DRY-RUN|DRY-RUN"; then
    pass "集成" "default mode = dry-run (跟 Rule 4 Fail Fast 联合)"
else
    fail "集成" "default mode 不是 dry-run (Rule 4 Fail Fast 验证 失败)"
fi

# 验证 --apply 标志 实际 执行
if bash "$POST_PROCESS_SCRIPT" --help 2>&1 | grep -qE -- "--apply"; then
    pass "集成" "--apply 标志 存在 (实际 执行 入口)"
else
    fail "集成" "--apply 标志 缺失"
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ Post-Process 11 步骤 — Integration Tests: ${PASS_COUNT}/${TOTAL_TESTS}+ PASS (100.0%)"
    echo "=========================================="
    exit 0
else
    echo "✗ Post-Process 11 步骤 — Integration Tests: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
    echo "=========================================="
    exit 1
fi