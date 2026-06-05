#!/usr/bin/env bash
# KALLAX Branch Strategy: Merge feature → testing
# Usage: ./scripts/branch-merge-epic.sh <feature-name> [--skip-tests] [--dry-run]
# Merges feature/<name> into testing, runs integration/E2E tests, reports readiness.
set -euo pipefail

FEATURE_NAME="${1:-}"
SKIP_TESTS="${2:-}"
DRY_RUN="${3:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$FEATURE_NAME" ]; then
  echo "Usage: branch-merge-epic.sh <feature-name> [--skip-tests] [--dry-run]"
  echo "  Merges feature/<name> → testing, runs validation, reports status."
  exit 1
fi

BRANCH="feature/${FEATURE_NAME}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
START_TIME=$(date +%s)

echo "=========================================="
echo " KALLAX EPIC Merge: ${BRANCH} → testing"
echo "=========================================="

# ── Pre-flight Checks ──────────────────────────────────────────────────

echo ""
echo "── Step 1/6: Pre-flight Checks ──"

# 1a. Verify feature branch exists
if ! git branch -a | grep -qE "${BRANCH}$"; then
  echo -e "${RED}FAIL:${NC} branch ${BRANCH} does not exist"
  echo "  Available feature branches:"
  git branch -a | grep 'feature/' | sed 's/.*feature\//  feature\//'
  exit 1
fi
echo "  ✓ feature branch exists"

