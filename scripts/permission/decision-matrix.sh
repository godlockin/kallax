#!/usr/bin/env bash
# scripts/permission/decision-matrix.sh — KALLAX 决策矩阵 (5 levels × 5 roles = 25 cells)
#
# 目的: 明确 "何时该问主公 / 何时 AI 自主 / 何时 Conductor 推" 的决策模式
# 跟 4-roles.md (Conductor + Performer 4 sub-roles) 联合
# 跟 5-levels.md (L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary) 联合
# 跟 Q18 决策模型 (KALLAX 评估+建议, 重大主公拍) 联合
# 跟 decision-gate.sh 5 类 block + 3 类 danger 联合
#
# 决策模式三档 (跟 Q18 一致):
#   自主  = AI 自主决定 (低风险 + 低争议)
#   推荐  = Conductor 推 + AI 跟 (中风险, Conductor 决定 OK)
#   主公拍 = 主公必须拍 (高风险 / 重大影响 / 规则例外)
#
# Usage:
#   bash scripts/permission/decision-matrix.sh                       # 输出 markdown table
#   bash scripts/permission/decision-matrix.sh --format json         # 输出 JSON
#   bash scripts/permission/decision-matrix.sh --cell <role> <level> # 输出单 cell
#   bash scripts/permission/decision-matrix.sh --check <role> <level> # 输出 mode
#   bash scripts/permission/decision-matrix.sh --self-test           # 自测
#
# 注: 5 levels × 5 roles = 25 cells (Conductor + 4 sub-roles).
# 简化展示: docs sub-role 跟 reviewer 同决策模式, 单列 5 roles 完整
#
# 兼容性: 0 依赖 bash 4 (macOS 3.2 bash 也支持), 用 case 替代 assoc array
#
# Source: Iter 10 (Q18 决策模型完整实施, 5×5=25 cell) + Rule 12 (3 模式) 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================
# Cell 查询 (5 levels × 5 roles = 25 cells)
# ============================================================
# 返回格式: "mode|justification"
# mode: 自主 | 推荐 | 主公拍
get_cell() {
  local role="$1"
  local level="$2"

  # L1: 5 cells 全 自主
  if [[ "$level" == "L1" || "$level" == "l1" || "$level" == "L1_git" ]]; then
    case "$role" in
      Conductor)         echo "自主|L1 git log 自审, Conductor 可自决" ;;
      Performer/coder)   echo "自主|coder 自证 commit 真存在 (L1 self-attest)" ;;
      Performer/reviewer) echo "自主|reviewer 自证 review SHA 真变" ;;
      Performer/tester)  echo "自主|tester 自证 test run SHA 真跑" ;;
      Performer/docs)    echo "自主|docs 自证 doc SHA 真变" ;;
      *) echo "UNKNOWN|role=$role (not in matrix)" >&2; return 1 ;;
    esac
    return 0
  fi

  # L2: 5 cells 全 自主
  if [[ "$level" == "L2" || "$level" == "l2" || "$level" == "L2_stdout" ]]; then
    case "$role" in
      Conductor)         echo "自主|L2 stdout 自审, Conductor 可自决" ;;
      Performer/coder)   echo "自主|coder 自证 cargo test stdout 真实" ;;
      Performer/reviewer) echo "自主|reviewer 自证 review stdout 真实" ;;
      Performer/tester)  echo "自主|tester 自证 raw stdout 跑过 (tester 自证)" ;;
      Performer/docs)    echo "自主|docs 自证 docs 1:1 验证 stdout" ;;
      *) echo "UNKNOWN|role=$role (not in matrix)" >&2; return 1 ;;
    esac
    return 0
  fi

  # L3: 5 cells (Conductor + coder + docs = 推荐, reviewer + tester = 自主)
  if [[ "$level" == "L3" || "$level" == "l3" || "$level" == "L3_4expert" ]]; then
    case "$role" in
      Conductor)         echo "推荐|L3 4-expert 评审, Conductor 派单 + 汇总" ;;
      Performer/coder)   echo "推荐|coder 接受 4-expert 评审, Conductor 派" ;;
      Performer/reviewer) echo "自主|reviewer 是 4-expert 之一, 自主审" ;;
      Performer/tester)  echo "自主|tester 是 4-expert 之一, 自主审" ;;
      Performer/docs)    echo "推荐|docs 接受 4-expert 中 docs 评审" ;;
      *) echo "UNKNOWN|role=$role (not in matrix)" >&2; return 1 ;;
    esac
    return 0
  fi

  # L4: 5 cells 全 主公拍 (independent witness 跨 subagent)
  if [[ "$level" == "L4" || "$level" == "l4" || "$level" == "L4_independent" ]]; then
    case "$role" in
      Conductor)         echo "主公拍|L4 independent witness 跨 subagent, 主公必拍" ;;
      Performer/coder)   echo "主公拍|L4 重跑 L1-L3, coder 不可自审" ;;
      Performer/reviewer) echo "主公拍|L4 witness 涉及 reviewer 独立性, 主公必拍" ;;
      Performer/tester)  echo "主公拍|L4 跨 subagent 独立见证, 主公必拍" ;;
      Performer/docs)    echo "主公拍|L4 跨 role 独立见证, 主公必拍" ;;
      *) echo "UNKNOWN|role=$role (not in matrix)" >&2; return 1 ;;
    esac
    return 0
  fi

  # L5: 5 cells 全 推荐
  if [[ "$level" == "L5" || "$level" == "l5" || "$level" == "L5_boundary" ]]; then
    case "$role" in
      Conductor)         echo "推荐|L5 边界/异常, Conductor 决定 + 备案" ;;
      Performer/coder)   echo "推荐|L5 边界 coder 实施, Conductor 派单决定" ;;
      Performer/reviewer) echo "推荐|L5 边界 reviewer 审, Conductor 决定" ;;
      Performer/tester)  echo "推荐|L5 边界 tester 测, Conductor 派单" ;;
      Performer/docs)    echo "推荐|L5 边界 docs 写, Conductor 派单" ;;
      *) echo "UNKNOWN|role=$role (not in matrix)" >&2; return 1 ;;
    esac
    return 0
  fi

  echo "UNKNOWN|level=$level (L1..L5 only)" >&2
  return 1
}

# mode 解析: "自主|..." → "自主"
parse_mode() {
  local cell="$1"
  echo "${cell%%|*}"
}

# ============================================================
# 输出
# ============================================================

emit_markdown() {
  cat <<'EOF'
# KALLAX 决策矩阵 (5 levels × 5 roles = 25 cells)

> **决策模式三档 (Q18 完整化)**:
> - **自主** = AI 自主决定 (低风险 + 低争议, Performer self-attest)
> - **推荐** = Conductor 推 + AI 跟 (中风险, Conductor 决定 OK)
> - **主公拍** = 主公必须拍 (高风险 / 重大影响 / 规则例外)

跟 4-roles.md (Conductor + 4 sub-roles) 联合, 跟 5-levels.md (L1-L5 验证机制) 联合.

## 矩阵 (5 levels × 5 roles)

| Role \ Level | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |
|---|---|---|---|---|---|
| Conductor          | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |
| Performer/coder    | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |
| Performer/reviewer | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| Performer/tester   | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| Performer/docs     | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |

**汇总**: 自主 12 cells + 推荐 8 cells + 主公拍 5 cells = 25 cells

## 决策模式 说明

### 自主 (12 cells: L1 全 5 + L2 全 5 + L3 reviewer + L3 tester = 12)
- L1 git log + L2 stdout 都是 Performer self-attest (自证), 风险低
- L3 中 reviewer + tester 是 4-expert 之一, 自主审 OK
- Conductor/Performer 各自执行, 不需要 escalate
- 反 "Performer 自报 PASS 实际 0 commit" (Rule 18 KPI falsification 联合)

### 推荐 (8 cells: L3 Conductor/coder/docs + L5 全 5 = 3 + 5 = 8)
- L3 4-expert 评审: 涉及跨 sub-role 协调, Conductor 派单 + 汇总
- L5 boundary/exception: 异常路径, Conductor 决定 + 备案
- Conductor 推, AI 跟; 不需主公拍 (主公仅备案)

### 主公拍 (5 cells: L4 全 5)
- L4 independent witness 跨 subagent 独立见证, 不可 AI 自主
- 任何 cell 进入 L4 → 主公必拍 (Rule 12 + Rule 18 联合)
- 反 "subagent 报 PASS 实际 0 commit" + "瞒报 witness fail"

## 跟 Q18 + Rule 12 + Rule 18 联合

| Q18 类别 | 矩阵对应 | 联合 |
|----------|----------|------|
| Q18-AI 自主 | 自主 12 cells | Performer 自证 (L1+L2 + L3 reviewer/tester) |
| Q18-AI 推荐 | 推荐 8 cells | Conductor 派单 (L3 Conductor/coder/docs + L5) |
| Q18-主公拍 | 主公拍 5 cells | L4 独立见证 (跨 subagent) |
| 5 类 block | 全部 cells | decision-gate.sh 命中 → 升级主公拍 |
| 3 类 danger | 全部 cells | 立即 stop + 主公拍 |
| Rule 18 KPI 黑名单 | L1/L2 自主 cell | 估数/verbatim = FAIL |

## 集成

- `decision-gate.sh --action block.*|danger.*` 命中 → 写 inbox/decision-*.md ask file + audit
- `decision-gate.sh` 启动时调 `decision-matrix.sh` 打印此表
- Conductor 派单时 `--cell <role> <level>` 返回模式, 决定 escalate
- Performer 完工时跑 `decision-matrix.sh --check <role> <level>` 确认决策模式
EOF
}

