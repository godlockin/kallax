#!/bin/bash
# workspace-switch.sh — Integration test for workspace switch + readonly path
#
# Tests:
# 1. Master can switch to any workspace
# 2. Conductor can switch to conductor/auditor/readonly workspaces
# 3. Performer cannot switch workspaces
# 4. Readonly paths are enforced for performer
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SWITCH_SCRIPT="${KALLAX_ROOT}/scripts/workspace/switch.sh"
READONLY_SCRIPT="${KALLAX_ROOT}/scripts/workspace/readonly.sh"

echo "=== Workspace Switch Integration Tests ==="
PASS=0
FAIL=0

test_switch() {
  local role="$1"
  local workspace="$2"
  local expected="$3"  # "ALLOWED" or "DENIED"
  local test_name="$4"

  if bash "$SWITCH_SCRIPT" --workspace "$workspace" --actor "test-user" --role "$role" 2>/dev/null; then
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

test_readonly() {
  local role="$1"
  local path="$2"
  local expected="$3"  # "READONLY" or "WRITABLE"
  local test_name="$4"

  if bash "$READONLY_SCRIPT" --path "$path" --actor "test-user" --role "$role" 2>/dev/null; then
    actual="WRITABLE"
  else
    actual="READONLY"
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
echo "[Test 1] Workspace switch permissions"
test_switch "master" "conductor" "ALLOWED" "master can switch to conductor workspace"
test_switch "master" "auditor" "ALLOWED" "master can switch to auditor workspace"
test_switch "master" "readonly" "ALLOWED" "master can switch to readonly workspace"
test_switch "conductor" "auditor" "ALLOWED" "conductor can switch to auditor workspace"
test_switch "conductor" "readonly" "ALLOWED" "conductor can switch to readonly workspace"
test_switch "conductor" "performer" "DENIED" "conductor cannot switch to performer workspace"
test_switch "performer" "conductor" "DENIED" "performer cannot switch workspaces"
test_switch "auditor" "conductor" "ALLOWED" "auditor can switch to conductor workspace"
test_switch "readonly" "conductor" "DENIED" "readonly cannot switch workspaces"

echo ""
echo "[Test 2] Readonly path enforcement"
test_readonly "performer" "miao/test.txt" "READONLY" "performer cannot write to miao/"
test_readonly "performer" ".git/hooks/pre-commit" "READONLY" "performer cannot write to .git/hooks/"
test_readonly "performer" ".kallax/config/test.yml" "READONLY" "performer cannot write to .kallax/config/"
test_readonly "performer" "node/src/index.ts" "WRITABLE" "performer can write to node/src/"
test_readonly "conductor" "miao/test.txt" "READONLY" "conductor cannot write to miao/"
test_readonly "master" "miao/test.txt" "WRITABLE" "master can write to miao/"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
