#!/usr/bin/env bash
# KALLAX PR Size Check — evaluate diff size and flag oversized PRs
# Usage: ./scripts/check-pr-size.sh [--json]
set -euo pipefail

self_test() {
  local fixture="tests/fixtures/pr-size/cases.json"
  [[ ! -f "$fixture" ]] && { echo "FAIL: fixture $fixture not found"; exit 1; }

  local total
  total=$(jq 'length' "$fixture")
  local pass=0

  for i in $(seq 0 $((total - 1))); do
    local name
    local lines
    local expected
    name=$(jq -r ".[$i].name" "$fixture")
    lines=$(jq -r ".[$i].lines" "$fixture")
    expected=$(jq -r ".[$i].expected" "$fixture")

    local actual
    if [[ $lines -gt 500 ]]; then actual="FAIL"
    elif [[ $lines -gt 100 ]]; then actual="WARN"
    else actual="PASS"; fi

    if [[ "$actual" == "$expected" ]]; then
      echo "  [PASS] case $i: $name ($lines lines -> $actual)"
      pass=$((pass + 1))
    else
      echo "  [FAIL] case $i: $name expected $expected, got $actual"
    fi
  done

  echo "=== Summary: $pass/$total PASS ==="
  [[ $pass -eq "$total" ]] || exit 1
}

[[ "${1:-}" == "--self-test" ]] && { self_test; exit $?; }

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON_OUT="${2:-}"
BASE_BRANCH="${3:-main}"

MAX_FILES=20
MAX_INSERTIONS=500
MAX_DELETIONS=200

echo "=== KALLAX PR Size Check ==="
echo "  Base branch: ${BASE_BRANCH}"
echo ""

cd "$PROJECT_ROOT"

# Get diff stats
DIFF_STATS=$(git diff "${BASE_BRANCH}"..."HEAD" --stat 2>/dev/null || git diff "@{upstream}"..."HEAD" --stat 2>/dev/null || true)

if [ -z "$DIFF_STATS" ]; then
  echo "No diff found against ${BASE_BRANCH}. Checking staged changes..."
  DIFF_STATS=$(git diff --cached --stat)
fi

echo "${DIFF_STATS}"
echo ""

# Parse numbers
FILES_CHANGED=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
INSERTIONS=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DELETIONS=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

EXIT_CODE=0

[ "${FILES_CHANGED:-0}" -le "$MAX_FILES" ] && \
  echo "PASS: ${FILES_CHANGED} files changed (limit ${MAX_FILES})" || \
  { echo "FAIL: ${FILES_CHANGED} files changed (limit ${MAX_FILES})"; EXIT_CODE=1; }

[ "${INSERTIONS:-0}" -le "$MAX_INSERTIONS" ] && \
  echo "PASS: ${INSERTIONS} insertions (limit ${MAX_INSERTIONS})" || \
  { echo "FAIL: ${INSERTIONS} insertions (limit ${MAX_INSERTIONS})"; EXIT_CODE=1; }

[ "${DELETIONS:-0}" -le "$MAX_DELETIONS" ] && \
  echo "PASS: ${DELETIONS} deletions (limit ${MAX_DELETIONS})" || \
  { echo "FAIL: ${DELETIONS} deletions (limit ${MAX_DELETIONS})"; EXIT_CODE=1; }

if [ "$JSON_OUT" = "--json" ]; then
  FILES_CHANGED="${FILES_CHANGED:-0}"; INSERTIONS="${INSERTIONS:-0}"; DELETIONS="${DELETIONS:-0}"
  PASS=$([ "$EXIT_CODE" -eq 0 ] && echo "true" || echo "false")
  printf '{"pass":%s,"files":%d,"insertions":%d,"deletions":%d,"limits":{"max_files":%d,"max_insertions":%d,"max_deletions":%d}}\n' \
    "$PASS" "$FILES_CHANGED" "$INSERTIONS" "$DELETIONS" "$MAX_FILES" "$MAX_INSERTIONS" "$MAX_DELETIONS"
fi

exit $EXIT_CODE
