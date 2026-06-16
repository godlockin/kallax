#!/usr/bin/env bash
# KALLAX Stale Worktree Detector — find worktrees unused for 7+ days
# Usage: ./scripts/detect-stale-worktrees.sh [--age 7] [--clean]
# EPIC-054-A: Single-root invariant — all worktrees expected under SINGLE_ROOT_DIR
# (= .kallax/worktrees). Worktrees outside this root trigger an invariant warning
# and should be migrated via scripts/worktree/unify-roots.sh.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STALE_AGE_DAYS=7
CLEAN=false
# EPIC-054-A: canonical single-root (跟 git worktree list 1:1)
readonly SINGLE_ROOT_DIR=".kallax/worktrees"

for arg in "$@"; do
  case "$arg" in
    --age=*) STALE_AGE_DAYS="${arg#*=}" ;;
    --clean) CLEAN=true ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

EXIT_CODE=0

echo "=== KALLAX Stale Worktree Detector ==="
echo "  Age threshold: ${STALE_AGE_DAYS} days"
echo "  Auto-clean: ${CLEAN}"
echo "  Single-root: ${SINGLE_ROOT_DIR} (EPIC-054-A invariant)"
echo ""

WT_LIST=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null)
NOW_TS=$(date +%s)
STALE_COUNT=0
CLEANED_COUNT=0
OUTSIDE_ROOT_COUNT=0

# EPIC-054-A: pre-pass to detect worktrees outside single-root invariant
while IFS= read -r line; do
  [ -z "$line" ] && continue
  WT_PATH=$(echo "$line" | awk '{print $1}')
  [ "$WT_PATH" = "$PROJECT_ROOT" ] && continue
  case "$WT_PATH" in
    *"/${SINGLE_ROOT_DIR}/"*) : ;;
    *)
      warn "INVARIANT: worktree outside ${SINGLE_ROOT_DIR}: ${WT_PATH}"
      OUTSIDE_ROOT_COUNT=$((OUTSIDE_ROOT_COUNT + 1))
      ;;
  esac
done <<< "$WT_LIST"

if [ "$OUTSIDE_ROOT_COUNT" -gt 0 ]; then
  warn "EPIC-054-A: $OUTSIDE_ROOT_COUNT worktree(s) outside single-root (run scripts/worktree/unify-roots.sh)"
fi
echo ""

while IFS= read -r line; do
  WT_PATH=$(echo "$line" | awk '{print $1}')
  WT_BRANCH=$(echo "$line" | awk '{print $3}' | tr -d '[]')

  # Skip main worktree
  if [ "$WT_PATH" = "$PROJECT_ROOT" ]; then
    continue
  fi

  # Check last modification time of any file in the worktree
  LAST_MOD=$(find "$WT_PATH" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/target/*' \
    -exec stat -f %m {} + 2>/dev/null \
    | sort -rn \
    | head -1 \
    || echo 0)

  if [ "$LAST_MOD" -eq 0 ]; then
    info "Worktree: ${WT_PATH} (${WT_BRANCH}) — cannot determine age, skipping"
    continue
  fi

  AGE_DAYS=$(( (NOW_TS - LAST_MOD) / 86400 ))

  if [ "$AGE_DAYS" -ge "$STALE_AGE_DAYS" ]; then
    LAST_DATE=$(date -r "$LAST_MOD" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
    warn "STALE: ${WT_BRANCH} at ${WT_PATH} (last modified ${AGE_DAYS}d ago on ${LAST_DATE})"
    STALE_COUNT=$((STALE_COUNT + 1))

    if [ "$CLEAN" = true ]; then
      info "  -> Removing stale worktree: ${WT_BRANCH}"
      git -C "$PROJECT_ROOT" worktree remove --force "$WT_PATH" 2>/dev/null && \
        pass "  Removed worktree ${WT_BRANCH}" || \
        warn "  Failed to remove ${WT_PATH} (may have uncommitted changes)"
      git -C "$PROJECT_ROOT" branch -D "$WT_BRANCH" 2>/dev/null || true
      CLEANED_COUNT=$((CLEANED_COUNT + 1))
    fi
  else
    pass "OK: ${WT_BRANCH} (last modified ${AGE_DAYS}d ago)"
  fi
done <<< "$WT_LIST"

echo ""
info "Total worktrees: $(echo "$WT_LIST" | wc -l | tr -d ' ')"
info "Stale (>${STALE_AGE_DAYS}d): ${STALE_COUNT}"
info "Cleaned: ${CLEANED_COUNT}"
info "Outside single-root: ${OUTSIDE_ROOT_COUNT}"
echo ""

[ $STALE_COUNT -eq 0 ] && pass "No stale worktrees found" \
                       || warn "${STALE_COUNT} stale worktree(s) — consider --clean"
[ "$OUTSIDE_ROOT_COUNT" -gt 0 ] && EXIT_CODE=1
exit $EXIT_CODE
