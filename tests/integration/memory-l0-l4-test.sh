#!/bin/bash
# tests/integration/memory-l0-l4-test.sh — Integration test for memory-promote.sh (EPIC-059-H)
#
# 5 mock 场景 × 各 1+ 案例 + 5/5 PASS 验证
# L4: 5 mock 场景 PASS (跟 Rule 9 X/Y 格式 联合)
#
# Mock 设计 (跟 Step 6 AC 联合):
#   Mock 1: 5 层 全部 满足 → 5/5 PASS
#   Mock 2: L1 缺失 → 4/5 PASS + 1 FAIL
#   Mock 3: L3 缺失 → 4/5 PASS + 1 FAIL
#   Mock 4: 升级 路径 错误 → 4/5 PASS + 1 FAIL
#   Mock 5: 全部 缺失 → 0/5 PASS
#
# 跟 confluence/memory/LAYERS.md 联合
# 跟 eket confluence/memory/ 多级记忆 模式 联合
# 跟 ~/.claude/knowledge/core/patterns/knowledge-system.md L0-L4 架构 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9-hard-rules.md §1 联合)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMOTE_SCRIPT="${KALLAX_ROOT}/scripts/memory-promote.sh"

# Temp dir for test isolation (跟 dispatch-audit-test.sh 模式 一致)
TMP_ROOT="${BASH_SOURCE[0]}.tmp.$$"
cleanup() {
  rm -rf "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT
mkdir -p "$TMP_ROOT"

# Reusable: create all 5 layer dirs in given root
create_all_layers() {
  local root="$1"
  mkdir -p "$root/.kallax/state"
  mkdir -p "$root/confluence/decisions"
  mkdir -p "$root/confluence/memory/lessons"
  mkdir -p "$root/confluence/memory/patterns"
  mkdir -p "$root/confluence/memory/research"
}

echo "=== memory-promote.sh Integration Tests (5 mock scenarios, 跟 EPIC-059-H 联合) ==="
echo "KALLAX_ROOT=$KALLAX_ROOT"
echo "PROMOTE_SCRIPT=$PROMOTE_SCRIPT"
echo "TMP_ROOT=$TMP_ROOT"
echo ""

# ============================================================
# Counters
# ============================================================
MOCK_PASS=0
MOCK_FAIL=0
ASSERT_PASS=0
ASSERT_FAIL=0

# Helper: assert pass/fail
assert_pass() {
  echo "    ✓ $1"
  ASSERT_PASS=$((ASSERT_PASS + 1))
}

assert_fail() {
  echo "    ✗ $1"
  ASSERT_FAIL=$((ASSERT_FAIL + 1))
}

mock_pass() {
  echo "  [MOCK PASS] $1"
  MOCK_PASS=$((MOCK_PASS + 1))
}

mock_fail() {
  echo "  [MOCK FAIL] $1"
  MOCK_FAIL=$((MOCK_FAIL + 1))
}

# ============================================================
# Mock 1: 5 层 全部 满足 → 5/5 PASS
# ============================================================
echo ""
echo "[Mock 1] All 5 layers satisfied → 5/5 PASS"
MOCK1_ROOT="${TMP_ROOT}/mock1"
create_all_layers "$MOCK1_ROOT"

OUTPUT=$(KALLAX_ROOT="$MOCK1_ROOT" bash "$PROMOTE_SCRIPT" verify-all 2>&1)
EXIT_CODE=$?
echo "$OUTPUT" | sed 's/^/  /'

if [ "$EXIT_CODE" = "0" ]; then
  assert_pass "verify-all exit code = 0 (5/5 layer checks all PASS)"
else
  assert_fail "verify-all exit code = $EXIT_CODE (expected 0)"
fi

if echo "$OUTPUT" | grep -q "5/5 PASS, 0/5 FAIL"; then
  assert_pass "verify-all reports 5/5 PASS, 0/5 FAIL"
else
  assert_fail "verify-all does not report 5/5 PASS, 0/5 FAIL"
fi

# Count PASS marks in output
PASS_COUNT=$(echo "$OUTPUT" | grep -c "  ✓ L" || true)
if [ "$PASS_COUNT" = "5" ]; then
  assert_pass "5 layer ✓ marks found in output"
else
  assert_fail "expected 5 layer ✓ marks, got $PASS_COUNT"
fi

if [ "$ASSERT_FAIL" = "0" ]; then
  mock_pass "Mock 1: 5/5 PASS"
else
  mock_fail "Mock 1: assertions failed"
fi

# ============================================================
# Mock 2: L1 缺失 → 4/5 PASS + 1 FAIL
# ============================================================
echo ""
echo "[Mock 2] L1 missing → 4/5 PASS + 1 FAIL"
ASSERT_FAIL=0  # reset for this mock

MOCK2_ROOT="${TMP_ROOT}/mock2"
create_all_layers "$MOCK2_ROOT"
rm -rf "$MOCK2_ROOT/confluence/decisions"  # Remove L1

OUTPUT=$(KALLAX_ROOT="$MOCK2_ROOT" bash "$PROMOTE_SCRIPT" verify-all 2>&1)
EXIT_CODE=$?
echo "$OUTPUT" | sed 's/^/  /'

if [ "$EXIT_CODE" = "1" ]; then
  assert_pass "verify-all exit code = 1 (1 failure, expected)"
else
  assert_fail "verify-all exit code = $EXIT_CODE (expected 1)"
fi

if echo "$OUTPUT" | grep -q "4/5 PASS, 1/5 FAIL"; then
  assert_pass "verify-all reports 4/5 PASS, 1/5 FAIL"
else
  assert_fail "verify-all does not report 4/5 PASS, 1/5 FAIL"
fi

if echo "$OUTPUT" | grep -q "✗ L1"; then
  assert_pass "L1 marked as missing"
else
  assert_fail "L1 not marked as missing"
fi

if [ "$ASSERT_FAIL" = "0" ]; then
  mock_pass "Mock 2: 4/5 PASS + 1 FAIL (L1 missing)"
else
  mock_fail "Mock 2: assertions failed"
fi

# ============================================================
# Mock 3: L3 缺失 → 4/5 PASS + 1 FAIL
# ============================================================
echo ""
echo "[Mock 3] L3 missing → 4/5 PASS + 1 FAIL"
ASSERT_FAIL=0

MOCK3_ROOT="${TMP_ROOT}/mock3"
create_all_layers "$MOCK3_ROOT"
rm -rf "$MOCK3_ROOT/confluence/memory/patterns"  # Remove L3

OUTPUT=$(KALLAX_ROOT="$MOCK3_ROOT" bash "$PROMOTE_SCRIPT" verify-all 2>&1)
EXIT_CODE=$?
echo "$OUTPUT" | sed 's/^/  /'

if [ "$EXIT_CODE" = "1" ]; then
  assert_pass "verify-all exit code = 1 (1 failure, expected)"
else
  assert_fail "verify-all exit code = $EXIT_CODE (expected 1)"
fi

if echo "$OUTPUT" | grep -q "4/5 PASS, 1/5 FAIL"; then
  assert_pass "verify-all reports 4/5 PASS, 1/5 FAIL"
else
  assert_fail "verify-all does not report 4/5 PASS, 1/5 FAIL"
fi

if echo "$OUTPUT" | grep -q "✗ L3"; then
  assert_pass "L3 marked as missing"
else
  assert_fail "L3 not marked as missing"
fi

if [ "$ASSERT_FAIL" = "0" ]; then
  mock_pass "Mock 3: 4/5 PASS + 1 FAIL (L3 missing)"
else
  mock_fail "Mock 3: assertions failed"
fi

# ============================================================
# Mock 4: 升级 路径 错误 → 4/5 PASS + 1 FAIL
# ============================================================
echo ""
echo "[Mock 4] Bad promotion path (L2→L4 skip) → 4/5 PASS + 1 FAIL"
ASSERT_FAIL=0

MOCK4_ROOT="${TMP_ROOT}/mock4"
create_all_layers "$MOCK4_ROOT"

# Create a fake L2 source file
TEST_SRC="${MOCK4_ROOT}/test-source.md"
echo "# Test L2 source" > "$TEST_SRC"

# Try invalid promotion: L2→L4 (skipping L3)
OUTPUT=$(KALLAX_ROOT="$MOCK4_ROOT" bash "$PROMOTE_SCRIPT" promote L2 L4 "$TEST_SRC" "${MOCK4_ROOT}/confluence/memory/research/test-source.md" 2>&1)
EXIT_CODE=$?
echo "$OUTPUT" | sed 's/^/  /'

if [ "$EXIT_CODE" = "1" ]; then
  assert_pass "promote L2→L4 rejected with exit code 1"
else
  assert_fail "promote L2→L4 exit code = $EXIT_CODE (expected 1)"
fi

if echo "$OUTPUT" | grep -q "Invalid promotion path"; then
  assert_pass "Invalid promotion path message displayed"
else
  assert_fail "Invalid promotion path message missing"
fi

# Verify L2→L3 (valid path) works
MOCK4B_ROOT="${TMP_ROOT}/mock4b"
create_all_layers "$MOCK4B_ROOT"
echo "# Test L2 source" > "${MOCK4B_ROOT}/test-source.md"

OUTPUT_VALID=$(KALLAX_ROOT="$MOCK4B_ROOT" bash "$PROMOTE_SCRIPT" promote L2 L3 "${MOCK4B_ROOT}/test-source.md" "${MOCK4B_ROOT}/confluence/memory/patterns/test-source.md" 2>&1)
EXIT_CODE_VALID=$?

if [ "$EXIT_CODE_VALID" = "0" ]; then
  assert_pass "promote L2→L3 (valid path) succeeds with exit code 0"
else
  assert_fail "promote L2→L3 exit code = $EXIT_CODE_VALID (expected 0)"
fi

if [ -f "${MOCK4B_ROOT}/confluence/memory/patterns/test-source.md" ]; then
  assert_pass "L2→L3 destination file created"
else
  assert_fail "L2→L3 destination file not created"
fi

if [ "$ASSERT_FAIL" = "0" ]; then
  mock_pass "Mock 4: 4/5 PASS + 1 FAIL (bad promotion path rejected, valid path works)"
else
  mock_fail "Mock 4: assertions failed"
fi

# ============================================================
# Mock 5: 全部 缺失 → 0/5 PASS
# ============================================================
echo ""
echo "[Mock 5] All layers missing → 0/5 PASS"
ASSERT_FAIL=0

MOCK5_ROOT="${TMP_ROOT}/mock5"
# Don't create any dirs
mkdir -p "$MOCK5_ROOT"  # Just create root, no subdirs

OUTPUT=$(KALLAX_ROOT="$MOCK5_ROOT" bash "$PROMOTE_SCRIPT" verify-all 2>&1)
EXIT_CODE=$?
echo "$OUTPUT" | sed 's/^/  /'

if [ "$EXIT_CODE" = "5" ]; then
  assert_pass "verify-all exit code = 5 (5 failures, expected)"
else
  assert_fail "verify-all exit code = $EXIT_CODE (expected 5)"
fi

if echo "$OUTPUT" | grep -q "0/5 PASS, 5/5 FAIL"; then
  assert_pass "verify-all reports 0/5 PASS, 5/5 FAIL"
else
  assert_fail "verify-all does not report 0/5 PASS, 5/5 FAIL"
fi

FAIL_COUNT=$(echo "$OUTPUT" | grep -c "  ✗ L" || true)
if [ "$FAIL_COUNT" = "5" ]; then
  assert_pass "5 layer ✗ marks found in output"
else
  assert_fail "expected 5 layer ✗ marks, got $FAIL_COUNT"
fi

# Verify all 5 layers marked missing
for layer in L0 L1 L2 L3 L4; do
  if echo "$OUTPUT" | grep -q "✗ $layer"; then
    assert_pass "$layer marked as missing"
  else
    assert_fail "$layer not marked as missing"
  fi
done

if [ "$ASSERT_FAIL" = "0" ]; then
  mock_pass "Mock 5: 0/5 PASS (all layers missing)"
else
  mock_fail "Mock 5: assertions failed"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Summary ==="
echo "Mocks: $MOCK_PASS/$((MOCK_PASS + MOCK_FAIL)) PASS"
echo "Assertions: $ASSERT_PASS PASS, $ASSERT_FAIL FAIL"
echo ""

if [ "$MOCK_FAIL" = "0" ] && [ "$ASSERT_FAIL" = "0" ]; then
  echo "=== Final: 5/5 mock scenarios PASS ==="
  exit 0
else
  echo "=== Final: $MOCK_PASS/5 mock scenarios PASS ==="
  exit 1
fi
