#!/bin/bash
# audit-stale-text-test.sh — 2 case PASS (audit line 596 数字 跟实际一致)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SCRIPT="${KALLAX_ROOT}/scripts/expert-quality-audit.py"
EXTENDED_INDEX="${KALLAX_ROOT}/.kallax/experts/extended/INDEX.md"
GENERATOR="${KALLAX_ROOT}/scripts/expert-generate-l3.py"
M1_TEST_SCRIPT="${KALLAX_ROOT}/scripts/verify/expert-match-m1-v3.sh"

PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
  set +e
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_fail() {
  set +e
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ─── T1: audit 脚本 line 596 数字 跟实际 generated count 一致 (动态 grep) ───
test_t1_audit_generated_count_matches_actual() {
  echo "=== T1: audit line 596 generated count matches actual INDEX.md ==="

  [[ -f "$AUDIT_SCRIPT" ]] || { echo "FAIL: audit script missing"; return 1; }
  [[ -f "$EXTENDED_INDEX" ]] || { echo "FAIL: INDEX.md missing"; return 1; }

  # 找 audit 脚本中 co_evolution_debt 字段
  audit_line=$(grep -n "co_evolution_debt" "$AUDIT_SCRIPT" | head -1)

  if [[ -z "$audit_line" ]]; then
    assert_fail "co_evolution_debt field not found in audit script"
    return 1
  fi

  echo "  [verify] audit line: ${audit_line}"

  # 从 audit_line 提取数字 (X generated experts)
  audit_count=$(echo "$audit_line" | grep -oE "[0-9]+ generated experts" | grep -oE "^[0-9]+" || echo 0)

  if [[ -z "$audit_count" || "$audit_count" -eq 0 ]]; then
    assert_fail "could not parse generated count from audit line"
    return 1
  fi

  # 实际 generated count
  actual_count=$(grep -cE "^id: kallax.generated\." "$EXTENDED_INDEX" || echo 0)

  echo "  [verify] audit count = ${audit_count}, actual count = ${actual_count}"

  if [[ "$audit_count" -eq "$actual_count" ]]; then
    assert_pass "audit count (${audit_count}) == actual count (${actual_count})"
  else
    assert_fail "audit count (${audit_count}) != actual count (${actual_count})"
  fi
}

# ─── T2: audit 脚本 line 596 test case count 跟 TESTS 数组 length 一致 ───
test_t2_audit_test_case_count_matches() {
  echo "=== T2: audit line 596 test case count matches M1 test count ==="

  [[ -f "$AUDIT_SCRIPT" ]] || { echo "FAIL: audit script missing"; return 1; }
  [[ -f "$M1_TEST_SCRIPT" ]] || { echo "FAIL: M1 test script missing"; return 1; }

  # 找 audit 脚本中 co_evolution_debt 字段
  audit_line=$(grep -n "co_evolution_debt" "$AUDIT_SCRIPT" | head -1)

  if [[ -z "$audit_line" ]]; then
    assert_fail "co_evolution_debt field not found in audit script"
    return 1
  fi

  # 从 audit_line 提取 test case count (X test cases)
  audit_tc=$(echo "$audit_line" | grep -oE "[0-9]+ test cases" | grep -oE "^[0-9]+" || echo 0)

  if [[ -z "$audit_tc" || "$audit_tc" -eq 0 ]]; then
    assert_fail "could not parse test case count from audit line"
    return 1
  fi

  # 实际 test case count from M1 test script (m1_total=100)
  actual_tc=$(grep -E "^m1_total=" "$M1_TEST_SCRIPT" | head -1 | grep -oE "[0-9]+$" || echo 0)

  if [[ -z "$actual_tc" || "$actual_tc" -eq 0 ]]; then
    assert_fail "could not parse m1_total from M1 test script"
    return 1
  fi

  echo "  [verify] audit tc = ${audit_tc}, actual tc = ${actual_tc}"

  if [[ "$audit_tc" -eq "$actual_tc" ]]; then
    assert_pass "audit test cases (${audit_tc}) == actual m1_total (${actual_tc})"
  else
    assert_fail "audit test cases (${audit_tc}) != actual m1_total (${actual_tc})"
  fi
}

# ─── MAIN ───
# Disable set -e / pipefail for the final summary+exit block so transient
# grep -c pipeline exits can't poison the script's overall exit code when
# FAIL_COUNT is actually 0. EPIC-034-C R4 fix: same pattern as
# generated-experts-test.sh, defensive against shell pipeline failures.
set +e +o pipefail
echo "=== audit-stale-text-test.sh ==="
test_t1_audit_generated_count_matches_actual
echo ""
test_t2_audit_test_case_count_matches
echo ""
echo "=== summary: ${PASS_COUNT} PASS, ${FAIL_COUNT} FAIL ==="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
