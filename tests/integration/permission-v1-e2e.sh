#!/bin/bash
# permission-v1-e2e.sh — End-to-end permission flow test
#
# Tests the full KALLAX permission flow:
# task:claim → worktree → commit → merge
#
# PHASE-002 follow-up: --role CLI removed, switch via state.json (see scripts/permission/authz/check.sh).
# Test injects role into .kallax/state/state.json temporarily, restores on exit.
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §6

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTHZ_CHECK="${KALLAX_ROOT}/scripts/permission/authz/check.sh"
WORKSPACE_SWITCH="${KALLAX_ROOT}/scripts/workspace/switch.sh"
ROLE_TRANSITION="${KALLAX_ROOT}/scripts/role-transition.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

echo "=== KALLAX Permission v1 E2E Integration Tests ==="
PASS=0
FAIL=0

# Save original state, restore on exit
ORIGINAL_STATE=""
if [[ -f "$STATE_FILE" ]]; then
  ORIGINAL_STATE="$(cat "$STATE_FILE")"
fi
restore_state() {
  if [[ -n "$ORIGINAL_STATE" ]]; then
    printf '%s\n' "$ORIGINAL_STATE" > "$STATE_FILE"
  fi
}
trap restore_state EXIT

switch_role() {
  local new_role="$1"
  jq --arg r "$new_role" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

test_authz() {
  local role="$1"
  local action="$2"
  local expected="$3"
  local test_name="$4"

  switch_role "$role"

  if bash "$AUTHZ_CHECK" --action "$action" --actor "e2e-test" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

test_workspace() {
  local role="$1"
  local workspace="$2"
  local expected="$3"
  local test_name="$4"

  switch_role "$role"

  if bash "$WORKSPACE_SWITCH" --workspace "$workspace" --actor "e2e-test" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

test_transition() {
  local from_role="$1"
  local to_role="$2"
  local reason="$3"
  local expected="$4"
  local test_name="$5"

  # Switch role in state.json (--from removed per PHASE-002 + a6dedcaa)
  switch_role "$from_role"

  if bash "$ROLE_TRANSITION" --to "$to_role" --actor "e2e-test" --reason "$reason" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "[E2E 1] Performer flow (task:claim → worktree → commit)"
test_authz "performer" "task.claim" "ALLOWED" "performer can claim tasks"
test_authz "performer" "worktree.create" "ALLOWED" "performer can create worktrees"
test_authz "performer" "worktree.commit" "ALLOWED" "performer can commit to worktree"
test_authz "performer" "ticket.read" "ALLOWED" "performer can read tickets"
test_authz "performer" "miao.write" "DENIED" "performer blocked from miao.write"
test_authz "performer" "testing.merge" "DENIED" "performer blocked from testing.merge"

echo ""
echo "[E2E 2] Conductor flow (task:assign → testing.merge)"
test_authz "conductor" "task.assign" "ALLOWED" "conductor can assign tasks"
test_authz "conductor" "testing.merge" "ALLOWED" "conductor can merge to testing"
test_authz "conductor" "miao.write" "DENIED" "conductor blocked from miao.write"
test_authz "conductor" "miao.merge" "DENIED" "conductor blocked from miao.merge"

echo ""
echo "[E2E 3] Master flow (full access)"
test_authz "master" "task.assign" "ALLOWED" "master can assign tasks"
test_authz "master" "testing.merge" "ALLOWED" "master can merge to testing"
test_authz "master" "miao.write" "ALLOWED" "master can write to miao"
test_authz "master" "instance.terminate" "DENIED" "master blocked from emergency-only actions"

echo ""
echo "[E2E 4] Workspace switch flow"
test_workspace "conductor" "auditor" "ALLOWED" "conductor can switch to auditor workspace"
test_workspace "performer" "conductor" "DENIED" "performer cannot switch workspaces"
test_workspace "master" "readonly" "ALLOWED" "master can switch to readonly workspace"

echo ""
echo "[E2E 5] Role transition flow"
test_transition "performer" "conductor" "normal: promoted" "ALLOWED" "performer can transition to conductor"
test_transition "conductor" "master" "break-glass: emergency" "ALLOWED" "conductor can break-glass to master"
test_transition "performer" "master" "invalid: not allowed" "DENIED" "performer cannot become master directly"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
