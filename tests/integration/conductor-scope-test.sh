#!/bin/bash
# conductor-scope-test.sh — Integration test for conductor scope check
#
# Tests the NEW scripts/permission/conductor-scope-check.sh:
#   1. Conductor scope: task.assign + testing.merge ALLOWED, miao.write DENIED
#   2. Performer scope: task.claim ALLOWED, task.assign DENIED
#   3. Master scope: all actions ALLOWED (except instance.terminate)
#   4. Readonly scope: *.read ALLOWED, write actions DENIED
#   5. Auditor scope: *.read + audit.export ALLOWED, write DENIED
#   6. Fail-closed: missing state.json / unknown role → exit 1
#   7. Audit log: ALLOWED + DENIED entries written to .kallax/data/conductor-scope-audit.log
#
# 跟 EPIC-022-B 联合 (Pre-commit Hook + Conductor Scope Check)
# 跟 EPIC-022-A 3 Role Definition 联合
# 跟 BE-23 / BE-25 / BE-26 pre-commit hook governance 联合
# 跟"翻篇&精进" 战略 联合 0 简单 记录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONDUCTOR_SCOPE_CHECK="${KALLAX_ROOT}/scripts/permission/conductor-scope-check.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
STATE_DIR="$(dirname "$STATE_FILE")"
AUDIT_LOG="${KALLAX_ROOT}/.kallax/data/conductor-scope-audit.log"

# ── Pre-flight: check conductor-scope-check.sh exists +x (AC-2) ─────
if [[ ! -x "$CONDUCTOR_SCOPE_CHECK" ]]; then
  echo "FAIL: conductor-scope-check.sh missing or not executable at $CONDUCTOR_SCOPE_CHECK" >&2
  exit 1
fi

echo "=== Conductor Scope Integration Tests ==="
PASS=0
FAIL=0

# ── Setup: save state, restore on exit ─────────────────────────────
mkdir -p "$STATE_DIR"
ORIGINAL_STATE=""
if [[ -f "$STATE_FILE" ]]; then
  ORIGINAL_STATE="$(cat "$STATE_FILE")"
fi
restore_state() {
  if [[ -n "$ORIGINAL_STATE" ]]; then
    printf '%s\n' "$ORIGINAL_STATE" > "$STATE_FILE"
  else
    rm -f "$STATE_FILE"
  fi
}
trap restore_state EXIT

# Initialize state.json if missing (idempotent)
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"role":"conductor","mode":"ai-copilot"}' > "$STATE_FILE"
fi

