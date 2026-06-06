#!/usr/bin/env bash
# KALLAX Worktree Isolation Bootstrapper — EPIC-015 Card C
# Checks CWD against git worktree list, guides role-appropriate action.
# Outputs WORKTREE_STATUS=isolated|not_isolated|pending (last stdout line).
# Can be sourced or run standalone; session_start.sh calls it inline.
set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CWD="$(pwd)"
ROLE="${KALLAX_ROLE:-}"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
WORKTREES_DIR="${PROJECT_ROOT}/.claude/worktrees"

# Infer role if env not set
if [ -z "$ROLE" ]; then
  case "$BRANCH" in
    feature/*|worktree-*) ROLE="performer" ;;
    *) ROLE="conductor" ;;
  esac
fi

# Colors (same palette as sibling scripts)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

# Expand tilde in path (git worktree list uses ~ for $HOME)
expand_tilde() { echo "${1/#\~/$HOME}"; }

# Detect which (non-main) worktree entry our CWD belongs to.
# Returns the raw worktree-list line, or empty.
get_my_worktree() {
  while IFS= read -r line; do
    WT_PATH=$(echo "$line" | awk '{print $1}')
    WT_PATH="$(expand_tilde "$WT_PATH")"
    # Skip main repo — check actual worktrees only
    [ "$WT_PATH" = "$PROJECT_ROOT" ] && continue
    # Check if CWD is at or under this worktree path
    case "$CWD" in
      "$WT_PATH"|"$WT_PATH"/*) echo "$line"; return 0 ;;
    esac
  done <<< "$(git worktree list 2>/dev/null || true)"
  return 1
}

# Check if CWD is inside the main repository
in_main_repo() {
  case "$CWD" in
    "$PROJECT_ROOT"|"$PROJECT_ROOT"/*) return 0 ;;
  esac
  return 1
}

# Forbidden: direct edit on miao/testing branches outside a worktree.
# Prints warning and WORKTREE_STATUS on match. Caller should exit after.
check_forbidden_branches() {
  case "$BRANCH" in
    miao|testing|miao/*|testing/*)
      echo ""
      fail "Forbidden: editing branch '${BRANCH}' outside a worktree!"
      fail "All development on '${BRANCH}' must go through a worktree."
      echo "WORKTREE_STATUS=not_isolated"
      return 1
      ;;
  esac
  return 0
}

# ---------- Main ----------

WT_LINE=$(get_my_worktree || true)

if [ -n "$WT_LINE" ]; then
  # -- Inside a proper (non-main) worktree --
  WT_PATH=$(echo "$WT_LINE" | awk '{print $1}')
  WT_PATH="$(expand_tilde "$WT_PATH")"
  WT_BRANCH=$(echo "$WT_LINE" | awk '{print $3}' | tr -d '[]')
  WT_GITDIR=$(git rev-parse --git-dir 2>/dev/null)

  echo ""
  info "Worktree isolation confirmed"
  info "  Path:   ${WT_PATH}"
  info "  Branch: ${WT_BRANCH}"
  info "  GitDir: ${WT_GITDIR}"
  echo ""
  if echo "$WT_GITDIR" | grep -q 'worktrees'; then
    pass "Git directory is fully isolated"
  else
    warn "Git directory may not be fully isolated"
  fi
  echo ""
  echo "WORKTREE_PATH=${WT_PATH}"
  echo "WORKTREE_BRANCH=${WT_BRANCH}"
  echo "WORKTREE_STATUS=isolated"

elif in_main_repo; then
  # -- Main repository (not isolated) --
  check_forbidden_branches || exit $?

  case "$ROLE" in
    conductor|master)
      echo ""
      info "Conductor detected in main repository (not isolated)."
      CONDUCTOR_WT="${WORKTREES_DIR}/conductor-init"
      if [ -d "$CONDUCTOR_WT" ]; then
        info "Existing worktree available:"
        info "  Path:   ${CONDUCTOR_WT}"
        info "  Action: cd ${CONDUCTOR_WT}   (or use EnterWorktree skill)"
        echo "WORKTREE_PATH=${CONDUCTOR_WT}"
      else
        info "No conductor worktree found. Creating one on main branch..."
        if git worktree add -b worktree-conductor-init "$CONDUCTOR_WT" main 2>/dev/null; then
          pass "Conductor worktree created at: ${CONDUCTOR_WT}  (branch: worktree-conductor-init)"
          echo "WORKTREE_PATH=${CONDUCTOR_WT}"
        else
          warn "Auto-create failed. Create manually: EnterWorktree"
          echo "WORKTREE_PATH=null"
        fi
      fi
      echo ""
      echo "WORKTREE_STATUS=not_isolated"
      ;;
    performer)
      check_forbidden_branches || exit $?
      echo ""
      warn "Performer detected in main repository (not isolated)!"
      warn "Do NOT write code here — wait for Conductor to assign a ticket."
      info "Monitor inbox at: .kallax/queue/inbox/"
      echo ""
      echo "WORKTREE_STATUS=pending"
      ;;
    *)
      echo ""
      warn "Role '${ROLE}' in main repository — not isolated."
      echo "WORKTREE_STATUS=not_isolated"
      ;;
  esac
else
  # Outside the repository entirely
  warn "Current directory is not inside this git repository."
  warn "  CWD: ${CWD}"
  echo "WORKTREE_STATUS=not_isolated"
fi
