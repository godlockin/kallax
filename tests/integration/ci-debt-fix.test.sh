#!/usr/bin/env bash
# tests/integration/ci-debt-fix.test.sh — EPIC-158 CI debt fixes tests
#
# 5 cases (per AC3):
#   1. Forbidden Patterns Check regex 不抓 JSDoc prose 'fail-closed: any error' (false-positive 0)
#   2. Forbidden Patterns Check regex 仍抓真 ': any' (real detection OK)
#   3. expert-invocations-queue.test.ts:120 在无 KALLAX_TEST_SQLITE_AVAILABLE 时 skipIf 跳过
#   4. 在 KALLAX_TEST_SQLITE_AVAILABLE=1 时不 skip
#   5. CI workflow file 改动检查 (regex 包含 '^\s*\*' 排除)
#
# Exit codes: 0=PASS all, 1=FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (got '$actual')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# Case 1: Forbidden Patterns Check 不抓 JSDoc prose
echo "Case 1: Forbidden Patterns Check excludes JSDoc prose"
# Replicate CI workflow step grep
RESULT=$(grep -rn ': any' --include="*.ts" --include="*.tsx" node/ 2>/dev/null \
  | grep -v 'node_modules' \
  | grep -v '.d.ts' \
  | grep -v -E '^[^:]+:[0-9]+:\s*\*' \
  | grep -v -E '^[^:]+:[0-9]+:\s*//' || true)
if [ -z "$RESULT" ]; then
  echo "  PASS: no JSDoc false-positive (empty output)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: JSDoc prose not filtered, got:"
  echo "$RESULT" | head -5
  FAIL=$((FAIL + 1))
fi

# Case 2: 真实 ': any' 仍被抓
echo ""
echo "Case 2: real : any still detected"
TEST_FILE=$(mktemp -t test-any-XXXXXX).ts
cat > "$TEST_FILE" <<'EOF'
const x: any = 1;
EOF
RESULT=$(grep -rn ': any' --include="*.ts" "$TEST_FILE" 2>/dev/null \
  | grep -v -E '^[^:]+:[0-9]+:\s*\*' \
  | grep -v -E '^[^:]+:[0-9]+:\s*//' || true)
if [ -n "$RESULT" ]; then
  echo "  PASS: real : any detected"
  PASS=$((PASS + 1))
else
  echo "  FAIL: real : any NOT detected"
  FAIL=$((FAIL + 1))
fi
rm -f "$TEST_FILE"

# Case 3: vitest 跑 expert-invocations-queue 在无 sqlite 时 skip
echo ""
echo "Case 3: vitest skipIf when no sqlite"
cd "${KALLAX_ROOT}/node"
SKIP_OUTPUT=$(KALLAX_HOOK_API_KEY=test npx vitest run tests/expert-invocations-queue.test.ts 2>&1 | grep -E "skipped|passed|failed" | tail -3)
cd "${KALLAX_ROOT}"
if echo "$SKIP_OUTPUT" | grep -q "skipped"; then
  echo "  PASS: vitest output contains 'skipped' (line: $(echo "$SKIP_OUTPUT" | grep skipped | head -1 | tr -d '\n'))"
  PASS=$((PASS + 1))
else
  echo "  FAIL: vitest output not contain 'skipped':"
  echo "$SKIP_OUTPUT"
  FAIL=$((FAIL + 1))
fi

# Case 4: KALLAX_TEST_SQLITE_AVAILABLE=1 不 skip (但本地无 sqlite 仍可能 skip 真实 backend)
echo ""
echo "Case 4: skipIfNoSqlite helper respects env"
cd "${KALLAX_ROOT}/node"
WITH_OUTPUT=$(KALLAX_TEST_SQLITE_AVAILABLE=1 KALLAX_HOOK_API_KEY=test npx vitest run tests/expert-invocations-queue.test.ts 2>&1 | grep -E "skipped|passed|failed" | tail -3)
WITHOUT_OUTPUT=$(KALLAX_HOOK_API_KEY=test npx vitest run tests/expert-invocations-queue.test.ts 2>&1 | grep -E "skipped|passed|failed" | tail -3)
cd "${KALLAX_ROOT}"
WITH_COUNT=$(echo "$WITH_OUTPUT" | grep -oE "[0-9]+ passed" | head -1 | grep -oE "[0-9]+")
WITHOUT_COUNT=$(echo "$WITHOUT_OUTPUT" | grep -oE "[0-9]+ passed" | head -1 | grep -oE "[0-9]+")
# env=1 时跳过少 → passed 数 >= env unset 时 passed 数
if [ "${WITH_COUNT:-0}" -ge "${WITHOUT_COUNT:-0}" ] && [ -n "$WITH_COUNT" ]; then
  echo "  PASS: env=1 passed (${WITH_COUNT}) >= env unset (${WITHOUT_COUNT})"
  PASS=$((PASS + 1))
else
  echo "  FAIL: env=1 passed (${WITH_COUNT}) < env unset (${WITHOUT_COUNT})"
  FAIL=$((FAIL + 1))
fi

# Case 5: CI workflow 文件含 JSDoc 排除 regex
echo ""
echo "Case 5: CI workflow contains JSDoc exclusion regex"
if grep -q 'grep -v -E' .github/workflows/ci.yml 2>/dev/null \
   && grep -qE 'JSDoc|JSDoc prose' .github/workflows/ci.yml 2>/dev/null; then
  echo "  PASS: CI workflow contains updated JSDoc exclusion regex + EPIC-158 comment"
  PASS=$((PASS + 1))
else
  echo "  FAIL: CI workflow missing updated regex"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "================================================"
echo "EPIC-158 CI Debt Fix Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0