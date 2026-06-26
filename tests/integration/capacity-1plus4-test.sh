#!/bin/bash
# capacity-1plus4-test.sh — Integration test for capacity-check.sh 1+4 容量 (EPIC-038-B)
#
# Tests 1+2/1+4/1+6/1+8 容量场景 + sub-roles 动态 N + 错误处理 = ≥4 case
#
# Source: EPIC-038-B ticket.json AC #3
# 跟 EPIC-038-A handoff_depth + Rule 15 1+4 容量 联合
# 跟 BE-23 + BE-25 + BE-26 fixes in place (1 ticket 1 subagent 串行, 0 静默 output)

set -euo pipefail

# Force fixture mode (KALLAX_TEST_FIXTURES=1) so capacity-check.sh uses test instances
export KALLAX_TEST_FIXTURES=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CAPACITY_CHECK="${KALLAX_ROOT}/scripts/conductor/capacity-check.sh"
FIXTURE_DIR="${KALLAX_ROOT}/tests/fixtures/agent"
TEST_DIR="/tmp/kallax-capacity-1plus4-test-$$"

PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

cleanup() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

#===============================================================================
# Helper: 生成自定义 instances.json (1 conductor + N performers)
#===============================================================================
build_instances() {
  local conductor_count="$1"   # 通常 1
  local performer_count="$2"   # 2/4/6/8 等
  local sub_role_strategy="$3" # "all-4-types" | "all-same" | "subset"
  local output_file="$4"

  local performers_json=""
  local i
  for ((i = 1; i <= performer_count; i++)); do
    local sub_role
    case "$sub_role_strategy" in
      all-4-types)
        case $((i % 4)) in
          1) sub_role="analyst" ;;
          2) sub_role="incremental" ;;
          3) sub_role="major" ;;
          0) sub_role="auditor" ;;
        esac
        ;;
      all-same)
        sub_role="incremental"
        ;;
      subset)
        # Only 2 sub-roles present
        if [[ $((i % 2)) -eq 0 ]]; then
          sub_role="incremental"
        else
          sub_role="analyst"
        fi
        ;;
      *)
        sub_role="incremental"
        ;;
    esac
    if [[ -n "$performers_json" ]]; then
      performers_json+=","
    fi
    performers_json+="
    {
      \"id\": \"performer-${sub_role}-${i}\",
      \"role\": \"performer\",
      \"sub_role\": \"${sub_role}\",
      \"skills\": [\"bash\"],
      \"expertise_cosine\": 0.7,
      \"trust_score\": 0.8
    }"
  done

  local conductors_json=""
  for ((i = 1; i <= conductor_count; i++)); do
    if [[ -n "$conductors_json" ]]; then
      conductors_json+=","
    fi
    conductors_json+="
    {
      \"id\": \"conductor-${i}\",
      \"role\": \"conductor\",
      \"skills\": [\"coordination\"],
      \"expertise_cosine\": 0.6,
      \"trust_score\": 0.95
    }"
  done

  # Add trailing comma after conductors if both present
  local separator=""
  if [[ -n "$conductors_json" ]] && [[ -n "$performers_json" ]]; then
    separator=","
  fi

  cat > "$output_file" <<EOF
{
  "instances": [${conductors_json}${separator}${performers_json}
  ]
}
EOF
}

