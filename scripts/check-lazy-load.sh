#!/usr/bin/env bash
# KALLAX Lazy Load Check — detect unused imports across the TypeScript codebase
# Usage: ./scripts/check-lazy-load.sh [--fix]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CDIR="${PROJECT_ROOT}/node/src"
FIX="${1:-}"

echo "=== KALLAX Unused Import Check ==="
echo ""

if ! command -v npx &>/dev/null; then
  echo "ERROR: npx not found. Install Node.js >= 18."
  exit 1
fi

# Use ts-prune to find unused exports (imported but not referenced)
echo "--- Running ts-prune ---"
npx ts-prune \
  --project "${PROJECT_ROOT}/tsconfig.json" \
  --error \
  | grep -v "(used in module)" \
  || true

# Count lines with unused exports
UNUSED_COUNT=$(npx ts-prune --project "${PROJECT_ROOT}/tsconfig.json" 2>/dev/null \
  | grep -v "(used in module)" \
  | grep -c ":" || true)

echo ""
if [ "$UNUSED_COUNT" -eq 0 ]; then
  echo "PASS: No unused imports detected."
  exit 0
else
  echo "WARN: ${UNUSED_COUNT} potential unused import(s) found."
  if [ "$FIX" = "--fix" ]; then
    echo "Attempting auto-cleanup with ts-prune --assume-exports-only..."
    npx ts-prune --project "${PROJECT_ROOT}/tsconfig.json" --assume-exports-only 2>/dev/null | wc -l
  fi
  exit 1
fi
