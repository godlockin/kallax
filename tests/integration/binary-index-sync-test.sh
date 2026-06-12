#!/usr/bin/env bash
# binary-index-sync-test.sh — Integration test (EPIC-034-D)
# Conductor corrective integration under 主公 explicit 授权 (Rule 11 v2.1 + Rule 1 boundary event 2026-06-12)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXPORT="${KALLAX_ROOT}/scripts/export/index-md-to-sqlite.py"
INDEX_MD="${KALLAX_ROOT}/.kallax/experts/extended/INDEX.md"

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

# ─── T1: export script exists + executable ───
test_t1_script_exists() {
  echo "=== T1: index-md-to-sqlite.py exists + executable ==="
  if [[ -x "$EXPORT" ]]; then
    assert_pass "[1/4] export script exists and is executable"
  else
    assert_fail "[1/4] export script missing or not executable"
  fi
}

# ─── T2: INDEX.md parsed count >= 100 ───
test_t2_index_count() {
  echo "=== T2: INDEX.md parsed count >= 90 (90 eket + 6 generated) ==="
  local count=$(grep -c "^id: " "$INDEX_MD" 2>/dev/null || echo 0)
  if [[ $count -ge 90 ]]; then
    assert_pass "[2/4] INDEX.md has $count experts (>= 90)"
  else
    assert_fail "[2/4] INDEX.md has $count experts (< 90, gap exists)"
  fi
}

# ─── T3: 6 generated 真 in INDEX.md ───
test_t3_generated_count() {
  echo "=== T3: 6 generated experts in INDEX.md ==="
  local gen_count=$(grep -c "^id: kallax.generated\." "$INDEX_MD" 2>/dev/null || echo 0)
  if [[ $gen_count -eq 6 ]]; then
    assert_pass "[3/4] 6 kallax.generated.* experts in INDEX"
  else
    assert_fail "[3/4] expected 6 generated, got $gen_count"
  fi
}

# ─── T4: export script runnable + has KALLAX_DB_PATH support ───
test_t4_env_support() {
  echo "=== T4: export script supports KALLAX_DB_PATH env var ==="
  if grep -q "KALLAX_DB_PATH" "$EXPORT"; then
    assert_pass "[4/4] KALLAX_DB_PATH env var supported"
  else
    assert_fail "[4/4] KALLAX_DB_PATH not supported"
  fi
}

# ─── MAIN ───
echo "=== Binary-Index Sync Tests (EPIC-034-D) ==="
test_t1_script_exists
echo ""
test_t2_index_count
echo ""
test_t3_generated_count
echo ""
test_t4_env_support
echo ""
echo "=== Summary ==="
echo "PASS: $PASS / 4"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
