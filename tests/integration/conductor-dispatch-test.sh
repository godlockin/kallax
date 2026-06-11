#!/bin/bash
# conductor-dispatch-test.sh — Integration test for conductor dispatch
#
# Tests3 decision paths:
# 1. accept (default) — ALGO_SUGGEST accepted
# 2. veto — Conductor显式否决
# 3. override — Conductor指定其他
#
# Each path tested with 2 scenarios:
# - With expertise filter (Layer 2 cosine match)
# - Without expertise (Layer 1 any/empty)
# Total: 6+ tests PASS
#
# Source: EPIC-031-A ticket.json AC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/conductor/dispatch.sh"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

echo "=== Conductor Dispatch Integration Tests ==="
PASS=0
FAIL=0

# Setup: ensure audit dir exists and clean date-stamped files before tests
ORIG_AUDIT_DIR="$AUDIT_DIR"
TMP_AUDIT_DIR="${BASH_SOURCE[0]}.tmp.$$"
export KALLAX_ROOT
cleanup() {
  rm -rf "$TMP_AUDIT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Override AUDIT_DIR to temp location for test isolation
export AUDIT_DIR="$TMP_AUDIT_DIR"
mkdir -p "$AUDIT_DIR"

test_dispatch() {
  local ticket_id="$1"
  local expertise="$2"
  local decision="$3"
  local override_to="${4:-}"
  local expected_final="$5"
  local test_name="$6"

  local output
  local actual_final

  if [[ "$decision" == "override" ]]; then
    output=$(bash "$DISPATCH" "$ticket_id" "$expertise" "$decision" "$override_to" 2>&1) || true
  else
    output=$(bash "$DISPATCH" "$ticket_id" "$expertise" "$decision" 2>&1) || true
  fi

  # Extract final= from output (macOS grep compatible: use sed instead of grep -oP)
  actual_final=$(echo "$output" | sed -E 's/.*final=([^ ]+).*/\1/' | head -1)

  if [[ "$actual_final" == "$expected_final" ]]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected final=$expected_final, got final=$actual_final)"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "[Test 1] Decision=accept (default)"
# Layer 1: empty expertise → highest trust score (conductor-gamma 0.95)
test_dispatch "EPIC-031-T001" "" "accept" "" "conductor-gamma" "accept: empty expertise → Layer 1 highest trust"
# Layer 2: "bash" → highest trust among cosine≥0.5 matches (conductor-gamma 0.95)
test_dispatch "EPIC-031-T002" "bash" "accept" "" "conductor-gamma" "accept: expertise bash → Layer 2 highest trust"

echo ""
echo "[Test 2] Decision=veto"
test_dispatch "EPIC-031-T003" "" "veto" "" "VETOED" "veto: empty expertise → VETOED"
test_dispatch "EPIC-031-T004" "python" "veto" "" "VETOED" "veto: expertise python → VETOED"

echo ""
echo "[Test 3] Decision=override"
test_dispatch "EPIC-031-T005" "" "override" "performer-beta" "performer-beta" "override: empty → performer-beta"
test_dispatch "EPIC-031-T006" "bash" "override" "performer-beta" "performer-beta" "override: expertise bash → performer-beta"

echo ""
echo "[Test 4] Error handling"
# Missing args (only 1 arg) → should exit 1
if bash "$DISPATCH" "TICKET" 2>/dev/null; then
  echo "  ✗ missing args should fail"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ missing args fails correctly"
  PASS=$((PASS + 1))
fi

# Override without OVERRIDE_TO → should exit 1
if bash "$DISPATCH" "TICKET" "bash" "override" 2>/dev/null; then
  echo "  ✗ override without OVERRIDE_TO should fail"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ override without OVERRIDE_TO fails correctly"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0