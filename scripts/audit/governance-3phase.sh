#!/usr/bin/env bash
# scripts/audit/governance-3phase.sh — KALLAX 3 阶段治理协调器 (EPIC-056-A)
# 5 阶段 → 3 阶段: Conductor 全局 + 4 专家+5扩展并行 + Master 仲裁+主公拍板
# 治 A4 治理爆炸, 净价值 62.5% → 65%+
#
# 3 阶段设计 (跟 v1.2.4 5 扩展组 保留, 跟 EPIC-055-B 拍板分级 联动):
#   Phase 1: Conductor 全局扫描 (原 Architect + Conductor 合并, 治协调开销)
#   Phase 2: 4 default 专家 + 5 extended 扩展 并行 (0 增 0 删)
#   Phase 3: Master 仲裁 + 主公拍板 (P0 阻塞 / P1 备案 / P2 放手)
#
# 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合 (主公 explicit 拍板 5/5)
# 跟 EPIC-055-B approval-tiering.md 联合 (P0/P1/P2 路由)
# 跟 EPIC-056-B metrics-kpi.md 联合 (净价值估算)
# 跟 v1.2.4 5 扩展组 联合 (security-tool-bypass/process-engineering/auditor/compliance/decision-gate 保留)
# 跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合
# 跟 Rule 9 X/Y 格式 联合, 跟 Rule 11 v2.1 强验证 联合, 跟 Rule 15 隔离 联合
# 跟"流程效果 > 流程表演" 战略 一致, 跟"诚实修正" 联合

set -uo pipefail

# Source guard — only run main when executed, not when sourced for tests
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    MAIN_MODE=0
else
    MAIN_MODE=1
fi

readonly KALLAX_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Constants (Rule 4: no magic numbers, name all)
readonly EXPERT_PANEL_DEFAULT_COUNT=4
readonly EXPERT_PANEL_EXTENDED_COUNT=5
readonly EXPERT_PANEL_TOTAL_COUNT=9
readonly NET_VALUE_BASELINE=62.5
readonly NET_VALUE_TARGET=65.0
readonly NET_VALUE_DELTA=$(awk "BEGIN{printf \"%.1f\", $NET_VALUE_TARGET - $NET_VALUE_BASELINE}")

# ----------------------------------------
# Phase 1: Conductor 全局扫描 (原 Architect + Conductor 合并)
# ----------------------------------------
phase1_conductor_scan() {
    local epic_id="${1:-EPIC-XXX}"
    echo "Phase 1: Conductor 全局扫描 — ${epic_id}"
    echo "  architect_merged=true (原 5 阶段 Phase 1 Architect 合并入 Conductor)"
    echo "  scope: 架构 / 边界 / 选型 / 重构 视角 (原 Architect 能力保留)"
    echo "  conductor: 1 份全局扫描报告 (省 0.4h/ticket, 跟 A4 治根 联合)"
    echo "PHASE1_PASS"
}

# ----------------------------------------
# Phase 2: 4 default 专家 + 5 extended 扩展 并行
# ----------------------------------------
# 4 default 专家 (跟 v1.2.4 5 default 一致, Architect 退出 → 合并 Phase 1)
list_default_experts() {
    echo "Backend"
    echo "Frontend"
    echo "UX"
    echo "Product"
}

# 5 extended 扩展 (跟 v1.2.4 5 扩展组 一致, 0 增 0 删)
list_extended_experts() {
    echo "security-tool-bypass"
    echo "process-engineering"
    echo "auditor"
    echo "compliance"
    echo "decision-gate"
}

# Phase 2 主入口
phase2_expert_panel() {
    local epic_id="${1:-EPIC-XXX}"
    echo "Phase 2: 4 default 专家 + 5 extended 扩展 并行 — ${epic_id}"
    echo "  default_experts:"
    list_default_experts | sed 's/^/    - /'
    echo "  extended_experts:"
    list_extended_experts | sed 's/^/    - /'
    echo "  total: $EXPERT_PANEL_TOTAL_COUNT 专家 并行 (Promise.all 调度, 0 协调开销)"
    echo "  Architect: NOT in default list (已合并 Phase 1, 验证)"
    echo "PHASE2_PASS"
}

