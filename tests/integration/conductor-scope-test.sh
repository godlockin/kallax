#!/bin/bash
# conductor-scope.sh — Integration test for conductor scope check
#
# Tests:
# 1. Conductor can assign tasks
# 2. Conductor cannot write to miao
# 3. Performer cannot assign tasks
# 4. Master can do everything
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTHZ_CHECK="${KALLAX_ROOT}/scripts/permission/authz/check.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

echo "=== Conductor Scope Integration Tests ==="
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

# Test helper
test_authz() {
  local role="$1"
  local action="$2"
  local expected="$3"  # "ALLOWED" or "DENIED"
  local test_name="$4"

  # Switch role in state.json (--role CLI removed per PHASE-002 9c + security review)
  switch_role "$role"

  # Run in subshell to handle set -euo pipefail
  if bash "$AUTHZ_CHECK" --action "$action" --actor "test-user" 2>/dev/null; then
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
echo "[Test 1] Conductor scope permissions"
test_authz "conductor" "task.assign" "ALLOWED" "conductor can assign tasks"
test_authz "conductor" "testing.merge" "ALLOWED" "conductor can merge to testing"
test_authz "conductor" "miao.write" "DENIED" "conductor cannot write to miao"
test_authz "conductor" "miao.merge" "DENIED" "conductor cannot merge to miao"

echo ""
echo "[Test 2] Performer scope permissions"
test_authz "performer" "task.claim" "ALLOWED" "performer can claim tasks"
test_authz "performer" "task.assign" "DENIED" "performer cannot assign tasks"
test_authz "performer" "testing.merge" "DENIED" "performer cannot merge to testing"
test_authz "performer" "miao.write" "DENIED" "performer cannot write to miao"

echo ""
echo "[Test 3] Master scope permissions"
test_authz "master" "task.assign" "ALLOWED" "master can assign tasks"
test_authz "master" "testing.merge" "ALLOWED" "master can merge to testing"
test_authz "master" "miao.write" "ALLOWED" "master can write to miao"
test_authz "master" "instance.terminate" "DENIED" "master cannot perform emergency-only actions"

echo ""
echo "[Test 4] Readonly scope permissions"
test_authz "readonly" "ticket.read" "ALLOWED" "readonly can read tickets"
test_authz "readonly" "task.claim" "DENIED" "readonly cannot claim tasks"
test_authz "readonly" "miao.write" "DENIED" "readonly cannot write to miao"

echo ""
echo "[Test 5] Auditor scope permissions"
test_authz "auditor" "ticket.read" "ALLOWED" "auditor can read tickets"
test_authz "auditor" "audit.export" "ALLOWED" "auditor can export audits"
test_authz "auditor" "miao.write" "DENIED" "auditor cannot write to miao"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0