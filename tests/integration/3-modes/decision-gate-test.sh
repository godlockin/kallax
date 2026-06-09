#!/bin/bash
# decision-gate-test.sh — decision-gate.sh integration test
# Covers: ai-auto + danger.data_destruction scenario
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"
INBOX_DIR="${KALLAX_ROOT}/.kallax/inbox"

PASS=0
FAIL=0

test_case() {
  local name="$1"
  local cmd="$2"
  local expected_exit="$3"

  if eval "$cmd" >/dev/null 2>&1; then
    actual_exit=0
  else
    actual_exit=$?
  fi

  if [[ "$actual_exit" == "$expected_exit" ]]; then
    echo "  ✓ $name (exit=$actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit=$expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "[decision-gate-test] L1: file existence"

# Test 1: decision-gate.sh exists and executable
if [[ -x "$DECISION_GATE" ]]; then
  echo "  ✓ decision-gate.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# Test 2: test script exists
if [[ -x "$0" ]]; then
  echo "  ✓ decision-gate-test.sh executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate-test.sh not executable"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "[decision-gate-test] L2: block/danger exit 2 behavior"

# Test: danger.data_destruction in ai-auto → exit 2 (ASK)
# Set mode to ai-auto
jq --arg m "ai-auto" --arg r "conductor" \
  '.mode = $m | .role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

test_case "danger.data_destruction + ai-auto = ASK (exit 2)" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd 'rm -rf test/'" 2

# Test: block.ambiguous_options → exit 2 (ASK)
test_case "block.ambiguous_options = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.ambiguous_options" 2

# Test: block.performer_failure → exit 2 (ASK)
test_case "block.performer_failure = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.performer_failure" 2

# Test: block.rule_exception → exit 2 (ASK)
test_case "block.rule_exception = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.rule_exception" 2

# Test: block.epic_critical → exit 2 (ASK)
test_case "block.epic_critical = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.epic_critical" 2

# Test: block.high_impact → exit 2 (ASK)
test_case "block.high_impact = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.high_impact" 2

echo ""
echo "[decision-gate-test] L2: ALLOW for non-block/danger actions"

# Test: safe action → exit 0 (ALLOW)
test_case "safe action = ALLOW (exit 0)" \
  "bash $DECISION_GATE --action safe.operation" 0

# Test: another safe action → exit 0 (ALLOW)
test_case "another safe action = ALLOW (exit 0)" \
  "bash $DECISION_GATE --action info.phase_switch" 0

echo ""
echo "[decision-gate-test] L3: ask file + audit jsonl written"

# Verify inbox file created for danger.data_destruction
INBOX_FILES_BEFORE=$(ls "$INBOX_DIR"/decision-danger_data_destruction-* 2>/dev/null | wc -l | tr -d ' ')

# Trigger danger.data_destruction again
bash "$DECISION_GATE" --action danger.data_destruction --cmd 'rm -rf prod/' >/dev/null 2>&1 || true

INBOX_FILES_AFTER=$(ls "$INBOX_DIR"/decision-danger_data_destruction-* 2>/dev/null | wc -l | tr -d ' ')

if [[ "$INBOX_FILES_AFTER" -gt "$INBOX_FILES_BEFORE" ]]; then
  echo "  ✓ inbox ask file created for danger.data_destruction"
  PASS=$((PASS + 1))
else
  echo "  ✗ inbox ask file NOT created"
  FAIL=$((FAIL + 1))
fi

# Verify audit JSONL written
AUDIT_FILES=$(ls "$AUDIT_DIR"/decision-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
if [[ "$AUDIT_FILES" -gt 0 ]]; then
  echo "  ✓ audit jsonl file exists"
  PASS=$((PASS + 1))
else
  echo "  ✗ audit jsonl file NOT found"
  FAIL=$((FAIL + 1))
fi

# Verify JSONL format (valid JSON per line)
AUDIT_FILE=$(ls -t "$AUDIT_DIR"/decision-*.jsonl 2>/dev/null | head -1)
if [[ -n "$AUDIT_FILE" ]] && [[ -s "$AUDIT_FILE" ]]; then
  if python3 -c "import json; [json.loads(l) for l in open('$AUDIT_FILE')]" 2>/dev/null; then
    echo "  ✓ audit jsonl format valid"
    PASS=$((PASS + 1))
  else
    echo "  ✗ audit jsonl format INVALID"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi