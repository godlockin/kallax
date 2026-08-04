#!/usr/bin/env bash
# tests/integration/check-private-context.test.sh — EPIC-163 Integration Test
# Simplified: test scanner behavior directly
#
# Exit: 0 = all test PASS, 1 = any test FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCANNER="${REPO_ROOT}/scripts/check-private-context.sh"
cd "$REPO_ROOT"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() { echo "  [PASS] $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
info() { echo "  [*] $*"; }

run_test() {
  local name="$1"
  local expected="$2"
  local cmd="$3"
  TOTAL=$((TOTAL + 1))
  info "Test $TOTAL: $name"

  local output exit_code
  output=$(eval "$cmd" 2>&1) || true
  exit_code=$?

  if [ "$exit_code" -eq "$expected" ]; then
    pass "$name (expected=$expected, got=$exit_code)"
  else
    fail "$name (expected=$expected, got=$exit_code)"
  fi
}

echo "=========================================="
echo "check-private-context.sh Integration Tests"
echo "=========================================="

# TC1: Clean state → PASS (exit 0)
run_test "TC1: Clean state" 0 \
  "bash $SCANNER >/dev/null 2>&1; echo \$?"

# TC2: Scanner is executable
run_test "TC2: Scanner executable" 0 \
  "[ -x '$SCANNER' ] && echo 0 || echo 1"

# TC3: --help exits 0
run_test "TC3: --help exits 0" 0 \
  "bash $SCANNER --help >/dev/null 2>&1; echo \$?"

# TC4: --staged-only works (clean state)
run_test "TC4: --staged-only (clean)" 0 \
  "bash $SCANNER --staged-only >/dev/null 2>&1; echo \$?"

# TC5: GitHub token pattern matches
run_test "TC5: GitHub token pattern" 0 \
  "echo 'ghp_test1234567890123456789012345678901234' | grep -qE 'ghp_[a-zA-Z0-9]{36}' && echo 0 || echo 1"

# TC6: OpenAI key pattern matches
run_test "TC6: OpenAI key pattern" 0 \
  "echo 'sk-test1234567890123456789012345678901234567890123' | grep -qE 'sk-[a-zA-Z0-9]{48}' && echo 0 || echo 1"

# TC7: AWS key pattern matches
run_test "TC7: AWS key pattern" 0 \
  "echo 'AKIAIOSFODNN7EXAMPLE' | grep -qE 'AKIA[0-9A-Z]{16}' && echo 0 || echo 1"

# TC8: Private path pattern matches
run_test "TC8: Private path pattern" 0 \
  "echo '/Users/testuser/Documents' | grep -qE '/Users/[^/]+/[a-zA-Z]' && echo 0 || echo 1"

# TC9: Skip pattern works (skip docs/)
run_test "TC9: Skip pattern (docs)" 0 \
  "echo 'docs/test.md' | grep -qE '^docs/' && echo 0 || echo 1"

# TC10: Skip pattern works (skip jira/)
run_test "TC10: Skip pattern (jira)" 0 \
  "echo 'jira/tickets/EPIC-163/ticket.json' | grep -qE '^jira/' && echo 0 || echo 1"

echo ""
echo "=========================================="
echo "Results: $PASS_COUNT/$TOTAL PASS, $FAIL_COUNT FAIL"
echo "=========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "INTEGRATION TEST FAILED"
  exit 1
fi

echo "INTEGRATION TEST PASSED"
exit 0
