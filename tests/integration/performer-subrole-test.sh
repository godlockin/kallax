#!/bin/bash
# performer-subrole-test.sh — Integration test for dispatch.sh 4 派单模式 (EPIC-038-B)
#
# Tests 4 类 Performer sub-role × 2 modes (accept/override) + 错误处理 = ≥8 case
#
# Source: EPIC-038-B ticket.json AC #3
# 跟 EPIC-038-A handoff_depth 字段 + Rule 15 联合
# 跟 BE-23 + BE-25 + BE-26 fixes in place (1 ticket 1 subagent 串行, 0 静默 output)

set -euo pipefail

# Force fixture mode (KALLAX_TEST_FIXTURES=1) so dispatch.sh uses test instances
export KALLAX_TEST_FIXTURES=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/conductor/dispatch.sh"

PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Extract handoff_depth/sub_role from DISPATCH output line
extract_field() {
  local output="$1"
  local field="$2"
  # Only look at lines containing the field
  echo "$output" | grep -E "${field}=" | head -1 | sed -E "s/.*${field}=([^ ]+).*/\\1/"
}

#===============================================================================
# Test 1: L1 → analyst (accept mode, default)
#===============================================================================
test_l1_analyst_accept() {
  echo ""
  echo "=== Test 1: L1 → analyst (accept mode) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T1" "bash" "accept" "" --handoff-depth=L1 2>&1)

  local sub_role
  sub_role=$(extract_field "$output" "sub_role")

  if [[ "$sub_role" == "performer-analyst" ]]; then
    log_pass "L1 accept: sub_role=performer-analyst"
  else
    log_fail "L1 accept: expected sub_role=performer-analyst, got sub_role='$sub_role'"
    echo "    output: $output"
  fi

  if echo "$output" | grep -q "handoff_depth=L1"; then
    log_pass "L1 accept: output contains handoff_depth=L1"
  else
    log_fail "L1 accept: missing handoff_depth=L1 in output"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 2: L2 → incremental (accept mode)
#===============================================================================
test_l2_incremental_accept() {
  echo ""
  echo "=== Test 2: L2 → incremental (accept mode) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T2" "bash" "accept" "" --handoff-depth=L2 2>&1)

  local sub_role
  sub_role=$(extract_field "$output" "sub_role")

  if [[ "$sub_role" == "performer-incremental" ]]; then
    log_pass "L2 accept: sub_role=performer-incremental"
  else
    log_fail "L2 accept: expected sub_role=performer-incremental, got sub_role='$sub_role'"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 3: L3 → major (accept mode)
#===============================================================================
test_l3_major_accept() {
  echo ""
  echo "=== Test 3: L3 → major (accept mode) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T3" "bash" "accept" "" --handoff-depth=L3 2>&1)

  local sub_role
  sub_role=$(extract_field "$output" "sub_role")

  if [[ "$sub_role" == "performer-major" ]]; then
    log_pass "L3 accept: sub_role=performer-major"
  else
    log_fail "L3 accept: expected sub_role=performer-major, got sub_role='$sub_role'"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 4: L4 → auditor (accept mode)
#===============================================================================
test_l4_auditor_accept() {
  echo ""
  echo "=== Test 4: L4 → auditor (accept mode) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T4" "bash" "accept" "" --handoff-depth=L4 2>&1)

  local sub_role
  sub_role=$(extract_field "$output" "sub_role")

  if [[ "$sub_role" == "performer-auditor" ]]; then
    log_pass "L4 accept: sub_role=performer-auditor"
  else
    log_fail "L4 accept: expected sub_role=performer-auditor, got sub_role='$sub_role'"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 5: L1 → analyst (override mode, decision=override keeps handoff_depth)
# 注: per dispatch.sh 设计, override 决策下 handoff_depth 不强制 sub-role (主公 D2 决策权)
# 测试 override + handoff-depth 联合使用时, final 应是 OVERRIDE_TO, sub_role 字段不应出现在 output
#===============================================================================
test_l1_analyst_override() {
  echo ""
  echo "=== Test 5: L1 + override (decision=override priority) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T5" "bash" "override" "performer-override-target" --handoff-depth=L1 2>&1)

  local final_id
  final_id=$(extract_field "$output" "final")

  if [[ "$final_id" == "performer-override-target" ]]; then
    log_pass "L1+override: final=performer-override-target (override 决策权优先)"
  else
    log_fail "L1+override: expected final=performer-override-target, got final='$final_id'"
    echo "    output: $output"
  fi

  # 决策权 override: handoff_depth 标记, 但 sub_role 不强制 (跟主公 D2 一致)
  if echo "$output" | grep -q "decision=override"; then
    log_pass "L1+override: decision=override 在 output"
  else
    log_fail "L1+override: missing decision=override"
  fi
}

