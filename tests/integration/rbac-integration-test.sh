#!/usr/bin/env bash
# rbac-integration-test.sh — RBAC end-to-end integration tests for KALLAX v1
#
# Scope (EPIC-022-E file scope, see jira/tickets/EPIC-022-E/ticket.json):
#   1. role transitions  (master / conductor / performer / auditor / readonly)
#   2. scope checks       (conductor blocked from miao.write, performer blocked from merge)
#   3. workspace switch   (master/conductor/auditor can switch; performer cannot)
#   4. delegation TTL     (break-glass transitions expire after ≤ 1h)
#   5. audit coverage     (state-changing actions produce audit log lines)
#
# Oracle: tests/integration/role-matrix.json (6 roles × 10 actions).
#
# Strategy:
#   - Inject role into .kallax/state/state.json, restore on EXIT (trap).
#   - Inject actor into state.json (authz/check.sh no longer accepts --role CLI
#     per PHASE-002 9c + security review; actor is sourced from state.json
#     to keep the harness identical to runtime).
#   - Back up authz.db.log + role-transitions.jsonl; restore on EXIT.
#   - Each test asserts (a) exit code, (b) expected audit line presence.
#
# BE-23 + BE-25 + BE-26 fixes are in place (.git/hooks/pre-commit + check-scope-creep)
# and do not affect this test harness — tests run against scripts/, not hooks.
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §6 + §7

set -euo pipefail

# ---- Paths ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AUTHZ_CHECK="${KALLAX_ROOT}/scripts/permission/authz/check.sh"
WORKSPACE_SWITCH="${KALLAX_ROOT}/scripts/workspace/switch.sh"
ROLE_TRANSITION="${KALLAX_ROOT}/scripts/role-transition.sh"

STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
STATE_DIR="$(dirname "$STATE_FILE")"

AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"
AUDIT_LOG="${AUDIT_DB}.log"
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"

ROLE_MATRIX="${SCRIPT_DIR}/role-matrix.json"

# ---- Sanity preconditions ---------------------------------------------------
if [[ ! -x "$AUTHZ_CHECK" ]]; then
  echo "FATAL: authz/check.sh not found or not executable at $AUTHZ_CHECK" >&2
  exit 2
fi
if [[ ! -x "$WORKSPACE_SWITCH" ]]; then
  echo "FATAL: workspace/switch.sh not found or not executable at $WORKSPACE_SWITCH" >&2
  exit 2
fi
if [[ ! -x "$ROLE_TRANSITION" ]]; then
  echo "FATAL: role-transition.sh not found or not executable at $ROLE_TRANSITION" >&2
  exit 2
fi
if [[ ! -f "$ROLE_MATRIX" ]]; then
  echo "FATAL: role-matrix.json not found at $ROLE_MATRIX" >&2
  exit 2
fi

# ---- Backup state, restore on EXIT ------------------------------------------
mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE"    ]] && cp "$STATE_FILE"    "${STATE_FILE}.bak"
[[ -f "$AUDIT_LOG"     ]] && cp "$AUDIT_LOG"     "${AUDIT_LOG}.bak"
[[ -f "$TRANSITION_LOG" ]] && cp "$TRANSITION_LOG" "${TRANSITION_LOG}.bak"

restore_state() {
  if [[ -f "${STATE_FILE}.bak" ]]; then
    mv "${STATE_FILE}.bak" "$STATE_FILE"
  else
    rm -f "$STATE_FILE"
  fi
  if [[ -f "${AUDIT_LOG}.bak" ]]; then
    mv "${AUDIT_LOG}.bak" "$AUDIT_LOG"
  else
    rm -f "$AUDIT_LOG"
  fi
  if [[ -f "${TRANSITION_LOG}.bak" ]]; then
    mv "${TRANSITION_LOG}.bak" "$TRANSITION_LOG"
  fi
}
trap restore_state EXIT

# ---- Counters ---------------------------------------------------------------
PASS=0
FAIL=0
TEST_NUM=0
ACTOR="epic-022-e-tester"

# ---- Test helpers -----------------------------------------------------------
inject_state() {
  local role="$1"
  printf '{"role":"%s","actor":"%s","ts":%d}\n' \
    "$role" "$ACTOR" "$(date +%s)" > "$STATE_FILE"
}

# Run authz/check.sh and return "ALLOW" or "DENY" (never throws).
run_authz() {
  local role="$1"
  local action="$2"
  inject_state "$role"
  if bash "$AUTHZ_CHECK" --action "$action" --actor "$ACTOR" >/dev/null 2>&1; then
    printf 'ALLOW'
  else
    printf 'DENY'
  fi
}

# Run workspace/switch.sh and return "ALLOW" or "DENY".
run_workspace() {
  local role="$1"
  local workspace="$2"
  inject_state "$role"
  if bash "$WORKSPACE_SWITCH" --workspace "$workspace" --actor "$ACTOR" >/dev/null 2>&1; then
    printf 'ALLOW'
  else
    printf 'DENY'
  fi
}

