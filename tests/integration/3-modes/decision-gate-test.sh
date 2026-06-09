#!/bin/bash
# decision-gate-test.sh — decision-gate.sh integration test
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

# Count valid JSONL lines in a file
count_valid_jsonl() {
  local file="$1"
  python3 -c "
import json, sys
valid = 0
with open('$file') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try: json.loads(line); valid += 1
        except: pass
print(valid)
"
}

echo "[decision-gate-test] L1: file existence"

if [[ -x "$DECISION_GATE" ]]; then
  echo "  ✓ decision-gate.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

if [[ -x "$0" ]]; then
  echo "  ✓ decision-gate-test.sh executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ decision-gate-test.sh not executable"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "[decision-gate-test] L2: block/danger exit 2 behavior"

jq --arg m "ai-auto" --arg r "conductor" \
  '.mode = $m | .role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

test_case "danger.data_destruction + ai-auto = ASK (exit 2)" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd 'rm -rf test/'" 2

test_case "block.ambiguous_options = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.ambiguous_options" 2

test_case "block.performer_failure = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.performer_failure" 2

test_case "block.rule_exception = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.rule_exception" 2

test_case "block.epic_critical = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.epic_critical" 2

test_case "block.high_impact = ASK (exit 2)" \
  "bash $DECISION_GATE --action block.high_impact" 2

echo ""
echo "[decision-gate-test] L2: fail-closed for unknown actions"

# Issue 3: unknown actions exit 2 (fail-closed), not exit 0
test_case "unknown action = fail-closed (exit 2)" \
  "bash $DECISION_GATE --action safe.operation" 2

test_case "unknown action = fail-closed (exit 2)" \
  "bash $DECISION_GATE --action info.phase_switch" 2

echo ""
echo "[decision-gate-test] L3: ask file + audit jsonl written"

AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
> "$AUDIT_FILE"

TEST_MARKER="test_$$_$(date +%s%N)"
bash "$DECISION_GATE" --action danger.data_destruction --cmd 'rm -rf prod/' --context "{\"marker\":\"$TEST_MARKER\"}" >/dev/null 2>&1 || true

CREATED_FILE=""
for f in "$INBOX_DIR"/decision-danger_data_destruction-*.md; do
  if [[ -f "$f" ]] && grep -q "$TEST_MARKER" "$f" 2>/dev/null; then
    CREATED_FILE="$f"
    break
  fi
done

if [[ -n "$CREATED_FILE" ]]; then
  echo "  ✓ inbox ask file created: $(basename "$CREATED_FILE")"
  PASS=$((PASS + 1))
else
  echo "  ✗ inbox ask file NOT created"
  FAIL=$((FAIL + 1))
fi

if [[ -s "$AUDIT_FILE" ]]; then
  echo "  ✓ audit jsonl file exists"
  PASS=$((PASS + 1))
else
  echo "  ✗ audit jsonl file NOT found"
  FAIL=$((FAIL + 1))
fi

AUDIT_VALID=$(count_valid_jsonl "$AUDIT_FILE")
AUDIT_LINES=$(wc -l < "$AUDIT_FILE" | tr -d ' ')
if [[ "$AUDIT_VALID" -eq "$AUDIT_LINES" ]] && [[ "$AUDIT_VALID" -gt 0 ]]; then
  echo "  ✓ audit jsonl format valid ($AUDIT_VALID lines)"
  PASS=$((PASS + 1))
else
  echo "  ✗ audit jsonl format INVALID (valid=$AUDIT_VALID, total=$AUDIT_LINES)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "[decision-gate-test] L4: security fixes"

# Test 1: path traversal — action含../应exit 2
test_case "path traversal in action = reject (exit 2)" \
  "bash $DECISION_GATE --action 'danger.foo/../../etc/passwd'" 2

# Test 2: known unknown action fail-closed
test_case "unknown action = fail-closed (exit 2)" \
  "bash $DECISION_GATE --action 'danger.unknown_action'" 2

# Test 3: JSONL injection — audit仍是1行合法JSON
AUDIT_BEFORE_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null || echo 0)
bash "$DECISION_GATE" --action danger.data_destruction --cmd 'rm -rf /; echo "FAKE LINE"' >/dev/null 2>&1 || true
AUDIT_AFTER_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null || echo 0)
AUDIT_DIFF=$((AUDIT_AFTER_LINES - AUDIT_BEFORE_LINES))
if [[ "$AUDIT_DIFF" -eq 1 ]]; then
  # Verify the new last line is valid compact JSON (not multi-line)
  LAST_LINE=$(tail -1 "$AUDIT_FILE")
  if [[ $(echo "$LAST_LINE" | wc -l | tr -d ' ') -eq 1 ]] && echo "$LAST_LINE" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "  ✓ JSONL injection blocked — audit is 1 line valid JSON"
    PASS=$((PASS + 1))
  else
    echo "  ✗ JSONL injection FAILED — last line not valid compact JSON"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ JSONL injection FAILED — expected 1 new line, got $AUDIT_DIFF"
  FAIL=$((FAIL + 1))
fi

# Test 4: redaction — Bearer token → [REDACTED]
AUDIT_BEFORE_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null || echo 0)
bash "$DECISION_GATE" --action danger.data_destruction --cmd 'curl -H "Authorization: Bearer secret123"' >/dev/null 2>&1 || true
AUDIT_AFTER_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null || echo 0)
if [[ "$AUDIT_AFTER_LINES" -gt "$AUDIT_BEFORE_LINES" ]]; then
  LAST_LINE=$(tail -1 "$AUDIT_FILE")
  if echo "$LAST_LINE" | grep -q 'secret123'; then
    echo "  ✗ redaction FAILED — secret123 still in audit"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ redaction PASS — secret123 replaced with [REDACTED]"
    PASS=$((PASS + 1))
  fi
else
  echo "  ✗ redaction test FAILED — no new audit line"
  FAIL=$((FAIL + 1))
fi

# Test 5: --cmd拒绝含控制字符
test_case "cmd with control chars = reject (exit 2)" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd $'rm -rf /\x00nasty'" 2

# Test 6: --context拒绝非法JSON
test_case "invalid context JSON = reject (exit 2)" \
  "bash $DECISION_GATE --action danger.data_destruction --context '{invalid}'" 2

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi