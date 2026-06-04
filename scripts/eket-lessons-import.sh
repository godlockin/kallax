#!/usr/bin/env bash
# KALLAX EKET Lessons Import — import lessons from EKET project to knowledge base
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
EKET_ROOT="${2:-}"
KB_DIR="${PROJECT_ROOT}/confluence/retrospectives"

# Check if node CLI is available
KALLAX_BIN="${KALLAX_BIN:-$(command -v kallax 2>/dev/null || echo 'npx tsx node/src/index.ts')}"

echo "=== KALLAX EKET Lessons Import ==="
echo ""

# 1. Locate EKET project
if [ -z "$EKET_ROOT" ]; then
  # Common locations
  for candidate in "../eket" "../eket-api" "${HOME}/projects/eket"; do
    if [ -f "${candidate}/.kallax/IDENTITY.md" ] || [ -d "${candidate}/.kallax" ]; then
      EKET_ROOT=$(realpath "$candidate")
      break
    fi
  done
fi

if [ -z "$EKET_ROOT" ] || [ ! -d "$EKET_ROOT" ]; then
  echo "EKET project not found. Provide the path:" >&2
  echo "  $0 <project-root> <eket-root>" >&2
  exit 1
fi

echo "EKET root: $EKET_ROOT"
mkdir -p "$KB_DIR"

# 2. Extract lessons from EKET knowledge areas
IMPORTED=0

# 2a. Check migration doc
MIGRATION_DOC="${PROJECT_ROOT}/docs/guides/migration-eket-to-kallax.md"
if [ -f "$MIGRATION_DOC" ]; then
  echo "Found migration guide — extracting lessons..."
  cp "$MIGRATION_DOC" "${KB_DIR}/migration-eket-to-kallax.md"
  IMPORTED=$((IMPORTED + 1))
fi

# 2b. Check EKET retrospectives
EKET_RETRO="${EKET_ROOT}/confluence/retrospectives"
if [ -d "$EKET_RETRO" ]; then
  echo "Found EKET retrospectives — copying..."
  cp -r "$EKET_RETRO/"* "${KB_DIR}/" 2>/dev/null || true
  RETRO_COUNT=$(find "$EKET_RETRO" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  IMPORTED=$((IMPORTED + RETRO_COUNT))
  echo "  Copied $RETRO_COUNT retro documents"
fi

# 2c. Check EKET memory/patterns
EKET_PATTERNS="${EKET_ROOT}/confluence/memory/patterns"
if [ -d "$EKET_PATTERNS" ]; then
  echo "Found EKET patterns — importing..."
  TARGET="${KB_DIR}/eket-patterns"
  mkdir -p "$TARGET"
  cp -r "$EKET_PATTERNS/"* "$TARGET/" 2>/dev/null || true
  PATTERN_COUNT=$(find "$EKET_PATTERNS" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  IMPORTED=$((IMPORTED + PATTERN_COUNT))
  echo "  Imported $PATTERN_COUNT pattern documents"
fi

# 3. Index imported content into KALLAX knowledge base
if [ "$IMPORTED" -gt 0 ]; then
  echo ""
  echo "Indexing $IMPORTED documents into knowledge base..."

  find "${KB_DIR}" -name "*.md" -maxdepth 2 | while read -r doc; do
    TITLE=$(head -1 "$doc" 2>/dev/null | sed 's/^# //' || echo "Untitled")
    CONTENT=$(head -100 "$doc" 2>/dev/null || true)
    TAGS="imported,eket,lesson"

    if $KALLAX_BIN knowledge index --title "$TITLE" --content "$CONTENT" --tags "$TAGS" 2>/dev/null; then
      echo "  Indexed: $TITLE"
    else
      echo "  SKIP: $TITLE (indexing failed)"
    fi
  done
fi

echo ""
if [ "$IMPORTED" -gt 0 ]; then
  echo "Import complete: $IMPORTED document(s) imported."
  echo "Location: $KB_DIR"
else
  echo "No lessons found to import."
fi
