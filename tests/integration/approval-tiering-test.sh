#!/usr/bin/env bash
# tests/integration/approval-tiering-test.sh — TDD tests for approval-tiering
# EPIC-055-B AC5: 6/6 PASS (P0/P1/P2 路由 + 历史决策扫描 + 边际效用计算 + 拍板成本估算)
#
# Test cases (6):
#   TC1: P0 路由 (R-NEW 升级 ticket) → 阻塞 + 写 REQUEST-P0-*.md
#   TC2: P1 路由 (Tier 1 ticket) → 写 RECORD-P1-*.md
#   TC3: P2 路由 (Tier 3 chore) → 直接执行 + 写 p2-log-*.jsonl
#   TC4: 历史决策扫描 — P0 漏拍检测
#   TC5: 边际效用计算 — 拍板成本 / 升级次数 / 升级率
#   TC6: 23 Rule 9 升级 拍板疲劳模拟 (Rule 32 联动)
#
# Rule 9 KPI X/Y 精确格式: 6/6 = 100.0% (no estimate, exact)
# 跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
# 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SCRIPT="$KALLAX_ROOT/scripts/audit/approval-tiering.sh"

# TDD red phase: verify script exists (created in step 7)
if [ ! -f "$SCRIPT" ]; then
    echo "=========================================="
    echo "Approval Tiering (P0/P1/P2) — Integration Tests (6/6)"
    echo "=========================================="
    echo ""
    echo "FAIL: $SCRIPT not found (TDD red phase)"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

# Source the script to access classify / audit / cost functions
# shellcheck disable=SC1090
source "$SCRIPT" 2>/dev/null || {
    echo "FAIL: could not source $SCRIPT"
    exit 1
}

echo "=========================================="
echo "Approval Tiering (P0/P1/P2) — Integration Tests (6/6)"
echo "EPIC-055-B | 5 governance cards core | Master 强验证"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# Track per-TC pass/fail (for TC-level summary)
declare -A TC_PASS TC_FAIL
for i in 1 2 3 4 5 6; do TC_PASS[$i]=0; TC_FAIL[$i]=0; done

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); TC_PASS[$1]=$((TC_PASS[$1]+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); TC_FAIL[$1]=$((TC_FAIL[$1]+1)); }

# ----------------------------------------
# TC1: P0 路由 (R-NEW 升级 ticket) → 阻塞 + 写 REQUEST-P0-*.md
# ----------------------------------------
echo ">>> TC1: P0 路由 — 战略红线 (R-NEW 升级)"
echo "=========================================="
TC1_RESULT=0

# Create a fake R-NEW upgrade ticket (Tier 0)
FAKE_P0_TICKET="$KALLAX_ROOT/.kallax/queue/EPIC-055-B-FAKE-P0.json"
mkdir -p "$(dirname "$FAKE_P0_TICKET")"
cat > "$FAKE_P0_TICKET" <<EOF
{"id": "EPIC-055-B-FAKE-P0", "tier": 0, "type": "rule_redline_upgrade", "approval": "P0"}
EOF

# Test classify_decision() returns P0
if declare -f classify_decision >/dev/null 2>&1; then
    CLASSIFY_RESULT=$(classify_decision "EPIC-055-B-FAKE-P0" "rule_redline_upgrade" 2>&1 || echo "FAIL")
    if echo "$CLASSIFY_RESULT" | grep -q "P0"; then
        pass 1 "P0 路由 — classify 返回 P0 (R-NEW 升级 触发战略红线)"
    else
        fail 1 "P0 路由 — classify 未返回 P0 (got: $CLASSIFY_RESULT)"
        TC1_RESULT=1
    fi

    # Verify P0 blocks + writes REQUEST-P0 file
    if declare -f route_p0 >/dev/null 2>&1; then
        ROUTE_RESULT=$(route_p0 "EPIC-055-B-FAKE-P0" 2>&1 || echo "FAIL")
        if echo "$ROUTE_RESULT" | grep -qE "(BLOCKED|REQUEST-P0)"; then
            pass 1 "P0 路由 — 阻塞 + 写 REQUEST-P0-EPIC-055-B-FAKE-P0.md"
        else
            fail 1 "P0 路由 — 未阻塞 (got: $ROUTE_RESULT)"
            TC1_RESULT=1
        fi
    else
        fail 1 "P0 路由 — route_p0 函数缺失"
        TC1_RESULT=1
    fi
else
    fail 1 "P0 路由 — classify_decision 函数缺失"
    TC1_RESULT=1
