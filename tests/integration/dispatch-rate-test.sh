#!/bin/bash
# dispatch-rate-test.sh — Integration test for dispatch rate 60→80% AI upgrade (EPIC-033-A)
#
# 派发权 60→80% 升级验证 (主公 2026-06-11 D2 决策, 渐进升级 EKET P1 #1)
#
# Tests:
# 1. Default KALLAX_AI_DELEGATION_RATIO=80 (no env var override)
# 2. KALLAX_AI_DELEGATION_RATIO=60 explicit (backward compat with old 60% AI)
# 3. KALLAX_AI_DELEGATION_RATIO=80 explicit (new default)
# 4. KALLAX_AI_DELEGATION_RATIO=90 explicit (forward compat with 90% AI)
# 5. Output contains "ai_ratio=N%" field at all 3 ratios
# 6. Output reason contains "(N% AI delegation)" at all 3 ratios
# 7. Accept/veto/override decisions all reflect the current ratio
# 8. Usage message shows current ratio
# 9. Error handling preserved (override without OVERRIDE_TO still fails)
# 10. Negative: KALLAX_AI_DELEGATION_RATIO=60 still works (0 删 0 改 60 path)
#
# Source: EPIC-033-A ticket.json AC
#   L1: scripts/conductor/dispatch.sh 有 KALLAX_AI_DELEGATION_RATIO=80 env var
#   L2: KALLAX_AI_DELEGATION_RATIO=80 → 80% AI default Accept
#   L3: jq 语法合法 (ai_ratio field in output)
#   L4: bash tests/integration/dispatch-rate-test.sh → 16 PASS
#
set -euo pipefail

# Force fixture mode so test uses tests/fixtures/agent/instances.json (conductor-gamma)
# instead of .kallax/state/instances.json (instance-003) — EPIC-031 fix
export KALLAX_TEST_FIXTURES=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/conductor/dispatch.sh"

echo "=== Dispatch Rate Integration Tests (60→80% Upgrade, EPIC-033-A) ==="
PASS=0
FAIL=0

# Setup: use temp audit dir for test isolation
TMP_AUDIT_DIR="${BASH_SOURCE[0]}.tmp.$$"
cleanup() {
  rm -rf "$TMP_AUDIT_DIR" 2>/dev/null || true
  unset KALLAX_AI_DELEGATION_RATIO
}
trap cleanup EXIT
export AUDIT_DIR="$TMP_AUDIT_DIR"
mkdir -p "$AUDIT_DIR"

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# Helper: extract ai_ratio=N% from dispatch output
extract_ai_ratio() {
  echo "$1" | sed -E 's/.*ai_ratio=([0-9]+)%.*/\1/' | head -1
}

# Helper: run dispatch and check ai_ratio + decision
# Args: ticket, expertise, decision, override_to, expected_ratio, expected_final, test_name
test_rate() {
  local ticket="$1"
  local expertise="$2"
  local decision="$3"
  local override_to="${4:-}"
  local expected_ratio="$5"
  local expected_final="$6"
  local test_name="$7"

  local output actual_ratio actual_final

  if [[ "$decision" == "override" ]]; then
    output=$(bash "$DISPATCH" "$ticket" "$expertise" "$decision" "$override_to" 2>&1) || true
  else
    output=$(bash "$DISPATCH" "$ticket" "$expertise" "$decision" 2>&1) || true
  fi

  actual_ratio=$(extract_ai_ratio "$output")
  actual_final=$(echo "$output" | sed -E 's/.*final=([^ ]+).*/\1/' | head -1)

  if [[ "$actual_ratio" == "$expected_ratio" ]] && [[ "$actual_final" == "$expected_final" ]]; then
    pass "$test_name (ai_ratio=${actual_ratio}%, final=$actual_final)"
  else
    fail "$test_name (expected ai_ratio=${expected_ratio}%/final=$expected_final, got ai_ratio=${actual_ratio}%/final=$actual_final)"
    echo "    output: $output"
  fi
}

# Helper: check output contains substring
# Args: output, substring, test_name
test_contains() {
  local output="$1"
  local needle="$2"
  local test_name="$3"

  if echo "$output" | grep -qF -- "$needle"; then
    pass "$test_name (contains '$needle')"
  else
    fail "$test_name (missing '$needle')"
    echo "    output: $output"
  fi
}

# ============================================================
# [Test 1] Default KALLAX_AI_DELEGATION_RATIO=80 (主公 D2 决策 default)
# ============================================================

echo ""
echo "[Test 1] Default ratio = 80% (no env var, 主公 D2 决策 default)"
unset KALLAX_AI_DELEGATION_RATIO

OUTPUT=$(bash "$DISPATCH" "EPIC-033-R001" "bash" "accept" 2>&1) || true
test_rate "EPIC-033-R002" "bash" "accept"  ""        "80" "conductor-gamma" "default 80%: accept bash"
test_rate "EPIC-033-R003" ""      "accept"  ""        "80" "conductor-gamma" "default 80%: accept empty"
test_rate "EPIC-033-R004" "python" "veto"    ""        "80" "VETOED"         "default 80%: veto python"
test_rate "EPIC-033-R005" "bash"  "override" "performer-beta" "80" "performer-beta" "default 80%: override bash"

# Verify reason field contains "(80% AI delegation)"
test_contains "$OUTPUT" "(80% AI delegation)" "default 80%: reason shows 80% AI delegation"

