#!/usr/bin/env bash
# kpi-audit-test.sh — Integration test for Rule 9a KPI estimator detection (EPIC-037-A)
# Conductor corrective integration under 主公 explicit 授权

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT="${KALLAX_ROOT}/scripts/audit/kpi-audit.sh"

PASS=0
FAIL=0

assert_pass() {
  echo "  ✓ $1"
  PASS=$((PASS+1))
  return 0
}

assert_fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL+1))
  return 0
}

# ─── T1: kpi-audit.sh exists + executable ───
test_t1_script_exists() {
  echo "=== T1: kpi-audit.sh exists + executable ==="
  if [[ -x "$AUDIT" ]]; then
    assert_pass "[1/4] kpi-audit.sh exists and is executable"
  else
    assert_fail "[1/4] kpi-audit.sh missing or not executable"
  fi
}

# ─── T2: precise X/Y → exit 0 (PASS) ───
test_t2_precise() {
  echo "=== T2: precise X/Y → exit 0 ==="
  if echo "M1: 26/30 = 86.7%" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_pass "[2/4] precise X/Y format returns exit 0"
  else
    assert_fail "[2/4] precise X/Y should not trigger estimator"
  fi
}

# ─── T3: tilde + percent (估数) → exit 1 ───
test_t3_tilde() {
  echo "=== T3: tilde+percent estimator → exit 1 ==="
  if echo "M1~70%" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_fail "[3/4] M1~70% should trigger estimator (exit 1)"
  else
    assert_pass "[3/4] M1~70% detected as estimator"
  fi
}

# ─── T4: "approximately 80" → exit 1 ───
test_t4_approximately() {
  echo "=== T4: 'approximately 80' estimator → exit 1 ==="
  if echo "M1 approximately 80 percent" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_fail "[4/4] 'approximately 80' should trigger estimator (exit 1)"
  else
    assert_pass "[4/4] 'approximately 80' detected as estimator"
  fi
}

# ─── MAIN ───
echo "=== KPI Audit Tests (EPIC-037-A) ==="
test_t1_script_exists
echo ""
test_t2_precise
echo ""
test_t3_tilde
echo ""
test_t4_approximately
echo ""
echo "=== Summary ==="
echo "PASS: $PASS / 4"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