#===============================================================================
# Test 6: L2 + override (主公 override 决策, 保留 L2 标记)
#===============================================================================
test_l2_incremental_override() {
  echo ""
  echo "=== Test 6: L2 + override ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T6" "bash" "override" "performer-override-target" --handoff-depth=L2 2>&1)

  if echo "$output" | grep -q "handoff_depth=L2" && echo "$output" | grep -q "final=performer-override-target"; then
    log_pass "L2+override: handoff_depth=L2 保留 + final=performer-override-target"
  else
    log_fail "L2+override: expected handoff_depth=L2 + final=performer-override-target"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 7: --handoff-depth 无值 → 报错
#===============================================================================
test_handoff_depth_no_value() {
  echo ""
  echo "=== Test 7: --handoff-depth= (空值) → 报错 ==="
  local rc
  set +e
  bash "$DISPATCH" "EPIC-038B-T7" "bash" "accept" "" --handoff-depth= 2>/dev/null
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log_pass "空 handoff-depth 报错 (rc=$rc, expected non-zero)"
  else
    log_fail "空 handoff-depth 应该报错, got rc=$rc"
  fi
}

#===============================================================================
# Test 8: --handoff-depth=INVALID → 报错 (enum 验证)
#===============================================================================
test_handoff_depth_invalid() {
  echo ""
  echo "=== Test 8: --handoff-depth=INVALID (enum 验证) ==="
  local rc
  set +e
  bash "$DISPATCH" "EPIC-038B-T8" "bash" "accept" "" --handoff-depth=INVALID 2>/dev/null
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log_pass "无效 handoff-depth 报错 (rc=$rc, expected non-zero)"
  else
    log_fail "无效 handoff-depth 应该报错, got rc=$rc"
  fi
}

#===============================================================================
# Test 9: --handoff-depth 不带 = → 报错
#===============================================================================
test_handoff_depth_no_equals() {
  echo ""
  echo "=== Test 9: --handoff-depth (无 =) → 报错 ==="
  local rc
  set +e
  bash "$DISPATCH" "EPIC-038B-T9" "bash" "accept" "" --handoff-depth 2>/dev/null
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log_pass "无 = handoff-depth 报错 (rc=$rc, expected non-zero)"
  else
    log_fail "无 = handoff-depth 应该报错, got rc=$rc"
  fi
}

#===============================================================================
# Test 10: 跟 EPIC-036-B --cross-worktree 联合 (--handoff-depth=L3 + --cross-worktree)
#===============================================================================
test_l3_major_with_cross_worktree() {
  echo ""
  echo "=== Test 10: L3 + --cross-worktree 联合 (EPIC-036-B + EPIC-038-B) ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-038B-T10" "bash" "accept" "" --handoff-depth=L3 --cross-worktree=EPIC-036-A 2>&1)

  local sub_role
  sub_role=$(extract_field "$output" "sub_role")

  if [[ "$sub_role" == "performer-major" ]] && echo "$output" | grep -q "CROSS_WORKTREE"; then
    log_pass "L3+cross-worktree: sub_role=performer-major + CROSS_WORKTREE 触发"
  else
    log_fail "L3+cross-worktree: expected sub_role=performer-major + CROSS_WORKTREE"
    echo "    output: $output"
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  echo "========================================"
  echo " performer-subrole-test.sh — 4 派单模式 + Override + Error handling"
  echo " 跟 EPIC-038-B + EPIC-038-A 联合"
  echo "========================================"

  test_l1_analyst_accept
  test_l2_incremental_accept
  test_l3_major_accept
  test_l4_auditor_accept
  test_l1_analyst_override
  test_l2_incremental_override
  test_handoff_depth_no_value
  test_handoff_depth_invalid
  test_handoff_depth_no_equals
  test_l3_major_with_cross_worktree

  echo ""
  echo "========================================"
  echo " Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "10/10 PASS (EPIC-038-B AC #3 ≥8 case)"
    exit 0
  else
    echo "$PASS_COUNT/10 PASS"
    exit 1
  fi
}

main "$@"
