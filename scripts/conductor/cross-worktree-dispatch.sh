#!/usr/bin/env bash
# scripts/conductor/cross-worktree-dispatch.sh — Cross-worktree commit dispatch
#
# Modes:
#   cherry-pick (default) — auto cherry-pick source commits not in target,
#                            STOP + non-zero exit on conflict (no auto-merge)
#   dry-run               — report would-be cherry-picks, no changes
#   list                  — list branches / commits available to dispatch
#
# Usage:
#   cross-worktree-dispatch.sh --source <path> --target <path> [--mode cherry-pick|dry-run|list]
#   cross-worktree-dispatch.sh --help
#
# Source: EPIC-036-A ticket.json AC
# Rule 9e: Performer self-verifies via stdout (L1 file present, L2 real logic, L3 wired, L4 working).

set -uo pipefail

SOURCE=""
TARGET=""
MODE="cherry-pick"

usage() {
  cat <<EOF
Usage: $0 --source <path> --target <path> [--mode cherry-pick|dry-run|list]
       $0 --help

Cross-worktree commit dispatch (auto cherry-pick + conflict STOP).

Options:
  --source <path>   Source git repo (worktree path) whose commits to dispatch.
  --target <path>   Target git repo (worktree path) to receive commits.
  --mode <mode>     cherry-pick (default) | dry-run | list.
  --help            Show this help.

Exit codes:
  0  success (cherry-pick clean / dry-run ok / list ok)
  1  invalid arguments
  2  source/target missing or invalid
  3  cherry-pick conflict — STOP, target untouched (no auto-merge)
  4  source == target
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --source)  SOURCE="${2:-}"; shift 2 ;;
    --target)  TARGET="${2:-}"; shift 2 ;;
    --mode)    MODE="${2:-cherry-pick}"; shift 2 ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Validate mode
case "$MODE" in
  cherry-pick|dry-run|list) ;;
  *) echo "ERROR: invalid mode '$MODE' (must be cherry-pick|dry-run|list)" >&2; exit 1 ;;
esac

# list mode only needs --source
if [[ "$MODE" == "list" ]]; then
  if [[ -z "$SOURCE" ]]; then
    echo "ERROR: list mode requires --source" >&2; exit 1
  fi
  if [[ ! -d "$SOURCE/.git" ]] && [[ ! -f "$SOURCE/.git" ]]; then
    echo "ERROR: --source '$SOURCE' is not a git repo" >&2; exit 2
  fi
  echo "LIST: source=$SOURCE"
  echo "Branches:"
  git -C "$SOURCE" branch -a 2>/dev/null | sed 's/^/  /'
  echo "Recent commits (HEAD..HEAD~5):"
  git -C "$SOURCE" log --oneline -5 2>/dev/null | sed 's/^/  /'
  exit 0
fi

# cherry-pick / dry-run require both source + target
if [[ -z "$SOURCE" ]] || [[ -z "$TARGET" ]]; then
  echo "ERROR: --source and --target required (mode=$MODE)" >&2; usage >&2; exit 1
fi
if [[ ! -d "$SOURCE/.git" ]] && [[ ! -f "$SOURCE/.git" ]]; then
  echo "ERROR: --source '$SOURCE' is not a git repo" >&2; exit 2
fi
if [[ ! -d "$TARGET/.git" ]] && [[ ! -f "$TARGET/.git" ]]; then
  echo "ERROR: --target '$TARGET' is not a git repo" >&2; exit 2
fi
if [[ "$SOURCE" == "$TARGET" ]]; then
  echo "ERROR: source == target (no-op rejected)" >&2; exit 4
fi

