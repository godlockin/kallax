#!/usr/bin/env bash
# precommit-integration-test.sh — EPIC-029-E L4 verification
# Verifies pre-commit hook references decision-gate after 3 anti-fab tools
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# file_scope: .kallax/hooks/pre-commit (installed hook, synced from scripts/hooks/pre-commit)
PRE_COMMIT="${KALLAX_ROOT}/.kallax/hooks/pre-commit"

PASS=0
FAIL=0

echo "=== EPIC-029-E pre-commit integration test ==="

# L1: pre-commit exists
if [[ -f "$PRE_COMMIT" ]]; then
  echo "  ✓ pre-commit exists"
  PASS=$((PASS + 1))
else
  echo "  ✗ pre-commit missing"
  FAIL=$((FAIL + 1))
fi

# L1: decision-gate.sh exists
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
if [[ -x "$DECISION_GATE" ]]; then
  echo "  ✓ decision-gate.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# L1: pre-commit references decision-gate
if grep -q "decision-gate" "$PRE_COMMIT"; then
  echo "  ✓ pre-commit references decision-gate"
  PASS=$((PASS + 1))
else
  echo "  ✗ pre-commit missing decision-gate"
  FAIL=$((FAIL + 1))
fi

# L1: pre-commit has 3 anti-fab tools (check each individually)
ANTIFAB_MISSING=0
for tool in check-test-case-isolation check-kpi-precision check-scope-creep; do
  if grep -q "$tool" "$PRE_COMMIT"; then
    echo "  ✓ pre-commit references $tool"
    PASS=$((PASS + 1))
  else
    echo "  ✗ pre-commit missing $tool"
    FAIL=$((FAIL + 1))
    ANTIFAB_MISSING=1
  fi
done

# L2: decision-gate called after authz check
AUTHZ_LINE=$(grep -n "authz/check.sh" "$PRE_COMMIT" | head -1 | cut -d: -f1 || echo "0")
DECISION_LINE=$(grep -n "decision-gate" "$PRE_COMMIT" | head -1 | cut -d: -f1 || echo "0")
if [[ "$DECISION_LINE" -gt "$AUTHZ_LINE" ]] && [[ "$DECISION_LINE" -gt 0 ]]; then
  echo "  ✓ decision-gate called after authz check (line $AUTHZ_LINE < $DECISION_LINE)"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate placement issue (authz line $AUTHZ_LINE, decision line $DECISION_LINE)"
  FAIL=$((FAIL + 1))
fi

# L2: 3 anti-fab tools present (count total occurrences across file)
ANTIFAB_COUNT=0
for tool in check-test-case-isolation check-kpi-precision check-scope-creep; do
  COUNT=$(grep -c "$tool" "$PRE_COMMIT" || echo "0")
  ANTIFAB_COUNT=$((ANTIFAB_COUNT + COUNT))
done
if [[ "$ANTIFAB_COUNT" -ge 3 ]]; then
  echo "  ✓ 3 anti-fab tools present ($ANTIFAB_COUNT total occurrences)"
  PASS=$((PASS + 1))
else
  echo "  ✗ only $ANTIFAB_COUNT anti-fab tool occurrences (expected ≥3)"
  FAIL=$((FAIL + 1))
fi

# L3: KALLAX_ROOT path correct in decision-gate section
if grep -q 'KALLAX_ROOT.*scripts/permission/decision-gate' "$PRE_COMMIT"; then
  echo "  ✓ KALLAX_ROOT path correct for decision-gate"
  PASS=$((PASS + 1))
else
  echo "  ✗ KALLAX_ROOT path incorrect for decision-gate"
  FAIL=$((FAIL + 1))
fi

# L3: exit 1 on decision-gate BLOCKED (BLOCKED msg on one line, exit 1 on next)
if grep -q "BLOCKED.*decision-gate\|BLOCKED.*dangerous" "$PRE_COMMIT" && \
   grep -q "exit 1" "$PRE_COMMIT"; then
  echo "  ✓ pre-commit exits 1 on decision-gate BLOCKED"
  PASS=$((PASS + 1))
else
  echo "  ✗ pre-commit missing exit 1 on decision-gate BLOCKED"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "PASSED"
  exit 0
fi