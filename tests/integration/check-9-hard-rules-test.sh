#!/usr/bin/env bash
# tests/integration/check-9-hard-rules-test.sh — TDD tests for 9 Hard Rules 简化
# EPIC-059-A AC: 9 Hard Rules 检查脚本 (跟 scripts/check-fact-forcing-preflight.sh 模式 一致, 跑 9 项 检查)
# 跟 eket template/docs/MASTER-RULES.md §6 联合, 借方法论 不借代码
#
# Test cases (5):
#   TC1: 9 项 规则 全部存在 (跟 AC #2 联合, 9 项全覆盖)
#   TC2: CLAUDE.md 22 Rule → 9 类别 group 索引 (跟 AC #1 联合, 0 删 Rule, file:line 1:1 映射)
#   TC3: docs/process/9-hard-rules.md 详细 解释 (跟 AC #5 联合, ≥9 反例 + ≥9 正例 + 撤销方法)
#   TC4: KALLAX-GLOSSARY §11.1 闭环段 (跟 AC #4 联合, 跟 v2.4.1 Rule 合并反思 联合)
#   TC5: 0 增 Rule KPI 精确 22/22 = 100.0% (跟 AC #10 联合, 跟"翻篇&精进" 战略 一致)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-055-C tag-sop-test.sh 模式 一致
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信
# 跟 KALLAX-GLOSSARY §11.1 联合, 跟 v2.4.1 revert 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CHECK_SCRIPT="$KALLAX_ROOT/scripts/check-9-hard-rules.sh"
readonly DOC="$KALLAX_ROOT/docs/process/9-hard-rules.md"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
readonly GLOSSARY="$KALLAX_ROOT/docs/KALLAX-GLOSSARY.md"
readonly TICKET_DIR="$KALLAX_ROOT/jira/tickets/EPIC-059-A"

# Constants (Rule 4: no magic numbers, name all)
readonly EXPECTED_HARD_RULES=9
readonly EXPECTED_KALLAX_RULES=22

# TDD red phase: verify script + doc exist
if [ ! -f "$CHECK_SCRIPT" ]; then
    echo "=========================================="
    echo "9 Hard Rules 简化 — Integration Tests (5/5)"
    echo "=========================================="
    echo ""
    echo "FAIL: $CHECK_SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$DOC" ]; then
    echo "=========================================="
    echo "9 Hard Rules 简化 — Integration Tests (5/5)"
    echo "=========================================="
    echo ""
    echo "FAIL: $DOC not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

# Source the script to access functions
# shellcheck disable=SC1090
source "$CHECK_SCRIPT" 2>/dev/null || {
    echo "FAIL: could not source $CHECK_SCRIPT"
    exit 1
}

echo "=========================================="
echo "9 Hard Rules 简化 — Integration Tests (5/5)"
echo "EPIC-059-A | 跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5

# bash 3.2 compat: use parallel variables instead of declare -A
TC1_PASS=0; TC1_FAIL=0
TC2_PASS=0; TC2_FAIL=0
TC3_PASS=0; TC3_FAIL=0
TC4_PASS=0; TC4_FAIL=0
TC5_PASS=0; TC5_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); eval "TC${1}_PASS=\$((TC${1}_PASS+1))"; }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); eval "TC${1}_FAIL=\$((TC${1}_FAIL+1))"; }

# ----------------------------------------
# TC1: 9 项 规则 全部存在
# ----------------------------------------
echo ">>> TC1: 9 项 规则 全部存在 — AC #2 9 项全覆盖"
echo "=========================================="
TC1_RESULT=0

if declare -f check_9_hard_rules >/dev/null 2>&1; then
    OUTPUT=$(check_9_hard_rules 2>&1 || echo "FAIL")
    if echo "$OUTPUT" | grep -qE "rules_total="; then
        RULES_TOTAL=$(echo "$OUTPUT" | grep -oE "rules_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$RULES_TOTAL" -eq "$EXPECTED_HARD_RULES" ]; then
            pass 1 "9 项 规则 全部存在 (rules_total=$RULES_TOTAL)"
        else
            fail 1 "9 项 规则 数不对 (rules_total=$RULES_TOTAL, 期望 $EXPECTED_HARD_RULES)"
            TC1_RESULT=1
        fi
    else
        fail 1 "9 项 规则 — 缺 rules_total 字段"
        TC1_RESULT=1
    fi

    # 验证 9 项 全部 有 name + description
    for i in $(seq 1 $EXPECTED_HARD_RULES); do
        if echo "$OUTPUT" | grep -qE "rule_${i}_name="; then
            RULE_NAME=$(echo "$OUTPUT" | grep -oE "rule_${i}_name=[^[:space:]]+" | head -1 || echo "")
            if [ -n "$RULE_NAME" ]; then
                pass 1 "Rule ${i} 有 name ($RULE_NAME)"
            else
                fail 1 "Rule ${i} name 为空"
                TC1_RESULT=1
            fi
        else
            fail 1 "缺 rule_${i}_name 字段"
            TC1_RESULT=1
        fi
    done