# Compute commits in source not in target.
# Use FETCH_HEAD or fallback: compare refs directly.
# For local worktree repos, both share .git directory often — instead, we compare
# source's branch tip vs target's branch tip.
SRC_BRANCH=$(git -C "$SOURCE" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
TGT_BRANCH=$(git -C "$TARGET" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
SRC_TIP=$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null || echo "")
TGT_TIP=$(git -C "$TARGET" rev-parse HEAD 2>/dev/null || echo "")

if [[ -z "$SRC_TIP" ]] || [[ -z "$TGT_TIP" ]]; then
  echo "ERROR: cannot resolve HEAD in source or target" >&2; exit 2
fi

# Commits reachable from source tip but not from target tip (ancestor-only check).
# If source is ancestor of target, nothing to dispatch.
if git -C "$TARGET" merge-base --is-ancestor "$SRC_TIP" "$TGT_TIP" 2>/dev/null; then
  echo "DISPATCH: source already in target (nothing to do). source=$SOURCE($$SRC_BRANCH@$SRC_TIP) target=$TARGET($TGT_BRANCH@$TGT_TIP)"
  exit 0
fi

# Find commits in source not in target.
# Strategy: list commits reachable from SRC_TIP, excluding those reachable from TGT_TIP.
PENDING=$(git -C "$SOURCE" log --reverse --pretty=format:%H "$TGT_TIP..$SRC_TIP" 2>/dev/null || true)
COUNT=$(echo -n "$PENDING" | grep -c . || true)

if [[ -z "$PENDING" ]] || [[ "$COUNT" -eq 0 ]]; then
  echo "DISPATCH: no pending commits to cherry-pick. source=$SRC_TIP target=$TGT_TIP"
  exit 0
fi

echo "DISPATCH: source=$SOURCE($$SRC_BRANCH@$SRC_TIP) target=$TARGET($TGT_BRANCH@$TGT_TIP) mode=$MODE pending=$COUNT"

if [[ "$MODE" == "dry-run" ]]; then
  echo "DRY-RUN: would cherry-pick $COUNT commits:"
  echo "$PENDING" | while read -r sha; do
    [[ -n "$sha" ]] && git -C "$SOURCE" log -1 --pretty=format:"  %h %s%n" "$sha"
  done
  echo "DRY-RUN: no changes applied"
  exit 0
fi

# cherry-pick mode: walk commits in reverse order, abort on first conflict.
# Save target HEAD to allow rollback verification.
ORIG_TGT_TIP="$TGT_TIP"

# Apply each commit. If a commit fails (conflict or non-cherry), abort and report.
APPLIED=0
FAILED_SHA=""
FAILED_MSG=""

for sha in $PENDING; do
  [[ -z "$sha" ]] && continue
  echo "  cherry-pick $sha: $(git -C "$SOURCE" log -1 --pretty=%s "$sha")"

  # Attempt cherry-pick. -x adds source ref to message; --no-commit lets us inspect.
  # Use single-commit cherry-pick with --no-edit to keep messages.
  if git -C "$TARGET" cherry-pick --no-commit -x "$sha" >/dev/null 2>&1; then
    # Commit it (no-ff to keep cherry-pick marker).
    if git -C "$TARGET" commit --no-edit -q 2>/dev/null; then
      APPLIED=$((APPLIED + 1))
      echo "    → applied"
    else
      FAILED_SHA="$sha"
      FAILED_MSG="commit failed after cherry-pick (stage state)"
      git -C "$TARGET" cherry-pick --abort 2>/dev/null || true
      break
    fi
  else
    # Conflict or non-cherry-pickable commit.
    if git -C "$TARGET" status --porcelain 2>/dev/null | grep -qE "^(UU|AA|DD)"; then
      FAILED_SHA="$sha"
      FAILED_MSG="cherry-pick conflict (unmerged paths)"
    else
      FAILED_SHA="$sha"
      FAILED_MSG="cherry-pick rejected (merge commit or empty)"
    fi
    git -C "$TARGET" cherry-pick --abort 2>/dev/null || true
    break
  fi
done

NEW_TGT_TIP=$(git -C "$TARGET" rev-parse HEAD 2>/dev/null || echo "")

if [[ -n "$FAILED_SHA" ]]; then
  echo "STOP: cherry-pick conflict/abort." >&2
  echo "  failed commit: $FAILED_SHA" >&2
  echo "  reason:        $FAILED_MSG" >&2
  echo "  applied before fail: $APPLIED / $COUNT" >&2
  echo "  target HEAD:   $ORIG_TGT_TIP (rolled back to before dispatch)" >&2
  echo "  current HEAD:  $NEW_TGT_TIP" >&2
  # Roll back any partial applies so target HEAD == ORIGINAL.
  if [[ "$NEW_TGT_TIP" != "$ORIG_TGT_TIP" ]] && [[ -n "$NEW_TGT_TIP" ]]; then
    echo "  rolling back partial applies..." >&2
    git -C "$TARGET" reset --hard "$ORIG_TGT_TIP" >/dev/null 2>&1 || true
  fi
  echo "ACTION: manual conflict resolution required. Do NOT auto-merge." >&2
  exit 3
fi

echo "DISPATCH: applied $APPLIED / $COUNT commits. target=$TGT_TIP -> $(git -C "$TARGET" rev-parse HEAD 2>/dev/null)"
exit 0
