#!/usr/bin/env bash
# KALLAX Merged Branch Cleanup — remove local branches merged into main
# Usage: ./scripts/cleanup-merged-branches.sh [--dry-run] [--exclude "branch1 branch2"]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=false
EXCLUDE_PATTERNS="main master develop"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --exclude=*) EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS} ${arg#*=}" ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=== KALLAX Merged Branch Cleanup ==="
echo "  Dry run: ${DRY_RUN}"
echo "  Excluded patterns: ${EXCLUDE_PATTERNS}"
echo ""

# Determine main branch
MAIN_BRANCH="main"
if ! git -C "$PROJECT_ROOT" rev-parse --verify "$MAIN_BRANCH" &>/dev/null 2>&1; then
  MAIN_BRANCH="master"
fi
info "Base branch: ${MAIN_BRANCH}"

# Fetch latest remote state
git -C "$PROJECT_ROOT" fetch origin --prune 2>/dev/null || warn "git fetch failed"

# Find merged branches (excluding protected ones)
MERGED_BRANCHES=$(git -C "$PROJECT_ROOT" branch --merged "$MAIN_BRANCH" 2>/dev/null \
  | grep -v "^\*" \
  | tr -d ' ' \
  || true)

DELETED_COUNT=0

if [ -z "$MERGED_BRANCHES" ]; then
  info "No merged branches found"
else
  echo "$MERGED_BRANCHES" | while read -r branch; do
    # Skip excluded patterns
    SKIP=false
    for exclude in $EXCLUDE_PATTERNS; do
      if [ "$branch" = "$exclude" ]; then
        SKIP=true
        break
      fi
    done
    [ "$SKIP" = true ] && continue

    # Skip if branch is a remote tracking ref ($branch contains /)
    if echo "$branch" | grep -q "/"; then
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      info "[DRY RUN] Would delete merged branch: ${branch}"
    else
      git -C "$PROJECT_ROOT" branch -d "$branch" 2>/dev/null && \
        pass "Deleted merged branch: ${branch}" || \
        warn "Failed to delete: ${branch}"
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done

  # Also prune remote tracking branches that no longer exist
  if [ "$DRY_RUN" = false ]; then
    git -C "$PROJECT_ROOT" remote prune origin 2>/dev/null || true
    pass "Pruned stale remote tracking refs"
  fi
fi

echo ""
[ "$DRY_RUN" = true ] && info "Dry run — no branches actually deleted"
info "Deleted: ${DELETED_COUNT} branch(es)"
echo ""
pass "Branch cleanup complete"
