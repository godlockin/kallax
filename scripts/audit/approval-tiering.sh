#!/usr/bin/env bash
# scripts/audit/approval-tiering.sh — 主公拍板分级 P0/P1/P2 (EPIC-055-B)
# 5 张治理卡 核心 ticket, 治 P2 决策疲劳
#
# 3 级路由:
#   P0 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级) → 阻塞 + 写 REQUEST-P0-*.md
#   P1 流程升级 (Tier 1/2 ticket / Rule 合并 / 阶段变更) → 备案 + 写 RECORD-P1-*.md
#   P2 操作 (Tier 3 chore / docs / 单文件改动) → 直接执行 + 写 p2-log-*.jsonl
#
# 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合 (主公 explicit 拍板 5/5)
# 跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合
# 跟 Rule 32 (Rule 治胀) 联合, 跟 Rule 9 X/Y 格式 联合
# 跟 decision-gate-design.md "complex-only" 联合

set -uo pipefail

# Source guard — only run main when executed, not when sourced for tests
# When sourced from test: BASH_SOURCE is set and != $0 → MAIN_MODE=0
# When executed directly: BASH_SOURCE[0] == $0 → MAIN_MODE=1
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    MAIN_MODE=0
else
    MAIN_MODE=1
fi

readonly KALLAX_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly INBOX_DIR="$KALLAX_ROOT/.kallax/inbox/human_feedback"
readonly AUDIT_DIR="$KALLAX_ROOT/.kallax/audit"
readonly TICKETS_DIR="$KALLAX_ROOT/jira/tickets"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"

# Constants (Rule 4: no magic numbers, name all)
readonly THRESHOLD_P0_TYPES=3
readonly THRESHOLD_UPGRADE_RATE_WARN=30
readonly COST_PER_P0_MINUTES=15
readonly COST_PER_P1_MINUTES=5
readonly COST_PER_P2_MINUTES=0

# ----------------------------------------
# Tier classifier — 决定 P0/P1/P2
# ----------------------------------------
classify_decision() {
    local ticket_id="$1"
    local change_type="${2:-default}"
    local tier="${3:-2}"

    # P0 触发: 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级 / Tier 0 ticket)
    case "$change_type" in
        rule_redline_upgrade|rule_revoke|governance_upgrade|tier0|critical)
            echo "P0"
            return 0
            ;;
    esac

    if [ "$tier" = "0" ]; then
        echo "P0"
        return 0
    fi

    # P1 触发: 流程升级 (Tier 1/2 ticket / Rule 合并 / 阶段变更)
    case "$change_type" in
        rule_merge|phase_change|tier1|tier2|process_upgrade)
            echo "P1"
            return 0
            ;;
    esac

    if [ "$tier" = "1" ] || [ "$tier" = "2" ]; then
        echo "P1"
        return 0
    fi

    # P2 默认: 操作 (Tier 3 chore / docs / 单文件改动)
    echo "P2"
}

# ----------------------------------------
# P0 路由 — 阻塞 + 写 REQUEST-P0-*.md
# ----------------------------------------
route_p0() {
    local ticket_id="$1"
    mkdir -p "$INBOX_DIR"

    local req_file="$INBOX_DIR/REQUEST-P0-$ticket_id.md"
    cat > "$req_file" <<EOF
# REQUEST-P0 — 战略红线 拍板请求

**Ticket**: $ticket_id
**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Type**: P0 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级)

## 状态
**BLOCKED** — 等主公 explicit 拍板 (跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合)

## 拍板参考
- 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md (5 张治理卡 拍板 联合)
- decision-gate-design.md (复杂才问 联合)

## 主公拍板 后
执行 ticket + 更新 audit/p2-log + 通知 Conductor.
EOF

    echo "BLOCKED → $req_file"
}

# ----------------------------------------
# P1 路由 — 备案 + 写 RECORD-P1-*.md (不阻塞)
# ----------------------------------------
route_p1() {
    local ticket_id="$1"
    mkdir -p "$INBOX_DIR"

    local rec_file="$INBOX_DIR/RECORD-P1-$ticket_id.md"
    cat > "$rec_file" <<EOF
# RECORD-P1 — 流程升级 备案

**Ticket**: $ticket_id
**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Type**: P1 流程升级 (Tier 1/2 ticket)

## 状态
**RECORDED** — 已备案, 主公 review 时 check 即可

## 拍板参考
- 跟 PROCESS.md:25-26 联合 (P1 不阻塞主公, 备案即可)
EOF

    echo "RECORDED → $rec_file"
}

