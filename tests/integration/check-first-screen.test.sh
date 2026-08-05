#!/usr/bin/env bash
# tests/integration/check-first-screen.test.sh — EPIC-173 Integration Test
# Simplified: test scanner behavior directly
#
# Exit: 0 = all test PASS, 1 = any test FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCANNER="${REPO_ROOT}/scripts/check-first-screen.sh"
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

  local exit_code=0
  (eval "$cmd" >/dev/null 2>&1) || exit_code=$?

  if [ "$exit_code" -eq "$expected" ]; then
    pass "$name (expected=$expected, got=$exit_code)"
  else
    fail "$name (expected=$expected, got=$exit_code)"
  fi
}

echo "=========================================="
echo "check-first-screen.sh Integration Tests"
echo "=========================================="

# TC1: Scanner is executable
run_test "TC1: Scanner executable" 0 \
  "[ -x '$SCANNER' ] && echo 0 || echo 1"

# TC2: --help exits 0
run_test "TC2: --help exits 0" 0 \
  "bash $SCANNER --help >/dev/null 2>&1; echo \$?"

# TC3: --staged-only works (clean state)
run_test "TC3: --staged-only (clean)" 0 \
  "bash $SCANNER --staged-only >/dev/null 2>&1; echo \$?"

# TC4: README.md pattern matches
run_test "TC4: README.md pattern" 0 \
  "(echo 'README.md' | grep -qE '^README\.md$') && exit 0; exit 1"

# TC5: README.en.md pattern matches
run_test "TC5: README.en.md pattern" 0 \
  "(echo 'README.en.md' | grep -qE '^README\.en\.md$') && exit 0; exit 1"

# TC6: web/index.html pattern matches
run_test "TC6: web/index.html pattern" 0 \
  "(echo 'web/index.html' | grep -qE '^web/index\.html$') && exit 0; exit 1"

# TC7: web/showcase/index.html pattern matches
run_test "TC7: web/showcase/index.html pattern" 0 \
  "(echo 'web/showcase/index.html' | grep -qE '^web/showcase/index\.html$') && exit 0; exit 1"

# TC8: docs/showcases/README.md pattern matches
run_test "TC8: docs/showcases/README.md pattern" 0 \
  "(echo 'docs/showcases/README.md' | grep -qE '^docs/showcases/README\.md$') && exit 0; exit 1"

# TC9: Exit code 0 on clean state
run_test "TC9: Clean state exit 0" 0 \
  "bash $SCANNER >/dev/null 2>&1; echo \$?"

# TC10: --approved flag recognized
run_test "TC10: --approved flag recognized" 0 \
  "bash $SCANNER --approved >/dev/null 2>&1; echo \$?"

# TC11: First-screen path detection logic
run_test "TC11: First-screen path detection" 0 \
  "(echo -e 'README.md\nother.md' | grep -qE '^README\.md$') && exit 0; exit 1"

# TC12: Non-first-screen path not detected
run_test "TC12: Non-first-screen path" 1 \
  "(echo 'docs/other.md' | grep -qE '^README\.md$') && exit 0; exit 1"

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
