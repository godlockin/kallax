#!/usr/bin/env bash
# tests/integration/tag-sop-test.sh — TDD tests for tag SOP
# EPIC-055-C AC6: 5/5 PASS (5 标签扫描 + 证据链校验 + 咒语化检测 + 笔误识别 + SOP 合规性)
#
# Test cases (5):
#   TC1: 5 标签扫描 (反讽/诚实修正/独立/翻篇&精进/流程逻辑)
#   TC2: 证据链校验 (每条引用带 file:line OR commit hash)
#   TC3: 咒语化检测 (无证据链 装饰引用 = 违规)
#   TC4: 笔误识别 (e.g. "主公拍 explicit 拍 explicit")
#   TC5: SOP 合规性 (5 标签 引用 全部符合 SOP)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合
# 跟 EPIC-055-A CLAUDE+GLOSSARY 去重 联合
# 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
# 跟 14-ISSUES-INTAKE-2026-06-16.md Part 4 联合
# 跟"诚实修正" 战略 联合, 跟"独立" 拍 explicit 约束 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SCRIPT="$KALLAX_ROOT/scripts/audit/tag-audit.sh"
readonly SOP_DOC="$KALLAX_ROOT/docs/process/tag-sop.md"

# Constants (Rule 4: no magic numbers, name all)
readonly EXPECTED_TAG_COUNT=5
readonly TARGET_CURSED_REDUCTION_MIN=10

# Evidence pattern — file:line (any extension) OR commit hash OR 40-char SHA
readonly EVIDENCE_PATTERN='(file:|[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+|commit [0-9a-f]{7,}|commit_sha=|[0-9a-f]{40})'

# TDD red phase: verify script + sop doc exist
if [ ! -f "$SCRIPT" ]; then
    echo "=========================================="
    echo "Tag SOP (反讽/诚实修正/独立/翻篇&精进/流程逻辑) — Integration Tests (5/5)"
    echo "=========================================="
    echo ""
    echo "FAIL: $SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$SOP_DOC" ]; then
    echo "=========================================="
    echo "Tag SOP (反讽/诚实修正/独立/翻篇&精进/流程逻辑) — Integration Tests (5/5)"
    echo "=========================================="
    echo ""
    echo "FAIL: $SOP_DOC not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

# Source the script to access functions
# shellcheck disable=SC1090
source "$SCRIPT" 2>/dev/null || {
    echo "FAIL: could not source $SCRIPT"
    exit 1
}

echo "=========================================="
echo "Tag SOP (反讽/诚实修正/独立/翻篇&精进/流程逻辑) — Integration Tests (5/5)"
echo "EPIC-055-C | A2 咒语化 + A3 笔误 治根 | Master 强验证"
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
# TC1: 5 标签扫描 (反讽/诚实修正/独立/翻篇&精进/流程逻辑)
# ----------------------------------------
echo ">>> TC1: 5 标签扫描 — 频率统计"
echo "=========================================="
TC1_RESULT=0

