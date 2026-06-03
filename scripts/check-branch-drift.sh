#!/usr/bin/env bash
# KALLAX Branch Drift Check — detect feature branches far behind main
# Usage: ./scripts/check-branch-drift.sh [branch] [--threshold 50]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THRESHOLD=50
TARGET_BRANCH="${1:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

EXIT_CODE=0

# Parse --threshold flag
for arg in "$@"; do
  case "$arg" in
    --threshold=*) THRESHOLD="${arg#*=}" ;;
  esac
done

echo "=== KALLAX Branch Drift Check ==="
echo "  Threshold: ${THRESHOLD} commits behind main"
echo ""

# Determine main branch
MAIN_BRANCH="main"
if ! git -C "$PROJECT_ROOT" rev-parse --verify "$MAIN_BRANCH" &>/dev/null 2>&1; then
  MAIN_BRANCH="master"
fi
pass "Base branch: ${MAIN_BRANCH}"

# If no branch specified, scan all branches
if [ -z "$TARGET_BRANCH" ]; then
  info "Scanning all local branches (excluding ${MAIN_BRANCH})..."

  git -C "$PROJECT_ROOT" fetch origin "$MAIN_BRANCH" 2>/dev/null || true

  git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' refs/heads/ \
    | grep -v "^${MAIN_BRANCH}$" \
    | while read -r branch; do

    BEHIND=$(git -C "$PROJECT_ROOT" rev-list --count "${MAIN_BRANCH}..${branch}" 2>/dev/null || echo 0)
    AHEAD=$(git -C "$PROJECT_ROOT" rev-list --count "${branch}..${MAIN_BRANCH}" 2>/dev/null || echo 0)

    if [ "$BEHIND" -gt "$THRESHOLD" ]; then
      warn "${branch}: ${BEHIND} commits behind ${MAIN_BRANCH} (threshold: ${THRESHOLD})"
    else
      pass "${branch}: ${BEHIND} behind, ${AHEAD} ahead"
    fi
  done
else
  info "Checking branch: ${TARGET_BRANCH}"

  git -C "$PROJECT_ROOT" fetch origin "$MAIN_BRANCH" 2>/dev/null || true

  if ! git -C "$PROJECT_ROOT" rev-parse --verify "$TARGET_BRANCH" &>/dev/null 2>&1; then
    fail "Branch '${TARGET_BRANCH}' does not exist"
    exit $EXIT_CODE
  fi

  BEHIND=$(git -C "$PROJECT_ROOT" rev-list --count "${MAIN_BRANCH}..${TARGET_BRANCH}" 2>/dev/null || echo 0)
  AHEAD=$(git -C "$PROJECT_ROOT" rev-list --count "${TARGET_BRANCH}..${MAIN_BRANCH}" 2>/dev/null || echo 0)

  LAST_COMMIT=$(git -C "$PROJECT_ROOT" log -1 --format='%ci' "$TARGET_BRANCH" 2>/dev/null || echo "unknown")
  echo "    Last commit: ${LAST_COMMIT}"

  if [ "$BEHIND" -gt "$THRESHOLD" ]; then
    fail "${TARGET_BRANCH} is ${BEHIND} commits behind ${MAIN_BRANCH} (threshold: ${THRESHOLD})"
    echo "    Recommendation: rebase onto ${MAIN_BRANCH}"
  else
    pass "${TARGET_BRANCH} is ${BEHIND} behind, ${AHEAD} ahead — within threshold"
  fi
fi

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}=== No drifting branches detected ===${NC}" \
                      || echo -e "${RED}=== Drift threshold exceeded ===${NC}"
exit $EXIT_CODE
