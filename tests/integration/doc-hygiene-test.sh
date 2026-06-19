#!/usr/bin/env bash
# tests/integration/doc-hygiene-test.sh — TDD tests for 文档卫生 (每 10 轮) 5 项 检查
# EPIC-059-G: 文档卫生 (每 10 轮) + 新建前先想 — 5/5 PASS 验证
# 跟 eket template/docs/MASTER-RULES.md §6 Master Hard Rule 6 文档卫生 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules 模式 一致)
# 跟 KALLAX-GLOSSARY 反哺框架 战略 联合
#
# Test cases (5):
#   TC1: 5 项 全部 满足 → 5/5 PASS (mock all-pass)
#   TC2: 未追踪 md 缺失 → 4/5 PASS + 1 FAIL (mock fail-untracked-md)
#   TC3: 重复文档 存在 → 4/5 PASS + 1 FAIL (mock fail-duplicate-docs)
#   TC4: 僵尸 ticket 存在 → 4/5 PASS + 1 FAIL (mock fail-zombie-ticket)
#   TC5: 全部 缺失 → 0/5 PASS (mock all-fail)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-059-A check-9-hard-rules-test.sh 模式 一致
# 跟 EPIC-059-B check-rule-of-500-test.sh 模式 一致
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "文档碎片化" 反讽
# 跟 v2.4.0+v2.4.1 反思 联合, 跟"翻篇&精进" 战略 一致

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CHECK_SCRIPT="$KALLAX_ROOT/scripts/check-doc-hygiene.sh"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
readonly PHASE_INDEX="$KALLAX_ROOT/docs/PHASE-INDEX.md"
readonly DOC_9HR="$KALLAX_ROOT/docs/process/9-hard-rules.md"
readonly TICKET_DIR="$KALLAX_ROOT/jira/tickets/EPIC-059-G"

# Constants (Rule 4: no magic numbers, name all)
readonly TOTAL_CHECKS=5
readonly EXPECTED_MOCKS=5
readonly UNTRACKED_MD_THRESHOLD=10
readonly ZOMBIE_TICKET_DAYS=7
readonly REVIEW_MTIME_DAYS=3
readonly DUPLICATE_THRESHOLD=2
readonly RULE_CONSISTENCY_MIN=95

echo "=========================================="
echo "文档卫生 (每 10 轮) — Integration Tests (5/5)"
echo "EPIC-059-G | 跟 eket MASTER-RULES.md §6 Rule 6 联合"
echo "借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules 模式 一致)"
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

# bash 3.2 compat: use parallel variables instead of declare -A
TC1_PASS=0; TC1_FAIL=0
TC2_PASS=0; TC2_FAIL=0
TC3_PASS=0; TC3_FAIL=0
TC4_PASS=0; TC4_FAIL=0
TC5_PASS=0; TC5_FAIL=0
TC6_PASS=0; TC6_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); eval "TC${1}_PASS=\$((TC${1}_PASS+1))"; }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); eval "TC${1}_FAIL=\$((TC${1}_FAIL+1))"; }

# Helper: invoke the script with --mock <mode>
invoke_mock() {
    local mock="$1"
    bash "$CHECK_SCRIPT" --mock "$mock" 2>&1 || true
}

# ----------------------------------------
# TC1: 5 项 全部 满足 → 5/5 PASS (mock all-pass)
# ----------------------------------------
echo ">>> TC1: 5 项 全部 满足 → 5/5 PASS — mock all-pass"
echo "=========================================="
TC1_RESULT=0

OUTPUT_ALL_PASS=$(invoke_mock "all-pass")
if echo "$OUTPUT_ALL_PASS" | grep -qE "5/5 PASS"; then
    pass 1 "mock all-pass → 5/5 PASS (跟 eket §6 Rule 6 联合, 0 缺项)"
else
    fail 1 "mock all-pass → 非 5/5 PASS (output 截取: $(echo "$OUTPUT_ALL_PASS" | tail -5))"
    TC1_RESULT=1
fi

# 验证 exit code = 0
EXIT_ALL_PASS=$(bash "$CHECK_SCRIPT" --mock "all-pass" >/dev/null 2>&1; echo $?)
if [ "$EXIT_ALL_PASS" = "0" ]; then
    pass 1 "mock all-pass exit code = 0 (无 FAIL 项)"