switch_role() {
  local new_role="$1"
  jq --arg r "$new_role" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# ── Test helper ────────────────────────────────────────────────────
test_scope() {
  local role="$1"
  local action="$2"
  local expected="$3"  # "ALLOWED" or "DENIED"
  local test_name="$4"

  switch_role "$role"

  if bash "$CONDUCTOR_SCOPE_CHECK" --action "$action" --actor "test-user" 2>/dev/null; then
    actual="ALLOWED"
  else
    actual="DENIED"
  fi

  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test 1: Conductor scope permissions (AC-2 + AC-3) ──────────────
echo ""
echo "[Test 1] Conductor scope permissions"
test_scope "conductor" "task.assign"     "ALLOWED" "conductor can assign tasks (AC-2)"
test_scope "conductor" "testing.merge"   "ALLOWED" "conductor can merge to testing (AC-2)"
test_scope "conductor" "testing.write"   "ALLOWED" "conductor can write to testing"
test_scope "conductor" "instance.read"   "ALLOWED" "conductor can read instance"
test_scope "conductor" "miao.write"      "DENIED"  "conductor blocked from miao.write (AC-3)"
test_scope "conductor" "miao.merge"      "DENIED"  "conductor blocked from miao.merge (AC-3)"
test_scope "conductor" "release.tag"     "DENIED"  "conductor blocked from release.tag"
test_scope "conductor" "task.claim"      "DENIED"  "conductor blocked from task.claim"

# ── Test 2: Performer scope permissions ────────────────────────────
echo ""
echo "[Test 2] Performer scope permissions"
test_scope "performer" "task.claim"      "ALLOWED" "performer can claim tasks"
test_scope "performer" "worktree.create" "ALLOWED" "performer can create worktree"
test_scope "performer" "worktree.commit" "ALLOWED" "performer can commit to worktree"
test_scope "performer" "task.assign"     "DENIED"  "performer cannot assign tasks"
test_scope "performer" "testing.merge"   "DENIED"  "performer cannot merge to testing"
test_scope "performer" "miao.write"      "DENIED"  "performer cannot write to miao"

# ── Test 3: Master scope permissions ───────────────────────────────
echo ""
echo "[Test 3] Master scope permissions"
test_scope "master" "task.assign"        "ALLOWED" "master can assign tasks"
test_scope "master" "testing.merge"      "ALLOWED" "master can merge to testing"
test_scope "master" "miao.write"         "ALLOWED" "master can write to miao"
test_scope "master" "release.tag"        "ALLOWED" "master can tag releases"
test_scope "master" "instance.terminate" "DENIED"  "master blocked from emergency-only actions"

# ── Test 4: Readonly scope permissions ──────────────────────────────
echo ""
echo "[Test 4] Readonly scope permissions"
test_scope "readonly" "ticket.read"      "ALLOWED" "readonly can read tickets"
test_scope "readonly" "log.read"         "ALLOWED" "readonly can read logs"
test_scope "readonly" "task.claim"       "DENIED"  "readonly cannot claim tasks"
test_scope "readonly" "miao.write"       "DENIED"  "readonly cannot write to miao"

# ── Test 5: Auditor scope permissions ──────────────────────────────
echo ""
echo "[Test 5] Auditor scope permissions"
test_scope "auditor" "ticket.read"       "ALLOWED" "auditor can read tickets"
test_scope "auditor" "audit.export"      "ALLOWED" "auditor can export audits"
test_scope "auditor" "miao.write"        "DENIED"  "auditor cannot write to miao"

# ── Test 6: Fail-closed behavior (AC-4) ────────────────────────────
echo ""
echo "[Test 6] Fail-closed behavior (AC-4)"

# Missing state.json = exit 1
ORIG_STATE_BACKUP="$(cat "$STATE_FILE" 2>/dev/null || echo '')"
rm -f "$STATE_FILE"
if bash "$CONDUCTOR_SCOPE_CHECK" --action "task.assign" --actor "test-user" >/dev/null 2>&1; then
  echo "  ✗ missing state.json should fail-closed (exit 1)"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ missing state.json fails closed (AC-4)"
  PASS=$((PASS + 1))
fi
# Restore
if [[ -n "$ORIG_STATE_BACKUP" ]]; then
  printf '%s\n' "$ORIG_STATE_BACKUP" > "$STATE_FILE"
fi

# Unknown role = exit 1
echo '{"role":"unknown-role","mode":"ai-copilot"}' > "$STATE_FILE"
if bash "$CONDUCTOR_SCOPE_CHECK" --action "task.assign" --actor "test-user" >/dev/null 2>&1; then
  echo "  ✗ unknown role should fail-closed (exit 1)"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ unknown role fails closed (AC-4)"
  PASS=$((PASS + 1))
fi

# Missing --action = exit 1
echo '{"role":"conductor","mode":"ai-copilot"}' > "$STATE_FILE"
if bash "$CONDUCTOR_SCOPE_CHECK" --actor "test-user" >/dev/null 2>&1; then
  echo "  ✗ missing --action should fail-closed (exit 1)"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ missing --action fails closed (AC-4)"
  PASS=$((PASS + 1))
fi

# ── Test 7: P0 hardening (AC-5: set -euo pipefail + SIGTERM handler) ─
echo ""
echo "[Test 7] P0 hardening (AC-5)"
# Check set -euo pipefail present
if grep -q '^set -euo pipefail' "$CONDUCTOR_SCOPE_CHECK"; then
  echo "  ✓ set -euo pipefail present (AC-5)"
  PASS=$((PASS + 1))
else
  echo "  ✗ set -euo pipefail missing (AC-5)"
  FAIL=$((FAIL + 1))
fi
# Check SIGTERM handler present
if grep -q 'trap cleanup SIGTERM' "$CONDUCTOR_SCOPE_CHECK"; then
  echo "  ✓ SIGTERM handler present (AC-5)"
  PASS=$((PASS + 1))
else
  echo "  ✗ SIGTERM handler missing (AC-5)"
  FAIL=$((FAIL + 1))
fi

# ── Test 8: Audit log written (AC: audit to .kallax/data/) ─────────
echo ""
echo "[Test 8] Audit log written (AC-12)"
echo '{"role":"conductor","mode":"ai-copilot"}' > "$STATE_FILE"
# Run a couple of checks
bash "$CONDUCTOR_SCOPE_CHECK" --action "task.assign" --actor "audit-test" >/dev/null 2>&1 || true
bash "$CONDUCTOR_SCOPE_CHECK" --action "miao.write" --actor "audit-test" >/dev/null 2>&1 || true

if [[ -f "$AUDIT_LOG" ]] && grep -q "audit-test" "$AUDIT_LOG"; then
  echo "  ✓ audit log entry written (AC-12)"
  PASS=$((PASS + 1))
else
  echo "  ✗ audit log entry missing (AC-12)"
  FAIL=$((FAIL + 1))
fi

# Verify both ALLOWED and DENIED entries
if grep -q '"result": "ALLOWED"' "$AUDIT_LOG" 2>/dev/null && \
   grep -q '"result": "DENIED"' "$AUDIT_LOG" 2>/dev/null; then
  echo "  ✓ both ALLOWED and DENIED entries present"
  PASS=$((PASS + 1))
else
  echo "  ✗ missing ALLOWED or DENIED entry"
  FAIL=$((FAIL + 1))
fi

# Verify check=conductor-scope tag (distinguishes from authz/check.sh)
if grep -q '"check": "conductor-scope"' "$AUDIT_LOG" 2>/dev/null; then
  echo "  ✓ audit entries tagged with check=conductor-scope"
  PASS=$((PASS + 1))
else
  echo "  ✗ audit entries missing check=conductor-scope tag"
  FAIL=$((FAIL + 1))
fi

# ── Test 9: Pre-commit integration (AC-1) ─────────────────────────
echo ""
echo "[Test 9] Pre-commit integration (AC-1)"
PRE_COMMIT="${KALLAX_ROOT}/scripts/hooks/pre-commit"
if [[ -f "$PRE_COMMIT" ]] && grep -q "conductor-scope-check" "$PRE_COMMIT"; then
  echo "  ✓ pre-commit references conductor-scope-check.sh (AC-1)"
  PASS=$((PASS + 1))
else
  echo "  ✗ pre-commit missing conductor-scope-check reference (AC-1)"
  FAIL=$((FAIL + 1))
fi
# Verify branch-aware action mapping (跟 BE-23 联合)
if grep -q 'AUTHZ_ACTION=' "$PRE_COMMIT" && grep -q 'miao.write' "$PRE_COMMIT"; then
  echo "  ✓ pre-commit has branch-aware action mapping (BE-23)"
  PASS=$((PASS + 1))
else
  echo "  ✗ pre-commit missing branch-aware action mapping (BE-23)"
  FAIL=$((FAIL + 1))
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
