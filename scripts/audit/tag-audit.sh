#!/usr/bin/env bash
# scripts/audit/tag-audit.sh — 5 标签扫描 + 证据链校验 + 咒语化检测 + 笔误识别 (EPIC-055-C)
# 5 标签 SOP: 反讽/诚实修正/独立/翻篇&精进/流程逻辑
# 治 A2 反讽咒语化 + A3 笔误 (主公拍 explicit 拍 explicit)
#
# 证据链 3 件套 (5 标签 SOP 强制):
#   1. 证据 (file:line OR commit hash)
#   2. 反驳/支持案例
#   3. 实际影响
#
# 跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合
# 跟 EPIC-055-A CLAUDE+GLOSSARY 去重 联合
# 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
# 跟 14-ISSUES-INTAKE-2026-06-16.md Part 4 联合
# 跟 KALLAX-GLOSSARY.md §1.1-1.5 联合
# 跟"诚实修正" 战略 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 Rule 5 DRY 联动 — 标签引用去重

set -uo pipefail

# Source guard — only run main when executed, not when sourced for tests
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    MAIN_MODE=0
else
    MAIN_MODE=1
fi

readonly KALLAX_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Constants (Rule 4: no magic numbers, name all)
readonly TAG_IRONY="反讽"
readonly TAG_HONEST_CORRECTION="诚实修正"
readonly TAG_INDEPENDENCE="独立"
readonly TAG_MOVE_ON_REFINE="翻篇"
readonly TAG_PROCESS_LOGIC="流程逻辑"
readonly TYPO_PATTERN="主公拍 explicit 拍 explicit"
readonly SOP_DOC_REL="docs/process/tag-sop.md"

# 5 标签 数组 (跟 KALLAX-GLOSSARY.md §1.1-1.5 联动)
readonly TAGS=(
    "$TAG_IRONY"
    "$TAG_HONEST_CORRECTION"
    "$TAG_INDEPENDENCE"
    "$TAG_MOVE_ON_REFINE"
    "$TAG_PROCESS_LOGIC"
)

# Evidence pattern — file:line (any extension) OR commit hash OR 40-char SHA
# Match: "file:" literal OR ".ext:NN" OR "commit <hash>" OR "commit_sha=" OR 40-char hex
readonly EVIDENCE_PATTERN='(file:|[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+|commit [0-9a-f]{7,}|commit_sha=|[0-9a-f]{40})'

# ----------------------------------------
# scan_tags — 5 标签频率统计
# 输出: irony_count=N honest_correction_count=N independence_count=N move_on_refine_count=N process_logic_count=N total=N
# ----------------------------------------
scan_tags() {
    local root="${1:-$KALLAX_ROOT}"

    local irony=0
    local hc=0
    local ind=0
    local mor=0
    local pl=0

    if [ -d "$root" ]; then
        irony=$(rg -c "$TAG_IRONY" --type md "$root" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
        hc=$(rg -c "$TAG_HONEST_CORRECTION" --type md "$root" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
        ind=$(rg -c "$TAG_INDEPENDENCE" --type md "$root" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
        mor=$(rg -c "$TAG_MOVE_ON_REFINE" --type md "$root" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
        pl=$(rg -c "$TAG_PROCESS_LOGIC" --type md "$root" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
    fi

    local total=$((irony + hc + ind + mor + pl))
    echo "irony_count=$irony honest_correction_count=$hc independence_count=$ind move_on_refine_count=$mor process_logic_count=$pl total=$total"
}

# ----------------------------------------
# validate_evidence_chain — 校验 文档 中 5 标签 引用 是否带 证据链 (file:line OR commit)
# 输出: evidence_ok=N evidence_total=N tag_sop_cursed=0
# ----------------------------------------
validate_evidence_chain() {
    local doc="$1"

    if [ ! -f "$doc" ]; then
        echo "evidence_ok=0 evidence_total=0"
        return 0
    fi

    local evidence_ok=0
    local evidence_total=0

    for tag in "${TAGS[@]}"; do
        # 提取 doc 中 含 tag 的所有行
        local tag_lines
        tag_lines=$(grep -n "$tag" "$doc" 2>/dev/null | cut -d: -f1 || echo "")
        if [ -z "$tag_lines" ]; then
            continue
        fi

        # 对每行 tag 引用, 检查 后续 5 行内 是否有 证据 (file:line / commit / commit_sha)
        for line in $tag_lines; do
            evidence_total=$((evidence_total + 1))
            local context
            context=$(sed -n "${line},$((line + 5))p" "$doc" 2>/dev/null)
            if echo "$context" | grep -qE "$EVIDENCE_PATTERN"; then
                evidence_ok=$((evidence_ok + 1))
            fi
        done
    done

    echo "evidence_ok=$evidence_ok evidence_total=$evidence_total"
}

# ----------------------------------------
# detect_cursed_references — 咒语化引用检测 (无证据链 装饰引用)
# A2 治根: 50+ 反讽咒语化 闭环
# 输出: cursed_total=N tag_sop_cursed=N [file:line: tag] ...
# ----------------------------------------
detect_cursed_references() {
    local root="${1:-$KALLAX_ROOT}"

    local cursed_total=0
    local tag_sop_cursed=0
    local report=""

    if [ ! -d "$root" ]; then
        echo "cursed_total=0 tag_sop_cursed=0"
        return 0
    fi

    for tag in "${TAGS[@]}"; do
        # 扫所有 .md 文件, 找含 tag 的行, 检查 是否在 5 行内有证据
        while IFS= read -r match; do
            [ -z "$match" ] && continue
            local file
            local line
            file=$(echo "$match" | cut -d: -f1)
            line=$(echo "$match" | cut -d: -f2)

            if [ ! -f "$file" ]; then
                continue
            fi

            local context
            context=$(sed -n "${line},$((line + 5))p" "$file" 2>/dev/null)
            # 如果 5 行内 无 证据 (file:line / commit / commit_sha) → 咒语化
            if ! echo "$context" | grep -qE "$EVIDENCE_PATTERN"; then
                cursed_total=$((cursed_total + 1))
                # 检查是否是 SOP 自身
                if echo "$file" | grep -qE "(tag-sop\.md|EPIC-055-C.*tag-sop)"; then
                    tag_sop_cursed=$((tag_sop_cursed + 1))
                fi
                # 累加 Top 重灾区报告
                if echo "$file" | grep -qE "KALLAX-GLOSSARY.md"; then
                    report="$report\nKALLAX-GLOSSARY.md:$line: $tag (反讽 重灾区)"
                fi
            fi
        done < <(rg -n "$tag" --type md "$root" 2>/dev/null)
    done

    echo -e "cursed_total=$cursed_total tag_sop_cursed=$tag_sop_cursed$report"
}

# ----------------------------------------
# detect_typos — 笔误识别 (A3 治根)
# "主公拍 explicit 拍 explicit" → 笔误/重复
# 输出: typo_total=N [file:line: typo] ...
# ----------------------------------------
detect_typos() {
    local root="${1:-$KALLAX_ROOT}"

    local typo_total=0
    local report=""

    if [ ! -d "$root" ]; then
        echo "typo_total=0"
        return 0
    fi

    # Pattern 1: 主公拍 explicit 拍 explicit (A3 已知笔误)
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        local file
        local line
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)

        if [ -f "$file" ]; then
            typo_total=$((typo_total + 1))
            report="$report\n$file:$line: $TYPO_PATTERN (A3 笔误)"
        fi
    done < <(rg -n "$TYPO_PATTERN" "$root" 2>/dev/null)

    echo -e "typo_total=$typo_total$report"
}

# ----------------------------------------
# check_sop_compliance — SOP 合规性 (5 标签 全部符合证据链 3 件套)
# 证据链 3 件套: 证据 + 反驳/支持案例 + 实际影响
# 输出: compliance_score=100.0 OR <100.0 [tag: missing...]
# ----------------------------------------
check_sop_compliance() {
    local doc="$1"

    if [ ! -f "$doc" ]; then
        echo "compliance_score=0.0"
        return 0
    fi

    local compliant_tags=0
    local total_tags=0
    local missing_report=""

    for tag in "${TAGS[@]}"; do
        local tag_line
        tag_line=$(grep -n "$tag" "$doc" 2>/dev/null | head -1 | cut -d: -f1 || echo "0")
        if [ "$tag_line" -eq 0 ]; then
            missing_report="$missing_report $tag(缺定义)"
            continue
        fi

        total_tags=$((total_tags + 1))

        # 检查 后续 30 行 是否有 证据链 3 件套
        local context
        context=$(sed -n "${tag_line},$((tag_line + 30))p" "$doc" 2>/dev/null)

        local has_evidence=0
        local has_case=0
        local has_impact=0

        # 证据: file:line OR commit hash OR commit_sha
        if echo "$context" | grep -qE "(证据|file:|\.md:[0-9]+|commit [0-9a-f]{7,}|commit_sha=)"; then
            has_evidence=1
        fi
        # 反驳/支持案例: 含 反驳 / 支持 / 案例 / 例子 / 实测 / case
        if echo "$context" | grep -qE "(反驳|支持|案例|例子|实测|case)"; then
            has_case=1
        fi
        # 实际影响: 含 影响 / 效果 / 治根 / 闭环 / → / 减少 / ↑ / ↓
        if echo "$context" | grep -qE "(影响|效果|治根|闭环|→|减少|↑|↓)"; then
            has_impact=1
        fi

        if [ "$has_evidence" -eq 1 ] && [ "$has_case" -eq 1 ] && [ "$has_impact" -eq 1 ]; then
            compliant_tags=$((compliant_tags + 1))
        else
            local missing=""
            [ "$has_evidence" -eq 0 ] && missing="$missing 证据"
            [ "$has_case" -eq 0 ] && missing="$missing 案例"
            [ "$has_impact" -eq 0 ] && missing="$missing 影响"
            missing_report="$missing_report $tag(缺:$missing)"
        fi
    done

    if [ "$total_tags" -gt 0 ]; then
        local score
        score=$(awk "BEGIN{printf \"%.1f\", $compliant_tags * 100 / $total_tags}")
        echo "compliance_score=$score missing: $missing_report"
    else
        echo "compliance_score=0.0"
    fi
}

# ----------------------------------------
# Main entry — only when executed directly
# ----------------------------------------
if [ "$MAIN_MODE" = "1" ]; then
    case "${1:-help}" in
        scan)
            shift
            scan_tags "$@"
            ;;
        validate)
            shift
            validate_evidence_chain "$@"
            ;;
        cursed)
            shift
            detect_cursed_references "$@"
            ;;
        typo|typos)
            shift
            detect_typos "$@"
            ;;
        compliance)
            shift
            check_sop_compliance "$@"
            ;;
        all)
            echo "=== scan_tags ==="
            scan_tags "${2:-$KALLAX_ROOT}"
            echo ""
            echo "=== validate_evidence_chain ($SOP_DOC_REL) ==="
            validate_evidence_chain "$KALLAX_ROOT/$SOP_DOC_REL"
            echo ""
            echo "=== detect_cursed_references ==="
            detect_cursed_references "${2:-$KALLAX_ROOT}"
            echo ""
            echo "=== detect_typos ==="
            detect_typos "${2:-$KALLAX_ROOT}"
            echo ""
            echo "=== check_sop_compliance ($SOP_DOC_REL) ==="
            check_sop_compliance "$KALLAX_ROOT/$SOP_DOC_REL"
            ;;
        help|*)
            cat <<EOF
Usage: tag-audit.sh <command> [args]

Commands:
  scan [root]                          Scan 5 tag frequencies
  validate <doc>                       Validate evidence chain in doc
  cursed [root]                        Detect cursed (no-evidence) tag references
  typo [root]                          Detect typos (主公拍 explicit 拍 explicit)
  compliance <doc>                     Check SOP compliance (evidence + case + impact)
  all [root]                           Run all checks

EPIC-055-C | 5 标签 SOP | A2 咒语化 + A3 笔误 治根
EOF
            ;;
    esac
fi
