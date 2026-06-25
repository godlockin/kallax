#!/bin/bash
# cross-worktree-dispatch.sh — Cross-worktree auto cherry-pick + conflict detect
# EPIC-036-A: 1 ticket 1 worktree 串行 共识 + BE-20 --theirs 治根
#
# Modes:
#   list                                   — list worktrees (path + branch)
#   validate --source <path> --target <path>
#                                          — verify both worktree paths exist
#   dispatch --source <path> --target <path> [--dry-run]
#                                          — auto cherry-pick source → target
#                                            STOP + non-zero on conflict
#                                            (no forced resolution, BE-20 治根)
#
# Exit codes:
#   0  success / no conflict / dry-run preview
#   1  invalid args / missing worktree / conflict detected
#
# Source: EPIC-036-A ticket.json AC + BE-20 governance

set -euo pipefail

# Constants (no magic numbers per Hard Rule #4)
readonly EXIT_OK=0
readonly EXIT_USAGE=1
readonly EXIT_VALIDATION_FAIL=1
readonly EXIT_CONFLICT=1
readonly EXIT_CHERRY_PICK_FAIL=1

# Logging helper — stderr to keep stdout clean for piping
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

#===============================================================================
# list — list all worktrees with path + branch
# Output format: "<path>\t<branch>" (tab-separated for machine parsing)
# Args: [--repo <path>]   default: current directory's git toplevel
#===============================================================================
mode_list() {
  local repo_root=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_root="$2"; shift 2 ;;
      *) log_err "list: unknown arg: $1"; return "$EXIT_USAGE" ;;
    esac
  done

  if [[ -z "$repo_root" ]]; then
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
      log_err "list: not in a git repository (use --repo <path>)"
      return "$EXIT_VALIDATION_FAIL"
    }
  fi

  if [[ ! -d "$repo_root" ]]; then
    log_err "list: repo path not found: $repo_root"
    return "$EXIT_VALIDATION_FAIL"
  fi

  # Use porcelain for stable parsing
  git -C "$repo_root" worktree list --porcelain | \
    awk '
      /^worktree / { path = $2 }
      /^branch /   { sub(/^refs\/heads\//, "", $2); print path "\t" $2 }
    '
}

#===============================================================================
# validate --source <path> --target <path>
# Verify both paths are valid worktrees
#===============================================================================
mode_validate() {
  local source="" target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      *) log_err "validate: unknown arg: $1"; return "$EXIT_USAGE" ;;
    esac
  done

  if [[ -z "$source" ]] || [[ -z "$target" ]]; then
    log_err "validate: --source and --target required"
    return "$EXIT_USAGE"
  fi

  if [[ ! -d "$source" ]]; then
    log_err "validate: source worktree not found: $source"
    return "$EXIT_VALIDATION_FAIL"
  fi
  if [[ ! -d "$target" ]]; then
    log_err "validate: target worktree not found: $target"
    return "$EXIT_VALIDATION_FAIL"
  fi

  # Verify each is a git worktree (has .git file or dir)
  if ! git -C "$source" rev-parse --git-dir >/dev/null 2>&1; then
    log_err "validate: source is not a git worktree: $source"
    return "$EXIT_VALIDATION_FAIL"
  fi
  if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    log_err "validate: target is not a git worktree: $target"
    return "$EXIT_VALIDATION_FAIL"
  fi

  log_info "validate: source=$source target=$target VALIDATE_OK"
  return "$EXIT_OK"
}

