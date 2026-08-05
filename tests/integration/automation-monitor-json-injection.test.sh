#!/usr/bin/env bash
# tests/integration/automation-monitor-json-injection.test.sh
# EPIC-175-fix: Test automation-monitor-todos.sh JSON injection mitigation
#
# Covers 4 injection attack vectors:
#   1. Normal status (baseline)
#   2. Single quote injection ('; rm -rf /)
#   3. Double quote injection ("; rm -rf /)
#   4. Newline + malicious injection (\n + payload)
#
# Exit codes: 0=PASS, 1=FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MONITOR_SCRIPT="$KALLAX_ROOT/scripts/automation-monitor-todos.sh"
STATE_DIR="$KALLAX_ROOT/state"
LEDGER="$STATE_DIR/run-history.jsonl"

# Setup
setup() {
  mkdir -p "$STATE_DIR"
  touch "$LEDGER"
  # Clear ledger for clean test
  : > "$LEDGER"
}

cleanup() {
  rm -f "$LEDGER"
  rm -rf "$STATE_DIR"
}

trap cleanup EXIT

# Test helper: check ledger is valid JSON for each line
assert_valid_jsonl() {
  local label="$1"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! echo "$line" | jq . >/dev/null 2>&1; then
      echo "FAIL [$label]: Invalid JSON line: $line"
      return 1
    fi
  done < "$LEDGER"
  echo "PASS [$label]: All JSON lines valid"
}

# Test helper: check no malicious content escaped
assert_no_injection() {
  local label="$1"
  local malicious="$2"
  if grep -qF "$malicious" "$LEDGER" 2>/dev/null; then
    echo "FAIL [$label]: Injection detected: $malicious"
    return 1
  fi
  echo "PASS [$label]: No injection detected"
}

# ── Test Cases ────────────────────────────────────────────────────────────────

test_normal_status() {
  echo "=== Test: Normal status ==="
  "$MONITOR_SCRIPT" emit "TEST-NORMAL" --status="in_progress"
  assert_valid_jsonl "normal-status"
  grep -q '"status":"in_progress"' "$LEDGER"
  echo "PASS: Normal status injection test"
}

test_single_quote_injection() {
  echo "=== Test: Single quote injection ==="
  local malicious="' OR '1'='1"
  "$MONITOR_SCRIPT" emit "TEST-SQL-INJECT" --status="$malicious"
  assert_valid_jsonl "single-quote-injection"
  # The single quote should be escaped in JSON
  if grep -q "'" "$LEDGER" 2>/dev/null; then
    echo "FAIL: Single quote not properly escaped"
    return 1
  fi
  echo "PASS: Single quote injection mitigated"
}

test_double_quote_injection() {
  echo "=== Test: Double quote injection ==="
  local malicious='"; DROP TABLE users; --'
  "$MONITOR_SCRIPT" emit "TEST-NOSQL-INJECT" --status="$malicious"
  assert_valid_jsonl "double-quote-injection"
  # Verify no unescaped double quotes break JSON structure
  if ! jq . "$LEDGER" >/dev/null 2>&1; then
    echo "FAIL: JSON structure broken by injection"
    return 1
  fi
  echo "PASS: Double quote injection mitigated"
}

test_newline_injection() {
  echo "=== Test: Newline + malicious payload injection ==="
  local malicious=$'test\\n{\"malicious\":\"payload\"}'
  "$MONITOR_SCRIPT" emit "TEST-NEWLINE-INJECT" --status="$malicious"
  assert_valid_jsonl "newline-injection"
  # Verify no unescaped newlines in JSON values
  local line
  line=$(grep "TEST-NEWLINE-INJECT" "$LEDGER" | tail -1)
  if echo "$line" | grep -q '\\\\n\|\\n'; then
    echo "FAIL: Newline not properly escaped"
    return 1
  fi
  echo "PASS: Newline injection mitigated"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  echo "EPIC-175-fix: automation-monitor JSON injection tests"
  echo "====================================================="
  echo ""

  setup

  local failed=0

  test_normal_status || ((failed++))
  test_single_quote_injection || ((failed++))
  test_double_quote_injection || ((failed++))
  test_newline_injection || ((failed++))

  echo ""
  echo "====================================================="
  if [ $failed -eq 0 ]; then
    echo "ALL TESTS PASSED (4/4)"
    exit 0
  else
    echo "FAILED: $failed/4 tests"
    exit 1
  fi
}

main "$@"