emit_json() {
  cat <<'EOF'
{
  "matrix": {
    "rows": [
      {"role": "Conductor",          "L1_git": "自主",  "L2_stdout": "自主",  "L3_4expert": "推荐",     "L4_independent": "主公拍", "L5_boundary": "推荐"},
      {"role": "Performer/coder",    "L1_git": "自主",  "L2_stdout": "自主",  "L3_4expert": "推荐",     "L4_independent": "主公拍", "L5_boundary": "推荐"},
      {"role": "Performer/reviewer", "L1_git": "自主",  "L2_stdout": "自主",  "L3_4expert": "自主",     "L4_independent": "主公拍", "L5_boundary": "推荐"},
      {"role": "Performer/tester",   "L1_git": "自主",  "L2_stdout": "自主",  "L3_4expert": "自主",     "L4_independent": "主公拍", "L5_boundary": "推荐"},
      {"role": "Performer/docs",     "L1_git": "自主",  "L2_stdout": "自主",  "L3_4expert": "推荐",     "L4_independent": "主公拍", "L5_boundary": "推荐"}
    ],
    "summary": {
      "自主_cells": 12,
      "推荐_cells": 8,
      "主公拍_cells": 5,
      "total_cells": 25
    },
    "rules": {
      "Q18_evaluate": "KALLAX 评估+建议",
      "Q18_主公拍": "重大影响 → 主公必拍",
      "Rule_12_modes": ["ai-auto", "ai-copilot", "manual"],
      "Rule_18_KPI": "KPI falsification = FAIL"
    }
  }
}
EOF
}

# ============================================================
# 自测 (5 levels × 5 roles = 25 cells 全 cover + 5 L4 主公拍)
# ============================================================
self_test() {
  local roles=("Conductor" "Performer/coder" "Performer/reviewer" "Performer/tester" "Performer/docs")
  local levels=("L1" "L2" "L3" "L4" "L5")
  local pass=0
  local fail=0
  for role in "${roles[@]}"; do
    for level in "${levels[@]}"; do
      local cell mode
      cell=$(get_cell "$role" "$level" 2>/dev/null) || {
        echo "FAIL: role=$role level=$level → get_cell error"
        fail=$((fail+1))
        continue
      }
      mode=$(parse_mode "$cell")
      if [[ "$mode" == "自主" || "$mode" == "推荐" || "$mode" == "主公拍" ]]; then
        pass=$((pass+1))
      else
        echo "FAIL: role=$role level=$level → unknown mode '$mode'"
        fail=$((fail+1))
      fi
    done
  done

  # 5 主公拍 (L4 × 5 roles)
  local zh_count=0
  for role in "${roles[@]}"; do
    local cell mode
    cell=$(get_cell "$role" "L4")
    mode=$(parse_mode "$cell")
    if [[ "$mode" == "主公拍" ]]; then
      zh_count=$((zh_count+1))
    fi
  done

  if [[ $pass -eq 25 && $fail -eq 0 && $zh_count -eq 5 ]]; then
    echo "PASS: 25/25 cells covered, 5 L4 主公拍 cells confirmed"
    return 0
  else
    echo "FAIL: pass=$pass fail=$fail zh_count=$zh_count (期望 25/0/5)"
    return 1
  fi
}

# ============================================================
# Main
# ============================================================
FORMAT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --cell)
      get_cell "$2" "$3"
      exit 0
      ;;
    --check)
      cell=$(get_cell "$2" "$3" 2>/dev/null) || { echo "ERROR" >&2; exit 1; }
      parse_mode "$cell"
      exit 0
      ;;
    --self-test)
      self_test
      exit $?
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--format markdown|json] [--cell <role> <level>] [--check <role> <level>] [--self-test]
  --format     输出格式 (markdown|json, default markdown)
  --cell       输出单 cell 内容 (role × level), 格式 "mode|justification"
  --check      输出单 cell 决策模式 (自主/推荐/主公拍)
  --self-test  自测 25 cells + 5 L4 主公拍

Roles: Conductor | Performer/coder | Performer/reviewer | Performer/tester | Performer/docs
Levels: L1 | L2 | L3 | L4 | L5
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

case "$FORMAT" in
  markdown|md) emit_markdown ;;
  json) emit_json ;;
  *) echo "Unknown format: $FORMAT" >&2; exit 1 ;;
esac
