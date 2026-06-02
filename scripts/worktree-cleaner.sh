#!/usr/bin/env bash
# KALLAX Worktree Cleaner — removes stale/prunable worktrees
# Safe: only removes worktrees with "prunable" marker or kallax/ branches
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
DRY_RUN="${2:-false}"

echo "=== KALLAX Worktree Cleaner ==="
echo ""

# List all worktrees
WT_LIST=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null)
STALE_COUNT=0
CLEANED_COUNT=0

while IFS= read -r line; do
  WT_PATH=$(echo "$line" | awk '{print $1}')
  WT_BRANCH=$(echo "$line" | awk '{print $3}' | tr -d '[]')

  # Skip main worktree (the project root itself)
  if [ "$WT_PATH" = "$PROJECT_ROOT" ]; then
    continue
  fi

  # Check if it's a KALLAX worktree (branch name starts with "kallax/")
  if echo "$WT_BRANCH" | grep -q "^kallax/"; then
    TASK_ID=$(echo "$WT_BRANCH" | sed 's/kallax\///')

    # Check if task is completed
    if [ -f "${PROJECT_ROOT}/.kallax/state/instance_config.yml" ]; then
      echo "  KALLAX worktree: $WT_PATH (task: $TASK_ID)"
      echo "    Branch: $WT_BRANCH"

      if [ "$DRY_RUN" = "true" ]; then
        echo "    [DRY RUN] Would remove"
        CLEANED_COUNT=$((CLEANED_COUNT + 1))
      else
        read -r -p "    Remove? [y/N]: " CONFIRM
        if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
          git -C "$PROJECT_ROOT" worktree remove --force "$WT_PATH" 2>/dev/null || true
          git -C "$PROJECT_ROOT" branch -D "$WT_BRANCH" 2>/dev/null || true
          echo "    Removed"
          CLEANED_COUNT=$((CLEANED_COUNT + 1))
        else
          echo "    Skipped"
        fi
      fi
    fi
  elif echo "$line" | grep -q "prunable"; then
    echo "  Prunable worktree: $WT_PATH"
    echo "    (leftover from previous cleanup)"
    if [ "$DRY_RUN" != "true" ]; then
      git -C "$PROJECT_ROOT" worktree prune 2>/dev/null || true
    fi
    CLEANED_COUNT=$((CLEANED_COUNT + 1))
    STALE_COUNT=$((STALE_COUNT + 1))
  fi
done <<< "$WT_LIST"

echo ""
echo "Stale/prunable: $STALE_COUNT"
echo "Cleaned: $CLEANED_COUNT"
echo ""
echo "Tip: Run with 'dry-run' to preview: scripts/worktree-cleaner.sh . true"
