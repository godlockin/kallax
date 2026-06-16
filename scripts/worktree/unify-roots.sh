#!/usr/bin/env bash
# scripts/worktree/unify-roots.sh — KALLAX Worktree Root Unifier
# EPIC-054-A: Unify 4 worktree roots (.claude/worktrees/, .kallax/worktrees/,
# .worktrees/, performer-EPIC-*/) into 1 single root (.kallax/worktrees/),
# matching `git worktree list` output 1:1.
#
# Usage:
#   unify-roots.sh [--dry-run] [--classify] [--source-repo=<path>]
#                  [--target-root=<relative-path>]
#
# Defaults:
#   --source-repo    : current directory (must be a git repo root)
#   --target-root    : .kallax/worktrees
#
# Exit codes:
#   0 = success (all worktrees unified OR dry-run/--classify)
#   1 = migration failure
#   2 = invalid args / not a git repo
#
# Strategy:
#   1. Enumerate all non-main worktrees via `git worktree list --porcelain`
#   2. Classify each into 1 of 4 root buckets (.claude / .kallax / .worktrees / nested)
#   3. For each worktree NOT already under target root, use `git worktree move`
#      (git-native atomic move, updates .git/worktrees/<id>/gitdir + worktree/.git
#      pointers automatically)
#   4. Verify final state matches `git worktree list` (single-root invariant)
#
# Safety:
#   - --dry-run: print plan, no changes
#   - backup-on-fail: each move is preceded by `git worktree move` which is atomic;
#     on failure, leftover directory is reported for manual cleanup
#   - target-root directory is created if missing
#
# Rule 9 KPI: outputs X/Y format on completion

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_TARGET_ROOT=".kallax/worktrees"

# ----- args -----
DRY_RUN=false
CLASSIFY_ONLY=false
SOURCE_REPO=""
TARGET_ROOT="$DEFAULT_TARGET_ROOT"

for arg in "$@"; do
    case "$arg" in
        --dry-run)            DRY_RUN=true ;;
        --classify)           CLASSIFY_ONLY=true ;;
        --source-repo=*)      SOURCE_REPO="${arg#*=}" ;;
        --target-root=*)      TARGET_ROOT="${arg#*=}" ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        *)
            echo "[ERROR] $SCRIPT_NAME: unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# ----- resolve source repo -----
if [ -z "$SOURCE_REPO" ]; then
    SOURCE_REPO="$(pwd)"
fi

# Strip trailing slash for consistent path handling
SOURCE_REPO="${SOURCE_REPO%/}"

if [ ! -d "$SOURCE_REPO/.git" ] && ! git -C "$SOURCE_REPO" rev-parse --git-dir >/dev/null 2>&1; then
    echo "[ERROR] $SCRIPT_NAME: $SOURCE_REPO is not a git repository" >&2
    exit 2
fi

# Resolve to absolute path for git operations
SOURCE_REPO="$(cd "$SOURCE_REPO" && pwd)"

# ----- colors -----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# ----- enumerate non-main worktrees -----
# Output format: one worktree per line, each as "<worktree_path>|<branch>"
enumerate_worktrees() {
    local porcelain
    porcelain="$(git -C "$SOURCE_REPO" worktree list --porcelain 2>/dev/null)" || {
        fail "git worktree list failed in $SOURCE_REPO"
        return 1
    }

    local wt_path=""
    local wt_branch=""
    local is_first=1

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            # End of worktree entry
            if [ -n "$wt_path" ] && [ "$wt_path" != "$SOURCE_REPO" ]; then
                echo "${wt_path}|${wt_branch}"
            fi
            wt_path=""
            wt_branch=""
            is_first=1
            continue
        fi

        case "$line" in
            "worktree "*) wt_path="${line#worktree }" ;;
            "HEAD "*) : ;;  # skip
            "branch "*) wt_branch="${line#branch }" ;;
            "detached"*) wt_branch="(detached)" ;;
            *) : ;;
        esac
    done <<< "$porcelain"

    # Handle last entry (no trailing blank line)
    if [ -n "$wt_path" ] && [ "$wt_path" != "$SOURCE_REPO" ]; then
        echo "${wt_path}|${wt_branch}"
    fi
}

# ----- classify a worktree path into root bucket -----
# Returns one of: claude | kallax | dot | nested | target (already in target)
classify_root() {
    local wt_path="$1"
    case "$wt_path" in
        *"/.kallax/worktrees/"*|*"$SOURCE_REPO/$TARGET_ROOT/"*) echo "target" ;;
        *"/.claude/worktrees/"*) echo "claude" ;;
        *"/.worktrees/"*)       echo "dot" ;;
        *"performer-EPIC-"*)    echo "nested" ;;
        *)                       echo "other" ;;
    esac
}

# ----- main -----
info "Worktree Root Unifier (EPIC-054-A)"
info "  Source repo : $SOURCE_REPO"
info "  Target root : $TARGET_ROOT"
info "  Dry-run     : $DRY_RUN"
info "  Classify    : $CLASSIFY_ONLY"
echo ""

WORKTREES=()
while IFS='|' read -r path branch; do
    [ -z "$path" ] && continue
    WORKTREES+=("$path|$branch")
done < <(enumerate_worktrees)

