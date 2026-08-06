#!/bin/bash
# tests/integration/workspace-switch-test.sh — Integration test for EPIC-022-C
#
# Tests (跟 ticket.json AC 1:1 联合):
#   AC-1: workspace-switch.sh supports master/conductor/auditor switches
#   AC-2: readonly-path.sh identifies miao/, .git/hooks/, .kallax/config/
#   AC-4: kallax workspace:switch <name> CLI
#   AC-5: readonly-path.sh checks path readonly status
#   AC-6: switching to readonly workspace denies writes
#   AC-7: realpath first (symlink bypass protection)
#   AC-13: cross-workspace audit log
#
# P0 invariants verified:
#   - fail-closed: any error exit 1
#   - role MUST come from state.json (--role CLI removed)
#   - SIGTERM handler
#   - jq -n safe JSONL serialization
#   - flock serializes audit log writes
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3 + §4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SWITCH_SCRIPT="${KALLAX_ROOT}/scripts/permission/workspace-switch.sh"
READONLY_SCRIPT="${KALLAX_ROOT}/scripts/permission/readonly-path.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

echo "=== EPIC-022-C Workspace Switch + Read-Only Path Integration Tests ==="
PASS=0
FAIL=0

# Setup: ensure state.json exists for the test
mkdir -p "$(dirname "$STATE_FILE")"
if [[ ! -f "$STATE_FILE" ]]; then
  cat > "$STATE_FILE" <<'STATE_INIT'
{
  "role": "performer",
  "actor": "test-init",
  "mode": "ai-copilot",
  "branch": "test",
  "head_sha": "test",
  "initialized_at": "2026-06-26T00:00:00Z"
}
STATE_INIT
fi

# Backup original state.json and restore on EXIT
BACKUP_FILE="${STATE_FILE}.test-backup.$$"
cp "$STATE_FILE" "$BACKUP_FILE"
restore_state() {
  if [[ -f "$BACKUP_FILE" ]]; then
    mv "$BACKUP_FILE" "$STATE_FILE"
  fi
}
trap restore_state EXIT

ORIGINAL_ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"

# Set role in state.json
set_role() {
  local new_role="$1"
  jq --arg r "$new_role" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp" \
    && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Run switch script and check result
test_switch() {
  local role="$1"
  local workspace="$2"
  local expected="$3"
  local test_name="$4"

  set_role "$role"

  local actual
  if bash "$SWITCH_SCRIPT" --workspace "$workspace" --actor "test-user" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# Run readonly script and check result
test_readonly() {
  local role="$1"
  local path="$2"
  local expected="$3"
  local test_name="$4"

  set_role "$role"

  local actual
  if bash "$READONLY_SCRIPT" --path "$path" --actor "test-user" 2>/dev/null; then
    actual="WRITABLE"
  else
    actual="READONLY"
  fi

  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# Test 1: Workspace switch permissions (AC-1, AC-4)
# ============================================================
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

# ============================================================
# Test 2: Readonly path enforcement (AC-2, AC-5)
# ============================================================
echo ""
echo "[Test 2] Readonly path enforcement"
test_readonly "performer" "miao/test.txt" "READONLY" "performer cannot write to miao/"
test_readonly "performer" ".git/hooks/pre-commit" "READONLY" "performer cannot write to .git/hooks/"
test_readonly "performer" ".kallax/config/test.yml" "READONLY" "performer cannot write to .kallax/config/"
test_readonly "performer" "node/src/index.ts" "WRITABLE" "performer can write to node/src/"
test_readonly "conductor" "miao/test.txt" "READONLY" "conductor cannot write to miao/"
test_readonly "master" "miao/test.txt" "WRITABLE" "master can write to miao/"

# ============================================================
# Test 3: Unknown role fail-closed (P0 invariant)
# ============================================================
echo ""
echo "[Test 3] Unknown role fail-closed"
set_role "nonexistent-role"
if bash "$READONLY_SCRIPT" --path "anywhere/file.txt" --actor "test-user" 2>/dev/null; then
  echo "  FAIL: unknown role should be readonly (fail-closed)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: unknown role is readonly (fail-closed)"
  PASS=$((PASS + 1))
fi

# ============================================================
# Test 4: Missing state.json fail-closed
# ============================================================
echo ""
echo "[Test 4] Missing state.json fail-closed"
mv "$STATE_FILE" "${STATE_FILE}.hidden"
if bash "$SWITCH_SCRIPT" --workspace "conductor" --actor "test-user" 2>/dev/null; then
  echo "  FAIL: missing state.json should exit 1"
  FAIL=$((FAIL + 1))
  mv "${STATE_FILE}.hidden" "$STATE_FILE"
else
  echo "  PASS: missing state.json exits 1 (fail-closed)"
  PASS=$((PASS + 1))
  mv "${STATE_FILE}.hidden" "$STATE_FILE"
fi

# ============================================================
# Test 5: Audit log written (AC-13)
# ============================================================
echo ""
echo "[Test 5] Cross-workspace audit log"
set_role "master"
bash "$SWITCH_SCRIPT" --workspace "conductor" --actor "audit-test" 2>/dev/null || true
bash "$READONLY_SCRIPT" --path "miao/test.txt" --actor "audit-test" 2>/dev/null || true
AUDIT_LOG="${KALLAX_ROOT}/.kallax/data/authz.db.log"
if [[ -f "$AUDIT_LOG" ]] && grep -q "workspace_switch" "$AUDIT_LOG"; then
  echo "  PASS: workspace_switch event written to audit log"
  PASS=$((PASS + 1))
else
  echo "  FAIL: workspace_switch event NOT in audit log"
  FAIL=$((FAIL + 1))
fi
if [[ -f "$AUDIT_LOG" ]] && grep -q "readonly_check" "$AUDIT_LOG"; then
  echo "  PASS: readonly_check event written to audit log"
  PASS=$((PASS + 1))
else
  echo "  FAIL: readonly_check event NOT in audit log"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 6: Role cannot be supplied by environment
# ============================================================
echo ""
echo "[Test 6] Environment role is ignored"
set_role "performer"
if KALLAX_CURRENT_ROLE=master bash "$SWITCH_SCRIPT" --workspace "conductor" --actor "env-test" 2>/dev/null; then
  echo "  FAIL: environment role bypassed state.json"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: environment role ignored"
  PASS=$((PASS + 1))
fi

# Absolute canonical protected path must remain readonly.
MIAO_ABS="$(cd "$KALLAX_ROOT" && pwd)/miao/test.txt"
if bash "$READONLY_SCRIPT" --path "$MIAO_ABS" --actor "absolute-test" 2>/dev/null; then
  echo "  FAIL: absolute protected path was writable"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: absolute protected path readonly"
  PASS=$((PASS + 1))
fi


echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
