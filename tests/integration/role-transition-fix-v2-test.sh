#!/bin/bash
# role-transition-fix-v2.sh — Integration tests for EPIC-022 second batch fixes
#
# Tests:
# 1. JSON log injection prevention (malicious actor name)
# 2. No-op guard (same role transition denied)
# 3. Unknown role in readonly.sh → fail-closed (readonly)
# 4. Break-glass TTL enforced (expires_at written to log)
# 5. switch.sh rejects --role CLI (must read from state.json)
# 6. Case branch deduplication (no duplicate conductor/readonly/auditor)
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRANSITION_SCRIPT="${KALLAX_ROOT}/scripts/role-transition.sh"
READONLY_SCRIPT="${KALLAX_ROOT}/scripts/workspace/readonly.sh"
SWITCH_SCRIPT="${KALLAX_ROOT}/scripts/workspace/switch.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

# Backup original state.json
if [[ -f "$STATE_FILE" ]]; then
  cp "$STATE_FILE" "${STATE_FILE}.bak"
fi
# Backup original transition log
if [[ -f "$TRANSITION_LOG" ]]; then
  cp "$TRANSITION_LOG" "${TRANSITION_LOG}.bak"
fi

cleanup() {
  # Restore originals
  if [[ -f "${STATE_FILE}.bak" ]]; then
    mv "${STATE_FILE}.bak" "$STATE_FILE"
  fi
  if [[ -f "${TRANSITION_LOG}.bak" ]]; then
    mv "${TRANSITION_LOG}.bak" "$TRANSITION_LOG"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0
invalid=0

echo "=== EPIC-022 Second Batch Security Fixes — Integration Tests ==="

# ---------------------------------------------------------------------------
# Test 1: JSON log injection prevention
# actor='; DROP TABLE -- → must not corrupt JSON log
# ---------------------------------------------------------------------------
echo ""
echo "[Test 1] JSON log injection prevention"
printf '{"role": "conductor", "actor": "Steven Chen"}\n' > "$STATE_FILE"
rm -f "$TRANSITION_LOG"

INJECTION_ACTOR="'; DROP TABLE users; --"
set +e
bash "$TRANSITION_SCRIPT" \
  --to "master" \
  --actor "$INJECTION_ACTOR" \
  --reason "break-glass: test" \
  >/dev/null 2>&1
set -e

if [[ ! -f "$TRANSITION_LOG" ]]; then
  echo "  ✗ transition log not created"
  FAIL=$((FAIL + 1))
else
  invalid=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if ! jq -e '.' <<< "$line" >/dev/null 2>&1; then
      echo "  ✗ malformed JSON line: $line"
      invalid=1
    fi
  done < "$TRANSITION_LOG"

  if [[ "$invalid" -eq 0 ]]; then
    echo "  ✓ JSON log stays valid with injection attempt"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
fi

# ---------------------------------------------------------------------------
# Test 2: No-op guard — same role transition denied
# ---------------------------------------------------------------------------
echo ""
echo "[Test 2] No-op guard (same role transition denied)"

printf '{"role": "conductor", "actor": "Steven Chen"}\n' > "$STATE_FILE"

set +e
result=$(bash "$TRANSITION_SCRIPT" --to "conductor" --actor "test" --reason "no-op test" 2>&1)
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
  echo "  ✓ same-role transition correctly denied (exit $ec)"
  PASS=$((PASS + 1))
else
  echo "  ✗ same-role transition should be denied but got exit $ec"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Test 3: Unknown role in readonly.sh → fail-closed (readonly)
# ---------------------------------------------------------------------------
echo ""
echo "[Test 3] Unknown role = fail-closed (readonly) in readonly.sh"

# readonly.sh still accepts --role, so test directly
set +e
result=$(bash "$READONLY_SCRIPT" --path "miao/test" --actor "attacker" --role "hacker" 2>&1)
ec=$?
set -e

if [[ $ec -eq 1 ]]; then
  echo "  ✓ unknown role 'hacker' is treated as readonly (exit 1)"
  PASS=$((PASS + 1))
else
  echo "  ✗ unknown role should be readonly (exit 1) but got exit $ec"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Test 4: Break-glass TTL enforced — write expires_at in audit log
# ---------------------------------------------------------------------------
echo ""
echo "[Test 4] Break-glass TTL enforced (expires_at written to log)"

printf '{"role": "conductor", "actor": "Steven Chen"}\n' > "$STATE_FILE"
rm -f "$TRANSITION_LOG"
bash "$TRANSITION_SCRIPT" --to "master" --actor "test" --reason "break-glass: test TTL" >/dev/null 2>&1

if [[ ! -f "$TRANSITION_LOG" ]]; then
  echo "  ✗ transition log not created"
  FAIL=$((FAIL + 1))
else
  last_line=$(tail -1 "$TRANSITION_LOG")
  has_expires=$(jq -r '.expires_at // empty' <<< "$last_line" 2>/dev/null)
  if [[ -n "$has_expires" && "$has_expires" -gt 0 ]]; then
    echo "  ✓ break-glass log contains expires_at=$has_expires"
    PASS=$((PASS + 1))
  else
    echo "  ✗ break-glass log missing or invalid expires_at: $last_line"
    FAIL=$((FAIL + 1))
  fi
fi

# ---------------------------------------------------------------------------
# Test 5: switch.sh reads role from state.json only (no --role CLI)
# ---------------------------------------------------------------------------
echo ""
echo "[Test 5] switch.sh — role from state.json only (--role removed)"

# Verify --role parameter is no longer accepted
set +e
result=$(bash "$SWITCH_SCRIPT" --workspace "auditor" --actor "test" --role "master" 2>&1)
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
  echo "  ✓ switch.sh rejects --role param (exit $ec)"
  PASS=$((PASS + 1))
else
  echo "  ✗ switch.sh should reject --role but accepted it (exit $ec)"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Test 6: Role allowlist validation in role-transition.sh
# ---------------------------------------------------------------------------
echo ""
echo "[Test 6] Role allowlist validation"

# Create state.json with invalid role
printf '{"role": "invalid_role", "actor": "attacker"}\n' > "$STATE_FILE"

set +e
result=$(bash "$TRANSITION_SCRIPT" --to "master" --actor "test" --reason "test" 2>&1)
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
  echo "  ✓ invalid role 'invalid_role' is rejected (exit $ec)"
  PASS=$((PASS + 1))
else
  echo "  ✗ invalid role should be rejected but got exit $ec"
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