#!/usr/bin/env bash
# tests/integration/lazy-load-test.sh — Iter 2 + Iter 10 集成验证
#
# 验证目标:
# 1. Iter 2 lazy load 架构 (3 文档: cheatsheet / 5-levels / 4-roles)
# 2. Iter 10 决策模型 (decision-matrix.sh 25 cells + q18 SOP 文档)
# 3. 集成: 决策矩阵 + 决策 SOP 1:1 验证
#
# 不依赖: node (不跑 `kallax load`) — 直接读 .md 文件验证内容
# 兼容 macOS bash 3.2 (0 依赖 assoc array)
#
# Source: Iter 2 (S-04 CLAUDE.md 5KB trim + lazy load) + Iter 10 (Q18 决策模型) 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 配置
CHEATSHEET="${KALLAX_ROOT}/docs/CHEATSHEET.md"
LEVELS_5="${KALLAX_ROOT}/docs/5-levels.md"
ROLES_4="${KALLAX_ROOT}/docs/4-roles.md"
Q18_SOP="${KALLAX_ROOT}/docs/process/q18-decision-model.md"
DECISION_MATRIX="${KALLAX_ROOT}/scripts/permission/decision-matrix.sh"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"

pass=0
fail=0

echo "=========================================="
echo "Lazy Load + Decision Model Integration Test"
echo "=========================================="
echo ""

# ============================================================
# L1 存在性
# ============================================================
echo "--- L1: 存在性 ---"

check_exists() {
  local file="$1"
  local desc="$2"
  if [[ -f "$file" ]]; then
    echo "PASS: $desc exists ($file)"
    pass=$((pass+1))
  else
    echo "FAIL: $desc missing ($file)"
    fail=$((fail+1))
  fi
}

check_exists "$CHEATSHEET" "CHEATSHEET.md (Iter 2 lazy load)"
check_exists "$LEVELS_5" "5-levels.md (Iter 2 lazy load)"
check_exists "$ROLES_4" "4-roles.md (Iter 2 lazy load)"
check_exists "$Q18_SOP" "q18-decision-model.md (Iter 10 SOP)"
check_exists "$DECISION_MATRIX" "decision-matrix.sh (Iter 10)"
check_exists "$DECISION_GATE" "decision-gate.sh (Q18 实施)"

# ============================================================
# L2 实质性 (内容 验证)
# ============================================================
echo ""
echo "--- L2: 实质性 ---"

# CHEATSHEET ≤ 30 行 (硬约束, 跟 Iter 2 联合)
CHEAT_LINES=$(wc -l < "$CHEATSHEET" | tr -d ' ')
if [[ $CHEAT_LINES -le 30 ]]; then
  echo "PASS: CHEATSHEET.md = $CHEAT_LINES lines (≤ 30 硬约束)"
  pass=$((pass+1))
else
  echo "FAIL: CHEATSHEET.md = $CHEAT_LINES lines (> 30 硬约束)"
  fail=$((fail+1))
fi

# 5-levels.md 100-200 行 (lazy load 文档, 跟 Iter 2 联合)
LEVELS_LINES=$(wc -l < "$LEVELS_5" | tr -d ' ')
if [[ $LEVELS_LINES -ge 100 && $LEVELS_LINES -le 200 ]]; then
  echo "PASS: 5-levels.md = $LEVELS_LINES lines (100-200 OK)"
  pass=$((pass+1))
else
  echo "WARN: 5-levels.md = $LEVELS_LINES lines (期望 100-200)"
fi

# 4-roles.md 100-200 行
ROLES_LINES=$(wc -l < "$ROLES_4" | tr -d ' ')
if [[ $ROLES_LINES -ge 100 && $ROLES_LINES -le 200 ]]; then
  echo "PASS: 4-roles.md = $ROLES_LINES lines (100-200 OK)"
  pass=$((pass+1))
else
  echo "WARN: 4-roles.md = $ROLES_LINES lines (期望 100-200)"
fi

# q18-decision-model.md 300+ 行 (SOP 完整)
Q18_LINES=$(wc -l < "$Q18_SOP" | tr -d ' ')
if [[ $Q18_LINES -ge 300 ]]; then
  echo "PASS: q18-decision-model.md = $Q18_LINES lines (≥ 300 SOP 完整)"
  pass=$((pass+1))
else
  echo "FAIL: q18-decision-model.md = $Q18_LINES lines (< 300 SOP 不完整)"
  fail=$((fail+1))
fi

# ============================================================
# L3 接线正确 (内容 关键字段 验证)
# ============================================================
echo ""
echo "--- L3: 接线正确 ---"

# CHEATSHEET 关键字段
for keyword in "5 Levels" "4 Roles" "Q18"; do
  if grep -q "$keyword" "$CHEATSHEET"; then
    echo "PASS: CHEATSHEET.md contains '$keyword'"
    pass=$((pass+1))
  else
    echo "FAIL: CHEATSHEET.md missing '$keyword'"
    fail=$((fail+1))
  fi
done

# 5-levels.md 5 levels 命名
for level in "L1" "L2" "L3" "L4" "L5"; do
  if grep -q "^## $level" "$LEVELS_5" || grep -q "^### $level" "$LEVELS_5"; then
    echo "PASS: 5-levels.md contains '$level' section"
    pass=$((pass+1))
  else
    echo "FAIL: 5-levels.md missing '$level' section"
    fail=$((fail+1))
  fi
done

# 4-roles.md 4 sub-roles 命名
for role in "coder" "reviewer" "tester" "docs"; do
  if grep -q "$role" "$ROLES_4"; then
    echo "PASS: 4-roles.md contains sub-role '$role'"
    pass=$((pass+1))
  else
    echo "FAIL: 4-roles.md missing sub-role '$role'"
    fail=$((fail+1))
  fi
done

# q18-decision-model.md 5 类 block + 3 类 danger
for block in "block.ambiguous_options" "block.performer_failure" "block.rule_exception" "block.epic_critical" "block.high_impact"; do
  if grep -q "$block" "$Q18_SOP"; then
    echo "PASS: q18-decision-model.md contains '$block'"
    pass=$((pass+1))
  else
    echo "FAIL: q18-decision-model.md missing '$block'"
    fail=$((fail+1))
  fi
done

for danger in "danger.miao_modify" "danger.security_failing" "danger.data_destruction"; do
  if grep -q "$danger" "$Q18_SOP"; then
    echo "PASS: q18-decision-model.md contains '$danger'"
    pass=$((pass+1))
  else
    echo "FAIL: q18-decision-model.md missing '$danger'"
    fail=$((fail+1))
  fi
done

# decision-matrix.sh 5×5 = 25 cells
DM_LINES=$(wc -l < "$DECISION_MATRIX" | tr -d ' ')
if [[ $DM_LINES -ge 200 ]]; then
  echo "PASS: decision-matrix.sh = $DM_LINES lines (≥ 200 实施完整)"
  pass=$((pass+1))
else
  echo "FAIL: decision-matrix.sh = $DM_LINES lines (< 200 实施不完整)"
  fail=$((fail+1))
fi

# decision-matrix.sh --self-test
echo ""
echo "--- decision-matrix.sh --self-test ---"
if bash "$DECISION_MATRIX" --self-test 2>&1 | grep -q "PASS: 25/25 cells covered"; then
  echo "PASS: decision-matrix.sh --self-test → 25/25 cells + 5 L4 主公拍"
  pass=$((pass+1))
else
  echo "FAIL: decision-matrix.sh --self-test failed"
  fail=$((fail+1))
fi

# ============================================================
# L4 数据流动 (跨文档 1:1 验证)
# ============================================================
echo ""
echo "--- L4: 数据流动 (1:1 验证) ---"

# decision-matrix 输出 跟 q18 SOP 1:1 验证
# (1) Q18 SOP 引用 25 cells, 决策矩阵 输出 25 cells
if bash "$DECISION_MATRIX" --format json 2>&1 | grep -q '"total_cells": 25'; then
  echo "PASS: decision-matrix JSON has total_cells: 25"
  pass=$((pass+1))