else
    fail 1 "mock all-pass exit code = $EXIT_ALL_PASS (期望 0)"
    TC1_RESULT=1
fi

# 验证 KPI 100.0%
if echo "$OUTPUT_ALL_PASS" | grep -qE "kpi_score=100\.0"; then
    pass 1 "mock all-pass KPI = 100.0% (跟 Rule 9 精确 X/Y 联合)"
else
    fail 1 "mock all-pass KPI ≠ 100.0%"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: 未追踪 md 缺失 → 4/5 PASS + 1 FAIL (mock fail-untracked-md)
# ----------------------------------------
echo ">>> TC2: 未追踪 md 缺失 → 4/5 PASS + 1 FAIL — mock fail-untracked-md"
echo "=========================================="
TC2_RESULT=0

OUTPUT_FAIL_UNTRACKED=$(invoke_mock "fail-untracked-md")

# 验证 4/5 PASS
if echo "$OUTPUT_FAIL_UNTRACKED" | grep -qE "4/5 PASS"; then
    pass 2 "mock fail-untracked-md → 4/5 PASS (跟 eket §6 Rule 6 阈值 联合)"
else
    fail 2 "mock fail-untracked-md → 非 4/5 PASS (output 截取: $(echo "$OUTPUT_FAIL_UNTRACKED" | tail -5))"
    TC2_RESULT=1
fi

# 验证 Check 1 FAIL
if echo "$OUTPUT_FAIL_UNTRACKED" | grep -qE "check_1_status=FAIL"; then
    pass 2 "Check 1 (未追踪 md) → FAIL (跟 Rule 5 DRY 矛盾)"
else
    fail 2 "Check 1 期望 FAIL, 实际 PASS"
    TC2_RESULT=1
fi

# 验证 exit code != 0
EXIT_FAIL_UNTRACKED=$(bash "$CHECK_SCRIPT" --mock "fail-untracked-md" >/dev/null 2>&1; echo $?)
if [ "$EXIT_FAIL_UNTRACKED" != "0" ]; then
    pass 2 "mock fail-untracked-md exit code = $EXIT_FAIL_UNTRACKED (FAIL 阻止 commit)"
else
    fail 2 "mock fail-untracked-md exit code = 0 (期望 ≠0)"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: 重复文档 存在 → 4/5 PASS + 1 FAIL (mock fail-duplicate-docs)
# ----------------------------------------
echo ">>> TC3: 重复文档 存在 → 4/5 PASS + 1 FAIL — mock fail-duplicate-docs"
echo "=========================================="
TC3_RESULT=0

OUTPUT_FAIL_DUP=$(invoke_mock "fail-duplicate-docs")

# 验证 4/5 PASS
if echo "$OUTPUT_FAIL_DUP" | grep -qE "4/5 PASS"; then
    pass 3 "mock fail-duplicate-docs → 4/5 PASS (跟 eket §6 Rule 6 阈值 联合)"
else
    fail 3 "mock fail-duplicate-docs → 非 4/5 PASS (output 截取: $(echo "$OUTPUT_FAIL_DUP" | tail -5))"
    TC3_RESULT=1
fi

# 验证 Check 4 FAIL
if echo "$OUTPUT_FAIL_DUP" | grep -qE "check_4_status=FAIL"; then
    pass 3 "Check 4 (重复文档) → FAIL (跟 Rule 5 DRY SoT 矛盾)"
else
    fail 3 "Check 4 期望 FAIL, 实际 PASS"
    TC3_RESULT=1
fi

# 验证 exit code != 0
EXIT_FAIL_DUP=$(bash "$CHECK_SCRIPT" --mock "fail-duplicate-docs" >/dev/null 2>&1; echo $?)
if [ "$EXIT_FAIL_DUP" != "0" ]; then
    pass 3 "mock fail-duplicate-docs exit code = $EXIT_FAIL_DUP (FAIL 阻止 commit)"
else
    fail 3 "mock fail-duplicate-docs exit code = 0 (期望 ≠0)"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: 僵尸 ticket 存在 → 4/5 PASS + 1 FAIL (mock fail-zombie-ticket)