if declare -f scan_tags >/dev/null 2>&1; then
    SCAN_OUTPUT=$(scan_tags "$KALLAX_ROOT" 2>&1 || echo "FAIL")
    if echo "$SCAN_OUTPUT" | grep -qE "irony_count="; then
        IRONY=$(echo "$SCAN_OUTPUT" | grep -oE "irony_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$IRONY" -ge 1 ]; then
            pass 1 "5 标签扫描 — 反讽 计数 (irony_count=$IRONY)"
        else
            fail 1 "5 标签扫描 — 反讽 计数为 0"
            TC1_RESULT=1
        fi
    else
        fail 1 "5 标签扫描 — 缺 irony_count 字段"
        TC1_RESULT=1
    fi

    if echo "$SCAN_OUTPUT" | grep -qE "honest_correction_count="; then
        HC=$(echo "$SCAN_OUTPUT" | grep -oE "honest_correction_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$HC" -ge 1 ]; then
            pass 1 "5 标签扫描 — 诚实修正 计数 (honest_correction_count=$HC)"
        else
            fail 1 "5 标签扫描 — 诚实修正 计数为 0"
            TC1_RESULT=1
        fi
    else
        fail 1 "5 标签扫描 — 缺 honest_correction_count 字段"
        TC1_RESULT=1
    fi

    if echo "$SCAN_OUTPUT" | grep -qE "independence_count="; then
        IND=$(echo "$SCAN_OUTPUT" | grep -oE "independence_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$IND" -ge 1 ]; then
            pass 1 "5 标签扫描 — 独立 计数 (independence_count=$IND)"
        else
            fail 1 "5 标签扫描 — 独立 计数为 0"
            TC1_RESULT=1
        fi
    else
        fail 1 "5 标签扫描 — 缺 independence_count 字段"
        TC1_RESULT=1
    fi

    if echo "$SCAN_OUTPUT" | grep -qE "move_on_refine_count="; then
        MOR=$(echo "$SCAN_OUTPUT" | grep -oE "move_on_refine_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$MOR" -ge 1 ]; then
            pass 1 "5 标签扫描 — 翻篇&精进 计数 (move_on_refine_count=$MOR)"
        else
            fail 1 "5 标签扫描 — 翻篇&精进 计数为 0"
            TC1_RESULT=1
        fi
    else
        fail 1 "5 标签扫描 — 缺 move_on_refine_count 字段"
        TC1_RESULT=1
    fi

    if echo "$SCAN_OUTPUT" | grep -qE "process_logic_count="; then
        PL=$(echo "$SCAN_OUTPUT" | grep -oE "process_logic_count=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$PL" -ge 1 ]; then
            pass 1 "5 标签扫描 — 流程逻辑 计数 (process_logic_count=$PL)"
        else
            fail 1 "5 标签扫描 — 流程逻辑 计数为 0"
            TC1_RESULT=1
        fi
    else
        fail 1 "5 标签扫描 — 缺 process_logic_count 字段"
        TC1_RESULT=1
    fi
else
    fail 1 "5 标签扫描 — scan_tags 函数缺失"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: 证据链校验 (每条引用带 file:line OR commit hash)
# ----------------------------------------
echo ">>> TC2: 证据链校验 — 每条引用带 file:line OR commit"
echo "=========================================="
TC2_RESULT=0