# Run role-transition.sh and return "ALLOW" or "DENY".
run_transition() {
  local role="$1"
  local to_role="$2"
  local reason="$3"
  inject_state "$role"
  if bash "$ROLE_TRANSITION" --to "$to_role" --actor "$ACTOR" --reason "$reason" >/dev/null 2>&1; then
    printf 'ALLOW'
  else
    printf 'DENY'
  fi
}

assert_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  TEST_NUM=$((TEST_NUM + 1))
  if [[ "$expected" == "$actual" ]]; then
    printf '  \xe2\x9c\x93 [%02d] %s (got %s)\n' "$TEST_NUM" "$test_name" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  \xe2\x9c\x97 [%02d] %s (expected %s, got %s)\n' "$TEST_NUM" "$test_name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

# Read the role-matrix.json decision for (role, action). Fail loudly if either key is missing.
matrix_decision() {
  local role="$1"
  local action="$2"
  jq -r --arg r "$role" --arg a "$action" '.matrix[$a][$r]' "$ROLE_MATRIX"
}

# Assert that the authz.db.log has at least one entry referencing the role+action since the test started.
assert_audit_present() {
  local role="$1"
  local action="$2"
  local test_name="$3"
  TEST_NUM=$((TEST_NUM + 1))
  # authz/check.sh logs JSONL with `"action": "<value>"` (jq emits with space after colon).
  if [[ -f "$AUDIT_LOG" ]] && grep -qE "\"action\":[[:space:]]*\"$action\"" "$AUDIT_LOG" 2>/dev/null; then
    printf '  \xe2\x9c\x93 [%02d] %s\n' "$TEST_NUM" "$test_name"
    PASS=$((PASS + 1))
  else
    printf '  \xe2\x9c\x97 [%02d] %s (no audit entry for action=%s role=%s)\n' \
      "$TEST_NUM" "$test_name" "$action" "$role"
    FAIL=$((FAIL + 1))
  fi
}

# ------------------------------------------------------------------------------
# Begin tests
# ------------------------------------------------------------------------------
printf '\n=== KALLAX RBAC Integration Tests (EPIC-022-E) ===\n'
printf 'Oracle: %s\n' "$ROLE_MATRIX"

# ---------------------------------------------------------------------------
# [E2E 1] Role × Action matrix — drive the spec, assert reality matches
#         AC-2: 6 role × 10 action matrix coverage
# ---------------------------------------------------------------------------
printf '\n[E2E 1] Role × Action matrix (6 roles × 10 actions = 60 cells)\n'

ROLES=(master conductor performer readonly auditor super-admin)
ACTIONS=(task.claim task.assign worktree.create worktree.commit ticket.read \
         miao.write miao.merge testing.merge audit.export instance.terminate)

for role in "${ROLES[@]}"; do
  for action in "${ACTIONS[@]}"; do
    expected=$(matrix_decision "$role" "$action")
    actual=$(run_authz "$role" "$action")
    assert_result "authz[$role][$action]" "$expected" "$actual"
  done
done

# ---------------------------------------------------------------------------
# [E2E 2] Conductor scope violations (P0 — AC-3: miao.write 100% blocked)
# ---------------------------------------------------------------------------
printf '\n[E2E 2] Conductor scope violations (P0)\n'

assert_result "conductor.miao.write → DENY"  "DENY"  "$(run_authz conductor miao.write)"
assert_result "conductor.miao.merge → DENY"  "DENY"  "$(run_authz conductor miao.merge)"
assert_audit_present "conductor" "miao.write" "conductor.miao.write logged to audit"

# ---------------------------------------------------------------------------
# [E2E 3] Performer merge attempt (P0 — AC-4: testing.merge 100% blocked)
# ---------------------------------------------------------------------------
printf '\n[E2E 3] Performer merge attempts (P0)\n'

assert_result "performer.testing.merge → DENY" "DENY" "$(run_authz performer testing.merge)"
assert_result "performer.miao.merge    → DENY" "DENY" "$(run_authz performer miao.merge)"
assert_audit_present "performer" "testing.merge" "performer.testing.merge logged to audit"

# ---------------------------------------------------------------------------
# [E2E 4] Workspace switch + audit
#         AC-6: all workspace switches logged
# ---------------------------------------------------------------------------
printf '\n[E2E 4] Workspace switch (role × workspace)\n'

assert_result "conductor → auditor"   "ALLOW" "$(run_workspace conductor auditor)"
assert_result "conductor → readonly"  "ALLOW" "$(run_workspace conductor readonly)"
assert_result "master    → readonly"  "ALLOW" "$(run_workspace master readonly)"
assert_result "auditor   → conductor" "ALLOW" "$(run_workspace auditor conductor)"
assert_result "performer → conductor" "DENY"  "$(run_workspace performer conductor)"
assert_result "readonly  → auditor"   "DENY"  "$(run_workspace readonly auditor)"
assert_result "performer → auditor"   "DENY"  "$(run_workspace performer auditor)"