else
    fail 1 "check_9_hard_rules 函数缺失"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: CLAUDE.md 22 Rule → 9 类别 group 索引
# ----------------------------------------
echo ">>> TC2: CLAUDE.md 22 Rule → 9 类别 group 索引 — 0 删 Rule, file:line 1:1 映射"
echo "=========================================="
TC2_RESULT=0

if declare -f check_claude_md_group_index >/dev/null 2>&1; then
    OUTPUT=$(check_claude_md_group_index 2>&1 || echo "FAIL")
    if echo "$OUTPUT" | grep -qE "kallax_rules_count="; then
        COUNT=$(echo "$OUTPUT" | grep -oE "kallax_rules_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$COUNT" -eq "$EXPECTED_KALLAX_RULES" ]; then
            pass 2 "CLAUDE.md 22 Rule 保留 0 删 (kallax_rules_count=$COUNT)"
        else
            fail 2 "CLAUDE.md Rule 数 不等于 22 (kallax_rules_count=$COUNT, 期望 $EXPECTED_KALLAX_RULES)"
            TC2_RESULT=1
        fi
    else
        fail 2 "CLAUDE.md 索引 — 缺 kallax_rules_count 字段"
        TC2_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "group_count=9"; then
        pass 2 "CLAUDE.md 9 类别 group 索引 (group_count=9)"
    else
        fail 2 "CLAUDE.md 缺 9 类别 group 索引"
        TC2_RESULT=1
    fi

    # 验证 "9 Hard Rules 模式" 章节存在 (跟 AC #3 联合)
    if grep -qE "9 Hard Rules 模式" "$CLAUDE_MD"; then
        SECTION_LINE=$(grep -n "9 Hard Rules 模式" "$CLAUDE_MD" | head -1 | cut -d: -f1 || echo "0")
        pass 2 "CLAUDE.md 含 '9 Hard Rules 模式' 章节 (line $SECTION_LINE, 跟 eket 联合)"
    else
        fail 2 "CLAUDE.md 缺 '9 Hard Rules 模式' 章节 (跟 AC #3 联合)"
        TC2_RESULT=1
    fi
else
    fail 2 "check_claude_md_group_index 函数缺失"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: docs/process/9-hard-rules.md 详细 解释
# ----------------------------------------
echo ">>> TC3: docs/process/9-hard-rules.md 详细 — ≥9 反例 + ≥9 正例 + 撤销方法"
echo "=========================================="
TC3_RESULT=0