# ----------------------------------------
echo ">>> TC4: 僵尸 ticket 存在 → 4/5 PASS + 1 FAIL — mock fail-zombie-ticket"
echo "=========================================="
TC4_RESULT=0

OUTPUT_FAIL_ZOMBIE=$(invoke_mock "fail-zombie-ticket")

# 验证 4/5 PASS
if echo "$OUTPUT_FAIL_ZOMBIE" | grep -qE "4/5 PASS"; then
    pass 4 "mock fail-zombie-ticket → 4/5 PASS (跟 eket §6 Rule 6 阈值 联合)"
else
    fail 4 "mock fail-zombie-ticket → 非 4/5 PASS (output 截取: $(echo "$OUTPUT_FAIL_ZOMBIE" | tail -5))"
    TC4_RESULT=1
fi

# 验证 Check 2 FAIL
if echo "$OUTPUT_FAIL_ZOMBIE" | grep -qE "check_2_status=FAIL"; then
    pass 4 "Check 2 (僵尸 ticket) → FAIL (跟 Rule 6 经验沉淀 + Rule 11 Anti-Fab 联合)"
else
    fail 4 "Check 2 期望 FAIL, 实际 PASS"
    TC4_RESULT=1
fi

# 验证 exit code != 0
EXIT_FAIL_ZOMBIE=$(bash "$CHECK_SCRIPT" --mock "fail-zombie-ticket" >/dev/null 2>&1; echo $?)
if [ "$EXIT_FAIL_ZOMBIE" != "0" ]; then
    pass 4 "mock fail-zombie-ticket exit code = $EXIT_FAIL_ZOMBIE (FAIL 阻止 commit)"
else
    fail 4 "mock fail-zombie-ticket exit code = 0 (期望 ≠0)"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: 全部 缺失 → 0/5 PASS (mock all-fail)
# ----------------------------------------
echo ">>> TC5: 全部 缺失 → 0/5 PASS — mock all-fail"
echo "=========================================="
TC5_RESULT=0

OUTPUT_ALL_FAIL=$(invoke_mock "all-fail")

# 验证 0/5 PASS
if echo "$OUTPUT_ALL_FAIL" | grep -qE "0/5 PASS"; then
    pass 5 "mock all-fail → 0/5 PASS (跟 eket §6 Rule 6 联合, 全 FAIL 检测)"
else
    fail 5 "mock all-fail → 非 0/5 PASS (output 截取: $(echo "$OUTPUT_ALL_FAIL" | tail -5))"
    TC5_RESULT=1
fi

# 验证所有 check status=FAIL
ALL_FAIL_CHECKS=0
for chk in 1 2 3 4 5; do
    if echo "$OUTPUT_ALL_FAIL" | grep -qE "check_${chk}_status=FAIL"; then
        ALL_FAIL_CHECKS=$((ALL_FAIL_CHECKS + 1))
    fi
done

if [ "$ALL_FAIL_CHECKS" -eq 5 ]; then
    pass 5 "5 项 check 全部 FAIL (跟 test mock 5 一致, 5/5 FAIL 检测)"
else
    fail 5 "5 项 check FAIL 检测只匹配 ${ALL_FAIL_CHECKS}/5 (期望 5/5)"
    TC5_RESULT=1
fi

# 验证 exit code != 0
EXIT_ALL_FAIL=$(bash "$CHECK_SCRIPT" --mock "all-fail" >/dev/null 2>&1; echo $?)
if [ "$EXIT_ALL_FAIL" != "0" ]; then
    pass 5 "mock all-fail exit code = $EXIT_ALL_FAIL (FAIL 阻止 commit)"
else
    fail 5 "mock all-fail exit code = 0 (期望 ≠0)"
    TC5_RESULT=1
fi

# 验证 KPI 0.0%
if echo "$OUTPUT_ALL_FAIL" | grep -qE "kpi_score=0\.0"; then
    pass 5 "mock all-fail KPI = 0.0% (跟 Rule 9 精确 X/Y 联合)"
