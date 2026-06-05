#!/usr/bin/env bash
# KALLAX Branch: Create PR: testing → miao (Request Release)
# Conductor creates the PR. Master reviews and approves.
# Usage: ./scripts/branch-promote.sh [--emergency] [--dry-run]
set -euo pipefail

DRY_RUN="${1:-}"
EMERGENCY="${2:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"
START_TIME=$(date +%s)

echo "=========================================="
echo " KALLAX Request Release: testing → miao"
echo "=========================================="

# ── Pre-flight ──────────────────────────────────────────────────────────

echo ""
echo "── Step 1/5: Pre-flight ──"

CURRENT_BRANCH="$(git branch --show-current)"
git fetch origin testing miao 2>/dev/null || true

COMMITS_AHEAD=$(git rev-list --count "miao..testing" 2>/dev/null || echo 0)
if [ "$COMMITS_AHEAD" -eq 0 ]; then
  echo -e "${RED}BLOCKED:${NC} testing has no changes to release"
  exit 1
fi
echo "  ✓ testing is ${COMMITS_AHEAD} commits ahead of miao"

# Ensure testing is pushed
if ! git branch -r | grep -q 'origin/testing' 2>/dev/null; then
  echo "  pushing testing to origin..."
  git push -u origin testing 2>/dev/null || true
fi
echo "  ✓ testing is on remote"

# ── Gate: Conductor Role Check ──────────────────────────────────────────

echo ""
echo "── Step 2/5: Role Check ──"

ROLE_FILE=".kallax/state/instance_config.yml"
ROLE="unknown"
if [ -f "$ROLE_FILE" ]; then
  ROLE=$(grep -E '^\s*role:' "$ROLE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")
fi

if [ "$ROLE" != "conductor" ] && [ "$ROLE" != "master" ]; then
  echo -e "${RED}BLOCKED:${NC} only Conductor or Master can request a release"
  echo "  Current role: ${ROLE}"
  echo "  Run /kallax-start to set your role."
  exit 1
fi
echo "  ✓ role: ${ROLE}"

# ── Change Summary ───────────────────────────────────────────────────────

echo ""
echo "── Step 3/5: Release Summary ──"

echo "  Commits to release:"
git log --oneline "miao..testing" | head -10
echo ""
FILES_CHANGED=$(git diff --name-only "miao..testing" 2>/dev/null | wc -l | tr -d ' ')
echo "  Files changed: ${FILES_CHANGED}"

# ── Expert Panel Gate (unless emergency) ─────────────────────────────────

if [ "$EMERGENCY" != "--emergency" ]; then
  echo ""
  echo "── Step 4/5: Expert Panel Approval ──"
  echo "  Required sign-offs before release:"
  echo "    [ ] Product Manager   — functional completeness"
  echo "    [ ] Test/QA Engineer  — integration tests pass"
  echo "    [ ] Architect         — system impact OK"
  echo ""
  read -p "  Have ALL experts approved? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}BLOCKED:${NC} expert approval required. Run /kallax-panel first."
    exit 1
  fi
  echo -e "  ${GREEN}✓${NC} expert panel approved"
else
  echo ""
  echo "── Step 4/5: Expert Panel ──"
  echo -e "  ${YELLOW}EMERGENCY MODE${NC} — bypassing expert panel"
fi

# ── Create PR ────────────────────────────────────────────────────────────

echo ""
echo "── Step 5/5: Create Release PR ──"

PR_TITLE="Release: testing → miao ($(date +%Y-%m-%d))"
PR_BODY=$(cat <<BODY
## Release Request: testing → miao

**Created by:** ${ROLE}
**Date:** $(date '+%Y-%m-%d %H:%M')
**Commits:** ${COMMITS_AHEAD}
**Files changed:** ${FILES_CHANGED}

### Changes

$(git log --oneline "miao..testing" | sed 's/^/- /')

### Approval Required

- [ ] Master review
- [ ] CI checks pass
- [ ] No regressions

### Expert Panel
$(if [ "$EMERGENCY" = "--emergency" ]; then echo "- ⚠️ EMERGENCY RELEASE (expert panel bypassed)"; else echo "- ✅ Expert panel approved"; fi)

---
🤖 Generated with [KALLAX](https://github.com/godlockin/kallax) branch pipeline
BODY
)

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo -e "  ${YELLOW}DRY RUN${NC} — would create PR:"
  echo "  Title: ${PR_TITLE}"
  echo "  Base: miao ← Head: testing"
else
  # Check if gh CLI is available
  if ! command -v gh &> /dev/null; then
    echo -e "${RED}ERROR:${NC} GitHub CLI (gh) not found. Install with: brew install gh"
    echo "  Then: gh auth login"
    exit 1
  fi

  # Check for existing PR
  EXISTING_PR=$(gh pr list --base miao --head testing --json number --jq '.[0].number' 2>/dev/null || echo "")
  if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
    echo -e "  ${YELLOW}⚠${NC} PR #${EXISTING_PR} already exists: testing → miao"
    gh pr view "$EXISTING_PR" --web 2>/dev/null || true
    echo "  Updated existing PR"
  else
    gh pr create \
      --base miao \
      --head testing \
      --title "${PR_TITLE}" \
      --body "${PR_BODY}" \
      --label "release"
    echo -e "  ${GREEN}✓${NC} PR created: testing → miao"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────

ELAPSED=$(($(date +%s) - START_TIME))
echo ""
echo "=========================================="
echo " Release PR Created"
echo "=========================================="
echo ""
echo "  From:    testing"
echo "  To:      miao"
echo "  Commits: ${COMMITS_AHEAD}"
echo "  Time:    ${ELAPSED}s"
echo ""
echo "Next steps:"
echo "  1. Master reviews the PR"
echo "  2. Master approves and merges"
echo "  3. Master tags the release"
echo ""
