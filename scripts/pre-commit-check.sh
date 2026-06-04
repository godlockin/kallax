#!/usr/bin/env bash
# KALLAX Pre-Commit Check — run lint + typecheck + test before committing
# Usage: ./scripts/pre-commit-check.sh [--skip-test]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_TEST="${1:-}"
EXIT_CODE=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
skip() { echo -e "  ${YELLOW}[SKIP]${NC} $*"; }

cd "$PROJECT_ROOT"

echo "=== KALLAX Pre-Commit Check ==="
echo ""

# 1. Lint
echo "--- ESLint ---"
if npm run lint --silent 2>&1 | tail -5; then
  pass "ESLint passed"
else
  fail "ESLint failed — run 'npm run lint' for details"
fi

# 2. TypeScript typecheck
echo ""
echo "--- TypeScript Type Check ---"
if npx tsc --noEmit 2>&1 | head -20; then
  pass "TypeScript type check passed"
else
  fail "TypeScript type check failed"
fi

# 3. Tests
if [ "$SKIP_TEST" = "--skip-test" ]; then
  echo ""
  skip "Tests skipped (--skip-test)"
else
  echo ""
  echo "--- Tests ---"
  if npm test -- --run 2>&1 | tail -10; then
    pass "All tests passed"
  else
    fail "Tests failed"
  fi
fi

# 4. Rust (if Cargo.toml exists)
if [ -f "${PROJECT_ROOT}/rust/Cargo.toml" ]; then
  echo ""
  echo "--- Rust Checks ---"
  (cd "${PROJECT_ROOT}/rust" && cargo check 2>&1 | tail -3) && pass "Rust check passed" || fail "Rust check failed"
fi

# 5. Forbidden patterns
echo ""
echo "--- Forbidden Patterns ---"
"${PROJECT_ROOT}/scripts/scan-forbidden.sh" 2>/dev/null && pass "No forbidden patterns" || fail "Forbidden patterns found"

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}=== Ready to commit ===${NC}" || echo -e "${RED}=== ${EXIT_CODE} issue(s) blocking commit ===${NC}"
exit $EXIT_CODE