if declare -f check_doc_completeness >/dev/null 2>&1; then
    OUTPUT=$(check_doc_completeness 2>&1 || echo "FAIL")
    if echo "$OUTPUT" | grep -qE "doc_lines="; then
        DOC_LINES=$(echo "$OUTPUT" | grep -oE "doc_lines=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        # AC #5 要求 150-250 行
        if [ "$DOC_LINES" -ge 150 ] && [ "$DOC_LINES" -le 250 ]; then
            pass 3 "9-hard-rules.md 行数 150-250 (doc_lines=$DOC_LINES)"
        else
            fail 3 "9-hard-rules.md 行数 越界 (doc_lines=$DOC_LINES, 期望 150-250)"
            TC3_RESULT=1
        fi
    else
        fail 3 "9-hard-rules.md — 缺 doc_lines 字段"
        TC3_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "anti_patterns_total="; then
        ANTI_TOTAL=$(echo "$OUTPUT" | grep -oE "anti_patterns_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$ANTI_TOTAL" -ge "$EXPECTED_HARD_RULES" ]; then
            pass 3 "9-hard-rules.md 反例 ≥9 (anti_patterns_total=$ANTI_TOTAL)"
        else
            fail 3 "9-hard-rules.md 反例 <9 (anti_patterns_total=$ANTI_TOTAL)"
            TC3_RESULT=1
        fi
    else
        fail 3 "9-hard-rules.md — 缺 anti_patterns_total 字段"
        TC3_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "positive_examples_total="; then
        POS_TOTAL=$(echo "$OUTPUT" | grep -oE "positive_examples_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$POS_TOTAL" -ge "$EXPECTED_HARD_RULES" ]; then
            pass 3 "9-hard-rules.md 正例 ≥9 (positive_examples_total=$POS_TOTAL)"
        else
            fail 3 "9-hard-rules.md 正例 <9 (positive_examples_total=$POS_TOTAL)"
            TC3_RESULT=1
        fi
    else
        fail 3 "9-hard-rules.md — 缺 positive_examples_total 字段"
        TC3_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "rollback_section="; then
        pass 3 "9-hard-rules.md 撤销方法 段存在 (rollback_section=1)"
    else
        fail 3 "9-hard-rules.md — 缺撤销方法 段"
        TC3_RESULT=1
    fi
else
    fail 3 "check_doc_completeness 函数缺失"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: KALLAX-GLOSSARY §11.1 闭环段
# ----------------------------------------
echo ">>> TC4: KALLAX-GLOSSARY §11.1 闭环段 — 跟 '9 Hard Rules 简化' + v2.4.1 revert 联合"
echo "=========================================="
TC4_RESULT=0

if declare -f check_glossary_loop >/dev/null 2>&1; then
    OUTPUT=$(check_glossary_loop 2>&1 || echo "FAIL")
    if echo "$OUTPUT" | grep -qE "loop_marker_total="; then
        MARKER_TOTAL=$(echo "$OUTPUT" | grep -oE "loop_marker_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        # §11.1 闭环段 跟 "9 Hard Rules 简化" 跟 v2.4.1 revert 联合 (3 联合)
        if [ "$MARKER_TOTAL" -ge 3 ]; then
            pass 4 "GLOSSARY §11.1 闭环 ≥3 联合 (loop_marker_total=$MARKER_TOTAL)"
        else
            fail 4 "GLOSSARY §11.1 闭环 <3 (loop_marker_total=$MARKER_TOTAL, 期望 ≥3)"
            TC4_RESULT=1
        fi
    else
        fail 4 "GLOSSARY §11.1 — 缺 loop_marker_total 字段"
        TC4_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "v241_revert_ref="; then
        pass 4 "GLOSSARY §11.1 含 v2.4.1 revert 引用 (跟 PHASE-013 联合)"
    else
        fail 4 "GLOSSARY §11.1 缺 v2.4.1 revert 引用"
        TC4_RESULT=1
    fi

    if echo "$OUTPUT" | grep -qE "nine_hr_ref="; then
        pass 4 "GLOSSARY §11.1 含 '9 Hard Rules' 引用 (跟 EPIC-059-A 联合)"
    else
        fail 4 "GLOSSARY §11.1 缺 '9 Hard Rules' 引用"
        TC4_RESULT=1
    fi
else
    fail 4 "check_glossary_loop 函数缺失"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: 0 增 Rule KPI 精确 22/22 = 100.0%
# ----------------------------------------
echo ">>> TC5: 0 增 Rule KPI — 22 Rule → 9 类别 group = 100% 落地, 0 增 Rule"
echo "=========================================="
TC5_RESULT=0

if declare -f check_zero_rule_inflation >/dev/null 2>&1; then
    OUTPUT=$(check_zero_rule_inflation 2>&1 || echo "FAIL")
    if echo "$OUTPUT" | grep -qE "kpi_score="; then
        SCORE=$(echo "$OUTPUT" | grep -oE "kpi_score=[0-9.]+" | grep -oE "[0-9.]+" || echo "0")
        if awk "BEGIN{exit !($SCORE == 100.0)}" 2>/dev/null; then
            pass 5 "0 增 Rule KPI 100.0% (kpi_score=$SCORE, 跟'翻篇&精进' 一致)"
        else
            fail 5 "0 增 Rule KPI < 100% (kpi_score=$SCORE, 期望 100.0)"
            TC5_RESULT=1
        fi
    else
        fail 5 "0 增 Rule KPI — 缺 kpi_score 字段"
        TC5_RESULT=1
    fi

    # 验证 22 Rule 全部 落地 (跟 v2.4.1 revert 一致)
    if echo "$OUTPUT" | grep -qE "rules_landed=22"; then
        pass 5 "22 Rule 全部 落地 (rules_landed=22, 跟 v2.4.1 联合)"
    else
        fail 5 "22 Rule 落地 不全 (rules_landed 不等于 22)"
        TC5_RESULT=1
    fi

    # 验证 0 增 Rule
    if echo "$OUTPUT" | grep -qE "rules_added=0"; then
        pass 5 "0 增 Rule (rules_added=0, 跟'翻篇&精进' 一致)"
    else
        fail 5 "0 增 Rule 验证失败 (rules_added 不等于 0)"
        TC5_RESULT=1
    fi
else
    fail 5 "check_zero_rule_inflation 函数缺失"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# Summary (Rule 9 KPI X/Y 精确格式)
# ----------------------------------------
TC_TOTAL=0
TC_PASSED=0
TC_VAR="TC1_PASS TC2_PASS TC3_PASS TC4_PASS TC5_PASS"
TC_FAIL_VAR="TC1_FAIL TC2_FAIL TC3_FAIL TC4_FAIL TC5_FAIL"
for i in 1 2 3 4 5; do
    TC_TOTAL=$((TC_TOTAL + 1))
    eval "current_pass=\$TC${i}_PASS"
    eval "current_fail=\$TC${i}_FAIL"
    if [ "$current_fail" -eq 0 ] && [ "$current_pass" -gt 0 ]; then
        TC_PASSED=$((TC_PASSED + 1))
    fi
done

echo "=========================================="
echo "Summary: $TC_PASSED/$TC_TOTAL PASS (TC-level, Rule 9 X/Y 精确格式)"
echo "=========================================="

if [ "$TC_PASSED" -eq "$TC_TOTAL" ]; then
    echo "PASS: $TC_PASSED/$TC_TOTAL (100.0%)"
    exit 0
else
    PERCENT=$(awk "BEGIN{printf \"%.1f\", $TC_PASSED * 100 / $TC_TOTAL}")
    echo "FAIL: $TC_PASSED/$TC_TOTAL ($PERCENT%)"
    exit 1
fi