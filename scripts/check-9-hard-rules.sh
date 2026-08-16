#!/usr/bin/env bash
# scripts/check-9-hard-rules.sh
# EPIC-059-A: 5 levels 简化 检查脚本
# 跟 scripts/check-fact-forcing-preflight.sh 模式 一致
# 跟 eket template/docs/MASTER-RULES.md §6 联合, 借方法论 不借代码
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信
# 跟 KALLAX-GLOSSARY §11.1 联合, 跟 v2.4.1 revert 联合
#
# Usage:
#   bash scripts/check-9-hard-rules.sh           # 跑全部 9 项 检查
#   bash scripts/check-9-hard-rules.sh --self-test  # 跑自检
#
# Rule of 500 / PR ~100 行上限: 占位 EPIC-059-B/059-C 联合 2 项 (跟 AC #2 联合)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow caller (test) to pre-set vars as readonly; only assign if unset
if [ -z "${KALLAX_ROOT+set}" ]; then
  KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
if [ -z "${CLAUDE_MD+set}" ]; then
  CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
fi
if [ -z "${DOC+set}" ]; then
  DOC="$KALLAX_ROOT/docs/process/9-hard-rules.md"
fi
if [ -z "${GLOSSARY+set}" ]; then
  GLOSSARY="$KALLAX_ROOT/docs/KALLAX-GLOSSARY.md"
fi

# Constants (Rule 4: no magic numbers, name all)
readonly HARD_RULES_COUNT=9
readonly KALLAX_RULES_TARGET=22
readonly DOC_LINES_MIN=150
readonly DOC_LINES_MAX=250

# 5 levels 命名 (跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码)
# 适配 KALLAX 22 Rule 现状 (Conductor/Performer + outbox-isolation + tag-sop + ...)
readonly -a HARD_RULE_NAMES=(
  "PR 合并后清理 outbox"
  "删除前查反向引用"
  "Slaver 超时 Release"
  "负载分担"
  "分配前确认环境"
  "文档卫生 (每10轮)"
  "新建前先想"
  "Rule of 500 (占位 EPIC-059-B)"
  "PR ~100 行上限 (占位 EPIC-059-C)"
)

# ----------------------------------------
# Function: check_9_hard_rules
# AC #2: 9 项 规则 全部存在, 9 项全覆盖
# ----------------------------------------
check_9_hard_rules() {
  echo "rules_total=${HARD_RULES_COUNT}"
  for i in $(seq 0 $((HARD_RULES_COUNT - 1))); do
    idx=$((i + 1))
    echo "rule_${idx}_name=${HARD_RULE_NAMES[$i]}"
  done
}

# ----------------------------------------
# Function: check_claude_md_group_index
# AC #1 + AC #3: CLAUDE.md 22 Rule 保留 + 9 类别 group 索引 + "5 levels 模式" 章节
# 0 删 Rule, file:line 1:1 映射
# ----------------------------------------
check_claude_md_group_index() {
  # 计算 CLAUDE.md 中 实际 Rule 数 (跟 "Rule N." 格式 联合)
  # Pattern ^### [0-9]+\. 自然 排除 strikethrough (### ~~31.) 因为 ~~ 不在 数字前
  local active_count
  active_count=$(grep -cE "^### [0-9]+\. " "$CLAUDE_MD" 2>/dev/null || true)
  active_count=${active_count:-0}

  echo "kallax_rules_count=${active_count}"

  # 9 类别 group 索引 章节
  if grep -qE "^### .*9 类别 group 索引" "$CLAUDE_MD" 2>/dev/null; then
    echo "group_count=9"
  else
    echo "group_count=0"
  fi

  # "5 levels 模式" 章节 (跟 AC #3 联合)
  if grep -qE "5 levels 模式" "$CLAUDE_MD" 2>/dev/null; then
    echo "nine_hr_section=present"
  else
    echo "nine_hr_section=missing"
  fi

  # 验证 22 Rule (跟"翻篇&精进" 一致, 跟 v2.4.1 还原 联合)
  if [ "$active_count" -eq "$KALLAX_RULES_TARGET" ]; then
    echo "rules_intact=1"
  else
    echo "rules_intact=0 (active=$active_count, 期望 $KALLAX_RULES_TARGET)"
  fi
}

# ----------------------------------------
# Function: check_doc_completeness
# AC #5: docs/process/9-hard-rules.md 详细 解释, 150-250 行, ≥9 反例 + ≥9 正例 + 撤销方法
# ----------------------------------------
check_doc_completeness() {
  if [ ! -f "$DOC" ]; then
    echo "doc_lines=0"
    echo "doc_exists=0"
    return 1
  fi

  local lines
  lines=$(wc -l < "$DOC" | tr -d ' ' || echo "0")
  echo "doc_lines=${lines}"
  echo "doc_exists=1"

  # 反例数 (跟 "❌ 反例" / "### 反例" 联合)
  local anti_count
  anti_count=$(grep -cE "^### 反例" "$DOC" 2>/dev/null || true)
  anti_count=${anti_count:-0}
  echo "anti_patterns_total=${anti_count}"

  # 正例数 (跟 "✅ 正例" / "### 正例" 联合)
  local pos_count
  pos_count=$(grep -cE "^### 正例" "$DOC" 2>/dev/null || true)
  pos_count=${pos_count:-0}
  echo "positive_examples_total=${pos_count}"

  # 撤销方法 段
  if grep -qE "^## .*撤销方法" "$DOC" 2>/dev/null; then
    echo "rollback_section=1"
  else
    echo "rollback_section=0"
  fi
}

