#!/usr/bin/env bash
# tests/integration/decision-matrix-test.sh — Iter 11 决策模型 5 levels × 4 roles 1:1 验证
#
# 验证 decision-matrix.sh 完整覆盖 5 levels (L1-L5) × 4 Performer sub-roles (coder/reviewer/tester/docs) = 20 cells.
# 扩展: 5 levels × 5 roles (含 Conductor) = 25 cells.
#
# 决策模式三档 (Q18):
#   自主   = AI 自主决定 (低风险 + 低争议, Performer self-attest)
#   推荐   = Conductor 推 + AI 跟 (中风险, Conductor 决定 OK)
#   主公拍 = 主公必须拍 (高风险 / 重大影响 / 规则例外)
#
# Rule 9 KPI X/Y 格式: 20/20 = 100.0% PASS (no estimate, exact)
# Rule 8 4-Level Fact-Forcing: L1 存在性 + L2 实质性 + L3 接线正确 + L4 数据流动
#
# Source: Iter 10 (Q18 决策模型 5x5=25 cell) + Rule 12 (3 模式) + Iter 11 (端到端验证) 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly MATRIX_SCRIPT="$KALLAX_ROOT/scripts/permission/decision-matrix.sh"

# 5 levels
readonly LEVELS=("L1" "L2" "L3" "L4" "L5")
# 4 Performer sub-roles (跟 Rule 15 + EPIC-038-A sub-role schema 联合)
readonly SUBROLES=("Performer/coder" "Performer/reviewer" "Performer/tester" "Performer/docs")
# 5 roles (含 Conductor, 跟 decision-matrix.sh schema 1:1 联合)
readonly ROLES=("Conductor" "Performer/coder" "Performer/reviewer" "Performer/tester" "Performer/docs")

# ============================================================
# Test infrastructure
# ============================================================
TOTAL=0
PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); TOTAL=$((TOTAL + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); TOTAL=$((TOTAL + 1)); }
section() { echo ""; echo "============================================"; echo "$1"; echo "============================================"; }

# ============================================================
# Main
# ============================================================
echo "=========================================="
echo "Iter 11 — 决策模型 5 levels × 4 roles 1:1 验证"
echo "Rule 12 3 模式 + Q18 决策模型 + Rule 15 sub-role schema 联合"
echo "=========================================="
echo ""

# ============================================================
# Section A: 5 levels × 4 sub-roles = 20 cells
# ============================================================
section "A. 5 levels × 4 sub-roles = 20 cells (1:1 验证)"

CELL_OK=0
CELL_TOTAL=0
for role in "${SUBROLES[@]}"; do
  for level in "${LEVELS[@]}"; do
    CELL_TOTAL=$((CELL_TOTAL + 1))
    cell=$(bash "$MATRIX_SCRIPT" --check "$role" "$level" 2>&1)
    rc=$?
    if [[ "$rc" -eq 0 ]] && [[ "$cell" =~ ^(自主|推荐|主公拍)$ ]]; then
      CELL_OK=$((CELL_OK + 1))
    else
      log_fail "  [$role × $level] cell='$cell' rc=$rc (expected 自主/推荐/主公拍)"
    fi
  done
done

if [[ "$CELL_OK" -eq 20 ]]; then
  log_pass "20/20 cells PASS (4 sub-roles × 5 levels 全覆盖)"
else
  log_fail "20 cells: $CELL_OK/20 PASS"
fi

# ============================================================
# Section B: 5 levels × 5 roles (含 Conductor) = 25 cells
# ============================================================
section "B. 5 levels × 5 roles (含 Conductor) = 25 cells"

