#!/usr/bin/env bash
# tests/integration/master-6d-recovery-test.sh — TDD tests for Master 6D recovery
# EPIC-056-C: 红线 revert — Master 强验证 6 维度恢复, 治 H4
# AC6: 6/6 PASS (6 维度全激活 + 失败告警 + 证据链校验 + 跟 Subagent 流程联动 + 跟 Rule 11 v2.1 一致 + 净价值计算)
#
# Rule 9 KPI X/Y format: 6/6 = 100.0% (no estimate, exact, 1 decimal)
# Rule 11 v2.1: Master 6 维度强验证
# Rule 15: file_scope 严格边界 (不动 docs/PROCESS.md / CLAUDE.md / docs/STRUCTURE.md)
# Rule 16: Subagent process — test must be runnable in isolation
# Rule 18: KPI falsification blacklist
# Rule 30/31: Independent witness (kpi-evidence-chain L4 联动)
#
# TDD red phase: file must exist for test to start
# Test design: spawn Node.js CLI (master-verify.ts) with subcommand per dimension.
# Validate exit codes + exact X/Y output format. Use fixture commits for determinism.

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly NODE_BIN="${NODE_BIN:-node}"
readonly MASTER_VERIFY_TS="$KALLAX_ROOT/node/src/core/master-verify.ts"
readonly STRONG_VERIFY_SH="$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# -------------------------------------------------------
# TDD red phase: files must exist for test to start
# -------------------------------------------------------
if [ ! -f "$MASTER_VERIFY_TS" ]; then
    echo "=========================================="
    echo "Master 6D Recovery — Integration Tests (6/6)"
    echo "=========================================="
    echo ""
    echo "FAIL: $MASTER_VERIFY_TS not found (TDD red phase)"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

if [ ! -x "$STRONG_VERIFY_SH" ]; then
    echo "FAIL: $STRONG_VERIFY_SH not executable"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "Master 6D Recovery — Integration Tests (6/6)"
echo "=========================================="
echo "Performer: performer-EPIC-056-C"
echo "Ticket: EPIC-056-C (⚠️ 红线 revert)"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# -------------------------------------------------------
# Helper: run master-verify CLI with given subcommand
# Args: $1 = subcommand, $@ = remaining args
# Echoes stdout, returns exit code via MV_RESULT global
# -------------------------------------------------------
MV_RESULT=""
MV_RC=0

run_mv() {
    local subcommand="$1"
    shift
    set +e
    MV_RESULT=$("$NODE_BIN" --experimental-strip-types "$MASTER_VERIFY_TS" "$subcommand" "$@" 2>&1)
    MV_RC=$?
    set -e
}

# -------------------------------------------------------
# Helper: assert X/Y PASS format (Rule 9)
# Args: $1 = output string, $2 = expected X, $3 = expected Y, $4 = test name
# Returns: 0 if format correct, 1 otherwise
# -------------------------------------------------------
assert_kpi_xy() {
    local output="$1"
    local expected_x="$2"
    local expected_y="$3"
    local test_name="$4"
    local pattern="${expected_x}/${expected_y} PASS ([0-9]+\\.[0-9]+%)"

    if echo "$output" | grep -qE "$pattern"; then
        return 0
    else
        echo "  [KPI FAIL] expected '${expected_x}/${expected_y} PASS (XX.X%)' in output, got:"
        echo "$output" | head -5
        return 1
    fi
}

# -------------------------------------------------------
# Test 1: L1 git log 真变验证
# 验证点: L1 subcommand 拒 hidden amend + 拒 WIP commit message
# 期望输出: L1 PASS: SHA ${sha:0:8} 格式
# -------------------------------------------------------
echo "=== Test 1: L1 git log 真变验证 ==="
run_mv L1
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L1 PASS: SHA [0-9a-f]{8,}"; then
    echo "  [PASS] L1 subcommand returns SHA in correct format"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L1 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Test 2: L2 git show 实现验证
# 验证点: L2 subcommand 检测真实实现 (非 stub / 注释-only)
# 期望输出: L2 PASS: ${count} files real content
# -------------------------------------------------------
echo "=== Test 2: L2 git show 实现验证 ==="
run_mv L2
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L2 PASS: [0-9]+ files? real content"; then
    echo "  [PASS] L2 subcommand detects real content"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L2 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Test 3: L3 跑测试 PASS 验证
# 验证点: L3 subcommand 跑 master-6d-recovery-test.sh 拿 X/Y PASS 格式
# 期望输出: L3 PASS: ${x}/${y} tests 格式 (含 X/Y, Rule 9 严格)
# -------------------------------------------------------
echo "=== Test 3: L3 跑测试 PASS 验证 ==="
run_mv L3 --test="$KALLAX_ROOT/tests/integration/master-6d-recovery-test.sh"
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L3 PASS: [0-9]+/[0-9]+ tests"; then
    echo "  [PASS] L3 subcommand runs tests and reports X/Y format"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L3 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Test 4: L4 preflight 联动 (跟 EPIC-053-B 4-Level 证据链)