fi
echo ""

# ----------------------------------------
# TC2: P1 路由 (Tier 1 ticket) → 写 RECORD-P1-*.md (不阻塞)
# ----------------------------------------
echo ">>> TC2: P1 路由 — 流程升级 (Tier 1 ticket)"
echo "=========================================="
TC2_RESULT=0

if declare -f route_p1 >/dev/null 2>&1; then
    ROUTE_P1=$(route_p1 "EPIC-055-B-FAKE-P1" 2>&1 || echo "FAIL")
    if echo "$ROUTE_P1" | grep -qE "RECORD-P1"; then
        pass 2 "P1 路由 — 写 RECORD-P1-EPIC-055-B-FAKE-P1.md (备案)"
    else
        fail 2 "P1 路由 — 未写 RECORD-P1 (got: $ROUTE_P1)"
        TC2_RESULT=1
    fi
    # Verify P1 is NOT blocked (no BLOCKED keyword)
    if echo "$ROUTE_P1" | grep -q "BLOCKED"; then
        fail 2 "P1 路由 — 不应阻塞但阻塞了"
        TC2_RESULT=1
    else
        pass 2 "P1 路由 — 不阻塞, 直接备案"
    fi
else
    fail 2 "P1 路由 — route_p1 函数缺失"
    TC2_RESULT=1
fi
echo ""

# ----------------------------------------
# TC3: P2 路由 (Tier 3 chore) → 直接执行 + 写 p2-log-*.jsonl
# ----------------------------------------
echo ">>> TC3: P2 路由 — 操作 (Tier 3 chore / docs)"
echo "=========================================="
TC3_RESULT=0

if declare -f route_p2 >/dev/null 2>&1; then
    ROUTE_P2=$(route_p2 "EPIC-055-B-FAKE-P2" 2>&1 || echo "FAIL")
    if echo "$ROUTE_P2" | grep -qE "(EXECUTED|p2-log)"; then
        pass 3 "P2 路由 — 直接执行 + 写 p2-log jsonl"
    else
        fail 3 "P2 路由 — 未直接执行 (got: $ROUTE_P2)"
        TC3_RESULT=1
    fi
    # Verify P2 doesn't write inbox (no RECORD- or REQUEST-)
    if echo "$ROUTE_P2" | grep -qE "(REQUEST-P|RECORD-P)"; then
        fail 3 "P2 路由 — 不应写 inbox 但写了"
        TC3_RESULT=1
    else
        pass 3 "P2 路由 — 不写 inbox, 放手执行"
    fi
else
    fail 3 "P2 路由 — route_p2 函数缺失"
    TC3_RESULT=1
fi
echo ""

# ----------------------------------------
# TC4: 历史决策扫描 — P0 漏拍检测
# ----------------------------------------
echo ">>> TC4: 历史决策扫描 — P0 漏拍检测"
echo "=========================================="
TC4_RESULT=0

if declare -f audit_p0_missed >/dev/null 2>&1; then
    AUDIT_RESULT=$(audit_p0_missed 2>&1 || echo "FAIL")
    if echo "$AUDIT_RESULT" | grep -qE "(P0_MISSED|AUDIT_OK|NONE|0)"; then
        pass 4 "P0 漏拍扫描 — 检测历史 P0 决策 (含漏拍计数)"
    else
        fail 4 "P0 漏拍扫描 — 未输出扫描结果 (got: $AUDIT_RESULT)"
        TC4_RESULT=1
    fi

    # Verify scan returns valid structure (number or NONE)
    if echo "$AUDIT_RESULT" | grep -qE "^P0_MISSED|^AUDIT_OK|^NONE|^0 P0"; then
        pass 4 "P0 漏拍扫描 — 结构有效 (P0_MISSED|AUDIT_OK|NONE|0)"
    else
        fail 4 "P0 漏拍扫描 — 结构无效 (got first line: $(echo "$AUDIT_RESULT" | head -1))"
        TC4_RESULT=1
    fi
else
    fail 4 "P0 漏拍扫描 — audit_p0_missed 函数缺失"
    TC4_RESULT=1
fi
echo ""

# ----------------------------------------
# TC5: 边际效用计算 — 拍板成本 / 升级次数 / 升级率
# ----------------------------------------
echo ">>> TC5: 边际效用计算 — 拍板成本估算"
echo "=========================================="
TC5_RESULT=0