#===============================================================================
# dispatch --source <path> --target <path> [--dry-run]
# Auto cherry-pick source's unique commits to target.
# On conflict: STOP + abort + non-zero (NEVER use --theirs, BE-20 治根).
#===============================================================================
mode_dispatch() {
  local source="" target="" dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)  source="$2"; shift 2 ;;
      --target)  target="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift 1 ;;
      *) log_err "dispatch: unknown arg: $1"; return "$EXIT_USAGE" ;;
    esac
  done

  if [[ -z "$source" ]] || [[ -z "$target" ]]; then
    log_err "dispatch: --source and --target required"
    return "$EXIT_USAGE"
  fi

  # Validate first (fail fast, Rule 4)
  mode_validate --source "$source" --target "$target" || return "$EXIT_VALIDATION_FAIL"

  # Resolve HEAD SHAs (worktrees share .git, so merge-base can use SHAs)
  local source_sha target_sha merge_base
  source_sha=$(git -C "$source" rev-parse HEAD 2>/dev/null) || {
    log_err "dispatch: failed to get source HEAD"
    return "$EXIT_CHERRY_PICK_FAIL"
  }
  target_sha=$(git -C "$target" rev-parse HEAD 2>/dev/null) || {
    log_err "dispatch: failed to get target HEAD"
    return "$EXIT_CHERRY_PICK_FAIL"
  }

  # Find merge base (common ancestor)
  if ! merge_base=$(git -C "$source" merge-base "$source_sha" "$target_sha" 2>/dev/null); then
    # No common ancestor — use source's initial commit as base
    merge_base=$(git -C "$source" rev-list --max-parents=0 HEAD | head -1)
  fi

  # Find commits in source not in target (source's unique commits)
  local unique_commits
  unique_commits=$(git -C "$source" rev-list --reverse "${merge_base}..${source_sha}" 2>/dev/null) || {
    log_err "dispatch: failed to list source commits"
    return "$EXIT_CHERRY_PICK_FAIL"
  }

  if [[ -z "$unique_commits" ]]; then
    log_info "dispatch: no unique commits in source (already in sync)"
    return "$EXIT_OK"
  fi

  local commit_count
  commit_count=$(echo "$unique_commits" | wc -l | tr -d ' ')

  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY_RUN: would cherry-pick $commit_count commit(s) from $source to $target"
    echo "DRY_RUN: commits:"
    echo "$unique_commits" | while read -r sha; do
      local subject
      subject=$(git -C "$source" log -1 --pretty=%s "$sha" 2>/dev/null)
      echo "DRY_RUN:   $sha $subject"
    done
    return "$EXIT_OK"
  fi

  log_info "dispatch: cherry-picking $commit_count commit(s) from $source to $target"

  # Cherry-pick each commit in order
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    local subject
    subject=$(git -C "$source" log -1 --pretty=%s "$sha" 2>/dev/null)

    # Use git -C target cherry-pick
    # CRITICAL: do NOT pass --theirs (BE-20 治根)
    if ! git -C "$target" cherry-pick "$sha" 2>/tmp/kallax-cherrypick-$$.err; then
      # Conflict detected — STOP, abort, no auto-merge
      log_err "dispatch: CONFLICT on commit $sha ($subject)"
      log_err "dispatch: STOP — aborting cherry-pick (BE-20 治根: 0 forced resolution)"
      cat /tmp/kallax-cherrypick-$$.err >&2 || true
      git -C "$target" cherry-pick --abort 2>/dev/null || true
      rm -f /tmp/kallax-cherrypick-$$.err
      return "$EXIT_CONFLICT"
    fi
    log_info "dispatch: applied $sha ($subject)"
  done <<< "$unique_commits"

  rm -f /tmp/kallax-cherrypick-$$.err
  log_info "dispatch: complete ($commit_count commits applied)"
  return "$EXIT_OK"
}

#===============================================================================
# Main dispatch — route by subcommand
#===============================================================================
main() {
  if [[ $# -eq 0 ]]; then
    log_err "usage: $0 {list|validate|dispatch} [args]"
    log_err ""
    log_err "  list"
    log_err "  validate --source <path> --target <path>"
    log_err "  dispatch --source <path> --target <path> [--dry-run]"
    return "$EXIT_USAGE"
  fi

  local subcmd="$1"
  shift

  case "$subcmd" in
    list)     mode_list "$@" ;;
    validate) mode_validate "$@" ;;
    dispatch) mode_dispatch "$@" ;;
    *)
      log_err "unknown subcommand: $subcmd"
      return "$EXIT_USAGE"
      ;;
  esac
}

main "$@"
