#!/bin/bash
# continuous-audit-test.sh — Integration test for continuous-audit.sh (EPIC-037-A)
#
# 9-pass redaction detection tests:
# T1: Authorization header leak detected → FAIL
# T2: Known prefix tokens (ghp_/sk-/AKIA) detected → FAIL
# T3: JWT token format detected → FAIL
# T4: env-var style KEY=VALUE detected → FAIL
# T5: clean content → PASS
# T6: scan directory → all leaks surfaced
#
# Source: EPIC-037-A AC: 9-pass detection (Authorization/Token/X-Auth-Token/
#   password/secret/Basic Auth URL/24-char 兜底 + 已知 prefix ghp_/sk-/AKIA +
#   JWT + env-var)
#
# 跟 AuditMiddleware 1:1 验证 (EPIC-030-G merge baseline)
# 跟 "翻篇&精进" 战略 联合 0 简单 记录 (Rule 9a KPI / Rule 9d no estimation)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONT_AUDIT_SCRIPT="${KALLAX_ROOT}/scripts/audit/continuous-audit.sh"

# Temp dir for test fixtures
TMP_FIX="${BASH_SOURCE[0]}.tmp.$$"
FIX_DIR="${TMP_FIX}/fixtures"
mkdir -p "$FIX_DIR"
cleanup() {
  rm -rf "$TMP_FIX" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== continuous-audit.sh Integration Tests (9-pass redaction) ==="
PASS=0
FAIL=0

# ─── T1: Authorization header leak detected ───
test_t1_auth_header() {
  echo ""
  echo "[T1] Authorization header leak detected"
  local sample="${FIX_DIR}/auth-leak.txt"
  printf 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9\n' > "$sample"

  if bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 (PASS) — expected FAIL on Authorization leak"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  if echo "$out" | grep -qiE "authorization|pass-1"; then
    echo "  ✓ Authorization leak flagged"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: Authorization leak not flagged in output"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T2: Known prefix tokens (ghp_/sk-/AKIA) detected ───
test_t2_known_prefixes() {
  echo ""
  echo "[T2] Known prefix tokens (ghp_/sk-/AKIA) detected"
  local sample="${FIX_DIR}/prefix-leak.txt"
  {
    printf 'ghp_abc123def456ghi789jkl012mno345pqr678\n'
    printf 'sk-abcdef1234567890ABCDEFGHIJ\n'
    printf 'AKIAIOSFODNN7EXAMPLE\n'
  } > "$sample"

  if bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on token prefix leak"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  local hit=0
  for prefix in "ghp_" "sk-" "AKIA"; do
    if echo "$out" | grep -q "$prefix"; then
      hit=$((hit + 1))
    fi
  done
  if [[ $hit -ge 3 ]]; then
    echo "  ✓ All 3 known prefixes flagged ($hit/3)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: only $hit/3 prefixes flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T3: JWT token format detected ───
test_t3_jwt() {
  echo ""
  echo "[T3] JWT token format detected"
  local sample="${FIX_DIR}/jwt-leak.txt"
  printf 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c\n' > "$sample"

  if bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on JWT leak"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  if echo "$out" | grep -qiE "jwt|pass-7"; then
    echo "  ✓ JWT leak flagged"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: JWT not flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T4: env-var style KEY=VALUE detected ───
test_t4_env_var() {
  echo ""
  echo "[T4] env-var style KEY=VALUE detected"
  local sample="${FIX_DIR}/env-leak.txt"
  {
    printf 'export API_KEY=abcdef1234567890SECRET\n'
    printf 'DB_PASSWORD=hunter2hunter2hunter2\n'
  } > "$sample"

  if bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on env-var leak"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  if echo "$out" | grep -qiE "env|password|pass-4|pass-8"; then
    echo "  ✓ env-var leak flagged"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: env-var leak not flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T5: clean content → PASS ───
test_t5_clean_passes() {
  echo ""
  echo "[T5] Clean content → PASS"
  local sample="${FIX_DIR}/clean.txt"
  {
    printf '# Normal markdown documentation\n'
    printf 'Use the [docs/](../docs/) for guidance.\n'
    printf 'PR: 24/30 = 80.0%% (exact KPI)\n'
    printf 'No secret data here, only public references.\n'
  } > "$sample"

  if bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✓ Clean content scanned, 0 leaks"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: clean content flagged as leak"
    bash "$CONT_AUDIT_SCRIPT" scan "$sample" 2>&1 || true
    FAIL=$((FAIL + 1))
  fi
}

# ─── T6: scan directory aggregates leaks ───
test_t6_directory_scan() {
  echo ""
  echo "[T6] Directory scan aggregates leaks across files"
  local dir="${FIX_DIR}/dir"
  mkdir -p "$dir"
  printf 'Authorization: Bearer abc\n' > "${dir}/a.txt"
  printf 'Token: ghp_zzz999888777\n' > "${dir}/b.md"

  if bash "$CONT_AUDIT_SCRIPT" scan "$dir" 2>/dev/null; then
    echo "  ✗ FAIL: directory scan returned 0 — expected FAIL"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$CONT_AUDIT_SCRIPT" scan "$dir" 2>&1 || true)
  local hits=0
  if echo "$out" | grep -qE "a\.txt"; then hits=$((hits + 1)); fi
  if echo "$out" | grep -qE "b\.md"; then hits=$((hits + 1)); fi
  if [[ $hits -ge 2 ]]; then
    echo "  ✓ Both leaky files flagged in directory scan ($hits/2)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: only $hits/2 files flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Run all 6 tests ───
test_t1_auth_header
test_t2_known_prefixes
test_t3_jwt
test_t4_env_var
test_t5_clean_passes
test_t6_directory_scan

echo ""
echo "=== Summary: $PASS PASS / $FAIL FAIL ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi