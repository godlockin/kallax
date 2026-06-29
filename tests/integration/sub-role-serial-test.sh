#!/bin/bash
# sub-role-serial-test.sh — Iter6 W3 Integration test for 1 EPIC 4 sub-roles 串行 dispatch
#
# 模拟 1 个 EPIC 含 4 ticket, 各要求不同 Performer sub-role
# 验证 dispatch 顺序: coder → tester → reviewer → docs
# Raw stdout 验证每步 PASS (跟 Rule 8 L2/L4 反 KPI falsification 联合)
#
# Source: Iter6 武器 3 — Performer Sub-Role Dispatch (Q15 强化)
# 跟 Rule 15 Performer sub-role schema + EPIC-038-A handoff_depth 联合
# 跟 eket 区分: eket 没 sub-role 概念, 4 sub-roles 串行 是 KALLAX 1+4 容量 特色

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

# Extract field from DISPATCH output line
extract_field() {
  local output="$1"
  local field="$2"
  echo "$output" | grep -E "${field}=" | head -1 | sed -E "s/.*${field}=([^ ]+).*/\\1/"
}

# Cleanup trap: remove test ticket dirs and instance_config sub_role override
TEST_TICKETS=("EPIC-W3-A" "EPIC-W3-B" "EPIC-W3-C" "EPIC-W3-D")
BACKUP_INSTANCE_CONFIG="/tmp/w3-instance-config.yml.bak.$$"
INSTANCE_CONFIG="${KALLAX_ROOT}/.kallax/state/instance_config.yml"

setup_test_tickets() {
  # Backup original instance_config
  cp "$INSTANCE_CONFIG" "$BACKUP_INSTANCE_CONFIG" 2>/dev/null || true

  # Create 4 ticket.json files, each with a different performer_sub_role
  for i in 0 1 2 3; do
    local tid="${TEST_TICKETS[$i]}"
    mkdir -p "${KALLAX_ROOT}/jira/tickets/${tid}"
    cat > "${KALLAX_ROOT}/jira/tickets/${tid}/ticket.json" <<JSON
{
  "id": "${tid}",
  "worktree_role": "performer",
  "performer_sub_role": "${SUBROLES[$i]}",
  "handoff_depth": "L2"
}
JSON
  done
}

cleanup() {
  for tid in "${TEST_TICKETS[@]}"; do
    rm -rf "${KALLAX_ROOT}/jira/tickets/${tid}" 2>/dev/null || true
  done
  if [[ -f "$BACKUP_INSTANCE_CONFIG" ]]; then
    cp "$BACKUP_INSTANCE_CONFIG" "$INSTANCE_CONFIG" 2>/dev/null || true
    rm -f "$BACKUP_INSTANCE_CONFIG"
  fi
}
trap cleanup EXIT

#===============================================================================
# Test 1: 1 EPIC 4 tickets 串行 dispatch (coder → tester → reviewer → docs)
# 顺序: A=coder → B=tester → C=reviewer → D=docs
# 每次 dispatch.sh 接受 ticket.json 期望 sub-role, 实际 sub-role 字段匹配
#===============================================================================
test_serial_4_subroles() {
  echo ""
  echo "=== Test 1: 1 EPIC 4 sub-roles 串行 dispatch (coder → tester → reviewer → docs) ==="

  local order=("A:EPIC-W3-A:coder" "B:EPIC-W3-B:tester" "C:EPIC-W3-C:reviewer" "D:EPIC-W3-D:docs")
  local seq=1

  for entry in "${order[@]}"; do
    IFS=':' read -r label ticket expected <<< "$entry"
    local output
    output=$(bash "$DISPATCH" "$ticket" "bash" "accept" "" 2>&1)

    local actual
    actual=$(extract_field "$output" "sub_role")
    local expected_full="performer-${expected}"

    if [[ "$actual" == "$expected_full" ]]; then
      log_pass "Step $seq: ${label}=${ticket} sub_role=${actual} (expected=${expected_full})"
    else
      log_fail "Step $seq: ${label}=${ticket} sub_role='$actual' (expected='$expected_full')"
      echo "    output: $output"
    fi
    seq=$((seq + 1))
  done

  # Verify dispatch order was respected by checking all 4 outputs in sequence
  echo ""
  echo "  --- Raw stdout (4 sub-roles 串行) ---"
  for entry in "${order[@]}"; do
    IFS=':' read -r label ticket expected <<< "$entry"
    local line
    line=$(bash "$DISPATCH" "$ticket" "bash" "accept" "" 2>&1 | head -1)
    echo "  [$label ${expected}] $line"
  done
}