# ============================================================
# [Test 2] KALLAX_AI_DELEGATION_RATIO=60 explicit (backward compat)
# ============================================================

echo ""
echo "[Test 2] KALLAX_AI_DELEGATION_RATIO=60 (backward compat with old 60% AI)"
export KALLAX_AI_DELEGATION_RATIO=60

test_rate "EPIC-033-R006" "bash"  "accept"  ""        "60" "conductor-gamma" "ratio 60%: accept bash"
test_rate "EPIC-033-R007" "python" "veto"    ""        "60" "VETOED"         "ratio 60%: veto python"
test_rate "EPIC-033-R008" "bash"  "override" "performer-beta" "60" "performer-beta" "ratio 60%: override bash"

OUTPUT_60=$(bash "$DISPATCH" "EPIC-033-R009" "bash" "accept" 2>&1) || true
test_contains "$OUTPUT_60" "(60% AI delegation)" "ratio 60%: reason shows 60% AI delegation"

# ============================================================
# [Test 3] KALLAX_AI_DELEGATION_RATIO=80 explicit (new default explicit)
# ============================================================

echo ""
echo "[Test 3] KALLAX_AI_DELEGATION_RATIO=80 (explicit new default)"
export KALLAX_AI_DELEGATION_RATIO=80

test_rate "EPIC-033-R010" "bash"  "accept"  ""        "80" "conductor-gamma" "ratio 80% explicit: accept bash"
test_rate "EPIC-033-R011" ""      "accept"  ""        "80" "conductor-gamma" "ratio 80% explicit: accept empty"
test_rate "EPIC-033-R012" "python" "veto"    ""        "80" "VETOED"         "ratio 80% explicit: veto python"
test_rate "EPIC-033-R013" "bash"  "override" "performer-beta" "80" "performer-beta" "ratio 80% explicit: override bash"

OUTPUT_80=$(bash "$DISPATCH" "EPIC-033-R014" "bash" "accept" 2>&1) || true
test_contains "$OUTPUT_80" "(80% AI delegation)" "ratio 80% explicit: reason shows 80% AI delegation"

# ============================================================
# [Test 4] KALLAX_AI_DELEGATION_RATIO=90 (forward compat: 90% AI)
# ============================================================

echo ""
echo "[Test 4] KALLAX_AI_DELEGATION_RATIO=90 (forward compat 90% AI)"
export KALLAX_AI_DELEGATION_RATIO=90

test_rate "EPIC-033-R015" "bash"  "accept"  ""        "90" "conductor-gamma" "ratio 90%: accept bash"
test_rate "EPIC-033-R016" "python" "veto"    ""        "90" "VETOED"         "ratio 90%: veto python"

OUTPUT_90=$(bash "$DISPATCH" "EPIC-033-R017" "bash" "accept" 2>&1) || true
test_contains "$OUTPUT_90" "(90% AI delegation)" "ratio 90%: reason shows 90% AI delegation"

# ============================================================
# [Test 5] Usage message shows current KALLAX_AI_DELEGATION_RATIO
# ============================================================

echo ""
echo "[Test 5] Usage message reflects current ratio"
export KALLAX_AI_DELEGATION_RATIO=80
USAGE_OUTPUT=$(bash "$DISPATCH" 2>&1 || true)
test_contains "$USAGE_OUTPUT" "KALLAX_AI_DELEGATION_RATIO=80" "usage message: shows 80 ratio"

# Reset to default and check usage
export KALLAX_AI_DELEGATION_RATIO=60
USAGE_OUTPUT_60=$(bash "$DISPATCH" 2>&1 || true)
test_contains "$USAGE_OUTPUT_60" "KALLAX_AI_DELEGATION_RATIO=60" "usage message: shows 60 ratio"

# ============================================================
# [Test 6] Error handling preserved (override requires OVERRIDE_TO)
# ============================================================

echo ""
echo "[Test 6] Error handling preserved (60→80 upgrade 不破坏 现有 invariant)"
unset KALLAX_AI_DELEGATION_RATIO

# override without OVERRIDE_TO → should still fail
if bash "$DISPATCH" "TICKET" "bash" "override" 2>/dev/null; then
  fail "override without OVERRIDE_TO should still fail after 60→80 upgrade"
else
  pass "override without OVERRIDE_TO still fails correctly (invariant preserved)"
fi

# invalid decision → should still fail
if bash "$DISPATCH" "TICKET" "bash" "invalid-decision" 2>/dev/null; then
  fail "invalid decision should still fail after 60→80 upgrade"
else
  pass "invalid decision still fails correctly (invariant preserved)"
fi

# ============================================================
# [Test 7] L1/L2/L3/L4 handoff_depth still works at 80% ratio
# ============================================================

echo ""
echo "[Test 7] handoff_depth integration with 80% ratio (4 派单模式 跟 60→80 升级 兼容)"
unset KALLAX_AI_DELEGATION_RATIO

OUTPUT_L1=$(bash "$DISPATCH" --handoff-depth=L1 "EPIC-033-R020" "bash" "accept" 2>&1) || true
test_contains "$OUTPUT_L1" "ai_ratio=80%" "handoff L1 + default 80%: ai_ratio in output"

OUTPUT_L3=$(bash "$DISPATCH" --handoff-depth=L3 "EPIC-033-R021" "bash" "accept" 2>&1) || true
test_contains "$OUTPUT_L3" "ai_ratio=80%" "handoff L3 + default 80%: ai_ratio in output"

# Reset env
unset KALLAX_AI_DELEGATION_RATIO

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
