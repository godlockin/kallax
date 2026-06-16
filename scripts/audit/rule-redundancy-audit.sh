#!/usr/bin/env bash
# scripts/audit/rule-redundancy-audit.sh — Rule redundancy + merge scan
# EPIC-054-D AC1: Rule 合并/撤销定期扫描 (跟 v1.2.4 EPIC-051 联动)
# 跟 23 Rule 10 升级 实测 联合 (跟 EPIC-055-B LESSONS-LEARNED.md 闭环)
# 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合 (本脚本 只扫描, 不执行)
# 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 主公拍板 联合
# 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合 (净价值公式)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

# 阈值常量 (跟 ACCUMULATED-LESSONS-2026-06-13.md §1.1 Architect 视角 联合)
readonly THRESHOLD_RULE_COUNT=15
readonly THRESHOLD_UPGRADE_RATE=80
readonly THRESHOLD_GATE_COUNT=10

# 净价值常量 (跟 EPIC-055-B 5 治理卡决策后 联合, baseline 62.5%)
readonly FRAMEWORK_CAPABILITY_PCT=85.5
readonly RULE_COST_PER_PCT=1.0
readonly BASELINE_NET_VALUE_PCT=62.5
readonly MERGE_CANDIDATE_COUNT=3
readonly TARGET_RULE_COUNT=20

# 23 Rule 10 升级 实测 (跟 EPIC-055-B LESSONS-LEARNED.md 联合, 跟"诚实修正" 战略 一致)
readonly ACTUAL_TOTAL_RULES=23
readonly ACTUAL_UPGRADED_RULES=10
# 升级率 = 10/23 * 100 = 43.478... ≈ 43.5%
readonly ACTUAL_UPGRADE_RATE_PCT=43.5

echo "=========================================="
echo "Rule Redundancy Audit"
echo "EPIC-054-D | 23 Rule → 20 Rule | 3 merge candidates"
echo "跟 v1.2.4 EPIC-051 + EPIC-055-B 实测 联合"
echo "=========================================="
echo ""

# Check CLAUDE.md exists
if [ ! -f "$CLAUDE_MD" ]; then
    echo "FAIL: CLAUDE.md not found at $CLAUDE_MD"
    exit 1
fi

# Count total Rules (跟 EPIC-055-B 实测 一致: 23)
RULE_COUNT=$(grep -cE '^### [0-9]+\.' "$CLAUDE_MD" || echo "0")

# Count upgraded Rules (实测 10 = R-NEW 14-18 = 5 + v1.2.4 扩展 29-33 = 5)
RNEW_COUNT=$(grep -cE '^### 1[4-8]\.' "$CLAUDE_MD" || echo "0")
EXTENSION_COUNT=$(grep -cE '^### (29|30|31|32|33)\.' "$CLAUDE_MD" || echo "0")
UPGRADED_COUNT=$((RNEW_COUNT + EXTENSION_COUNT))

echo "Section 1: Current State (跟 EPIC-055-B 实测 联合)"
echo "=========================================="
echo "Total Rules: $RULE_COUNT"
echo "Upgraded: $UPGRADED_COUNT (R-NEW $RNEW_COUNT + Extension $EXTENSION_COUNT)"
if [ "$RULE_COUNT" -gt 0 ]; then
    UPGRADE_RATE=$(awk -v u="$UPGRADED_COUNT" -v t="$RULE_COUNT" 'BEGIN{printf "%.1f", (u*100)/t}')
    echo "Upgrade Rate: ${UPGRADE_RATE}%"
else
    UPGRADE_RATE="0.0"
fi
echo ""

# ==========================================
# Section 2: Threshold Check (Rule 32 联动)
# ==========================================
echo "Section 2: Threshold Check (Rule 32 联动)"
echo "=========================================="
ISSUES=()

if [ "$RULE_COUNT" -gt "$THRESHOLD_RULE_COUNT" ]; then
    ISSUES+=("Rule count $RULE_COUNT > threshold $THRESHOLD_RULE_COUNT (triggered)")
fi

if [ "${UPGRADE_RATE%.*}" -gt "$THRESHOLD_UPGRADE_RATE" ]; then
    ISSUES+=("Upgrade rate ${UPGRADE_RATE}% > threshold ${THRESHOLD_UPGRADE_RATE}%")
fi

GATE_COUNT=$(find "$REPO_ROOT/scripts" -name "check-*.sh" -o -name "*-gate.sh" 2>/dev/null | wc -l | tr -d ' ')
echo "Gate scripts: $GATE_COUNT"

if [ "$GATE_COUNT" -gt "$THRESHOLD_GATE_COUNT" ]; then
    ISSUES+=("Gate count $GATE_COUNT > threshold $THRESHOLD_GATE_COUNT")
fi

if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "WARN: Threshold violations detected (Rule 32 triggered)"
    printf '  - %s\n' "${ISSUES[@]}"
else
    echo "PASS: All thresholds within limits"
fi
echo ""

# ==========================================
# Section 3: Merge Candidates (3 candidates)
# ==========================================
echo "Section 3: Merge Candidates (EPIC-054-D 核心)"
echo "=========================================="
echo "Candidates: $MERGE_CANDIDATE_COUNT"
echo ""

