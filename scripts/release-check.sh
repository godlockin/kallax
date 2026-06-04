#!/usr/bin/env bash
# KALLAX Release Checklist — verify everything before cutting a release
# Usage: ./scripts/release-check.sh [--json]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON_OUT="${1:-}"
EXIT_CODE=0
RESULTS=()

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
check() {
  local name="$1" result="$2" msg="$3"
  if [ "$result" = "pass" ]; then
    echo -e "  ${GREEN}[PASS]${NC} ${name}: ${msg}"
    RESULTS+=("{\"name\":\"${name}\",\"result\":\"pass\",\"message\":\"${msg}\"}")
  else
    echo -e "  ${RED}[FAIL]${NC} ${name}: ${msg}"
    RESULTS+=("{\"name\":\"${name}\",\"result\":\"fail\",\"message\":\"${msg}\"}")
    EXIT_CODE=1
  fi
}

cd "$PROJECT_ROOT"

echo "=== KALLAX Release Checklist ==="
echo ""

# 1. Git state
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] && check "branch" "pass" "On main branch" || check "branch" "fail" "On ${BRANCH} (expected main)"

UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[ "$UNCOMMITTED" -eq 0 ] && check "clean-tree" "pass" "Working tree clean" || check "clean-tree" "fail" "${UNCOMMITTED} uncommitted files"

# 2. Version tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
[ "$LATEST_TAG" != "none" ] && check "latest-tag" "pass" "Latest tag: ${LATEST_TAG}" || check "latest-tag" "fail" "No tags found"

# 3. Build
if [ -f package.json ]; then
  npm run build 2>&1 | tail -1 >/dev/null && check "build" "pass" "Build succeeded" || check "build" "fail" "Build failed"
fi

# 4. Tests (Node)
if [ -f package.json ]; then
  npm test -- --run 2>&1 | tail -3 >/dev/null && check "tests-node" "pass" "All Node tests passed" \
    || check "tests-node" "fail" "Node tests failed"
fi

# 5. Tests (Rust)
if [ -f rust/Cargo.toml ]; then
  (cd rust && cargo test 2>&1 | tail -3 >/dev/null) && check "tests-rust" "pass" "All Rust tests passed" \
    || check "tests-rust" "fail" "Rust tests failed"
fi

# 6. Lint
npm run lint --silent 2>&1 | tail -1 >/dev/null && check "lint" "pass" "Lint passed" \
  || check "lint" "fail" "Lint failed"

# 7. Forbidden patterns
"${PROJECT_ROOT}/scripts/scan-forbidden.sh" 2>/dev/null 1>/dev/null && check "forbidden" "pass" "No forbidden patterns" \
  || check "forbidden" "fail" "Forbidden patterns found"

# 8. Config validation
"${PROJECT_ROOT}/scripts/validate-config.sh" 2>/dev/null 1>/dev/null && check "config" "pass" "Config valid" \
  || check "config" "fail" "Config invalid"

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}=== Ready for release ===${NC}" \
  || echo -e "${RED}=== ${EXIT_CODE} issue(s) must be resolved before release ===${NC}"

# JSON output
if [ "$JSON_OUT" = "--json" ]; then
  IFS=,; ALL="${RESULTS[*]}"
  printf '{"pass":%s,"checks":[%s]}\n' "$([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false")" "${ALL}"
fi

exit $EXIT_CODE
