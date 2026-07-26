#!/usr/bin/env bash
# KALLAX Git Hooks Installer (EPIC-137-B)
#
# Points git at .githooks/ (repo-tracked) instead of .git/hooks/ (per-clone).
# Idempotent: safe to run repeatedly. `kallax init` calls this.
#
# Installs whatever hooks live in .githooks/:
#   - pre-commit          (EPIC-131-B dead-code sentinel)
#   - prepare-commit-msg  (EPIC-137-B DCO trailer auto-append)
#   - ...any future hooks

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="${REPO_ROOT}/.githooks"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "ERROR: $HOOKS_DIR does not exist" >&2
  exit 1
fi

# Point git at .githooks/ (idempotent — git config sets, not appends)
git config core.hooksPath .githooks

# Ensure every hook file is executable (idempotent — chmod +x is no-op if
# already +x). Hidden files (dotfiles) skipped.
count=0
for hook in "$HOOKS_DIR"/*; do
  [ -f "$hook" ] || continue
  case "$(basename "$hook")" in
    .*) continue ;;
    *.md) continue ;;
  esac
  if [ ! -x "$hook" ]; then
    chmod +x "$hook"
  fi
  count=$((count + 1))
done

echo "hooks installed: $count"
