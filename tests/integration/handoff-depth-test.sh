#!/bin/bash
#===============================================================================
# tests/integration/handoff-depth-test.sh — Integration test for
# dispatch.sh --handoff-depth=<L1|L2|L3|L4> + --sub-role (EPIC-038-A Rule 15)
#
# Tests 6 cases (per EPIC-038-A AC #6 ≥4 case: L1/L2/L3/L4 派单):
#   1. --handoff-depth=L1 (default) → DISPATCH output 含 handoff_depth=L1
#   2. --handoff-depth=L2 → DISPATCH output 含 handoff_depth=L2
#   3. --handoff-depth=L3 → DISPATCH output 含 handoff_depth=L3
#   4. --handoff-depth=L4 → DISPATCH output 含 handoff_depth=L4
#   5. --sub-role=<coder|reviewer|tester|docs> 4 枚举 PASS
#   6. Invalid --handoff-depth=L5 / --sub-role=invalid → exit 1 (红线)
#
# Rule 8 落地: 集成 dispatch.sh, 验证 schema 扩展 + 参数解析
# Source: EPIC-038-A ticket.json AC #6
#===============================================================================

set -euo pipefail

readonly TEST_ID="$$"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly DISPATCH="${WORKTREE_ROOT}/scripts/conductor/dispatch.sh"

PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_info() { echo "  [INFO] $1"; }

#===============================================================================
# Test 1: --handoff-depth=L1 (default) → handoff_depth=L1
#===============================================================================
test_handoff_l1_default() {
  echo ""
  echo "=== Test 1: --handoff-depth=L1 (default, 无参数) ==="

  local output
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" EPIC-038-A backend accept 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "L1 default: exit code $rc (expected 0)"
    echo "    output: $output"
    return 1
  fi

  if echo "$output" | grep -q "handoff_depth=L1"; then
    log_pass "L1 default: handoff_depth=L1 (Rule 15 default)"
  else
    log_fail "L1 default: missing handoff_depth=L1"
    echo "    output: $output"
    return 1
  fi

  if echo "$output" | grep -q "sub_role=none"; then
    log_pass "L1 default: sub_role=none (no sub-role specified)"
  else
    log_fail "L1 default: missing sub_role=none"
    echo "    output: $output"
    return 1
  fi
}

#===============================================================================
# Test 2: --handoff-depth=L2 (EPIC 内多 ticket 串行)
#===============================================================================
test_handoff_l2() {
  echo ""
  echo "=== Test 2: --handoff-depth=L2 ==="

  local output
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth=L2 EPIC-038-A backend accept 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "L2: exit code $rc (expected 0)"
    echo "    output: $output"
    return 1
  fi

  if echo "$output" | grep -q "handoff_depth=L2"; then
    log_pass "L2: handoff_depth=L2 (EPIC 内串行)"
  else
    log_fail "L2: missing handoff_depth=L2"
    echo "    output: $output"
    return 1
  fi
}

#===============================================================================
# Test 3: --handoff-depth=L3 (跨 EPIC 同 PHASE)
#===============================================================================
test_handoff_l3() {
  echo ""
  echo "=== Test 3: --handoff-depth=L3 ==="

  local output
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth=L3 EPIC-038-A backend accept 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "L3: exit code $rc (expected 0)"
    echo "    output: $output"
    return 1
  fi

  if echo "$output" | grep -q "handoff_depth=L3"; then
    log_pass "L3: handoff_depth=L3 (跨 EPIC 同 PHASE)"
  else
    log_fail "L3: missing handoff_depth=L3"
    echo "    output: $output"
    return 1
  fi
}

#===============================================================================
# Test 4: --handoff-depth=L4 (跨 PHASE)
#===============================================================================
test_handoff_l4() {
  echo ""
  echo "=== Test 4: --handoff-depth=L4 ==="

  local output
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth=L4 EPIC-038-A backend accept 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "L4: exit code $rc (expected 0)"
    echo "    output: $output"
    return 1
  fi

  if echo "$output" | grep -q "handoff_depth=L4"; then
    log_pass "L4: handoff_depth=L4 (跨 PHASE)"
  else
    log_fail "L4: missing handoff_depth=L4"
    echo "    output: $output"
    return 1
  fi
}

#===============================================================================
# Test 5: --sub-role 4 枚举 (coder/reviewer/tester/docs)
#===============================================================================
test_sub_role_enum() {
  echo ""
  echo "=== Test 5: --sub-role 4 枚举 PASS ==="

  local role
  for role in coder reviewer tester docs; do
    local output
    output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth=L2 --sub-role="$role" EPIC-038-A backend accept 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      log_fail "sub-role=$role: exit code $rc (expected 0)"
      echo "    output: $output"
      continue
    fi

    if echo "$output" | grep -q "sub_role=$role"; then
      log_pass "sub-role=$role: PASS (Rule 15 sub-role enum)"
    else
      log_fail "sub-role=$role: missing in output"
      echo "    output: $output"
    fi
  done
}

#===============================================================================
# Test 6: Invalid handoff-depth / sub-role → exit 1 (红线)
#===============================================================================
test_invalid_args() {
  echo ""
  echo "=== Test 6: Invalid args → FAIL (红线 5: enum 强制) ==="

  # 6a: --handoff-depth=L5 invalid
  local output
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth=L5 EPIC-038-A backend accept 2>&1 || true)
  if echo "$output" | grep -q "must be L1|L2|L3|L4"; then
    log_pass "invalid L5: rejected with clear error (红线 5)"
  else
    log_fail "invalid L5: should reject with enum error"
    echo "    output: $output"
  fi

  # 6b: --sub-role=invalid
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --sub-role=invalid EPIC-038-A backend accept 2>&1 || true)
  if echo "$output" | grep -q "must be coder|reviewer|tester|docs"; then
    log_pass "invalid sub-role: rejected with clear error (红线 5)"
  else
    log_fail "invalid sub-role: should reject with enum error"
    echo "    output: $output"
  fi

  # 6c: --handoff-depth= 空值
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" --handoff-depth= EPIC-038-A backend accept 2>&1 || true)
  if echo "$output" | grep -q "requires non-empty"; then
    log_pass "empty handoff-depth: rejected (红线 5)"
  else
    log_fail "empty handoff-depth: should reject"
    echo "    output: $output"
  fi
}

#===============================================================================
# Run all tests
#===============================================================================
echo "==============================================="
echo " handoff-depth Integration Test (EPIC-038-A)"
echo " 跟 Rule 15 4 层接手 + Performer sub-role 联合"
echo "==============================================="

test_handoff_l1_default
test_handoff_l2
test_handoff_l3
test_handoff_l4
test_sub_role_enum
test_invalid_args

echo ""
echo "==============================================="
echo " Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL (out of 6 tests)"
echo "==============================================="

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "PASS: handoff-depth-test.sh (EPIC-038-A Rule 15 落地)"
  exit 0
else
  echo "FAIL: handoff-depth-test.sh ($FAIL_COUNT failures)"
  exit 1
fi
