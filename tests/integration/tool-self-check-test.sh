#!/usr/bin/env bash
# tests/integration/tool-self-check-test.sh — TDD tests for tool-self-check.sh
# EPIC-053-C AC3: 8/8 PASS (4 工具 × 2 case: 真 PASS + 真 FAIL)
#
# Test design:
#   4 工具: review.sh, check-kpi-precision.sh, check-test-case-isolation.sh, check-scope-creep.sh
#   2 case: true-pass (工具应判 PASS) + true-fail (工具应判 FAIL)
#   = 8 case
#
# Rule 9 KPI X/Y format: 8/8 = 100.0% (no estimate, exact)
#
# 4 维度 (隐式) — 每个 tool 的 self-check 验证:
#   D1: syntax (bash -n)
#   D2: pattern compat (no [[:space:]] in array)
#   D3: true-pass detection (exit 0 on clean input)
#   D4: true-fail detection (exit non-zero on bad input)
#
# 跟 EPIC-053-B 联动: 4 工具是 kpi-evidence-chain.sh L3 的核心 tools
# 跟 BE-10 治根联动: D2 拦截 [[:space:]] 数组模式复发
# 跟 EPIC-048 联动: meta-tool 守住 framework 不退化

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly TOOL_SELF_CHECK="$KALLAX_ROOT/scripts/verify/tool-self-check.sh"

# 4 工具列表
readonly TOOLS=(
    "review.sh"
    "check-kpi-precision.sh"
    "check-test-case-isolation.sh"
    "check-scope-creep.sh"
)

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=8

# TDD red phase: verify tool-self-check.sh exists
if [ ! -f "$TOOL_SELF_CHECK" ]; then
    echo "=========================================="
    echo "Tool Self-Check — Integration Tests (8/8)"
    echo "=========================================="
    echo ""
    echo "FAIL: $TOOL_SELF_CHECK not found (TDD red phase)"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

# TDD red phase: verify tool-self-check.sh is executable
if [ ! -x "$TOOL_SELF_CHECK" ]; then
    echo "=========================================="
    echo "Tool Self-Check — Integration Tests (8/8)"
    echo "=========================================="
    echo ""
    echo "FAIL: $TOOL_SELF_CHECK not executable (TDD red phase)"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "Tool Self-Check — Integration Tests (8/8)"
echo "4 工具 × 2 case = 8 cases"
echo "=========================================="
echo ""

# Temp dir for cleanup
TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# -------------------------------------------------------
# Helper: run a single check, increment counters
# Args: $1 = tool, $2 = scenario
# Returns: 0 if check passed, 1 if failed
# -------------------------------------------------------
run_check() {
    local tool="$1"
    local scenario="$2"

    echo "--- Check: $tool / $scenario ---"
    set +e
    bash "$TOOL_SELF_CHECK" check "$tool" "$scenario" 2>&1
    local rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
        echo "[PASS] $tool / $scenario — tool correctly calibrated"
        PASS_COUNT=$((PASS_COUNT+1))
        return 0
    else
        echo "[FAIL] $tool / $scenario — tool self-check FAIL (exit=$rc)"
        FAIL_COUNT=$((FAIL_COUNT+1))
        return 1
    fi
    echo ""
}

# -------------------------------------------------------
# Test 1: review.sh / true-pass
# Expectation: review.sh exits 0 on clean commit (no estimate pattern)
# -------------------------------------------------------
run_check "review.sh" "true-pass"
echo ""

# -------------------------------------------------------
# Test 2: review.sh / true-fail
# Expectation: review.sh exits non-zero on commit with ~70% (kpi-precision FAIL)
# -------------------------------------------------------
run_check "review.sh" "true-fail"
echo ""

# -------------------------------------------------------
# Test 3: check-kpi-precision.sh / true-pass
# Expectation: check-kpi-precision.sh exits 0 on clean commit msg
# -------------------------------------------------------
run_check "check-kpi-precision.sh" "true-pass"
echo ""

# -------------------------------------------------------
# Test 4: check-kpi-precision.sh / true-fail
# Expectation: check-kpi-precision.sh exits non-zero on ~70%
# -------------------------------------------------------
run_check "check-kpi-precision.sh" "true-fail"
echo ""

# -------------------------------------------------------
# Test 5: check-test-case-isolation.sh / true-pass
# Expectation: check-test-case-isolation.sh exits 0 on clean experts
# -------------------------------------------------------
run_check "check-test-case-isolation.sh" "true-pass"
echo ""

# -------------------------------------------------------
# Test 6: check-test-case-isolation.sh / true-fail
# Expectation: check-test-case-isolation.sh exits non-zero on leaked test case
# -------------------------------------------------------
run_check "check-test-case-isolation.sh" "true-fail"
echo ""

# -------------------------------------------------------
# Test 7: check-scope-creep.sh / true-pass
# Expectation: check-scope-creep.sh exits 0 on in-scope change
# -------------------------------------------------------
run_check "check-scope-creep.sh" "true-pass"
echo ""

# -------------------------------------------------------
# Test 8: check-scope-creep.sh / true-fail
# Expectation: check-scope-creep.sh exits non-zero on out-of-scope change
# -------------------------------------------------------
run_check "check-scope-creep.sh" "true-fail"
echo ""

# -------------------------------------------------------
# Summary — exact X/Y format (Rule 9 KPI precision)
# -------------------------------------------------------
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAIL: $FAIL_COUNT check(s) failed"
    echo "$PASS_COUNT/$TOTAL PASS"
    exit 1
fi
echo "PASS: all $TOTAL integration checks passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0