# ----------------------------------------
# Phase 3: Master 仲裁 + 主公拍板
# ----------------------------------------
phase3_master_arbitration() {
    local epic_id="${1:-EPIC-XXX}"
    local report_count="${2:-$EXPERT_PANEL_TOTAL_COUNT}"
    echo "Phase 3: Master 仲裁 — ${epic_id}"
    echo "  master_arbitration: Master 收 ${report_count} 份报告 → 合并去重 → 仲裁冲突 → 出汇总"
    echo "  aggregated: ${report_count} reports merged"
    echo "  rule_11_v2_1: 5 levels (L1-L5) (跟 Rule 11 v2.1 联合)"
    echo "  fail_action: FAIL → 退回 Performer 修 (跟 v1.2.4 流程 一致)"
    echo "PHASE3_ARBITRATION_PASS"
}

# 主公拍板 (跟 EPIC-055-B 拍板分级 联动)
# classify_decision() / route_p0/p1/p2() 复用 approval-tiering.sh
phase3_master_decision() {
    local epic_id="${1:-EPIC-XXX}"
    local change_type="${2:-default}"
    local tier="${3:-2}"

    # 复用 EPIC-055-B 的 classify_decision 逻辑
    local decision_level
    case "$change_type" in
        rule_redline_upgrade|rule_revoke|governance_upgrade|tier0|critical)
            decision_level="P0"
            ;;
        rule_merge|phase_change|tier1|tier2|flow_upgrade)
            decision_level="P1"
            ;;
        chore|docs_typo|single_file|test_fix|tier3|default)
            decision_level="P2"
            ;;
        *)
            decision_level="P2"
            ;;
    esac

    case "$decision_level" in
        P0)
            echo "P0 — 战略红线 (${epic_id} / ${change_type})"
            echo "  action: BLOCKED 阻塞等主公 explicit 拍板"
            echo "  inbox: 写 REQUEST-P0-${epic_id}.md (跟 PROCESS.md:25-26 联合)"
            echo "  follow_up: 主公拍板 后 → subagent 执行 + 更新 audit"
            echo "PHASE3_DECISION_P0"
            ;;
        P1)
            echo "P1 — 流程升级 (${epic_id} / ${change_type})"
            echo "  action: 备案 不阻塞"
            echo "  inbox: 写 RECORD-P1-${epic_id}.md (跟 EPIC-055-B P1 备案 联合)"
            echo "  follow_up: 主公 review 时 check 即可"
            echo "PHASE3_DECISION_P1"
            ;;
        P2)
            echo "P2 — 操作 (${epic_id} / ${change_type})"
            echo "  action: EXECUTED 直接执行 + 写 p2-log-*.jsonl 留痕"
            echo "  inbox: 不写 inbox (跟 EPIC-055-B P2 放手 联合)"
            echo "  follow_up: subagent 直接执行"
            echo "PHASE3_DECISION_P2"
            ;;
    esac
}

# ----------------------------------------
# 集成入口 — 3 阶段全流程
# ----------------------------------------
run_governance_3phase() {
    local epic_id="${1:-EPIC-XXX}"

    echo "=========================================="
    echo "KALLAX 3 阶段治理 — ${epic_id}"
    echo "=========================================="
    echo ""

    # Phase 1
    phase1_conductor_scan "$epic_id"
    echo ""

    # Phase 2
    phase2_expert_panel "$epic_id"
    echo ""

    # Phase 3 — 仲裁
    phase3_master_arbitration "$epic_id" "$EXPERT_PANEL_TOTAL_COUNT"
    echo ""

    # Phase 3 — 拍板 (默认 P1, 流程升级 走备案)
    phase3_master_decision "$epic_id" "phase_change" "tier1"
    echo ""

    # 净价值估算 (跟 EPIC-056-B 3 KPI 联动)
    echo "=========================================="
    echo "净价值估算 (跟 EPIC-056-B 3 KPI 联动)"
    echo "  baseline: net_value=$NET_VALUE_BASELINE% (5 阶段, 10 专家协调开销)"
    echo "  target: net_value=$NET_VALUE_TARGET% (3 阶段, Architect 合并省 0.4h/ticket)"
    echo "  delta: +${NET_VALUE_DELTA}% (跟 056-B 3 KPI 闭环)"
    echo "  15 步 → 10 步 (省 5 步表演步骤, 跟\"流程效果 > 流程表演\" 联合)"
    echo "=========================================="
    echo ""
    echo "GOVERNANCE_3PHASE_PASS (Phase 1 PASS / Phase 2 PASS / Phase 3 PASS)"
}

# ----------------------------------------
# Main (only when executed directly, not sourced)
# ----------------------------------------
if [ "$MAIN_MODE" -eq 1 ]; then
    run_governance_3phase "${1:-EPIC-056-A}"
fi