#===============================================================================
# Test 1: 1+2 容量 (默认 sub-roles, 期望 fail 因 performer=2 < min=4)
#===============================================================================
test_1plus2_capacity() {
  echo ""
  echo "=== Test 1: 1+2 容量 (默认 sub-roles, 期望 fail 因 performer < min=4) ==="
  local cfg="${TEST_DIR}/instances-1plus2.json"
  build_instances 1 2 "all-4-types" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  # 1+2 with default --performer-min=4 → 期望 fail (performer < min)
  if [[ $rc -ne 0 ]] && echo "$output" | grep -q "status=fail" && echo "$output" | grep -q "performer=2"; then
    log_pass "1+2 默认: status=fail, performer=2 (performer < min=4)"
  else
    log_fail "1+2 默认: 期望 status=fail + performer=2, got rc=$rc"
    echo "    output: $output"
  fi

  # 但降低 --performer-min=2 后, performer 达标; sub-roles 仍缺 (1+2 只有 2 类 sub-role) → warn
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" --performer-min 2 2>&1)
  rc=$?
  set -e

  # performer-min=2 满足, 但 sub-roles 只有 2/4 → status=warn (动态 N 部分缺失)
  if echo "$output" | grep -q "status=warn" && echo "$output" | grep -q "performer=2"; then
    log_pass "1+2 降低 min=2: status=warn (performer 达标, sub-roles 部分缺失 2/4)"
  else
    log_fail "1+2 降低 min=2: 期望 status=warn + performer=2, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 2: 1+4 容量 (标准配置, 期望 status=ok)
#===============================================================================
test_1plus4_capacity() {
  echo ""
  echo "=== Test 2: 1+4 容量 (标准配置, 期望 status=ok) ==="
  local cfg="${TEST_DIR}/instances-1plus4.json"
  build_instances 1 4 "all-4-types" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "conductor=1" && echo "$output" | grep -q "performer=4"; then
    log_pass "1+4 标准: status=ok, conductor=1, performer=4"
  else
    log_fail "1+4 标准: 期望 status=ok, got rc=$rc"
    echo "    output: $output"
  fi

  # 验证 4 sub-roles 全找到
  if echo "$output" | grep -q "subroles=analyst,incremental,major,auditor" && echo "$output" | grep -q "subrole_count=4"; then
    log_pass "1+4 标准: 4 sub-roles 全找到 (analyst/incremental/major/auditor)"
  else
    log_fail "1+4 标准: 4 sub-roles 缺失"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 3: 1+6 容量 (动态 N, 期望 status=ok)
#===============================================================================
test_1plus6_capacity() {
  echo ""
  echo "=== Test 3: 1+6 容量 (动态 N, 期望 status=ok) ==="
  local cfg="${TEST_DIR}/instances-1plus6.json"
  build_instances 1 6 "all-4-types" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "performer=6"; then
    log_pass "1+6: status=ok, performer=6"
  else
    log_fail "1+6: 期望 status=ok + performer=6, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 4: 1+8 容量 (动态 N 上限, 期望 status=ok)
#===============================================================================
test_1plus8_capacity() {
  echo ""
  echo "=== Test 4: 1+8 容量 (动态 N, 期望 status=ok) ==="
  local cfg="${TEST_DIR}/instances-1plus8.json"
  build_instances 1 8 "all-4-types" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "performer=8"; then
    log_pass "1+8: status=ok, performer=8 (动态 N 上限)"
  else
    log_fail "1+8: 期望 status=ok + performer=8, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 5: 1+4 但 sub-roles 缺失 (部分缺失 → warn, 全部缺失 → fail)
#===============================================================================
test_1plus4_subrole_warn_fail() {
  echo ""
  echo "=== Test 5: 1+4 sub-roles 缺失 (subset 模式, 期望 warn) ==="
  local cfg="${TEST_DIR}/instances-subset.json"
  build_instances 1 4 "subset" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  # subset mode → 只有 analyst + incremental → 缺失 major + auditor → 期望 warn
  if [[ $rc -ne 0 ]] && echo "$output" | grep -q "status=warn" && echo "$output" | grep -q "subrole_count=2"; then
    log_pass "1+4 subset: status=warn (部分 sub-roles 缺失, subrole_count=2)"
  else
    log_fail "1+4 subset: 期望 status=warn + subrole_count=2, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 6: 0 conductor → fail
#===============================================================================
test_0_conductor_fail() {
  echo ""
  echo "=== Test 6: 0 conductor → fail ==="
  local cfg="${TEST_DIR}/instances-0cond.json"
  build_instances 0 4 "all-4-types" "$cfg"

  local output rc
  set +e
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" 2>&1)
  rc=$?
  set -e

  if [[ $rc -ne 0 ]] && echo "$output" | grep -q "status=fail"; then
    log_pass "0 conductor: status=fail (conductor < min=1)"
  else
    log_fail "0 conductor: 期望 status=fail, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 7: 自定义 subroles 列表 (跟 dispatch.sh --handoff-depth 联合, 动态 N)
#===============================================================================
test_custom_subroles() {
  echo ""
  echo "=== Test 7: 自定义 subroles 列表 (动态 N 验证) ==="
  local cfg="${TEST_DIR}/instances-1plus2.json"
  build_instances 1 2 "all-same" "$cfg"  # 2 个 incremental

  local output rc
  set +e
  # 只检查 incremental
  output=$(bash "$CAPACITY_CHECK" --instances="$cfg" --subroles incremental --performer-min 2 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "expected_subroles=1"; then
    log_pass "自定义 subroles=incremental: status=ok, expected_subroles=1 (动态 N)"
  else
    log_fail "自定义 subroles: 期望 status=ok + expected_subroles=1, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 8: 默认 fixture 验证 (1+4 + 4 sub-roles, EPIC-038-B AC #3 集成)
#===============================================================================
test_default_fixture() {
  echo ""
  echo "=== Test 8: 默认 fixture (KALLAX_TEST_FIXTURES=1) 1+4 status=ok ==="
  local output rc
  set +e
  output=$(KALLAX_TEST_FIXTURES=1 bash "$CAPACITY_CHECK" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "subroles=analyst,incremental,major,auditor"; then
    log_pass "默认 fixture: status=ok + 4 sub-roles 完整"
  else
    log_fail "默认 fixture: 期望 status=ok, got rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  mkdir -p "$TEST_DIR"
  echo "========================================"
  echo " capacity-1plus4-test.sh — 1+2/1+4/1+6/1+8 + 动态 N + 错误处理"
  echo " 跟 EPIC-038-B + EPIC-038-A 联合"
  echo "========================================"

  test_1plus2_capacity
  test_1plus4_capacity
  test_1plus6_capacity
  test_1plus8_capacity
  test_1plus4_subrole_warn_fail
  test_0_conductor_fail
  test_custom_subroles
  test_default_fixture

  echo ""
  echo "========================================"
  echo " Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "8/8 PASS (EPIC-038-B AC #3 ≥4 case)"
    exit 0
  else
    echo "$PASS_COUNT/8 PASS"
    exit 1
  fi
}

main "$@"