#===============================================================================
# Test 2: --sub-role CLI override ticket.json
# 即使 ticket.json 写 reviewer, --sub-role=coder 应 override
#===============================================================================
test_cli_override_ticket_json() {
  echo ""
  echo "=== Test 2: --sub-role CLI override ticket.json performer_sub_role ==="

  # EPIC-W3-C ticket.json performer_sub_role=reviewer, --sub-role=coder 强制 override
  local output
  output=$(bash "$DISPATCH" "EPIC-W3-C" "bash" "accept" "" --sub-role=coder 2>&1)

  local actual
  actual=$(extract_field "$output" "sub_role")

  if [[ "$actual" == "performer-coder" ]]; then
    log_pass "CLI --sub-role=coder override ticket.json reviewer → sub_role=performer-coder"
  else
    log_fail "CLI override failed: expected sub_role=performer-coder, got sub_role='$actual'"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 3: sub-role mismatch 强制 enforcement
# 当前 session sub_role=tester, 但 ticket.json requires=coder → 应拒绝
#===============================================================================
test_sub_role_mismatch_enforced() {
  echo ""
  echo "=== Test 3: sub-role mismatch 强制 enforcement (Rule 15) ==="

  # 临时在 instance_config.yml 加 sub_role: tester
  cp "$INSTANCE_CONFIG" "$BACKUP_INSTANCE_CONFIG"
  if ! grep -q "^sub_role:" "$INSTANCE_CONFIG"; then
    echo "sub_role: tester" >> "$INSTANCE_CONFIG"
  fi

  local rc
  set +e
  bash "$DISPATCH" "EPIC-W3-A" "bash" "accept" "" 2>/dev/null  # ticket.json requires coder
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log_pass "Mismatch (current=tester, expected=coder) 拒绝 dispatch (rc=$rc)"
  else
    log_fail "Mismatch 应该拒绝 dispatch, got rc=$rc"
  fi

  # Restore
  cp "$BACKUP_INSTANCE_CONFIG" "$INSTANCE_CONFIG"
  rm -f "$BACKUP_INSTANCE_CONFIG"
}

#===============================================================================
# Test 4: 4 sub-role enum 边界
# --sub-role 接受 coder / reviewer / tester / docs, 拒绝其他
#===============================================================================
test_sub_role_enum_validation() {
  echo ""
  echo "=== Test 4: --sub-role enum validation (4 valid + 2 invalid) ==="

  # 4 valid
  for role in coder reviewer tester docs; do
    local output
    output=$(bash "$DISPATCH" "EPIC-W3-A" "bash" "accept" "" --sub-role="$role" 2>&1)
    local actual
    actual=$(extract_field "$output" "sub_role")
    if [[ "$actual" == "performer-${role}" ]]; then
      log_pass "--sub-role=$role 接受 (sub_role=performer-${role})"
    else
      log_fail "--sub-role=$role: expected sub_role=performer-${role}, got '$actual'"
    fi
  done

  # 2 invalid
  for role in INVALID Slaver; do
    local rc
    set +e
    bash "$DISPATCH" "EPIC-W3-A" "bash" "accept" "" --sub-role="$role" 2>/dev/null
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      log_pass "--sub-role=$role 拒绝 (rc=$rc)"
    else
      log_fail "--sub-role=$role 应该拒绝, got rc=$rc"
    fi
  done
}

#===============================================================================
# Test 5: 跟 EPIC-038-B --handoff-depth 联合 + --sub-role 优先级
# --sub-role 显式 override handoff-depth 推导的 sub-role
#===============================================================================
test_sub_role_priority_over_handoff_depth() {
  echo ""
  echo "=== Test 5: --sub-role 优先级 > --handoff-depth 推导 ==="

  # --handoff-depth=L3 → performer-major, 但 --sub-role=coder 强制 performer-coder
  local output
  output=$(bash "$DISPATCH" "EPIC-W3-A" "bash" "accept" "" --handoff-depth=L3 --sub-role=coder 2>&1)
  local actual
  actual=$(extract_field "$output" "sub_role")

  if [[ "$actual" == "performer-coder" ]]; then
    log_pass "--handoff-depth=L3 + --sub-role=coder → sub_role=performer-coder (--sub-role 优先)"
  else
    log_fail "--sub-role 优先级: expected performer-coder, got '$actual'"
    echo "    output: $output"
  fi
}

#===============================================================================
# Main
#===============================================================================
SUBROLES=("coder" "tester" "reviewer" "docs")
main() {
  echo "========================================"
  echo " sub-role-serial-test.sh — Iter6 W3"
  echo " 1 EPIC 4 sub-roles 串行 dispatch (Q15 强化)"
  echo " 跟 Rule 15 Performer sub-role schema 联合"
  echo " 优于 eket: eket 没 sub-role dispatch"
  echo "========================================"

  setup_test_tickets

  test_serial_4_subroles
  test_cli_override_ticket_json
  test_sub_role_mismatch_enforced
  test_sub_role_enum_validation
  test_sub_role_priority_over_handoff_depth

  echo ""
  echo "========================================"
  echo " Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "$PASS_COUNT/$PASS_COUNT PASS (Iter6 W3 AC ≥5 case)"
    exit 0
  else
    echo "$PASS_COUNT/$(($PASS_COUNT + $FAIL_COUNT)) PASS"
    exit 1
  fi
}

main "$@"