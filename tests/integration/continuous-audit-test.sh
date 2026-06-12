#!/usr/bin/env bash
# continuous-audit-test.sh — Integration test for 9-pass redaction (EPIC-037-A)
# Conductor corrective integration under 主公 explicit 授权 (Rule 11 v2.1 + Rule 1 boundary event 2026-06-12)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT="${KALLAX_ROOT}/scripts/audit/continuous-audit.sh"

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

# ─── T1: 9-pass script exists + executable ───
test_t1_script_exists() {
  echo "=== T1: continuous-audit.sh exists + executable ==="
  if [[ -x "$AUDIT" ]]; then
    assert_pass "[1/4] continuous-audit.sh exists and is executable"
  else
    assert_fail "[1/4] continuous-audit.sh missing or not executable"
  fi
}

# ─── T2: clean text → exit 0 (no leak) ───
test_t2_clean_text() {
  echo "=== T2: clean text → exit 0 (no leak) ==="
  if echo "this is a clean log line with no secrets" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_pass "[2/4] clean text returns exit 0"
  else
    assert_fail "[2/4] clean text should not trigger leak"
  fi
}

# ─── T3: Authorization Bearer token → exit 1 (leak detected) ───
test_t3_auth_token() {
  echo "=== T3: Authorization Bearer token → exit 1 ==="
  if echo "Authorization: Bearer ghp_abc123def456ghi789jkl012mno345pqr" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_fail "[3/4] Authorization token should trigger leak (exit 1)"
  else
    assert_pass "[3/4] Authorization Bearer token detected as leak"
  fi
}

# ─── T4: password=field → exit 1 ───
test_t4_password_field() {
  echo "=== T4: password=field → exit 1 ==="
  if echo "db_password=supersecretvalue123" | bash "$AUDIT" scan-stdin 2>/dev/null; then
    assert_fail "[4/4] password= field should trigger leak (exit 1)"
  else
    assert_pass "[4/4] password= field detected as leak"
  fi
}

# ─── MAIN ───
echo "=== Continuous Audit Tests (EPIC-037-A) ==="
test_t1_script_exists
echo ""
test_t2_clean_text
echo ""
test_t3_auth_token
echo ""
test_t4_password_field
echo ""
echo "=== Summary ==="
echo "PASS: $PASS / 4"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