CELL5_OK=0
CELL5_TOTAL=0
for role in "${ROLES[@]}"; do
  for level in "${LEVELS[@]}"; do
    CELL5_TOTAL=$((CELL5_TOTAL + 1))
    cell=$(bash "$MATRIX_SCRIPT" --check "$role" "$level" 2>&1)
    rc=$?
    if [[ "$rc" -eq 0 ]] && [[ "$cell" =~ ^(自主|推荐|主公拍)$ ]]; then
      CELL5_OK=$((CELL5_OK + 1))
    else
      log_fail "  [$role × $level] cell='$cell' rc=$rc"
    fi
  done
done

if [[ "$CELL5_OK" -eq 25 ]]; then
  log_pass "25/25 cells PASS (5 roles × 5 levels 全覆盖)"
else
  log_fail "25 cells: $CELL5_OK/25 PASS"
fi

# ============================================================
# Section C: 决策模式分布 验证
# 期望: 12 自主 + 8 推荐 + 5 主公拍 = 25 cells
# ============================================================
section "C. 决策模式分布 (12 自主 + 8 推荐 + 5 主公拍 = 25)"

# 从 matrix 拉真实数据
MATRIX_JSON=$(bash "$MATRIX_SCRIPT" --format json 2>&1)
SELF_OK=$(echo "$MATRIX_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
m = d['matrix']['summary']
print(f\"{m['自主_cells']} {m['推荐_cells']} {m['主公拍_cells']} {m['total_cells']}\")
" 2>/dev/null || echo "PARSE_ERROR")

if [[ "$SELF_OK" == "12 8 5 25" ]]; then
  log_pass "决策模式分布 PASS (12 自主 + 8 推荐 + 5 主公拍 = 25 cells)"
else
  log_fail "决策模式分布: $SELF_OK (expected '12 8 5 25')"
fi

# ============================================================
# Section D: 4 L4 主公拍 cells (每个 role × L4 都必须主公拍)
# ============================================================
section "D. L4 主公拍 cells 验证 (5 roles × L4 = 5 cells, 全 主公拍)"

L4_OK=0
L4_TOTAL=0
for role in "${ROLES[@]}"; do
  L4_TOTAL=$((L4_TOTAL + 1))
  cell=$(bash "$MATRIX_SCRIPT" --check "$role" "L4" 2>&1)
  if [[ "$cell" == "主公拍" ]]; then
    L4_OK=$((L4_OK + 1))
  else
    log_fail "  [$role × L4] cell='$cell' (expected 主公拍)"
  fi
done

if [[ "$L4_OK" -eq 5 ]]; then
  log_pass "5/5 L4 cells 全 主公拍 (重大影响 必拍, 跟 Q18 一致)"
else
  log_fail "L4 cells: $L4_OK/5 主公拍"
fi

# ============================================================
# Section E: self-test 集成验证
# ============================================================
section "E. decision-matrix.sh --self-test 集成"

SELF_OUTPUT=$(bash "$MATRIX_SCRIPT" --self-test 2>&1)
SELF_RC=$?
if [[ "$SELF_RC" -eq 0 ]] && echo "$SELF_OUTPUT" | grep -qE "25/25 cells covered"; then
  log_pass "--self-test PASS ($SELF_OUTPUT)"
else
  log_fail "--self-test 失败: $SELF_OUTPUT (rc=$SELF_RC)"
fi

# ============================================================
# Section F: markdown table 输出验证 (跟 docs 联合)
# ============================================================
section "F. markdown table 输出验证 (跟 docs/decision-matrix.md 1:1)"

MD_OUTPUT=$(bash "$MATRIX_SCRIPT" 2>&1)
if echo "$MD_OUTPUT" | grep -qE "Conductor" && \
   echo "$MD_OUTPUT" | grep -qE "Performer/coder" && \
   echo "$MD_OUTPUT" | grep -qE "L1 git" && \
   echo "$MD_OUTPUT" | grep -qE "L4 independent" && \
   echo "$MD_OUTPUT" | grep -qE "主公拍"; then
  log_pass "markdown table 包含 5 roles + 5 levels + 主公拍 模式"
else
  log_fail "markdown table 输出不完整"
fi

# ============================================================
# Section G: Output 5 levels × 4 roles matrix (deliverable)
# ============================================================
section "G. 5 levels × 4 roles matrix (deliverable)"

# Count distribution: 自主 / 推荐 / 主公拍
DIST_ZIZHU=0
DIST_TUIJIAN=0
DIST_ZHUGONG=0
for role in "${SUBROLES[@]}"; do
  for level in "${LEVELS[@]}"; do
    cell=$(bash "$MATRIX_SCRIPT" --check "$role" "$level" 2>&1)
    case "$cell" in
      自主) DIST_ZIZHU=$((DIST_ZIZHU + 1)) ;;
      推荐) DIST_TUIJIAN=$((DIST_TUIJIAN + 1)) ;;
      主公拍) DIST_ZHUGONG=$((DIST_ZHUGONG + 1)) ;;
    esac
  done
done

if [[ "$DIST_ZIZHU" -eq 10 ]] && [[ "$DIST_TUIJIAN" -eq 6 ]] && [[ "$DIST_ZHUGONG" -eq 4 ]]; then
  log_pass "20 cells 分布: 10 自主 + 6 推荐 + 4 主公拍 = 20 (符合 schema 预期)"
else
  log_fail "20 cells 分布: $DIST_ZIZHU 自主 + $DIST_TUIJIAN 推荐 + $DIST_ZHUGONG 主公拍 (预期 10/6/4)"
fi

echo ""
echo "  | Role \\ Level | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |"
echo "  |---|---|---|---|---|---|"
for role in "${SUBROLES[@]}"; do
  L1=$(bash "$MATRIX_SCRIPT" --check "$role" "L1" 2>&1)
  L2=$(bash "$MATRIX_SCRIPT" --check "$role" "L2" 2>&1)
  L3=$(bash "$MATRIX_SCRIPT" --check "$role" "L3" 2>&1)
  L4=$(bash "$MATRIX_SCRIPT" --check "$role" "L4" 2>&1)
  L5=$(bash "$MATRIX_SCRIPT" --check "$role" "L5" 2>&1)
  L4_CELL=$([ "$L4" == "主公拍" ] && echo "**$L4**" || echo "$L4")
  echo "  | $role | $L1 | $L2 | $L3 | $L4_CELL | $L5 |"
done
echo ""
echo "  汇总 (4 sub-roles × 5 levels = 20 cells):"
echo "  - 自主: $DIST_ZIZHU cells"
echo "  - 推荐: $DIST_TUIJIAN cells"
echo "  - 主公拍: $DIST_ZHUGONG cells"
echo "  - 验证: $DIST_ZIZHU + $DIST_TUIJIAN + $DIST_ZHUGONG = $((DIST_ZIZHU + DIST_TUIJIAN + DIST_ZHUGONG)) cells"
echo ""

# ============================================================
# Final summary
# ============================================================
section "Iter 11 决策模型 测试 总结"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo ""
  echo "  全部 checks PASS: $PASS_COUNT/$TOTAL"
  echo "  - 4 sub-roles × 5 levels = 20 cells: 20/20 PASS"
  echo "  - 5 roles × 5 levels = 25 cells: 25/25 PASS"
  echo "  - 决策模式分布: 12 自主 + 8 推荐 + 5 主公拍"
  echo "  - 5 L4 主公拍 cells: 5/5 PASS"
  echo "  - --self-test: PASS"
  echo "  - markdown table: PASS"
  echo ""
  echo "=========================================="
  echo "RESULT: 20/20 + 25/25 cells 全 PASS — 决策模型 1:1 验证 完成"
  echo "=========================================="
  exit 0
else
  echo ""
  echo "  PASS: $PASS_COUNT / FAIL: $FAIL_COUNT / TOTAL: $TOTAL"
  echo ""
  echo "=========================================="
  echo "RESULT: 决策模型 测试 部分 FAIL"
  echo "=========================================="
  exit 1
fi
