#!/bin/bash
# KALLAX Branch Synchronization Script
# Sync local branches with remote, cleanup stale branches
# Usage: ./scripts/sync-branches.sh [--prune] [--force] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Flags
PRUNE_MERGED=false
FORCE_SYNC=false
DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prune) PRUNE_MERGED=true; shift ;;
        --force) FORCE_SYNC=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--prune] [--force] [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --prune    Delete local branches merged to main"
            echo "  --force    Force update tracking branches"
            echo "  --dry-run  Show what would be done"
            echo "  --verbose  Show detailed output"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cd "$PROJECT_ROOT"

# Verify git repository
if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not a git repository"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  KALLAX Branch Synchronization"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_warn "DRY RUN MODE - No changes will be made"
    echo ""
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
log_info "Current branch: $CURRENT_BRANCH"

# Get default branch
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
log_info "Default branch: $DEFAULT_BRANCH"

# ============================================================
# Fetch all remotes
# ============================================================
log_info "Fetching from remotes..."

if [[ "$DRY_RUN" == false ]]; then
    git fetch --all --prune
fi

log_success "Remote data updated"
echo ""

# ============================================================
# Sync default branch
# ============================================================
log_info "Syncing $DEFAULT_BRANCH..."

if [[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
        git pull --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null || \
        log_warn "Cannot fast-forward $DEFAULT_BRANCH, manual merge may be needed"
    else
        echo "  Would pull $DEFAULT_BRANCH"
    fi
else
    # Update default branch without checkout
    if [[ "$DRY_RUN" == false ]]; then
        git fetch origin "$DEFAULT_BRANCH:$DEFAULT_BRANCH" 2>/dev/null || true
    else
        echo "  Would update $DEFAULT_BRANCH reference"
    fi
fi

# ============================================================
# Check tracking branches status
# ============================================================
echo ""
log_info "Checking branch status..."
echo ""

printf "%-40s %-15s %-10s %s\n" "BRANCH" "STATUS" "AHEAD/BEHIND" "TRACKING"
echo "────────────────────────────────────────────────────────────────────────────────"

git for-each-ref --format='%(refname:short) %(upstream:short) %(upstream:track)' refs/heads | \
while read -r local remote tracking; do
    if [[ -z "$remote" ]]; then
        status="no tracking"
        tracking_info="-"
        ahead_behind="-"
    else
        if git show-ref --verify --quiet "refs/remotes/$remote" 2>/dev/null; then
            # Extract ahead/behind from tracking info
            ahead_behind="$tracking"
            if [[ -z "$tracking" || "$tracking" == "" ]]; then
                status="up-to-date"
                ahead_behind="0/0"
            elif [[ "$tracking" == *"ahead"* && "$tracking" == *"behind"* ]]; then
                status="diverged"
            elif [[ "$tracking" == *"ahead"* ]]; then
                status="ahead"
            elif [[ "$tracking" == *"behind"* ]]; then
                status="behind"
            fi
        else
            status="gone"
            ahead_behind="-"
        fi
        tracking_info="$remote"
    fi

    # Color status
    case "$status" in
        "up-to-date") status_col="${GREEN}${status}${NC}" ;;
        "ahead") status_col="${BLUE}${status}${NC}" ;;
        "behind") status_col="${YELLOW}${status}${NC}" ;;
        "diverged") status_col="${RED}${status}${NC}" ;;
        "gone") status_col="${RED}${status}${NC}" ;;
        *) status_col="$status" ;;
    esac

    # Mark current branch
    if [[ "$local" == "$CURRENT_BRANCH" ]]; then
        local="* $local"
    else
        local="  $local"
    fi

    printf "%-40s %-15b %-10s %s\n" "$local" "$status_col" "$ahead_behind" "$tracking_info"
done

# ============================================================
# Prune merged branches
# ============================================================
if [[ "$PRUNE_MERGED" == true ]]; then
    echo ""
    log_info "Pruning merged branches..."

    merged_branches=$(git branch --merged "$DEFAULT_BRANCH" | grep -v "^\*" | grep -v "$DEFAULT_BRANCH" | tr -d ' ')

    if [[ -z "$merged_branches" ]]; then
        log_info "No merged branches to prune"
    else
        for branch in $merged_branches; do
            # Skip protected branches
            if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "develop" ]]; then
                continue
            fi

            if [[ "$DRY_RUN" == true ]]; then
                echo "  Would delete: $branch (merged to $DEFAULT_BRANCH)"
            else
                git branch -d "$branch"
                log_success "Deleted: $branch"
            fi
        done
    fi
fi

# ============================================================
# Handle gone branches (remote deleted)
# ============================================================
echo ""
log_info "Checking for stale branches..."

gone_branches=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | grep '\[gone\]' | cut -d' ' -f1 || true)

if [[ -n "$gone_branches" ]]; then
    log_warn "Found branches with deleted remotes:"
    for branch in $gone_branches; do
        echo "  - $branch"
    done

    if [[ "$PRUNE_MERGED" == true ]]; then
        echo ""
        for branch in $gone_branches; do
            if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
                log_warn "Cannot delete current branch: $branch"
                continue
            fi

            if [[ "$DRY_RUN" == true ]]; then
                echo "  Would delete stale: $branch"
            else
                if [[ "$FORCE_SYNC" == true ]]; then
                    git branch -D "$branch"
                    log_success "Force deleted: $branch"
                else
                    git branch -d "$branch" 2>/dev/null && log_success "Deleted: $branch" || \
                    log_warn "Cannot delete $branch (has unmerged changes, use --force)"
                fi
            fi
        done
    else
        echo ""
        echo "  Run with --prune to delete these branches"
    fi
else
    log_info "No stale branches found"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
log_success "Branch sync complete"

if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
    # Check if current branch needs rebasing
    behind=$(git rev-list --count "$CURRENT_BRANCH".."origin/$DEFAULT_BRANCH" 2>/dev/null || echo "0")
    if [[ "$behind" -gt 0 ]]; then
        echo ""
        log_warn "Current branch is $behind commits behind $DEFAULT_BRANCH"
        echo "  Consider: git rebase origin/$DEFAULT_BRANCH"
    fi
fi

echo "════════════════════════════════════════════════════════════════"
echo ""