if declare -f validate_evidence_chain >/dev/null 2>&1; then
    # Validate tag-sop.md 自身: 5 标签 引用 全部带证据链
    VALIDATION=$(validate_evidence_chain "$SOP_DOC" 2>&1 || echo "FAIL")
    if echo "$VALIDATION" | grep -qE "evidence_ok="; then
        EVIDENCE_OK=$(echo "$VALIDATION" | grep -oE "evidence_ok=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        EVIDENCE_TOTAL=$(echo "$VALIDATION" | grep -oE "evidence_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$EVIDENCE_OK" -eq "$EVIDENCE_TOTAL" ] && [ "$EVIDENCE_TOTAL" -ge "$EXPECTED_TAG_COUNT" ]; then
            pass 2 "证据链校验 — SOP 5 标签 全部带证据 (evidence_ok=$EVIDENCE_OK/$EVIDENCE_TOTAL)"
        else
            fail 2 "证据链校验 — 缺证据 (evidence_ok=$EVIDENCE_OK/$EVIDENCE_TOTAL, 期望 ≥$EXPECTED_TAG_COUNT)"
            TC2_RESULT=1
        fi
    else
        fail 2 "证据链校验 — 缺 evidence_ok/evidence_total 字段"
        TC2_RESULT=1
    fi

    # Check 验证 SOP 5 标签都引用了具体的 file:line OR commit
    for tag in "反讽" "诚实修正" "独立" "翻篇" "流程逻辑"; do
        # 找 SOP 格式定义行: "跟\"<tag>\" 联合:" — 找具体的 tag 定义而非装饰引用
        SOP_DEF_LINE=$(grep -nE "跟[\"']?${tag}[\"']? 联合" "$SOP_DOC" 2>/dev/null | head -1 | cut -d: -f1 || echo "0")
        if [ "$SOP_DEF_LINE" -gt 0 ]; then
            CONTEXT=$(sed -n "${SOP_DEF_LINE},$((SOP_DEF_LINE + 5))p" "$SOP_DOC" 2>/dev/null)
            if echo "$CONTEXT" | grep -qE "$EVIDENCE_PATTERN"; then
                pass 2 "证据链校验 — '$tag' 引用带证据 (line $SOP_DEF_LINE)"
            else
                fail 2 "证据链校验 — '$tag' 引用缺证据 (line $SOP_DEF_LINE, 5 行内无 file:line/commit)"
                TC2_RESULT=1
            fi
        else
            fail 2 "证据链校验 — SOP 缺 '$tag' 标签定义 (跟\"$tag\" 联合: 格式)"
            TC2_RESULT=1
        fi
    done
else
    fail 2 "证据链校验 — validate_evidence_chain 函数缺失"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: 咒语化检测 (无证据链 装饰引用 = 违规)
# ----------------------------------------
echo ">>> TC3: 咒语化检测 — 无证据链 装饰引用"
echo "=========================================="
TC3_RESULT=0

if declare -f detect_cursed_references >/dev/null 2>&1; then
    CURSED=$(detect_cursed_references "$KALLAX_ROOT" 2>&1 || echo "FAIL")
    if echo "$CURSED" | grep -qE "cursed_total="; then
        CURSED_TOTAL=$(echo "$CURSED" | grep -oE "cursed_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$CURSED_TOTAL" -ge "$TARGET_CURSED_REDUCTION_MIN" ]; then
            pass 3 "咒语化检测 — 报告 ≥$TARGET_CURSED_REDUCTION_MIN 装饰引用 (cursed_total=$CURSED_TOTAL, 治 A2 治根)"
        else
            fail 3 "咒语化检测 — 报告 <$TARGET_CURSED_REDUCTION_MIN (cursed_total=$CURSED_TOTAL, 期望 ≥$TARGET_CURSED_REDUCTION_MIN)"
            TC3_RESULT=1
        fi
    else
        fail 3 "咒语化检测 — 缺 cursed_total 字段"
        TC3_RESULT=1
    fi

    # 验证 SOP 自身 0 咒语化
    SOP_CURSED=$(echo "$CURSED" | grep -oE "tag_sop_cursed=[0-9]+" | grep -oE "[0-9]+" || echo "0")
    if [ "$SOP_CURSED" -eq 0 ]; then
        pass 3 "咒语化检测 — SOP 自身 0 咒语化 (tag_sop_cursed=$SOP_CURSED)"
    else
        fail 3 "咒语化检测 — SOP 自身 含咒语化 (tag_sop_cursed=$SOP_CURSED, 期望 0)"
        TC3_RESULT=1
    fi

    # 验证 反讽 Top 1 重灾区 (KALLAX-GLOSSARY.md) 报告了咒语化
    if echo "$CURSED" | grep -qE "KALLAX-GLOSSARY.md"; then
        pass 3 "咒语化检测 — 报告 反讽 重灾区 (KALLAX-GLOSSARY.md 62 处)"
    else
        fail 3 "咒语化检测 — 未报告 反讽 重灾区"
        TC3_RESULT=1
    fi
else
    fail 3 "咒语化检测 — detect_cursed_references 函数缺失"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: 笔误识别 (e.g. "主公拍 explicit 拍 explicit")
# ----------------------------------------
echo ">>> TC4: 笔误识别 — '主公拍 explicit 拍 explicit'"
echo "=========================================="
TC4_RESULT=0

if declare -f detect_typos >/dev/null 2>&1; then
    TYPOS=$(detect_typos "$KALLAX_ROOT" 2>&1 || echo "FAIL")
    if echo "$TYPOS" | grep -qE "typo_total="; then
        TYPO_TOTAL=$(echo "$TYPOS" | grep -oE "typo_total=[0-9]+" | grep -oE "[0-9]+" || echo "0")
        if [ "$TYPO_TOTAL" -ge 2 ]; then
            pass 4 "笔误识别 — 报告 ≥2 处笔误 (typo_total=$TYPO_TOTAL, A3 治根)"
        else
            fail 4 "笔误识别 — 报告 <2 (typo_total=$TYPO_TOTAL, 期望 ≥2)"
            TC4_RESULT=1
        fi
    else
        fail 4 "笔误识别 — 缺 typo_total 字段"
        TC4_RESULT=1
    fi

    # 验证 报告 PHASE-REVIEW.md:11, 33 笔误
    if echo "$TYPOS" | grep -qE "PHASE-REVIEW.md.*:11"; then
        pass 4 "笔误识别 — 报告 PHASE-REVIEW.md:11 笔误"
    else
        fail 4 "笔误识别 — 未报告 PHASE-REVIEW.md:11 笔误"
        TC4_RESULT=1
    fi

    if echo "$TYPOS" | grep -qE "PHASE-REVIEW.md.*:33"; then
        pass 4 "笔误识别 — 报告 PHASE-REVIEW.md:33 笔误"
    else
        fail 4 "笔误识别 — 未报告 PHASE-REVIEW.md:33 笔误"
        TC4_RESULT=1
    fi
else
    fail 4 "笔误识别 — detect_typos 函数缺失"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: SOP 合规性 (5 标签 引用 全部符合 SOP)
# ----------------------------------------
echo ">>> TC5: SOP 合规性 — 5 标签 引用 符合证据链 3 件套"
echo "=========================================="
TC5_RESULT=0

if declare -f check_sop_compliance >/dev/null 2>&1; then
    COMPLIANCE=$(check_sop_compliance "$SOP_DOC" 2>&1 || echo "FAIL")
    if echo "$COMPLIANCE" | grep -qE "compliance_score="; then
        SCORE=$(echo "$COMPLIANCE" | grep -oE "compliance_score=[0-9.]+" | grep -oE "[0-9.]+" || echo "0")
        # Check 5 标签 全部 100% compliant
        if awk "BEGIN{exit !($SCORE == 100.0)}" 2>/dev/null; then
            pass 5 "SOP 合规性 — 5 标签 100% 合规 (compliance_score=$SCORE)"
        else
            fail 5 "SOP 合规性 — < 100% (compliance_score=$SCORE, 期望 100.0)"
            TC5_RESULT=1
        fi
    else
        fail 5 "SOP 合规性 — 缺 compliance_score 字段"
        TC5_RESULT=1
    fi

    # 验证 5 标签 全部有 证据链 3 件套 (证据 + 反驳/支持 + 影响)
    for tag in "反讽" "诚实修正" "独立" "翻篇" "流程逻辑"; do
        TAG_LINES=$(grep -n "$tag" "$SOP_DOC" 2>/dev/null | head -1 | cut -d: -f1 || echo "0")
        if [ "$TAG_LINES" -gt 0 ]; then
            CONTEXT=$(sed -n "${TAG_LINES},$((TAG_LINES + 30))p" "$SOP_DOC" 2>/dev/null)
            # 检查 3 件套: 证据 + 反驳/支持 + 影响
            HAS_EVIDENCE=0
            HAS_CASE=0
            HAS_IMPACT=0
            if echo "$CONTEXT" | grep -qE "(证据|file:|\.md:[0-9]+|commit [0-9a-f]{7,})"; then
                HAS_EVIDENCE=1
            fi
            if echo "$CONTEXT" | grep -qE "(反驳|支持|案例|例子|实测|case)"; then
                HAS_CASE=1
            fi
            if echo "$CONTEXT" | grep -qE "(影响|效果|治根|闭环|→|减少|↑|↓)"; then
                HAS_IMPACT=1
            fi

            if [ "$HAS_EVIDENCE" -eq 1 ] && [ "$HAS_CASE" -eq 1 ] && [ "$HAS_IMPACT" -eq 1 ]; then
                pass 5 "SOP 合规性 — '$tag' 证据链 3 件套 完整"
            else
                MISSING=""
                [ "$HAS_EVIDENCE" -eq 0 ] && MISSING="$MISSING 证据"
                [ "$HAS_CASE" -eq 0 ] && MISSING="$MISSING 案例"
                [ "$HAS_IMPACT" -eq 0 ] && MISSING="$MISSING 影响"
                fail 5 "SOP 合规性 — '$tag' 缺:$MISSING"
                TC5_RESULT=1
            fi
        else
            fail 5 "SOP 合规性 — SOP 缺 '$tag' 定义"
            TC5_RESULT=1
        fi
    done
else
    fail 5 "SOP 合规性 — check_sop_compliance 函数缺失"
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