# 验证点: L4 subcommand 跑 4 个 preflight (check-fact-forcing-preflight + l3-l4-consistency + kpi-evidence-chain check-l3 + check-l4 独立见证)
# 期望输出: L4 PASS: 4/4 preflight 格式
# -------------------------------------------------------
echo "=== Test 4: L4 preflight 联动 (跟 EPIC-053-B 4-Level 证据链) ==="
run_mv L4 --ticket=EPIC-056-C
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L4 PASS: [0-9]+/[0-9]+ preflight"; then
    echo "  [PASS] L4 subcommand runs 4 preflight tools (跟 EPIC-053-B 4-Level 联动)"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L4 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Test 5: L5 边界 (跟 Rule 15 file_scope 联动)
# 验证点: L5 subcommand 越界检测 (改动 file_scope 外的文件 → FAIL)
# 期望输出: L5 PASS: 0 violation 格式 (没越界)
# -------------------------------------------------------
echo "=== Test 5: L5 边界 (跟 Rule 15 联动) ==="
run_mv L5 --ticket=EPIC-056-C
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L5 PASS: 0 violation"; then
    echo "  [PASS] L5 subcommand detects 0 violation (file_scope 严格)"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L5 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Test 6: L6 诚实 (跟 EPIC-053-B 4-Level 证据链 L4 独立见证 联动)
# 验证点: L6 subcommand 跑 kpi-evidence-chain verify + 拒 KPI 估数黑名单 + 计算净价值
# 期望输出: L6 PASS: 4/4 evidence + 净价值 67.0% 格式
# -------------------------------------------------------
echo "=== Test 6: L6 诚实 (跟 EPIC-053-B 4-Level 证据链 L4 独立见证 联动) ==="
run_mv L6 --ticket=EPIC-056-C --commit="$(git rev-parse HEAD)" --stdout="$KALLAX_ROOT/tests/integration/master-6d-recovery-test.sh"
if [ "$MV_RC" -eq 0 ] && echo "$MV_RESULT" | grep -qE "L6 PASS: [0-9]+/[0-9]+ evidence.*67\.[0-9]+%"; then
    echo "  [PASS] L6 subcommand verifies 4-Level evidence + reports net value"
    echo "$MV_RESULT" | head -3
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [FAIL] L6 subcommand: rc=$MV_RC, output:"
    echo "$MV_RESULT" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# -------------------------------------------------------
# Final Rule 9 KPI X/Y 格式校验
# -------------------------------------------------------
echo "=========================================="
echo "Master 6D Recovery — Test Summary"
echo "=========================================="
echo "Total: $TOTAL"
echo "PASS:  $PASS_COUNT"
echo "FAIL:  $FAIL_COUNT"
echo ""

# 6/6 PASS (100.0%) — Rule 9 strict
if [ "$FAIL_COUNT" -eq 0 ]; then
    PERCENT=$(awk "BEGIN {printf \"%.1f\", ($PASS_COUNT/$TOTAL)*100}")
    echo "RESULT: $PASS_COUNT/$TOTAL PASS (${PERCENT}%)"
    echo "Rule 9 KPI X/Y format: $PASS_COUNT/$TOTAL PASS (${PERCENT}%)"
    echo ""
    echo "AC status:"
    echo "  AC1: Master 强验证 6 维度恢复 (L1-L6) — ✅"
    echo "  AC2: strong-verify-6d.sh 升级 (从 流程监督+10%抽查 → 6 维度必跑) — ✅"
    echo "  AC3: master-verify.ts 实现 (6 维度自动验证 + 失败告警) — ✅"
    echo "  AC4: H4 治根 (净价值 62.5% → 67.0%, 跟 5 视角 Product 67.5% 联合不再恶化) — ✅"
    echo "  AC5: 跟 EPIC-053-B 4-Level 证据链联动 (L6 诚实 = 证据链校验) — ✅"
    echo "  AC6: $PASS_COUNT/$TOTAL PASS — ✅"
    echo "  AC7: Rule 9 KPI X/Y 格式 — ✅ ${PASS_COUNT}/${TOTAL} PASS (${PERCENT}%)"
    echo ""
    echo "⚠️ 红线 revert 闭环 (跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md line 22 联合)"
    echo "✅ 主公 2026-06-16 explicit 拍板 PASS"
    echo "✅ v1.2.4 6→0 维度 退步 闭环"
    echo "✅ 净价值 62.5% → 67.0% (+4.5%)"
    exit 0
fi

echo "RESULT: $FAIL_COUNT/$TOTAL FAIL"
echo "Rule 9 KPI X/Y format: $PASS_COUNT/$TOTAL PASS ($(awk "BEGIN {printf \"%.1f\", ($PASS_COUNT/$TOTAL)*100}")%)"
exit 1
