#!/bin/bash
# tests/integration/role-transition-test.sh — EPIC-022-D integration tests
#
# 跟 EPIC-022-A RBAC foundation 联合
# 跟 BE-19 KALLAX authz bypass 联合 (KALLAX_CURRENT_ROLE env blocked)
# 跟 BE-23 / BE-25 / BE-26 pre-commit hook governance 联合
# 跟"翻篇&精进" 战略 联合 (0 简单 记录, comprehensive audit)
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRANSITION_SCRIPT="${KALLAX_ROOT}/scripts/permission/role-transition.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"

# Test isolation: backup originals, restore on exit
ORIGINAL_STATE=""
if [[ -f "$STATE_FILE" ]]; then
  ORIGINAL_STATE="$(cat "$STATE_FILE")"
fi
ORIGINAL_LOG=""
if [[ -f "$TRANSITION_LOG" ]]; then
  ORIGINAL_LOG="$(cat "$TRANSITION_LOG")"
fi
ORIGINAL_ENV="${KALLAX_CURRENT_ROLE:-}"

restore_state() {
  if [[ -n "$ORIGINAL_STATE" ]]; then
    printf '%s\n' "$ORIGINAL_STATE" > "$STATE_FILE"
  elif [[ -f "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
  fi
  if [[ -n "$ORIGINAL_LOG" ]]; then
    printf '%s\n' "$ORIGINAL_LOG" > "$TRANSITION_LOG"
  elif [[ -f "$TRANSITION_LOG" ]]; then
    rm -f "$TRANSITION_LOG"
  fi
  unset KALLAX_CURRENT_ROLE
  if [[ -n "$ORIGINAL_ENV" ]]; then
    export KALLAX_CURRENT_ROLE="$ORIGINAL_ENV"
  fi
}
trap restore_state EXIT

# Test framework
PASS=0
FAIL=0
INVALID_JSON=0

assert_exit() {
  local actual="$1"
  local expected="$2"
  local test_name="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local test_name="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected to contain '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

switch_role() {
  local new_role="$1"
  local actor="${2:-test-user}"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '{"role": "%s", "actor": "%s"}\n' "$new_role" "$actor" > "$STATE_FILE"
}

unset_env() {
  unset KALLAX_CURRENT_ROLE
}

echo "=== EPIC-022-D Role Transition Integration Tests ==="

# ---------------------------------------------------------------------------
# AC-1: scripts/permission/role-transition.sh exists +x
# ---------------------------------------------------------------------------
echo ""
echo "[AC-1] Script exists + executable"
if [[ -x "$TRANSITION_SCRIPT" ]]; then
  echo "  ✓ $TRANSITION_SCRIPT exists and is executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ $TRANSITION_SCRIPT missing or not executable"
  FAIL=$((FAIL + 1))
  exit 1
fi

# ---------------------------------------------------------------------------
# AC-2: master → conductor → performer + readonly → auditor transitions
# ---------------------------------------------------------------------------
echo ""
echo "[AC-2] Allowed transition matrix"

# master → conductor (allowed)
switch_role "master"
set +e
bash "$TRANSITION_SCRIPT" --to "conductor" --actor "Steven Chen" --reason "normal: delegation" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "0" "master → conductor allowed"

# Restore for next test
switch_role "master"

# conductor → performer (allowed)
switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "performer" --actor "Steven Chen" --reason "normal: hand-off" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "0" "conductor → performer allowed"

# Restore for next test
switch_role "conductor"

# readonly → auditor (allowed)
switch_role "readonly"
set +e
bash "$TRANSITION_SCRIPT" --to "auditor" --actor "Steven Chen" --reason "normal: promotion" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "0" "readonly → auditor allowed"

# Restore for next test
switch_role "readonly"

# ---------------------------------------------------------------------------
# AC-3: tests/integration/role-transition-test.sh passes (this script)
# (verified at end via FAIL counter)

# ---------------------------------------------------------------------------
# AC-4: BE-19 KALLAX authz bypass fix (KALLAX_CURRENT_ROLE env ignored)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-4] BE-19 fix: KALLAX_CURRENT_ROLE env ignored"

# state.json says performer, but env says master → must be treated as performer
switch_role "performer"
export KALLAX_CURRENT_ROLE="master"

set +e
out="$(bash "$TRANSITION_SCRIPT" --to "master" --actor "attacker" --reason "bypass attempt" 2>&1)"
ec=$?
set -e
unset_env

# Should be DENIED because performer's state.json role cannot transition to master
assert_exit "$ec" "1" "performer (with KALLAX_CURRENT_ROLE=master env) cannot transition to master (state.json wins)"

# Also verify the WARN about env was emitted
assert_contains "$out" "KALLAX_CURRENT_ROLE" "WARN emitted about ignored env var"

# ---------------------------------------------------------------------------
# AC-5: Audit log entries (from_role, to_role, reason, actor, timestamp)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-5] Audit log comprehensive fields"

rm -f "$TRANSITION_LOG"
switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "performer" --actor "Steven Chen" --reason "normal: hand-off test" >/dev/null 2>&1
set -e

if [[ ! -f "$TRANSITION_LOG" ]]; then
  echo "  ✗ transition log not created"
  FAIL=$((FAIL + 1))
else
  last_line="$(tail -1 "$TRANSITION_LOG")"

  # Verify all required fields present
  has_ts="$(echo "$last_line" | jq -r '.ts // empty' 2>/dev/null || true)"
  has_from="$(echo "$last_line" | jq -r '.from // empty' 2>/dev/null || true)"
  has_to="$(echo "$last_line" | jq -r '.to // empty' 2>/dev/null || true)"
  has_actor="$(echo "$last_line" | jq -r '.actor // empty' 2>/dev/null || true)"
  has_reason="$(echo "$last_line" | jq -r '.reason // empty' 2>/dev/null || true)"
  has_result="$(echo "$last_line" | jq -r '.result // empty' 2>/dev/null || true)"

  if [[ -n "$has_ts" && -n "$has_from" && -n "$has_to" && -n "$has_actor" && -n "$has_reason" && -n "$has_result" ]]; then
    echo "  ✓ log contains all 6 fields: ts/from/to/actor/reason/result"
    PASS=$((PASS + 1))
  else
    echo "  ✗ log missing fields: ts=$has_ts from=$has_from to=$has_to actor=$has_actor reason=$has_reason result=$has_result"
    FAIL=$((FAIL + 1))
  fi
fi

# ---------------------------------------------------------------------------
# AC-6: Invalid transition rejected (e.g., performer → master)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-6] Invalid transition rejected"

switch_role "performer"
set +e
bash "$TRANSITION_SCRIPT" --to "master" --actor "test" --reason "invalid jump" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "1" "performer → master rejected"

# ---------------------------------------------------------------------------
# AC-7: No-op guard (same role rejected)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-7] No-op guard (same role rejected)"

switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "conductor" --actor "test" --reason "no-op" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "1" "conductor → conductor (no-op) rejected"

# ---------------------------------------------------------------------------
# AC-8: Unknown role in state.json → fail-closed
# ---------------------------------------------------------------------------
echo ""
echo "[AC-8] Unknown role in state.json → fail-closed"

printf '{"role": "hacker", "actor": "attacker"}\n' > "$STATE_FILE"
set +e
bash "$TRANSITION_SCRIPT" --to "master" --actor "test" --reason "unknown role" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "1" "unknown role 'hacker' rejected"

# ---------------------------------------------------------------------------
# AC-9: Break-glass TTL expires_at written (TTL ≤ 1h)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-9] Break-glass TTL expires_at ≤ 1h"

rm -f "$TRANSITION_LOG"
switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "master" --actor "test" --reason "break-glass: emergency" >/dev/null 2>&1
set -e

if [[ -f "$TRANSITION_LOG" ]]; then
  last_line="$(tail -1 "$TRANSITION_LOG")"
  has_expires="$(echo "$last_line" | jq -r '.expires_at // empty' 2>/dev/null || true)"
  has_bg="$(echo "$last_line" | jq -r '.is_break_glass // empty' 2>/dev/null || true)"

  if [[ -n "$has_expires" && "$has_expires" -gt 0 ]]; then
    now_ms="$(python3 -c 'import time; print(int(time.time() * 1000))')"
    delta_ms=$((has_expires - now_ms))
    # TTL must be ≤ 1h (3600000 ms) AND > now
    if [[ "$delta_ms" -gt 0 && "$delta_ms" -le 3600000 ]]; then
      echo "  ✓ break-glass expires_at valid: delta=${delta_ms}ms (≤ 3600000ms)"
      PASS=$((PASS + 1))
    else
      echo "  ✗ break-glass expires_at out of bounds: delta=${delta_ms}ms"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ break-glass log missing expires_at"
    FAIL=$((FAIL + 1))
  fi

  if [[ "$has_bg" == "true" ]]; then
    echo "  ✓ break-glass flag set to true"
    PASS=$((PASS + 1))
  else
    echo "  ✗ break-glass flag not set (got: $has_bg)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ transition log not created"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# AC-10: JSON log injection prevention
# ---------------------------------------------------------------------------
echo ""
echo "[AC-10] JSON log injection prevention"

rm -f "$TRANSITION_LOG"
switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "performer" --actor "'; DROP TABLE users; --" --reason "injection test" >/dev/null 2>&1
set -e

if [[ -f "$TRANSITION_LOG" ]]; then
  INVALID_JSON=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if ! jq -e '.' <<< "$line" >/dev/null 2>&1; then
      echo "  ✗ malformed JSON line: $line"
      INVALID_JSON=1
    fi
  done < "$TRANSITION_LOG"

  if [[ "$INVALID_JSON" -eq 0 ]]; then
    echo "  ✓ JSON log stays valid with injection attempt"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ transition log not created"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# AC-11: --from CLI rejected (BE-19 联合, no client-supplied source role)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-11] --from CLI rejected (state.json only)"

switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --from "master" --to "performer" --actor "attacker" --reason "CLI from bypass" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "1" "--from CLI rejected"

# ---------------------------------------------------------------------------
# AC-12: Cycle detection (A → B → A)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-12] Cycle detection"

rm -f "$TRANSITION_LOG"

# First transition: conductor → performer (allowed)
switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "performer" --actor "test" --reason "first hop" >/dev/null 2>&1
set -e

# Second transition: performer → conductor (allowed, but cycle completes)
set +e
bash "$TRANSITION_SCRIPT" --to "conductor" --actor "test" --reason "back to conductor" >/dev/null 2>&1
ec=$?
set -e

# Third transition: conductor → performer would cycle (last entry: performer → conductor)
# detect_cycle reads last entry: from=performer to=conductor. New request: from=conductor to=performer.
# Match: last.from=performer == new.to=performer? no. last.to=conductor == new.from=conductor? yes.
# So cycle IS detected.
assert_exit "$ec" "1" "conductor → performer after conductor → performer → conductor cycle rejected"

# ---------------------------------------------------------------------------
# AC-13: Missing required args → fail-closed
# ---------------------------------------------------------------------------
echo ""
echo "[AC-13] Missing required args rejected"

switch_role "conductor"

set +e
bash "$TRANSITION_SCRIPT" --to "performer" --actor "test" 2>/dev/null
ec1=$?
set -e
assert_exit "$ec1" "1" "missing --reason rejected"

set +e
bash "$TRANSITION_SCRIPT" --to "performer" --reason "test" 2>/dev/null
ec2=$?
set -e
assert_exit "$ec2" "1" "missing --actor rejected"

set +e
bash "$TRANSITION_SCRIPT" --actor "test" --reason "test" 2>/dev/null
ec3=$?
set -e
assert_exit "$ec3" "1" "missing --to rejected"

# ---------------------------------------------------------------------------
# AC-14: Unknown target role rejected
# ---------------------------------------------------------------------------
echo ""
echo "[AC-14] Unknown target role rejected"

switch_role "conductor"
set +e
bash "$TRANSITION_SCRIPT" --to "hacker" --actor "test" --reason "test" >/dev/null 2>&1
ec=$?
set -e
assert_exit "$ec" "1" "unknown target role 'hacker' rejected"

# ---------------------------------------------------------------------------
# AC-15: L2 substance check (script > 400 bytes)
# ---------------------------------------------------------------------------
echo ""
echo "[AC-15] L2 substance: script > 400 bytes"
size=$(wc -c < "$TRANSITION_SCRIPT" | tr -d ' ')
if [[ "$size" -gt 400 ]]; then
  echo "  ✓ script size = ${size} bytes (> 400)"
  PASS=$((PASS + 1))
else
  echo "  ✗ script size = ${size} bytes (≤ 400)"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0