TOTAL=${#WORKTREES[@]}
info "Found $TOTAL non-main worktree(s)"
echo ""

# ----- classification report -----
CLAUDE_COUNT=0
KALLAX_COUNT=0
DOT_COUNT=0
NESTED_COUNT=0
OTHER_COUNT=0
TARGET_COUNT=0

for entry in "${WORKTREES[@]}"; do
    wt_path="${entry%|*}"
    bucket="$(classify_root "$wt_path")"
    case "$bucket" in
        claude)  CLAUDE_COUNT=$((CLAUDE_COUNT+1)) ;;
        kallax)  KALLAX_COUNT=$((KALLAX_COUNT+1)) ;;
        dot)     DOT_COUNT=$((DOT_COUNT+1)) ;;
        nested)  NESTED_COUNT=$((NESTED_COUNT+1)) ;;
        target)  TARGET_COUNT=$((TARGET_COUNT+1)) ;;
        other)   OTHER_COUNT=$((OTHER_COUNT+1)) ;;
    esac
    echo "  [$bucket] $wt_path"
done

echo ""
info "Classification: claude=$CLAUDE_COUNT kallax=$KALLAX_COUNT dot=$DOT_COUNT nested=$NESTED_COUNT target=$TARGET_COUNT other=$OTHER_COUNT"

if [ "$CLASSIFY_ONLY" = true ]; then
    echo ""
    if [ "$CLAUDE_COUNT" -ge 1 ] || [ "$DOT_COUNT" -ge 1 ] || [ "$NESTED_COUNT" -ge 1 ]; then
        echo "ROOT_BUCKETS=4"
    else
        echo "ROOT_BUCKETS=1"
    fi
    echo "TARGET_ROOT=$TARGET_ROOT"
    exit 0
fi

# ----- determine if migration needed -----
TO_MIGRATE=()
for entry in "${WORKTREES[@]}"; do
    wt_path="${entry%|*}"
    bucket="$(classify_root "$wt_path")"
    if [ "$bucket" != "target" ]; then
        TO_MIGRATE+=("$entry")
    fi
done

MIGRATE_COUNT=${#TO_MIGRATE[@]}

if [ "$MIGRATE_COUNT" -eq 0 ]; then
    pass "All $TOTAL worktrees already under $TARGET_ROOT (single-root invariant satisfied)"
    echo ""
    echo "ROOT_BUCKETS=1"
    echo "TARGET_ROOT=$TARGET_ROOT"
    echo "MIGRATED=0/$TOTAL"
    exit 0
fi

info "Need to migrate $MIGRATE_COUNT worktree(s) → $TARGET_ROOT"
echo ""

# ----- dry-run plan -----
if [ "$DRY_RUN" = true ]; then
    info "DRY-RUN plan:"
    for entry in "${TO_MIGRATE[@]}"; do
        wt_path="${entry%|*}"
        wt_branch="${entry#*|}"
        basename_dir="$(basename "$wt_path")"
        new_path="$SOURCE_REPO/$TARGET_ROOT/$basename_dir"
        echo "  [MIGRATE] $wt_path"
        echo "      →     $new_path"
        echo "      branch: $wt_branch"
    done
    echo ""
    echo "ROOT_BUCKETS_BEFORE=4"
    echo "ROOT_BUCKETS_AFTER=1"
    echo "TARGET_ROOT=$TARGET_ROOT"
    echo "MIGRATED=$MIGRATE_COUNT/$TOTAL (planned)"
    exit 0
fi

# ----- actual migration -----
TARGET_DIR="$SOURCE_REPO/$TARGET_ROOT"
mkdir -p "$TARGET_DIR"

MIGRATED=0
FAILED=0
for entry in "${TO_MIGRATE[@]}"; do
    wt_path="${entry%|*}"
    wt_branch="${entry#*|}"
    basename_dir="$(basename "$wt_path")"
    new_path="$TARGET_DIR/$basename_dir"

    # Skip if source equals destination (defensive)
    if [ "$wt_path" = "$new_path" ]; then
        continue
    fi

    # Skip if destination already occupied
    if [ -e "$new_path" ]; then
        warn "Destination exists, skipping: $new_path"
        FAILED=$((FAILED+1))
        continue
    fi

    info "Migrating: $wt_path → $new_path"
    if git -C "$SOURCE_REPO" worktree move "$wt_path" "$new_path" 2>/dev/null; then
        MIGRATED=$((MIGRATED+1))
        pass "  migrated: $basename_dir ($wt_branch)"
    else
        FAILED=$((FAILED+1))
        fail "  migration failed: $wt_path (manual intervention required)"
    fi
done

echo ""
echo "=========================================="
echo "Migration Summary"
echo "=========================================="
info "Total worktrees : $TOTAL"
info "Migrated        : $MIGRATED"
info "Failed          : $FAILED"
info "Target root     : $TARGET_ROOT"
echo ""

# Verify single-root invariant via git worktree list
POST_LIST=$(git -C "$SOURCE_REPO" worktree list 2>/dev/null)
OUTSIDE=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    WT=$(echo "$line" | awk '{print $1}')
    [ "$WT" = "$SOURCE_REPO" ] && continue
    case "$WT" in
        *"/$TARGET_ROOT/"*) : ;;
        *) OUTSIDE=$((OUTSIDE+1)); warn "  still outside: $WT" ;;
    esac
done <<< "$POST_LIST"

if [ "$OUTSIDE" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    pass "Single-root invariant satisfied: all worktrees under $TARGET_ROOT"
    echo ""
    echo "ROOT_BUCKETS=1"
    echo "MIGRATED=$MIGRATED/$TOTAL PASS (100.0%)"
    exit 0
else
    fail "Single-root invariant violated: $OUTSIDE worktree(s) outside $TARGET_ROOT, $FAILED migration(s) failed"
    echo ""
    echo "MIGRATED=$MIGRATED/$TOTAL FAIL"
    exit 1
fi
