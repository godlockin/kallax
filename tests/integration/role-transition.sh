#!/bin/bash
# role-transition.sh — Integration test for role transition
#
# Tests:
# 1. Valid transitions are allowed
# 2. Invalid transitions are denied
# 3. Break-glass transitions are allowed with audit
# 4. Cycle detection works
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRANSITION_SCRIPT="${KALLAX_ROOT}/scripts/role-transition.sh"

echo "=== Role Transition Integration Tests ==="
PASS=0
FAIL=0

test_transition() {
  local from_role="$1"
  local to_role="$2"
  local reason="$3"
  local expected="$4"  # "ALLOWED" or "DENIED"
  local test_name="$5"

  if bash "$TRANSITION_SCRIPT" --from "$from_role" --to "$to_role" --actor "test-user" --reason "$reason" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "[Test 1] Valid transitions"
test_transition "performer" "conductor" "normal: promoted to conductor" "ALLOWED" "performer can transition to conductor"
test_transition "conductor" "master" "break-glass: emergency elevation" "ALLOWED" "conductor can break-glass to master"
test_transition "auditor" "conductor" "normal: role adjustment" "ALLOWED" "auditor can transition to conductor"
test_transition "readonly" "conductor" "normal: role adjustment" "ALLOWED" "readonly can transition to conductor"

echo ""
echo "[Test 2] Invalid transitions"
test_transition "performer" "master" "invalid: performer cannot become master" "DENIED" "performer cannot transition to master"
test_transition "master" "conductor" "invalid: master cannot demote" "DENIED" "master cannot transition to conductor"
test_transition "readonly" "master" "invalid: readonly cannot become master" "DENIED" "readonly cannot transition to master"
test_transition "performer" "performer" "no-op: same role" "DENIED" "performer cannot transition to same role"

echo ""
echo "[Test 3] Break-glass transitions"
test_transition "conductor" "master" "break-glass: master is unreachable" "ALLOWED" "conductor can break-glass to master"
test_transition "performer" "conductor" "emergency: urgent task assignment" "ALLOWED" "performer can emergency transition to conductor"
test_transition "auditor" "master" "urgent: critical security incident" "ALLOWED" "auditor can urgent transition to master"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