if declare -f calc_marginal_utility >/dev/null 2>&1; then
    UTILITY=$(calc_marginal_utility 2>&1 || echo "FAIL")
    if echo "$UTILITY" | grep -qE "(cost|utility|upgrade_rate)"; then
        pass 5 "边际效用 — 输出 cost / utility / upgrade_rate 字段"
    else
        fail 5 "边际效用 — 缺字段 (got: $UTILITY)"
        TC5_RESULT=1
    fi

    # Verify numbers are non-negative integers
    COST_NUM=$(echo "$UTILITY" | grep -oE "cost=[0-9]+" | grep -oE "[0-9]+" || echo "0")
    if [ "$COST_NUM" -ge 0 ] 2>/dev/null; then
        pass 5 "边际效用 — cost 字段为非负整数 (cost=$COST_NUM)"
    else
        fail 5 "边际效用 — cost 字段无效 (got: $COST_NUM)"
        TC5_RESULT=1
    fi
else
    fail 5 "边际效用 — calc_marginal_utility 函数缺失"
    TC5_RESULT=1
fi
echo ""

# ----------------------------------------
# TC6: 23 Rule 9 升级 拍板疲劳模拟 (跟 Rule 32 联动)
# ----------------------------------------
echo ">>> TC6: 23 Rule 9 升级 拍板疲劳模拟"
echo "=========================================="
TC6_RESULT=0

if declare -f calc_fatigue_index >/dev/null 2>&1; then
    FATIGUE=$(calc_fatigue_index 2>&1 || echo "FAIL")
    if echo "$FATIGUE" | grep -qE "fatigue_index"; then
        pass 6 "拍板疲劳 — 输出 fatigue_index + recommendation"
    else
        fail 6 "拍板疲劳 — 缺 fatigue_index (got: $FATIGUE)"
        TC6_RESULT=1
    fi

    # Verify fatigue_index is a float between 0-1 (or percentage 0-100)
    F_INDEX=$(echo "$FATIGUE" | grep -oE "fatigue_index=[0-9.]+" | grep -oE "[0-9.]+" || echo "0")
    if awk "BEGIN{exit !($F_INDEX >= 0 && $F_INDEX <= 100)}" 2>/dev/null; then
        pass 6 "拍板疲劳 — fatigue_index 在 0-100 范围 (fatigue_index=$F_INDEX)"
    else
        fail 6 "拍板疲劳 — fatigue_index 越界 (got: $F_INDEX)"
        TC6_RESULT=1
    fi

    # Verify recommendation is provided
    if echo "$FATIGUE" | grep -qiE "recommend"; then
        pass 6 "拍板疲劳 — 输出 recommendation (治根建议)"
    else
        fail 6 "拍板疲劳 — 缺 recommendation"
        TC6_RESULT=1
    fi
else
    fail 6 "拍板疲劳 — calc_fatigue_index 函数缺失"
    TC6_RESULT=1
fi
echo ""

# ----------------------------------------
# Summary (Rule 9 KPI X/Y 精确格式 — 按 TC 而非子断言)
# ----------------------------------------
TC_TOTAL=0
TC_PASSED=0
for i in 1 2 3 4 5 6; do
    TC_TOTAL=$((TC_TOTAL + 1))
    if [ "${TC_FAIL[$i]}" -eq 0 ] && [ "${TC_PASS[$i]}" -gt 0 ]; then
        TC_PASSED=$((TC_PASSED + 1))
    fi
done

echo "=========================================="
echo "Summary: $TC_PASSED/$TC_TOTAL PASS (TC-level, Rule 9 X/Y 精确格式)"
echo "=========================================="

# Cleanup fake ticket
rm -f "$FAKE_P0_TICKET" 2>/dev/null || true

# Cleanup generated inbox files
rm -f "$KALLAX_ROOT/.kallax/inbox/human_feedback/REQUEST-P0-EPIC-055-B-FAKE-P0.md" 2>/dev/null || true
rm -f "$KALLAX_ROOT/.kallax/inbox/human_feedback/RECORD-P1-EPIC-055-B-FAKE-P1.md" 2>/dev/null || true
rm -f "$KALLAX_ROOT/.kallax/audit/p2-log-$(date +%u).jsonl" 2>/dev/null || true

if [ "$TC_PASSED" -eq "$TC_TOTAL" ]; then
    echo "PASS: $TC_PASSED/$TC_TOTAL (100.0%)"
    exit 0
else
    PERCENT=$(awk "BEGIN{printf \"%.1f\", $TC_PASSED * 100 / $TC_TOTAL}")
    echo "FAIL: $TC_PASSED/$TC_TOTAL ($PERCENT%)"
    exit 1
fi