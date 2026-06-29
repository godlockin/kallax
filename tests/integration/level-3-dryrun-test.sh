#!/usr/bin/env bash
# KALLAX L3 dry-run Test — V310 hotfix U-003
# 5 PASS: WARN banner present + counter increments + rate limit enforced + non-dry-run unaffected + dry-run PASS preserved
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEVEL3="${KALLAX_ROOT}/scripts/verify/level-3.sh"
COUNTER_FILE="${TMPDIR:-/tmp}/kallax-l3-dryrun-${USER:-anon}.count"

echo "=== V310 hotfix U-003: L3 dry-run WARN + Rate Limit Tests ==="
echo ""

# Reset counter before tests
rm -f "$COUNTER_FILE"

# ── Test 1: WARN banner emitted on --dry-run ────────────────────────────────
echo "[TEST 1] --dry-run emits WARN banner"
output=$(bash "$LEVEL3" TICKET-TEST-001 --dry-run 2>&1 || true)
if echo "$output" | grep -q "WARN: --dry-run mode (V310 hotfix U-003)"; then
  echo "  PASS: WARN banner present"
else
  echo "  FAIL: WARN banner missing in output"
  exit 1
fi

# ── Test 2: counter file incremented ───────────────────────────────────────
echo "[TEST 2] dry-run counter file incremented to 1"
if [ -f "$COUNTER_FILE" ] && [ "$(cat "$COUNTER_FILE")" = "1" ]; then
  echo "  PASS: counter=1 after first --dry-run"
else
  echo "  FAIL: counter file content: $(cat "$COUNTER_FILE" 2>/dev/null || 'missing')"
  exit 1
fi

# ── Test 3: 2nd --dry-run triggers rate limit (exit 2) ─────────────────────
echo "[TEST 3] 2nd --dry-run in same session → exit 2 (rate limit)"
rc=0
output=$(bash "$LEVEL3" TICKET-TEST-002 --dry-run 2>&1) || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "rate limit exceeded"; then
  echo "  PASS: rate limit enforced, exit 2 + 'rate limit exceeded' in stderr"
else
  echo "  FAIL: expected exit 2 + 'rate limit exceeded', got rc=$rc"
  exit 1
fi

# ── Test 4: --dry-run still returns PASS for review files (existing behavior)
echo "[TEST 4] --dry-run still PASSes (4 expert dry-run OK)"
# Counter is now 2 (over limit), reset and test fresh
rm -f "$COUNTER_FILE"
output=$(bash "$LEVEL3" TICKET-TEST-003 --dry-run 2>&1 || true)
if echo "$output" | grep -q "RESULT: PASS"; then
  echo "  PASS: --dry-run still returns RESULT: PASS"
else
  echo "  FAIL: --dry-run did not return PASS"
  exit 1
fi

# ── Test 5: non-dry-run mode unaffected (no counter increment) ────────────
echo "[TEST 5] non-dry-run mode does NOT increment counter"
counter_before=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
# Make a fake review file for non-dry-run to not error out
RD="$KALLAX_ROOT/.kallax/reviews/TICKET-TEST-005"
mkdir -p "$RD"
for expert in architect backend frontend security; do
  echo '{"status":"PASS","rationale":"test"}' > "$RD/${expert}.json"
done
output=$(bash "$LEVEL3" TICKET-TEST-005 2>&1 || true)
counter_after=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
if [[ "$counter_before" == "$counter_after" ]]; then
  echo "  PASS: counter unchanged ($counter_before → $counter_after)"
else
  echo "  FAIL: counter changed $counter_before → $counter_after (non-dry-run shouldn't increment)"
  exit 1
fi

# Cleanup
rm -f "$COUNTER_FILE"
rm -rf "$RD"

echo ""
echo "=== All 5 tests PASSED ==="