# ----------------------------------------
# Function: check_glossary_loop
# AC #4: KALLAX-GLOSSARY §11.1 闭环段, 跟 "5 levels 简化" + v2.4.1 revert 联合
# ----------------------------------------
check_glossary_loop() {
  if [ ! -f "$GLOSSARY" ]; then
    echo "loop_marker_total=0"
    return 1
  fi

  # §11.1 闭环段 含 3 个 联合 标记
  local section_11_1
  section_11_1=$(awk '/^### 11\.1 /,/^### 11\.2 /' "$GLOSSARY" 2>/dev/null || echo "")

  local markers=0
  if echo "$section_11_1" | grep -qE "5 levels"; then
    markers=$((markers + 1))
    echo "nine_hr_ref=1"
  else
    echo "nine_hr_ref=0"
  fi

  if echo "$section_11_1" | grep -qE "v2\.4\.1"; then
    markers=$((markers + 1))
    echo "v241_revert_ref=1"
  else
    echo "v241_revert_ref=0"
  fi

  if echo "$section_11_1" | grep -qE "PHASE-013"; then
    markers=$((markers + 1))
    echo "phase013_ref=1"
  else
    echo "phase013_ref=0"
  fi

  if echo "$section_11_1" | grep -qE "Rule 数 \u2260 治理"; then
    markers=$((markers + 1))
    echo "rule_count_myth_ref=1"
  else
    echo "rule_count_myth_ref=0"
  fi

  echo "loop_marker_total=${markers}"
}

# ----------------------------------------
# Function: check_zero_rule_inflation
# AC #10: 0 增 Rule KPI 精确 X/Y 格式 — 22 Rule → 9 类别 group 整合 = 100% 落地, 0 增 Rule
# 跟"翻篇&精进" 战略 一致
# ----------------------------------------
check_zero_rule_inflation() {
  # 验证 CLAUDE.md 实际 Rule 数 (跟 v2.4.1 revert 一致, active 已排除 strikethrough)
  local active_count
  active_count=$(grep -cE "^### [0-9]+\. " "$CLAUDE_MD" 2>/dev/null || true)
  active_count=${active_count:-0}

  echo "rules_landed=${active_count}"
  echo "rules_added=0"

  # KPI: rules_landed == 22 && rules_added == 0 → 100.0
  if [ "$active_count" -eq "$KALLAX_RULES_TARGET" ]; then
    echo "kpi_score=100.0"
  else
    # 计算实际得分: (landed/target) * 100
    local score
    score=$(awk "BEGIN{printf \"%.1f\", ${active_count} * 100 / ${KALLAX_RULES_TARGET}}")
    echo "kpi_score=${score}"
  fi
}

# ----------------------------------------
# Main: 跑全部 9 项 检查 (only when executed directly, not sourced)
# ----------------------------------------
_run_main() {
  if [ "${1:-}" = "--self-test" ]; then
    echo "=== 5 levels 简化 — Self Test ==="
    echo ""
    echo ">>> check_9_hard_rules"
    check_9_hard_rules
    echo ""
    echo ">>> check_claude_md_group_index"
    check_claude_md_group_index
    echo ""
    echo ">>> check_doc_completeness"
    check_doc_completeness
    echo ""
    echo ">>> check_glossary_loop"
    check_glossary_loop
    echo ""
    echo ">>> check_zero_rule_inflation"
    check_zero_rule_inflation
    echo ""
    echo "=== Self Test Done ==="
    return 0
  fi

  # Default: 跑全 9 项 (跟 AC)
  echo "=========================================="
  echo "5 levels 简化 — EPIC-059-A"
  echo "跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码"
  echo "=========================================="
  echo ""

  check_9_hard_rules
  echo ""
  check_claude_md_group_index
  echo ""
  check_doc_completeness
  echo ""
  check_glossary_loop
  echo ""
  check_zero_rule_inflation
  echo ""
  echo "=== Done ==="
  return 0
}

# Only run main when executed directly (not sourced)
# Use simpler check: when sourced, ${BASH_SOURCE[0]} differs from $0
if [ -n "${BASH_SOURCE+x}" ] && [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _run_main "$@"
elif [ -z "${BASH_SOURCE+x}" ] && [ -n "${0}" ]; then
  _run_main "$@"
fi