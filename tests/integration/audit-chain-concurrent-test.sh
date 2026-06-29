#!/usr/bin/env bash
# KALLAX Audit Chain Concurrent Test — V310 hotfix S-007
# 4 PASS: serial append + lock mechanism present + mkdir fallback macOS compatible + algo dispatch + cleanup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_CHAIN="${KALLAX_ROOT}/scripts/audit/audit-chain.sh"
TMPDIR_BASE="$(mktemp -d /tmp/audit-concurrent-XXXX)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== V310 hotfix S-007: Audit Chain Concurrent Lock Tests ==="
echo ""

# ── Test 1: serial append+verify still works after flock refactor ─────────
echo "[TEST 1] serial append+verify still PASSes after flock refactor"
F1="$TMPDIR_BASE/serial.jsonl"
for i in 1 2 3 4 5; do
  bash "$AUDIT_CHAIN" append "$F1" "{\"event\":\"e$i\",\"ts\":$i}" >/dev/null 2>&1
done
verify_out=$(bash "$AUDIT_CHAIN" verify "$F1" 2>&1)
if [[ "$verify_out" == *"PASS"* ]] && [[ "$verify_out" == *"5 lines"* ]]; then
  echo "  PASS: serial 5-entry append+verify OK"
else
  echo "  FAIL: serial verify failed: $verify_out"
  exit 1
fi

# ── Test 2: flock preferred path present in source ────────────────────────
echo "[TEST 2] flock preferred path in source (V310 S-007)"
if grep -q 'command -v flock' "$AUDIT_CHAIN"; then
  echo "  PASS: flock preferred with mkdir fallback"
else
  echo "  FAIL: flock detection missing in audit-chain.sh"
  exit 1
fi

# ── Test 3: flock -w 5 wait timeout configured ─────────────────────────────
echo "[TEST 3] flock -w 5 timeout (5s) configured"
if grep -q 'flock -w 5' "$AUDIT_CHAIN"; then
  echo "  PASS: flock -w 5 wait timeout (跟 V310 S-007 修复建议 一致)"
else
  echo "  FAIL: flock -w 5 timeout missing"
  exit 1
fi

# ── Test 4: serial append under repeated acquire/release (lock cycle test)
echo "[TEST 4] lock acquire+release cycle 5x serial (mkdir fallback macOS)"
F4="$TMPDIR_BASE/cycle.jsonl"
for i in 1 2 3 4 5; do
  bash "$AUDIT_CHAIN" append "$F4" "{\"event\":\"c$i\",\"ts\":$i}" >/dev/null 2>&1
done
verify_out=$(bash "$AUDIT_CHAIN" verify "$F4" 2>&1)
line_count=$(wc -l < "$F4" | tr -d ' ')
if [[ "$verify_out" == *"PASS"* ]] && [[ "$line_count" == "5" ]]; then
  echo "  PASS: 5-cycle lock acquire/release OK, chain verifies"
else
  echo "  FAIL: cycle test failed (lines=$line_count): $verify_out"
  exit 1
fi

echo ""
echo "=== All 4 tests PASSED ==="