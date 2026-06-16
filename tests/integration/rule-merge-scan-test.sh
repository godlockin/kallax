#!/usr/bin/env bash
# tests/integration/rule-merge-scan-test.sh — TDD tests for EPIC-054-D Rule merge scan
#
# EPIC-054-D AC5: 6/6 PASS (23 Rule mock + 3 合并候选 + 撤销影响分析 + 净价值计算)
#
# Test cases (6):
#   TC1: 23 Rule mock 数据准备 (audit 脚本读取 CLAUDE.md, 输出 23 Rule 列表)
#   TC2: 3 个合并候选识别 (Rule 30+31 / Rule 32→5 / Rule 33→13)
#   TC3: 撤销影响分析 (净 Rule 数 = 20, 23-3)
#   TC4: 净价值计算 (62.5% → 65.5%, +3.0%)
#   TC5: 真跑 audit 脚本 (exit 0, 输出结构化报告)
#   TC6: 输出 proposal markdown (docs/process/rule-merge-proposal.md 存在 + 3 candidates 详细 + 影响 + 净价值)
#
# Rule 9 KPI X/Y 精确格式: 6/6 = 100.0% (no estimate, exact)
# 跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
# 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合
# 跟 v1.2.4 EPIC-051 合规设计 联合 (23 Rule 10 升级 闭环)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SCRIPT="$KALLAX_ROOT/scripts/audit/rule-redundancy-audit.sh"
readonly PROPOSAL="$KALLAX_ROOT/docs/process/rule-merge-proposal.md"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"

echo "=========================================="
echo "Rule Merge Scan (EPIC-054-D) — Integration Tests (6/6)"
echo "23 Rule → 20 Rule | 3 merge candidates | net value 62.5% → 65.5%"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# Use indexed arrays (POSIX-portable; macOS bash doesn't support associative arrays by default)
TC1_PASS=0; TC2_PASS=0; TC3_PASS=0; TC4_PASS=0; TC5_PASS=0; TC6_PASS=0
TC1_FAIL=0; TC2_FAIL=0; TC3_FAIL=0; TC4_FAIL=0; TC5_FAIL=0; TC6_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# TDD red phase: verify script exists
if [ ! -f "$SCRIPT" ]; then
    echo "FAIL: $SCRIPT not found (TDD red phase, 待 Step 7a 实现)"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

# TDD red phase: verify CLAUDE.md exists
if [ ! -f "$CLAUDE_MD" ]; then
    fail 1 "CLAUDE.md not found at $CLAUDE_MD"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

# Run the audit script and capture output (for TC5 + downstream assertions)
readonly AUDIT_OUTPUT="$(bash "$SCRIPT" 2>&1)"
readonly AUDIT_EXIT=$?

# ----------------------------------------
# TC1: 23 Rule mock 数据准备
# Verify audit script reads CLAUDE.md, identifies 23 Rule 列表
# ----------------------------------------
if ! grep -qE "Total Rules:[[:space:]]+23\b" <<< "$AUDIT_OUTPUT"; then
    fail 1 "audit output missing 'Total Rules: 23' (跟 EPIC-055-B 实测一致)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

if ! grep -qE "Upgraded:[[:space:]]+10\b" <<< "$AUDIT_OUTPUT"; then
    fail 1 "audit output missing 'Upgraded: 10' (跟 EPIC-055-B LESSONS-LEARNED.md 实测 43.5% 升级率 联合)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

if ! grep -qE "43\.[45]" <<< "$AUDIT_OUTPUT"; then
    fail 1 "audit output missing upgrade rate 43.5% (Rule 9 X/Y 精确格式)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