else
    fail 5 "mock all-fail KPI ≠ 0.0%"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# Bonus TC6: docs/PHASE-INDEX.md + CLAUDE.md 落地验证
# ----------------------------------------
echo ">>> TC6 (bonus): docs/PHASE-INDEX.md + CLAUDE.md 落地 验证"
echo "=========================================="
TC6_RESULT=0

# 验证 PHASE-INDEX.md 含 "文档卫生 触发" 段
if grep -qE "^## 文档卫生 触发" "$PHASE_INDEX" 2>/dev/null; then
    SECTION_LINE=$(grep -nE "^## 文档卫生 触发" "$PHASE_INDEX" | head -1 | cut -d: -f1 || echo "0")
    pass 6 "PHASE-INDEX.md 含 '文档卫生 触发' 章节 (line $SECTION_LINE, 跟 eket §6 Rule 6 联合)"
else
    fail 6 "PHASE-INDEX.md 缺 '文档卫生 触发' 章节"
    TC6_RESULT=1
fi

# 验证 PHASE-INDEX.md 5 项 检查 列出
PHASE_INDEX_5CHECKS=0
for check_name in "未追踪 md" "僵尸 ticket" "积压 review" "重复文档" "过期 Rule"; do
    if grep -qE "$check_name" "$PHASE_INDEX" 2>/dev/null; then
        PHASE_INDEX_5CHECKS=$((PHASE_INDEX_5CHECKS + 1))
    fi
done

if [ "$PHASE_INDEX_5CHECKS" -eq 5 ]; then
    pass 6 "PHASE-INDEX.md 5 项 检查 全部列出 (跟 ticket AC #1 联合)"
else
    fail 6 "PHASE-INDEX.md 5 项 检查 只列 ${PHASE_INDEX_5CHECKS}/5 (期望 5)"
    TC6_RESULT=1
fi

# 验证 CLAUDE.md 含 "9 Hard Rules Rule 6+7" 段
if grep -qE "9 Hard Rules Rule 6\+7" "$CLAUDE_MD" 2>/dev/null; then
    SECTION_LINE=$(grep -nE "9 Hard Rules Rule 6\+7" "$CLAUDE_MD" | head -1 | cut -d: -f1 || echo "0")
    pass 6 "CLAUDE.md 含 '9 Hard Rules Rule 6+7 映射' 章节 (line $SECTION_LINE, 跟 ticket AC #2 联合)"
else
    fail 6 "CLAUDE.md 缺 '9 Hard Rules Rule 6+7 映射' 章节"
    TC6_RESULT=1
fi

# 验证 CLAUDE.md 含 "新建前先想" 3 问
NEW_THINK_3Q=0
for q in "是否有同类文档可更新" "是否有同类 ticket 可扩展" "是否有同类 Rule 可引用"; do
    if grep -qE "$q" "$CLAUDE_MD" 2>/dev/null; then
        NEW_THINK_3Q=$((NEW_THINK_3Q + 1))
    fi
done

if [ "$NEW_THINK_3Q" -eq 3 ]; then
    pass 6 "CLAUDE.md '新建前先想' 3 问 全部列出 (跟 ticket AC #2 联合)"
else
    fail 6 "CLAUDE.md '新建前先想' 3 问 只列 ${NEW_THINK_3Q}/3 (期望 3)"
    TC6_RESULT=1
fi

# 验证 22 Rule 完整保留 (跟"翻篇&精进" 战略 一致, 跟 v2.4.1 还原 联合)
ACTIVE_RULES=$(grep -cE "^### [0-9]+\. " "$CLAUDE_MD" 2>/dev/null || echo "0")
if [ "$ACTIVE_RULES" -eq 22 ]; then
    pass 6 "CLAUDE.md 22 Rule 保留 (跟 v2.4.1 revert 一致, 跟 0 增 Rule 持平 联合)"
else
    fail 6 "CLAUDE.md active Rule 数 = $ACTIVE_RULES (期望 22)"
    TC6_RESULT=1
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ 文档卫生 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS (100.0%)"
    echo "=========================================="
    exit 0
else
    echo "✗ 文档卫生 — Integration Tests: ${PASS_COUNT}/${TOTAL} PASS"
    echo "=========================================="
    exit 1
fi