# ----------------------------------------
# P2 路由 — 直接执行 + 写 p2-log-*.jsonl
# ----------------------------------------
route_p2() {
    local ticket_id="$1"
    mkdir -p "$AUDIT_DIR"

    local log_file="$AUDIT_DIR/p2-log-$(date +%u).jsonl"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat >> "$log_file" <<EOF
{"ticket_id": "$ticket_id", "time": "$timestamp", "type": "P2", "tier": "3", "approval": "none", "executor": "performer"}
EOF

    echo "EXECUTED → $log_file"
}

# ----------------------------------------
# TC4: 历史决策扫描 — P0 漏拍检测
# 扫描所有 Tier 0 ticket, 检查 REQUEST-P0-*.md 是否存在
# ----------------------------------------
audit_p0_missed() {
    mkdir -p "$INBOX_DIR"

    local tier0_count=0
    local tier0_found=0
    local missed=0

    # 找所有 Tier 0 ticket (如果有 tier 字段)
    if [ -d "$TICKETS_DIR" ]; then
        for f in "$TICKETS_DIR"/EPIC-*/ticket.json; do
            [ -f "$f" ] || continue
            local tid
            tid=$(basename "$(dirname "$f")")
            local req_file="$INBOX_DIR/REQUEST-P0-$tid.md"

            # 简化: 默认所有 EPIC ticket 都视为历史决策点 (无 tier 字段时)
            tier0_count=$((tier0_count + 1))
            if [ -f "$req_file" ]; then
                tier0_found=$((tier0_found + 1))
            else
                # 检查 ticket 类型是否是 P0 类型
                local ctype
                ctype=$(grep -oE '"type"[[:space:]]*:[[:space:]]*"[^"]+"' "$f" 2>/dev/null | head -1 | grep -oE '"[^"]+"$' | tr -d '"' || echo "")
                case "$ctype" in
                    rule_redline_upgrade|rule_revoke|governance_upgrade)
                        missed=$((missed + 1))
                        echo "P0_MISSED: $tid (type=$ctype, no REQUEST-P0-* file)"
                        ;;
                esac
            fi
        done
    fi

    if [ "$missed" -eq 0 ]; then
        echo "AUDIT_OK: 0 P0 missed (scanned $tier0_count tickets)"
    else
        echo "P0_MISSED: $missed P0 漏拍 (scanned $tier0_count tickets)"
    fi
}