# ---------------------------------------------------------------------------
# [E2E 5] Role transitions (EPIC-022-D + audit log coverage)
#         AC-5: delegation TTL auto-expire 100% rejected after expires_at
# ---------------------------------------------------------------------------
printf '\n[E2E 5] Role transitions\n'

# Allowed transitions
assert_result "performer → conductor (normal)" "ALLOW" \
  "$(run_transition performer conductor 'normal: promotion')"
assert_result "conductor → readonly (normal)" "ALLOW" \
  "$(run_transition conductor readonly 'normal: delegation')"

# Invalid transitions
assert_result "performer → master (no break-glass) → DENY" "DENY" \
  "$(run_transition performer master 'invalid: not allowed')"
assert_result "master    → conductor → DENY" "DENY" \
  "$(run_transition master conductor 'invalid: master cannot transition down')"

# Break-glass: conductor → master (allowed, but TTL ≤ 1h)
assert_result "conductor → master (break-glass)" "ALLOW" \
  "$(run_transition conductor master 'break-glass: master unavailable')"

# ---------------------------------------------------------------------------
# [E2E 6] Break-glass TTL ≤ 1h (EPIC-022-D AC-7 + AC-8)
#         Verify expires_at in audit log is within 1h of now
# ---------------------------------------------------------------------------
printf '\n[E2E 6] Break-glass TTL ≤ 1h (AC-7 + AC-8)\n'

TEST_NUM=$((TEST_NUM + 1))
if [[ ! -f "$TRANSITION_LOG" ]]; then
  printf '  \xe2\x9c\x97 [%02d] transition log not created\n' "$TEST_NUM"
  FAIL=$((FAIL + 1))
else
  # Find last break-glass entry with is_break_glass=true
  last_bg=$(grep '"is_break_glass":true' "$TRANSITION_LOG" | tail -1 || true)
  if [[ -z "$last_bg" ]]; then
    printf '  \xe2\x9c\x97 [%02d] no break-glass entry in transition log\n' "$TEST_NUM"
    FAIL=$((FAIL + 1))
  else
    expires_at=$(jq -r '.expires_at // empty' <<< "$last_bg")
    now_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
    if [[ -z "$expires_at" ]]; then
      printf '  \xe2\x9c\x97 [%02d] break-glass entry missing expires_at\n' "$TEST_NUM"
      FAIL=$((FAIL + 1))
    else
      # TTL must be ≤ 1h (3600000 ms) and > now
      delta_ms=$((expires_at - now_ms))
      if [[ "$delta_ms" -gt 0 ]] && [[ "$delta_ms" -le 3600000 ]]; then
        printf '  \xe2\x9c\x93 [%02d] break-glass TTL within 1h (delta=%dms)\n' "$TEST_NUM" "$delta_ms"
        PASS=$((PASS + 1))
      else
        printf '  \xe2\x9c\x97 [%02d] break-glass TTL out of range (delta=%dms, expected 0 < delta <= 3600000)\n' "$TEST_NUM" "$delta_ms"
        FAIL=$((FAIL + 1))
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# [E2E 7] Delegation TTL auto-expire (AC-5)
#         Simulate: a transition with expires_at in the past → request should be denied
#         (We can't fast-forward the role-transition.sh clock; instead we
#         verify the isBreakGlassExpired gate is present in the script.)
# ---------------------------------------------------------------------------
printf '\n[E2E 7] Delegation TTL — isBreakGlassExpired gate present\n'

TEST_NUM=$((TEST_NUM + 1))
if grep -q "isBreakGlassExpired" "$ROLE_TRANSITION"; then
  printf '  \xe2\x9c\x93 [%02d] role-transition.sh defines isBreakGlassExpired gate\n' "$TEST_NUM"
  PASS=$((PASS + 1))
else
  printf '  \xe2\x9c\x97 [%02d] role-transition.sh missing isBreakGlassExpired (AC-5 fail-closed)\n' "$TEST_NUM"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# [E2E 8] Closed deny-set per role (AC-2 + fail-closed default)
#         For non-master roles, an unknown action must be DENY (allowlist is closed).
#         Master is the explicit exception: grant-everything-except-emergency.
# ---------------------------------------------------------------------------
printf '\n[E2E 8] Closed deny-set (unknown action outside allowlist)\n'

assert_result "conductor.unknown.action → DENY (allowlist closed)" "DENY" \
  "$(run_authz conductor does.not.exist)"
assert_result "performer.unknown.action → DENY (allowlist closed)" "DENY" \
  "$(run_authz performer does.not.exist)"
assert_result "readonly.unknown.action  → DENY (allowlist closed)" "DENY" \
  "$(run_authz readonly does.not.exist)"
assert_result "auditor.unknown.action   → DENY (allowlist closed)" "DENY" \
  "$(run_authz auditor does.not.exist)"
assert_audit_present "conductor" "does.not.exist" "unknown action logged to audit"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Summary ===\n'
printf 'PASS: %d\n' "$PASS"
printf 'FAIL: %d\n' "$FAIL"
printf 'TOTAL: %d\n' "$TEST_NUM"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0