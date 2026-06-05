#!/usr/bin/env bash
# KALLAX Branch: Create feature worktree
# Usage: ./scripts/branch-feature.sh <feature-name> [--skip-worktree]
# Creates feature/<name> from miao, sets performer role, installs hooks.
set -euo pipefail

FEATURE_NAME="${1:-}"
SKIP_WORKTREE="${2:-}"

if [ -z "$FEATURE_NAME" ]; then
  echo "Usage: branch-feature.sh <feature-name> [--skip-worktree]"
  echo "  feature-name: kebab-case (e.g., epic-008-workflow)"
  exit 1
fi

if ! echo "$FEATURE_NAME" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "ERROR: feature name must be kebab-case (e.g., epic-008-workflow)"
  exit 1
fi

BRANCH="feature/${FEATURE_NAME}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "==> KALLAX Feature Branch: ${BRANCH}"

git fetch origin miao 2>/dev/null || true

if git branch -a | grep -qE "feature/${FEATURE_NAME}$"; then
  echo "WARNING: branch ${BRANCH} already exists"
  read -p "Force recreate? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "aborted."; exit 0
  fi
  git branch -D "${BRANCH}" 2>/dev/null || true
fi

git branch "${BRANCH}" miao
echo "Created: ${BRANCH}"

if [ "$SKIP_WORKTREE" != "--skip-worktree" ]; then
  WORKTREE_PATH="${REPO_ROOT}/.claude/worktrees/feature-${FEATURE_NAME}"
  if [ -d "$WORKTREE_PATH" ]; then
    git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || rm -rf "$WORKTREE_PATH"
  fi
  git worktree add "$WORKTREE_PATH" "${BRANCH}"
  echo "Worktree: ${WORKTREE_PATH}"

  # Auto-set performer role in the worktree
  KALLAX_STATE="${WORKTREE_PATH}/.kallax/state"
  if [ -d "$KALLAX_STATE" ]; then
    sed -i '' 's/role:.*/role: performer/' "${KALLAX_STATE}/instance_config.yml" 2>/dev/null || true
    echo "  role set to: performer"
  fi

  # Install hooks in the main repo
  if [ -f "${REPO_ROOT}/scripts/hooks/install.sh" ]; then
    bash "${REPO_ROOT}/scripts/hooks/install.sh" 2>/dev/null || true
  fi

  echo ""
  echo "To start working as Performer:"
  echo "  cd ${WORKTREE_PATH}"
  echo ""
  echo "Pipeline: feature/${FEATURE_NAME} → testing → miao"
fi