# ----------------------------------------
# TC5: 边际效用计算 — 拍板成本 / 升级次数 / 升级率
# cost = P0_count * 15min + P1_count * 5min + P2_count * 0min
# utility = 拍板次数 / Rule 升级次数 (每升级需要的拍板数)
# upgrade_rate = 升级 Rule 数 / Rule 总数
# ----------------------------------------
calc_marginal_utility() {
    # Read CLAUDE.md for Rule counts
    local total_rules
    total_rules=$(grep -cE '^### [0-9]+\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    # R-NEW 升级 Rule (14-18, Rule 19 doesn't exist)
    local rnew_count
    rnew_count=$(grep -cE '^### (14|15|16|17|18)\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    # v1.2.4 5 扩展组 联动 Rule (29-33: security + process-eng + auditor + decision-gate + extension)
    local extended_count
    extended_count=$(grep -cE '^### (29|30|31|32|33)\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    local upgraded=$((rnew_count + extended_count))
    local upgrade_rate=0
    if [ "$total_rules" -gt 0 ]; then
        upgrade_rate=$(awk "BEGIN{printf \"%.1f\", $upgraded * 100 / $total_rules}")
    fi

    # 拍板次数估算 (历史)
    local p0_count=0
    local p1_count=0
    local p2_count=0

    # 扫 REQUEST-P0-*.md
    if [ -d "$INBOX_DIR" ]; then
        p0_count=$(find "$INBOX_DIR" -maxdepth 1 -name "REQUEST-P0-*.md" 2>/dev/null | wc -l | tr -d ' ')
        p1_count=$(find "$INBOX_DIR" -maxdepth 1 -name "RECORD-P1-*.md" 2>/dev/null | wc -l | tr -d ' ')
    fi

    # 扫 p2-log-*.jsonl
    if [ -d "$AUDIT_DIR" ]; then
        p2_count=$(find "$AUDIT_DIR" -maxdepth 1 -name "p2-log-*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    fi

    local total_decisions=$((p0_count + p1_count + p2_count))
    local cost=$((p0_count * COST_PER_P0_MINUTES + p1_count * COST_PER_P1_MINUTES + p2_count * COST_PER_P2_MINUTES))

    local utility=0
    if [ "$upgraded" -gt 0 ]; then
        utility=$(awk "BEGIN{printf \"%.2f\", $total_decisions / $upgraded}")
    fi

    echo "cost=$cost"
    echo "p0_count=$p0_count p1_count=$p1_count p2_count=$p2_count"
    echo "total_decisions=$total_decisions"
    echo "total_rules=$total_rules upgraded=$upgraded"
    echo "upgrade_rate=${upgrade_rate}%"
    echo "utility=$utility (decisions per upgrade)"
}

# ----------------------------------------
# TC6: 拍板疲劳模拟 (跟 Rule 32 联动)
# fatigue_index = upgrade_rate * (1 - 1/utility)
# recommendation: 如果 fatigue_index > 50, 建议 Rule 合并 (054-D 联动)
# ----------------------------------------
calc_fatigue_index() {
    local total_rules
    total_rules=$(grep -cE '^### [0-9]+\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    local rnew_count
    rnew_count=$(grep -cE '^### (14|15|16|17|18)\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    local extended_count
    extended_count=$(grep -cE '^### (29|30|31|32|33)\.' "$CLAUDE_MD" 2>/dev/null || echo "0")

    local upgraded=$((rnew_count + extended_count))
    local upgrade_rate=0
    if [ "$total_rules" -gt 0 ]; then
        upgrade_rate=$(awk "BEGIN{printf \"%.1f\", $upgraded * 100 / $total_rules}")
    fi

    # utility 估算: 每张决策 ticket 假设产生 1 次拍板
    local p0_count=0
    local p1_count=0
    if [ -d "$INBOX_DIR" ]; then
        p0_count=$(find "$INBOX_DIR" -maxdepth 1 -name "REQUEST-P0-*.md" 2>/dev/null | wc -l | tr -d ' ')
        p1_count=$(find "$INBOX_DIR" -maxdepth 1 -name "RECORD-P1-*.md" 2>/dev/null | wc -l | tr -d ' ')
    fi
    local total_decisions=$((p0_count + p1_count))
    # 假设 total_decisions 至少 = upgraded (保守估算)
    if [ "$total_decisions" -lt "$upgraded" ]; then
        total_decisions=$upgraded
    fi

    local utility=0
    if [ "$upgraded" -gt 0 ]; then
        utility=$(awk "BEGIN{printf \"%.2f\", $total_decisions / $upgraded}")
    fi

    # fatigue_index: 升级率 × 边际效用倒数
    # utility 越低 (每升级拍板越少) → 疲劳指数越高
    local inv_utility=1
    if [ "$(awk "BEGIN{print ($utility > 0)}")" = "1" ]; then
        inv_utility=$(awk "BEGIN{printf \"%.2f\", 1 / $utility}")
    fi

    local fatigue_index
    fatigue_index=$(awk "BEGIN{printf \"%.1f\", $upgrade_rate * $inv_utility}")

    echo "total_rules=$total_rules upgraded=$upgraded"
    echo "upgrade_rate=${upgrade_rate}% utility=$utility"
    echo "fatigue_index=$fatigue_index (0-100, >50 = high fatigue)"

    # Recommendation (跟 054-D Rule 合并 联动)
    local rec_threshold=50
    if [ "$(awk "BEGIN{print ($fatigue_index > $rec_threshold)}")" = "1" ]; then
        echo "recommendation=HIGH_FATIGUE → 触发 EPIC-054-D Rule 合并扫描 (23→20 Rule 目标)"
    else
        echo "recommendation=OK → 拍板节奏 可持续"
    fi
}

# ----------------------------------------
# Main entry — only when executed directly
# ----------------------------------------
if [ "$MAIN_MODE" = "1" ]; then
    case "${1:-help}" in
        classify)
            shift
            classify_decision "$@"
            ;;
        route-p0)
            shift
            route_p0 "$@"
            ;;
        route-p1)
            shift
            route_p1 "$@"
            ;;
        route-p2)
            shift
            route_p2 "$@"
            ;;
        audit-p0)
            audit_p0_missed
            ;;
        cost)
            calc_marginal_utility
            ;;
        fatigue)
            calc_fatigue_index
            ;;
        help|*)
            cat <<EOF
Usage: approval-tiering.sh <command> [args]

Commands:
  classify <ticket_id> <change_type> [tier]  Classify decision as P0/P1/P2
  route-p0 <ticket_id>                       P0 route: BLOCKED + write REQUEST-P0-*.md
  route-p1 <ticket_id>                       P1 route: write RECORD-P1-*.md (no block)
  route-p2 <ticket_id>                       P2 route: execute + write p2-log-*.jsonl
  audit-p0                                   Audit historical P0 missed decisions
  cost                                       Calculate marginal utility (cost / decisions / upgrade_rate)
  fatigue                                    Calculate fatigue index + recommendation

EPIC-055-B | 5 governance cards core
EOF
            ;;
    esac
fi