# TC1 passes if all 3 sub-checks pass
if [ "$TC1_PASS" -eq 3 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC1: 23 Rule mock 数据准备 (23 Rule + 10 升级 + 43.5% 升级率) [3/3 sub-checks]"
fi

# ----------------------------------------
# TC2: 3 个合并候选识别
# ----------------------------------------
if ! grep -qE "Rule 30" <<< "$AUDIT_OUTPUT"; then
    fail 2 "audit output missing Rule 30 (候选 A: 独立见证合并)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "Rule 31" <<< "$AUDIT_OUTPUT"; then
    fail 2 "audit output missing Rule 31 (候选 A: 独立见证合并)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "Rule 32" <<< "$AUDIT_OUTPUT"; then
    fail 2 "audit output missing Rule 32 (候选 B: 反讽 anti-inflation Rule 撤销/合并)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "Rule 33" <<< "$AUDIT_OUTPUT"; then
    fail 2 "audit output missing Rule 33 (候选 C: decision-gate 复杂才问 并入 Rule 13)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "Candidates:[[:space:]]+3\b" <<< "$AUDIT_OUTPUT"; then
    fail 2 "audit output missing 'Candidates: 3'"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# TC2 passes if all 5 sub-checks pass
if [ "$TC2_PASS" -eq 5 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC2: 3 个合并候选识别 (Rule 30+31 / Rule 32→5 / Rule 33→13) [5/5 sub-checks]"
fi

# ----------------------------------------
# TC3: 撤销影响分析
# ----------------------------------------
if ! grep -qE "Target Rule count:[[:space:]]+20\b" <<< "$AUDIT_OUTPUT"; then
    fail 3 "audit output missing 'Target Rule count: 20' (净 Rule 数 = 20, 23-3)"
else
    TC3_PASS=$((TC3_PASS+1))
fi

if ! grep -qE "Delta:[[:space:]]+-3\b" <<< "$AUDIT_OUTPUT"; then
    fail 3 "audit output missing 'Delta: -3' (净减 3 Rule)"
else
    TC3_PASS=$((TC3_PASS+1))
fi

# TC3 passes if both sub-checks pass
if [ "$TC3_PASS" -eq 2 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC3: 撤销影响分析 (净 Rule 数 = 20, Delta = -3) [2/2 sub-checks]"
fi

# ----------------------------------------
# TC4: 净价值计算 (62.5% → 65.5%, +3.0%)
# ----------------------------------------
if ! grep -qE "62\.5%?" <<< "$AUDIT_OUTPUT"; then
    fail 4 "audit output missing baseline '62.5%' (跟 EPIC-056-A 决策后净价值 联合)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

if ! grep -qE "65\.5%?" <<< "$AUDIT_OUTPUT"; then
    fail 4 "audit output missing target '65.5%' (合并后净价值)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

if ! grep -qE "\+3\.0%?" <<< "$AUDIT_OUTPUT"; then
    fail 4 "audit output missing '+3.0%' (净价值 delta)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

# TC4 passes if all 3 sub-checks pass
if [ "$TC4_PASS" -eq 3 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC4: 净价值计算 (62.5% → 65.5%, +3.0%) [3/3 sub-checks]"
fi

# ----------------------------------------
# TC5: 真跑 audit 脚本
# ----------------------------------------
if [ "$AUDIT_EXIT" -ne 0 ]; then
    fail 5 "audit script exit code = $AUDIT_EXIT (expect 0)"
else
    TC5_PASS=$((TC5_PASS+1))
fi

for section in "Rule Redundancy Audit" "Merge Candidates" "Net Value Calculation" "Audit Summary"; do
    if ! grep -q "$section" <<< "$AUDIT_OUTPUT"; then
        fail 5 "audit output missing section '$section'"
    else
        TC5_PASS=$((TC5_PASS+1))
    fi
done

# TC5 passes if exit=0 + all 4 sections present (5 sub-checks)
if [ "$TC5_PASS" -eq 5 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC5: 真跑 audit 脚本 (exit 0, 4 sections 结构化输出) [5/5 sub-checks]"
fi

# ----------------------------------------
# TC6: 输出 proposal markdown
# ----------------------------------------
if [ ! -f "$PROPOSAL" ]; then
    fail 6 "proposal markdown not found at $PROPOSAL"
else
    TC6_PASS=$((TC6_PASS+1))
    for section in "候选 A" "候选 B" "候选 C" "影响分析" "净价值" "23 Rule → 20 Rule" "EPIC-055-B" "PROCESS.md:25-26" "主公拍板"; do
        if ! grep -q "$section" "$PROPOSAL"; then
            fail 6 "proposal missing section: '$section'"
        else
            TC6_PASS=$((TC6_PASS+1))
        fi
    done
fi

# TC6 passes if file exists + all 9 required sections present (10 sub-checks)
if [ "$TC6_PASS" -eq 10 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC6: 输出 proposal markdown (3 candidates + 影响 + 净价值 + EPIC-055-B 联动) [10/10 sub-checks]"
fi

# ----------------------------------------
# Summary (Rule 9 X/Y 精确格式)
# ----------------------------------------
echo ""
echo "=========================================="
PCT=$(awk -v p="$PASS_COUNT" -v t="$TOTAL" 'BEGIN{printf "%.1f", (p*100)/t}')
echo "Summary: $PASS_COUNT/$TOTAL PASS (${PCT}%)"
echo "=========================================="
echo ""

# Per-TC summary
echo "Per-TC sub-checks:"
echo "  TC1: $TC1_PASS/3 sub-checks"
echo "  TC2: $TC2_PASS/5 sub-checks"
echo "  TC3: $TC3_PASS/2 sub-checks"
echo "  TC4: $TC4_PASS/3 sub-checks"
echo "  TC5: $TC5_PASS/5 sub-checks"
echo "  TC6: $TC6_PASS/10 sub-checks"
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo "STATUS: ALL PASS (6/6 = 100.0%)"
    echo "EPIC-054-D 联动 EPIC-055-B 主公拍板分级, 23 Rule → 20 Rule proposal 完整"
    exit 0
else
    echo "STATUS: FAIL ($PASS_COUNT/$TOTAL = ${PCT}%)"
    exit 1
fi
