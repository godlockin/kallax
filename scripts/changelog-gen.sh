#!/usr/bin/env bash
# KALLAX Changelog Generator — produce CHANGELOG.md from git log
# Usage: ./scripts/changelog-gen.sh [--since <tag|date>] [--to HEAD]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SINCE="${2:-}"
TO="${4:-HEAD}"
OUTPUT="${PROJECT_ROOT}/CHANGELOG.md"

echo "=== KALLAX Changelog Generator ==="
echo ""

cd "$PROJECT_ROOT"

# Determine version from latest tag or git describe
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "  Latest tag: ${LATEST_TAG}"

SINCE="${SINCE:-${LATEST_TAG}}"
echo "  Range: ${SINCE}..${TO}"
echo ""

# Generate changelog
cat > "$OUTPUT" <<EOF
# Changelog

## $(date +%Y-%m-%d)

> Generated from ${SINCE}..${TO}

EOF

# Categorize commits
echo "### Features" >> "$OUTPUT"
git log "${SINCE}..${TO}" --grep="feat" --format="  - %s (%h)" --reverse 2>/dev/null >> "$OUTPUT" || true
echo "" >> "$OUTPUT"

echo "### Bug Fixes" >> "$OUTPUT"
git log "${SINCE}..${TO}" --grep="fix" --format="  - %s (%h)" --reverse 2>/dev/null >> "$OUTPUT" || true
echo "" >> "$OUTPUT"

echo "### Documentation" >> "$OUTPUT"
git log "${SINCE}..${TO}" --grep="docs" --format="  - %s (%h)" --reverse 2>/dev/null >> "$OUTPUT" || true
echo "" >> "$OUTPUT"

echo "### Refactoring" >> "$OUTPUT"
git log "${SINCE}..${TO}" --grep="refactor\|chore" --format="  - %s (%h)" --reverse 2>/dev/null >> "$OUTPUT" || true
echo "" >> "$OUTPUT"

echo "### Other" >> "$OUTPUT"
git log "${SINCE}..${TO}" --format="  - %s (%h)" --reverse 2>/dev/null \
  | grep -v "feat\|fix\|docs\|refactor\|chore" >> "$OUTPUT" || true
echo "" >> "$OUTPUT"

LINE_COUNT=$(wc -l < "$OUTPUT")
echo "Changelog written to ${OUTPUT} (${LINE_COUNT} lines)"
