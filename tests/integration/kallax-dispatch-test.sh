#!/bin/bash
# kallax-dispatch-test.sh — Integration test for kallax-dispatch.sh
#
# 12 scenarios: 4 modes × 3 behaviors
# 4 modes: default, ai-auto, ai-copilot, manual
# 3 behaviors: accept, veto, override
#
# Source: EPIC-031-B ticket.json AC
#   L1: scripts/kallax-dispatch.sh + test exist
#   L2: 真支持 3 flag (--algo-accept / --veto / --dispatch-to)
#   L3: 跟 A 兼容, 调 dispatch.sh 4 mode (default/ai-auto/ai-copilot/manual) 默认行为
#   L4: 12 测试 PASS (4 mode × 3 behavior)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/kallax-dispatch.sh"
CONDUCTOR_DISPATCH="${KALLAX_ROOT}/scripts/conductor/dispatch.sh"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

echo "=== kallax-dispatch.sh Integration Tests (12 scenarios) ==="
PASS=0
FAIL=0

# Setup: use fixtures in test/CI environment
export KALLAX_TEST_FIXTURES=1

# Temp audit dir for test isolation
TMP_AUDIT_DIR="${BASH_SOURCE[0]}.tmp.$$"
cleanup() {
  rm -rf "$TMP_AUDIT_DIR" 2>/dev/null || true
}
trap cleanup EXIT
export AUDIT_DIR="$TMP_AUDIT_DIR"
mkdir -p "$AUDIT_DIR"

# Helper: run one dispatch scenario
# Args: mode_env, ticket, expertise, extra_args, expected_final, test_name
test_dispatch() {
  local mode_env="$1"
  local ticket="$2"
  local expertise="$3"
  local extra_args="$4"
  local expected_final="$5"
  local test_name="$6"

  local output actual_final

  if [[ -n "$mode_env" ]]; then
    export KALLAX_MODE="$mode_env"
  else
    unset KALLAX_MODE
  fi

  if output=$(bash "$DISPATCH" --ticket "$ticket" --expertise "$expertise" $extra_args 2>&1); then
    actual_final=$(echo "$output" | sed -E 's/.*final=([^ ]+).*/\1/' | head -1)
    if [[ "$actual_final" == "$expected_final" ]]; then
      echo "  ✓ $test_name"
      PASS=$((PASS + 1))
    else
      echo "  ✗ $test_name (expected final=$expected_final, got final=$actual_final)"
      echo "    output: $output"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ $test_name (command failed)"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# 4 modes × 3 behaviors = 12 scenarios
# ============================================================

echo ""
echo "[Mode: default] 3 behaviors"
test_dispatch "" "EPIC-031-T001" "" "" "conductor-gamma" "default+accept: empty expertise"
test_dispatch ""        "EPIC-031-T002" "bash"   ""                        "conductor-gamma" "default+accept: expertise bash"
test_dispatch ""        "EPIC-031-T003" ""        "--veto"                  "VETOED"         "default+veto: empty expertise"
test_dispatch ""        "EPIC-031-T004" "python" "--veto"                  "VETOED"         "default+veto: expertise python"
test_dispatch ""        "EPIC-031-T005" ""        "--dispatch-to performer-beta" "performer-beta" "default+override: empty"
test_dispatch ""        "EPIC-031-T006" "bash"   "--dispatch-to performer-beta" "performer-beta" "default+override: expertise bash"

echo ""
echo "[Mode: ai-auto] 3 behaviors"
test_dispatch "ai-auto" "EPIC-031-T007" ""        ""                        "conductor-gamma" "ai-auto+accept: empty expertise"
test_dispatch "ai-auto" "EPIC-031-T008" "bash"   ""                        "conductor-gamma" "ai-auto+accept: expertise bash"
test_dispatch "ai-auto" "EPIC-031-T009" ""        "--veto"                  "VETOED"         "ai-auto+veto: empty expertise"
test_dispatch "ai-auto" "EPIC-031-T010" "bash"   "--veto"                  "VETOED"         "ai-auto+veto: expertise bash"
test_dispatch "ai-auto" "EPIC-031-T011" ""        "--dispatch-to performer-beta" "performer-beta" "ai-auto+override: empty"
test_dispatch "ai-auto" "EPIC-031-T012" "bash"   "--dispatch-to performer-beta" "performer-beta" "ai-auto+override: expertise bash"

echo ""
echo "[Mode: ai-copilot] 3 behaviors"
test_dispatch "ai-copilot" "EPIC-031-T013" "" ""                        "conductor-gamma" "ai-copilot+accept: empty expertise"
test_dispatch "ai-copilot" "EPIC-031-T014" "bash" ""                        "conductor-gamma" "ai-copilot+accept: expertise bash"
test_dispatch "ai-copilot" "EPIC-031-T015" ""      "--veto"                  "VETOED"         "ai-copilot+veto: empty expertise"
test_dispatch "ai-copilot" "EPIC-031-T016" "bash" "--veto"                  "VETOED"         "ai-copilot+veto: expertise bash"
test_dispatch "ai-copilot" "EPIC-031-T017" ""      "--dispatch-to performer-beta" "performer-beta" "ai-copilot+override: empty"
test_dispatch "ai-copilot" "EPIC-031-T018" "bash" "--dispatch-to performer-beta" "performer-beta" "ai-copilot+override: expertise bash"

echo ""
echo "[Mode: manual] 3 behaviors"
test_dispatch "manual" "EPIC-031-T019" ""         ""                        "conductor-gamma" "manual+accept: empty expertise"
test_dispatch "manual" "EPIC-031-T020" "bash"    ""                        "conductor-gamma" "manual+accept: expertise bash"
test_dispatch "manual" "EPIC-031-T021" ""         "--veto"                  "VETOED"         "manual+veto: empty expertise"
test_dispatch "manual" "EPIC-031-T022" "bash"    "--veto"                  "VETOED"         "manual+veto: expertise bash"
test_dispatch "manual" "EPIC-031-T023" ""         "--dispatch-to performer-beta" "performer-beta" "manual+override: empty"
test_dispatch "manual" "EPIC-031-T024" "bash"    "--dispatch-to performer-beta" "performer-beta" "manual+override: expertise bash"

echo ""
echo "[Error handling]"
# Missing --ticket
if bash "$DISPATCH" --expertise "bash" 2>/dev/null; then
  echo "  ✗ missing --ticket should fail"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ missing --ticket fails correctly"
  PASS=$((PASS + 1))
fi

# Missing --expertise (empty is valid — Layer 1 fallback, so it should succeed)
if bash "$DISPATCH" --ticket "EPIC-031-T001" 2>/dev/null; then
  echo "  ✓ missing --expertise defaults to Layer 1 (accepts empty expertise)"
  PASS=$((PASS + 1))
else
  echo "  ✗ missing --expertise should succeed (empty is valid for Layer 1)"
  FAIL=$((FAIL + 1))
fi

# --dispatch-to without id
if bash "$DISPATCH" --ticket "EPIC-031-T001" --expertise "bash" --dispatch-to 2>/dev/null; then
  echo "  ✗ --dispatch-to without id should fail"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ --dispatch-to without id fails correctly"
  PASS=$((PASS + 1))
fi

# --help exits0
if bash "$DISPATCH" --help >/dev/null 2>&1; then
  echo "  ✓ --help exits 0"
  PASS=$((PASS + 1))
else
  echo "  ✗ --help should exit 0"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0