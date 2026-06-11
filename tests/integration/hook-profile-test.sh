#!/usr/bin/env bash
# KALLAX Hook Profile Integration Tests — EPIC-030-D
# 5 PASS: minimal + standard + strict + default + invalid-reject
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_PROFILE="${KALLAX_ROOT}/.kallax/hooks/hook-profile.sh"

echo "=== EPIC-030-D: Hook Profile 3档 Integration Tests ==="
echo ""

# ── Test 1: minimal profile (1 hook) ─────────────────────────────────────
echo "[TEST 1] KALLAX_HOOK_PROFILE=minimal"
KALLAX_HOOK_PROFILE=minimal bash "$HOOK_PROFILE" >/dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  echo "  PASS: minimal profile exit 0"
else
  echo "  FAIL: minimal profile expected 0, got $result"
  exit 1
fi

# ── Test 2: standard profile (3 hooks) ───────────────────────────────────
echo "[TEST 2] KALLAX_HOOK_PROFILE=standard"
KALLAX_HOOK_PROFILE=standard bash "$HOOK_PROFILE" >/dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  echo "  PASS: standard profile exit 0"
else
  echo "  FAIL: standard profile expected 0, got $result"
  exit 1
fi

# ── Test 3: strict profile (4 hooks, preflight may not exist — warn OK) ──
echo "[TEST 3] KALLAX_HOOK_PROFILE=strict"
KALLAX_HOOK_PROFILE=strict bash "$HOOK_PROFILE" >/dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  echo "  PASS: strict profile exit 0 (preflight skipped with WARN if absent)"
else
  echo "  FAIL: strict profile expected 0, got $result"
  exit 1
fi

# ── Test 4: default (no env var → standard) ───────────────────────────────
echo "[TEST 4] KALLAX_HOOK_PROFILE unset → default standard"
unset KALLAX_HOOK_PROFILE
bash "$HOOK_PROFILE" >/dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  echo "  PASS: default (standard) exit 0"
else
  echo "  FAIL: default expected 0, got $result"
  exit 1
fi

# ── Test 5: invalid profile → exit 1 ──────────────────────────────────────
echo "[TEST 5] KALLAX_HOOK_PROFILE=invalid → reject"
# Use subshell to prevent set -e from exiting on non-zero (invalid profile returns 1)
result=0
( KALLAX_HOOK_PROFILE=invalid bash "$HOOK_PROFILE" >/dev/null 2>&1 ) || result=$?
if [[ $result -ne 0 ]]; then
  echo "  PASS: invalid profile rejected (exit $result)"
else
  echo "  FAIL: invalid profile expected non-zero, got 0"
  exit 1
fi

echo ""
echo "=== All 5 tests PASSED ==="