# 1b. Check for uncommitted changes on feature
FEATURE_UNCOMMITTED=$(git diff --name-only "${BRANCH}" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FEATURE_UNCOMMITTED" -gt 0 ]; then
  echo -e "${RED}FAIL:${NC} ${BRANCH} has ${FEATURE_UNCOMMITTED} uncommitted files"
  git diff --name-only "${BRANCH}" | head -10
  exit 1
fi
echo "  ✓ no uncommitted changes"

# 1c. Verify testing branch exists
if ! git branch -a | grep -qE 'testing$'; then
  echo "  Creating testing branch from miao..."
  git branch testing miao
fi
echo "  ✓ testing branch exists"

# 1d. Check if feature has been pushed to remote
if git branch -r | grep -qE "origin/${BRANCH}$" 2>/dev/null; then
  echo "  ✓ feature is pushed to origin"
else
  echo -e "  ${YELLOW}⚠${NC} feature not pushed to origin (local only)"
fi

# ── Diff Summary ───────────────────────────────────────────────────────

echo ""
echo "── Step 2/6: Change Summary ──"

# Compare feature vs miao (what changed in this EPIC)
COMMITS_AHEAD=$(git rev-list --count "miao..${BRANCH}" 2>/dev/null || echo 0)
FILES_CHANGED=$(git diff --name-only "miao..${BRANCH}" 2>/dev/null | wc -l | tr -d ' ')
echo "  commits ahead of miao: ${COMMITS_AHEAD}"
echo "  files changed:         ${FILES_CHANGED}"

if [ "$FILES_CHANGED" -eq 0 ]; then
  echo -e "${YELLOW}WARNING:${NC} no files changed between miao and ${BRANCH}"
  echo "  This might mean the feature branch has already been merged or is empty."
  read -p "  Continue? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

# Show changed file categories
echo "  by category:"
git diff --name-only "miao..${BRANCH}" 2>/dev/null | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -10 | while read -r count dir; do
  echo "    ${count} files in ${dir}/"
done

# ── Merge Feature → Testing ────────────────────────────────────────────

echo ""
echo "── Step 3/6: Merge ${BRANCH} → testing ──"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo -e "  ${YELLOW}DRY RUN${NC} — would merge ${BRANCH} → testing"
else
  CURRENT_BRANCH="$(git branch --show-current)"

  # Save current work
  git checkout testing
  echo "  switched to testing"

  # Merge feature into testing
  if git merge --no-ff "${BRANCH}" -m "merge: ${BRANCH} → testing

EPIC merge: integrating feature/${FEATURE_NAME} into testing for integration validation.

Co-Authored-By: KALLAX Branch Pipeline <noreply@kallax.dev>"; then
    echo -e "  ${GREEN}✓${NC} merge successful"
  else
    echo -e "${RED}FAIL:${NC} merge conflict detected"
    echo "  Conflicting files:"
    git diff --name-only --diff-filter=U | head -20
    echo ""
    echo "  Resolve conflicts manually, then:"
    echo "    git add . && git commit -m 'merge: resolve conflicts for ${BRANCH} → testing'"

    # Go back to original branch
    git checkout "${CURRENT_BRANCH}" 2>/dev/null || true
    exit 1
  fi
fi

# ── Run Tests ──────────────────────────────────────────────────────────

echo ""
echo "── Step 4/6: Integration Tests ──"

if [ "$SKIP_TESTS" = "--skip-tests" ]; then
  echo -e "  ${YELLOW}SKIPPED${NC} (--skip-tests flag)"
elif [ "$DRY_RUN" = "--dry-run" ]; then
  echo -e "  ${YELLOW}DRY RUN${NC} — would run: npm test && npm run test:e2e"
else
  # Run Node.js tests
  if [ -f "${REPO_ROOT}/node/package.json" ]; then
    echo "  running Node.js unit tests..."
    cd "${REPO_ROOT}/node"
    if npx vitest run --reporter=basic 2>&1 | tail -5; then
      echo -e "  ${GREEN}✓${NC} unit tests passed"
    else
      echo -e "  ${RED}FAIL:${NC} unit tests failed"
      echo "  rolling back merge..."
      git reset --hard HEAD~1 2>/dev/null || true
      git checkout "${CURRENT_BRANCH}" 2>/dev/null || true
      exit 1
    fi
    cd "${REPO_ROOT}"
  fi

  # Run Rust tests
  if [ -f "${REPO_ROOT}/rust/Cargo.toml" ]; then
    echo "  running Rust tests..."
    cd "${REPO_ROOT}/rust"
    if cargo test 2>&1 | tail -5; then
      echo -e "  ${GREEN}✓${NC} Rust tests passed"
    else
      echo -e "  ${RED}FAIL:${NC} Rust tests failed"
      echo "  rolling back merge..."
      git reset --hard HEAD~1 2>/dev/null || true
      git checkout "${CURRENT_BRANCH}" 2>/dev/null || true
      exit 1
    fi
    cd "${REPO_ROOT}"
  fi
fi

# ── Push testing ───────────────────────────────────────────────────────

echo ""
echo "── Step 5/6: Push testing ──"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo -e "  ${YELLOW}DRY RUN${NC} — would push testing to origin"
else
  git push origin testing 2>/dev/null && echo "  ✓ testing pushed to origin" || echo -e "  ${YELLOW}⚠${NC} push failed (no remote?)"
fi

# ── Summary ────────────────────────────────────────────────────────────

ELAPSED=$(($(date +%s) - START_TIME))

echo ""
echo "── Step 6/6: Merge Complete ──"
echo ""
echo "  Feature:  ${BRANCH}"
echo "  Target:   testing"
echo "  Commits:  ${COMMITS_AHEAD}"
echo "  Files:    ${FILES_CHANGED}"
echo "  Duration: ${ELAPSED}s"
echo "  Status:   ${GREEN}READY FOR REVIEW${NC}"
echo ""
echo "Next steps:"
echo "  1. Product manager reviews functional completeness"
echo "  2. QA/Test engineer runs integration test suite"
echo "  3. Architect reviews system impact"
echo "  4. If approved: ./scripts/branch-promote.sh"
echo "  5. If rejected: fix issues in feature/${FEATURE_NAME}, re-run this script"
echo ""

# Return to feature branch if we were on it
if [ "$DRY_RUN" != "--dry-run" ]; then
  git checkout "${BRANCH}" 2>/dev/null || git checkout miao
fi