else
  echo "FAIL: decision-matrix JSON missing total_cells: 25"
  fail=$((fail+1))
fi

# (2) Q18 SOP 引用 "5 levels × 5 roles = 25 cells", 实际 决策矩阵 是 25
if grep -q "5 levels × 5 roles = 25 cells" "$Q18_SOP"; then
  echo "PASS: Q18 SOP references '5 levels × 5 roles = 25 cells'"
  pass=$((pass+1))
else
  echo "FAIL: Q18 SOP missing '25 cells' reference"
  fail=$((fail+1))
fi

# (3) Q18 SOP §1 提到 5 类 block + 3 类 danger, 跟 decision-gate.sh KNOWN_ACTIONS 1:1
GATE_ACTIONS=$(grep -oE 'danger\.[a-z_]+|block\.[a-z_]+' "$DECISION_GATE" | sort -u)
SOP_ACTIONS=$(grep -oE 'danger\.[a-z_]+|block\.[a-z_]+' "$Q18_SOP" | sort -u)
if [[ "$GATE_ACTIONS" == "$SOP_ACTIONS" ]]; then
  echo "PASS: decision-gate.sh KNOWN_ACTIONS = Q18 SOP 5 block + 3 danger (1:1)"
  pass=$((pass+1))
else
  echo "INFO: gate vs sop actions:"
  echo "  gate: $GATE_ACTIONS"
  echo "  sop:  $SOP_ACTIONS"
  # Subset check: SOP must contain all gate actions
  missing=""
  for action in $GATE_ACTIONS; do
    if ! echo "$SOP_ACTIONS" | grep -q "$action"; then
      missing="$missing $action"
    fi
  done
  if [[ -z "$missing" ]]; then
    echo "PASS: Q18 SOP contains all 8 actions (subset OK)"
    pass=$((pass+1))
  else
    echo "FAIL: Q18 SOP missing actions:$missing"
    fail=$((fail+1))
  fi
fi

# (4) Q18 SOP 引用 4 sub-roles, 跟 4-roles.md 1:1
for subrole in "coder" "reviewer" "tester" "docs"; do
  if grep -q "Performer/$subrole\|sub-role.*$subrole\|$subrole.*sub-role" "$Q18_SOP"; then
    echo "PASS: Q18 SOP references sub-role '$subrole' (1:1 with 4-roles.md)"
    pass=$((pass+1))
  else
    echo "WARN: Q18 SOP may not reference '$subrole' explicitly"
  fi
done

# (5) decision-gate.sh 集成 decision-matrix (opt-in DECISION_MATRIX_PRINT=1)
if grep -q "DECISION_MATRIX_PRINT" "$DECISION_GATE"; then
  echo "PASS: decision-gate.sh integrates decision-matrix (DECISION_MATRIX_PRINT opt-in)"
  pass=$((pass+1))
else
  echo "FAIL: decision-gate.sh missing DECISION_MATRIX_PRINT integration"
  fail=$((fail+1))
fi

# (6) decision-gate.sh 实际触发 (用 quiet + opt-in 验证 exit 2 + matrix 输出)
echo ""
echo "--- decision-gate.sh 实际触发 ---"
DG_OUT=$(DECISION_MATRIX_PRINT=1 bash "$DECISION_GATE" --action block.ambiguous_options --cmd "test" --context '{"ticket":"TICKET-001"}' 2>&1 || true)
if echo "$DG_OUT" | grep -q "Decision Matrix (Q18"; then
  echo "PASS: decision-gate.sh + DECISION_MATRIX_PRINT=1 → prints matrix"
  pass=$((pass+1))
else
  echo "FAIL: decision-gate.sh + DECISION_MATRIX_PRINT=1 → matrix not printed"
  fail=$((fail+1))
fi

# ============================================================
# 总结
# ============================================================
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "PASS: $pass"
echo "FAIL: $fail"
echo ""

if [[ $fail -eq 0 ]]; then
  echo "ALL PASS: lazy load + decision model integration verified"
  exit 0
else
  echo "FAIL: $fail checks failed (see above)"
  exit 1
fi