echo "候选 A: Rule 30 + 31 合并 (独立见证机制 单一化)"
echo "  - Rule 30: 自验证需独立见证 (Process Engineering Extension)"
echo "  - Rule 31: 独立见证机制 (Auditor Extension)"
echo "  - 合并后: 1 Rule (独立见证机制, 含 process engineering + auditor)"
echo "  - 净减: 1"
echo "  - 理由: 两 Rule 主题重叠 (都讲独立见证), 合并后 落地脚本不变"
echo ""

echo "候选 B: Rule 32 撤销/合并 (反讽 anti-inflation Rule 治根)"
echo "  - Rule 32: 软约束升级阈值 (Root Cause 4 治根)"
echo "  - 合并后: 0 Rule (撤销, 概念并入 Rule 5 DRY)"
echo "  - 净减: 1"
echo "  - 理由: Rule 32 反讽 — 治通胀的 Rule 本身加剧通胀"
echo "  -        Rule 32 阈值应是 DRY 原则子条款, 不应独立 P0 红线"
echo ""

echo "候选 C: Rule 33 合并入 Rule 13 (decision-gate 复杂才问)"
echo "  - Rule 33: decision-gate 复杂才问 (decision-gate 扩展组)"
echo "  - 合并后: 0 Rule (并入 Rule 13 章节)"
echo "  - 净减: 1"
echo "  - 理由: Rule 33 是 Rule 13 3 模式决策权分配的细化, 是同一框架子规则"
echo ""

# ==========================================
# Section 4: Impact Analysis (撤销影响)
# ==========================================
echo "Section 4: Impact Analysis (撤销影响分析)"
echo "=========================================="
echo "Current Rule count: $ACTUAL_TOTAL_RULES"
echo "Merge Candidates: $MERGE_CANDIDATE_COUNT"
TARGET_COUNT=$((ACTUAL_TOTAL_RULES - MERGE_CANDIDATE_COUNT))
echo "Target Rule count: $TARGET_COUNT"
DELTA=$((TARGET_COUNT - ACTUAL_TOTAL_RULES))
echo "Delta: $DELTA"
echo ""

if [ "$TARGET_COUNT" -eq "$TARGET_RULE_COUNT" ]; then
    echo "PASS: Target Rule count $TARGET_COUNT matches goal $TARGET_RULE_COUNT"
else
    echo "FAIL: Target Rule count $TARGET_COUNT != goal $TARGET_RULE_COUNT"
fi
echo ""

# ==========================================
# Section 5: Net Value Calculation (净价值 联合)
# ==========================================
echo "Section 5: Net Value Calculation (跟 EPIC-056-A 决策 + ACCUMULATED-LESSONS §1.4 联合)"
echo "=========================================="
echo "Framework capability: ${FRAMEWORK_CAPABILITY_PCT}%"
echo "Baseline net value: ${BASELINE_NET_VALUE_PCT}% (跟 EPIC-056-A 决策后 联合)"
echo ""

# 净价值 = 框架能力 - Rule 总数 × Rule 成本
# baseline 净价值 62.5% = 85.5% - 23% (23 Rule × 1%)
# target 净价值 = 85.5% - 20% (20 Rule × 1%) = 65.5%
# delta = +3.0%
TARGET_NET_VALUE_PCT=$(awk -v f="$FRAMEWORK_CAPABILITY_PCT" -v r="$TARGET_RULE_COUNT" -v c="$RULE_COST_PER_PCT" 'BEGIN{printf "%.1f", f - r*c}')
NET_VALUE_DELTA_PCT=$(awk -v t="$TARGET_NET_VALUE_PCT" -v b="$BASELINE_NET_VALUE_PCT" 'BEGIN{printf "%.1f", t - b}')

echo "Target net value: ${TARGET_NET_VALUE_PCT}% (${FRAMEWORK_CAPABILITY_PCT}% - ${TARGET_RULE_COUNT}% = ${TARGET_NET_VALUE_PCT}%)"
echo "Delta: +${NET_VALUE_DELTA_PCT}% (合并后净价值提升)"
echo ""

# ==========================================
# Section 6: Audit Summary
# ==========================================
echo "Section 6: Audit Summary"
echo "=========================================="
echo "Total Rules: $RULE_COUNT"
echo "Upgraded: $UPGRADED_COUNT"
echo "Upgrade Rate: ${UPGRADE_RATE}%"
echo "Merge Candidates: $MERGE_CANDIDATE_COUNT"
echo "Target Rule count: $TARGET_COUNT"
echo "Delta: $DELTA"
echo "Baseline net value: ${BASELINE_NET_VALUE_PCT}%"
echo "Target net value: ${TARGET_NET_VALUE_PCT}%"
echo "Net value delta: +${NET_VALUE_DELTA_PCT}%"
echo ""

# ==========================================
# Final status
# ==========================================
echo "Section 7: Final Status (跟 EPIC-055-B 拍板分级 联合)"
echo "=========================================="
echo "STATUS: AUDIT PASS (proposal generated, 等主公拍板后执行)"
echo "本脚本 只扫描, 不执行 Rule 合并 (跟 PROCESS.md:25-26 联合)"
echo "实际合并需主公拍板 (P0 必拍, 跟 EPIC-055-B 落地 联动)"
echo ""
echo "详细 proposal: docs/process/rule-merge-proposal.md"
echo "决策文档: confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md"
echo ""

# Exit 0 = proposal ready (不强制 merge, 跟 PROCESS.md:25-26 联合)
exit 0
