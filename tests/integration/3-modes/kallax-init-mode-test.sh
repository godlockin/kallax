#!/usr/bin/env bash
# EPIC-029-F: kallax-init.sh --mode CLI test (L1-L4 fact-forcing)
# Validates --mode flag parsing, mode validation, mode-set.sh integration, E2E state.json write
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INIT="${KALLAX_ROOT}/scripts/kallax-init.sh"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"

PASS=0
FAIL=0

echo "=== EPIC-029-F kallax-init --mode integration test ==="

# L1: kallax-init.sh exists and executable
if [[ -x "$INIT" ]]; then
  echo "  ✓ kallax-init.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ kallax-init.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# L1: --mode string present in init script
if grep -q -- "--mode" "$INIT"; then
  echo "  ✓ kallax-init.sh accepts --mode flag"
  PASS=$((PASS + 1))
else
  echo "  ✗ kallax-init.sh missing --mode flag"
  FAIL=$((FAIL + 1))
fi

# L1: mode-set.sh exists and executable (EPIC-029-A dependency)
if [[ -x "$MODE_SET" ]]; then
  echo "  ✓ mode-set.sh exists and executable (EPIC-029-A dependency)"
  PASS=$((PASS + 1))
else
  echo "  ✗ mode-set.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# L2: 3 valid modes referenced in init script
for m in ai-auto ai-copilot manual; do
  if grep -q "$m" "$INIT"; then
    echo "  ✓ kallax-init.sh references mode '$m'"
    PASS=$((PASS + 1))
  else
    echo "  ✗ kallax-init.sh missing mode '$m'"
    FAIL=$((FAIL + 1))
  fi
done

# L2: init script calls mode-set.sh (EPIC-029-A integration)
if grep -q "mode-set.sh" "$INIT"; then
  echo "  ✓ kallax-init.sh integrates with mode-set.sh"
  PASS=$((PASS + 1))
else
  echo "  ✗ kallax-init.sh missing mode-set.sh integration"
  FAIL=$((FAIL + 1))
fi

# L2: invalid mode rejected (exit 1) — invoke init with bogus mode in temp project
TMPDIR=$(mktemp -d -t kallax-init-mode-test.XXXXXX)
trap "rm -rf ${TMPDIR}" EXIT
TMP_PROJECT="${TMPDIR}/fake-project"
mkdir -p "${TMP_PROJECT}"
INIT_OUTPUT=$(bash "$INIT" "${TMP_PROJECT}" --mode invalid-mode 2>&1 || true)
if echo "${INIT_OUTPUT}" | grep -q "must be one of"; then
  echo "  ✓ invalid mode rejected with error message"
  PASS=$((PASS + 1))
else
  echo "  ✗ invalid mode not rejected properly: ${INIT_OUTPUT}"
  FAIL=$((FAIL + 1))
fi
# Ensure init aborted and no project was created (state.json should not exist)
if [[ ! -f "${TMP_PROJECT}/.kallax/state/state.json" ]]; then
  echo "  ✓ invalid mode exits before state.json creation"
  PASS=$((PASS + 1))
else
  echo "  ✗ invalid mode created state.json anyway"
  FAIL=$((FAIL + 1))
fi
rm -rf "${TMP_PROJECT}"

# L3: while [[ $# -gt 0 ]] argument parsing pattern (跟 KALLAX 约定)
if grep -q "while \[\[ \$# -gt 0 \]\]" "$INIT"; then
  echo "  ✓ kallax-init.sh uses KALLAX-standard while-loop arg parsing"
  PASS=$((PASS + 1))
else
  echo "  ✗ kallax-init.sh missing KALLAX-standard arg parsing"
  FAIL=$((FAIL + 1))
fi

# L4: E2E — invoke init with --mode <each of 3 modes> and verify state.json.mode
for mode in ai-auto ai-copilot manual; do
  TMP_PROJECT="${TMPDIR}/fake-${mode}"
  mkdir -p "${TMP_PROJECT}"
  if bash "$INIT" "${TMP_PROJECT}" --mode "$mode" --actor "test-${mode}" >/dev/null 2>&1; then
    STATE_FILE="${TMP_PROJECT}/.kallax/state/state.json"
    if [[ -f "$STATE_FILE" ]]; then
      WRITTEN_MODE=$(jq -r '.mode // empty' "$STATE_FILE")
      if [[ "$WRITTEN_MODE" == "$mode" ]]; then
        echo "  ✓ --mode $mode → state.json.mode=$WRITTEN_MODE"
        PASS=$((PASS + 1))
      else
        echo "  ✗ --mode $mode wrote wrong mode: $WRITTEN_MODE"
        FAIL=$((FAIL + 1))
      fi
      MODE_SET_AT=$(jq -r '.mode_set_at // empty' "$STATE_FILE")
      if [[ -n "$MODE_SET_AT" ]]; then
        echo "  ✓ --mode $mode wrote mode_set_at=$MODE_SET_AT"
        PASS=$((PASS + 1))
      else
        echo "  ✗ --mode $mode missing mode_set_at"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "  ✗ --mode $mode did not create state.json"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ --mode $mode init failed"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "${TMP_PROJECT}"
done

# L4: mode_lock file written to NEW project's state dir (not caller's KALLAX_ROOT)
TMP_PROJECT="${TMPDIR}/fake-lock"
mkdir -p "${TMP_PROJECT}"
if bash "$INIT" "${TMP_PROJECT}" --mode ai-copilot >/dev/null 2>&1; then
  MODE_LOCK="${TMP_PROJECT}/.kallax/state/mode.lock"
  if [[ -f "$MODE_LOCK" ]]; then
    LOCK_PID=$(cat "$MODE_LOCK")
    echo "  ✓ --mode ai-copilot wrote mode.lock (PID=$LOCK_PID) in new project"
    PASS=$((PASS + 1))
  else
    echo "  ✗ --mode ai-copilot did not write mode.lock in new project"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ --mode ai-copilot init failed"
  FAIL=$((FAIL + 1))
fi
rm -rf "${TMP_PROJECT}"

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "PASS: kallax-init-mode-test.sh"
  exit 0
fi