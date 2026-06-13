#!/bin/bash
#===============================================================================
# worktree-state-sync.sh — Worktree state synchronization
# Rule 17 Step 5: IO layer worktree state sync
# 痛点 6 治根 5/5 步完成：状态不一致防护
#
# 功能:
#   - Performer commit 必 push 到 feature branch (不只本地)
#   - Master 必 merge feature → testing (不只 dispatch)
#   - 跟 merge-to-testing.sh (EPIC-039-C) 联动
#   - 跟 atomic-write.sh (Step 2) + conflict-detect.sh (Step 3) 联动
#   - 集成到 Conductor merge 流程 + pre-push hook + post-merge hook
#
# 用法:
#   source scripts/master/worktree-state-sync.sh
#   worktree_sync performer_push <worktree_path>     # Performer push feature branch
#   worktree_sync master_merge <feature_branch>      # Master merge feature → testing
#   worktree_sync verify_state <worktree_path>      # 验证 worktree 状态
#   worktree_sync full_sync <worktree_path>         # 完整同步流程
#
# 环境变量:
#   WORKTREE_SYNC_TIMEOUT=60        # git 操作超时秒数
#   WORKTREE_SYNC_DIR=/tmp/kallax-worktree-sync  # 状态目录
#===============================================================================

set -euo pipefail
umask 077

# 默认配置
WORKTREE_SYNC_TIMEOUT="${WORKTREE_SYNC_TIMEOUT:-60}"
WORKTREE_SYNC_DIR="${WORKTREE_SYNC_DIR:-/tmp/kallax-worktree-sync}"
KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"

# 检测 git 是否可用
_has_git() {
  command -v git >/dev/null 2>&1
}

# 状态目录初始化
_WORKTREE_SYNC_INIT_DONE=0

_worktree_sync_init() {
  if [[ $_WORKTREE_SYNC_INIT_DONE -eq 1 ]]; then
    return 0
  fi
  # Issue 1 fix (BE-7): install -d -m 700 + ownership check + 防 symlink
  if [[ -L "$WORKTREE_SYNC_DIR" ]] || [[ -L "$WORKTREE_SYNC_DIR.syncstate" ]]; then
    echo "ERROR: Refusing to follow symlink at $WORKTREE_SYNC_DIR" >&2
    return 1
  fi
  if install -d -m 700 "$WORKTREE_SYNC_DIR" 2>/dev/null; then
    # 验证 ownership (防 TOCTOU) - macOS/ Linux 兼容
    local dir_owner
    case "$(uname -s)" in
      Darwin) dir_owner="$(stat -f "%Su" "$WORKTREE_SYNC_DIR" 2>/dev/null)" ;;
      *) dir_owner="$(stat -c %U "$WORKTREE_SYNC_DIR" 2>/dev/null)" ;;
    esac
    if [[ -n "$dir_owner" ]] && [[ "$dir_owner" != "${USER:-$(whoami)}" ]]; then
      rm -rf "$WORKTREE_SYNC_DIR" 2>/dev/null
      echo "ERROR: Ownership mismatch for $WORKTREE_SYNC_DIR" >&2
      return 1
    fi
    _WORKTREE_SYNC_INIT_DONE=1
    return 0
  fi
  echo "ERROR: Failed to create worktree sync directory: $WORKTREE_SYNC_DIR" >&2
  return 1
}

# 生成状态文件路径
_worktree_sync_path() {
  local worktree_path="$1"
  local abs_path
  abs_path="$(realpath "$worktree_path" 2>/dev/null || echo "$worktree_path")"
  local hash
  hash="$(echo "$abs_path" | md5sum | cut -d' ' -f1)"
  echo "$WORKTREE_SYNC_DIR/sync.$hash.state"
}

#===============================================================================
# _git_push_to_feature — Performer commit push 到 feature branch
#===============================================================================
_git_push_to_feature() {
  local worktree_path="$1"
  local timeout_sec="${2:-$WORKTREE_SYNC_TIMEOUT}"

  if ! _has_git; then
    echo "ERROR: git not available" >&2
    return 1
  fi

  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: Worktree path does not exist: $worktree_path" >&2
    return 1
  fi

  (
    cd "$worktree_path" 2>/dev/null || {
      echo "ERROR: Cannot cd to worktree: $worktree_path" >&2
      return 1
    }

    # 检查是否是 worktree
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || {
      echo "ERROR: Not a git repository: $worktree_path" >&2
      return 1
    }

    # 获取当前分支
    local current_branch
    current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
      echo "ERROR: Cannot determine current branch" >&2
      return 1
    }

    # 检查是否有未提交的更改
    if ! git diff --quiet 2>/dev/null; then
      echo "ERROR: Uncommitted changes in worktree, refusing to push: $worktree_path" >&2
      return 1
    fi

    if ! git diff --cached --quiet 2>/dev/null; then
      echo "ERROR: Staged changes in worktree, refusing to push: $worktree_path" >&2
      return 1
    fi

    # 获取当前 commit SHA
    local current_sha
    current_sha="$(git rev-parse HEAD 2>/dev/null)" || {
      echo "ERROR: Cannot get current SHA" >&2
      return 1
    }

    # 检查 upstream 分支
    local upstream
    upstream="$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)" || {
      echo "ERROR: No upstream branch configured for $current_branch" >&2
      echo "HINT: Set upstream with: git push --set-upstream origin $current_branch" >&2
      return 1
    }

    # Push 到 feature branch
    if ! timeout "$timeout_sec" git push origin "$current_branch" 2>/dev/null; then
      echo "ERROR: git push failed for branch: $current_branch" >&2
      echo "HINT: Check network connectivity and branch permissions" >&2
      return 1
    fi

    echo "OK: Pushed to feature branch: $current_branch (SHA: $current_sha)"
    return 0
  )
}

#===============================================================================
# _git_merge_to_testing — Master merge feature → testing
#===============================================================================
_git_merge_to_testing() {
  local feature_branch="$1"
  local timeout_sec="${2:-$WORKTREE_SYNC_TIMEOUT}"

  if ! _has_git; then
    echo "ERROR: git not available" >&2
    return 1
  fi

  # 获取仓库根目录
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: Not in a git repository" >&2
    return 1
  }

  # 验证 feature 分支存在
  if ! git rev-parse --verify "$feature_branch" 2>/dev/null; then
    echo "ERROR: Feature branch does not exist: $feature_branch" >&2
    return 1
  fi

  # 验证 testing 分支存在
  if ! git rev-parse --verify "testing" 2>/dev/null; then
    echo "ERROR: testing branch does not exist" >&2
    return 1
  fi

  # 检查 feature 分支是否有新的 commit
  local testing_sha
  testing_sha="$(git rev-parse testing 2>/dev/null)" || {
    echo "ERROR: Cannot get testing SHA" >&2
    return 1
  }

  local feature_sha
  feature_sha="$(git rev-parse "$feature_branch" 2>/dev/null)" || {
    echo "ERROR: Cannot get feature SHA" >&2
    return 1
  }

  if [[ "$feature_sha" == "$testing_sha" ]]; then
    echo "OK: No new commits to merge (feature and testing are in sync)"
    return 0
  fi

  # Checkout testing 分支
  if ! git checkout testing 2>/dev/null; then
    echo "ERROR: Cannot checkout testing branch" >&2
    return 1
  fi

  # Merge feature 分支
  if ! timeout "$timeout_sec" git merge "$feature_branch" --no-edit 2>/dev/null; then
    echo "ERROR: Merge failed for branch: $feature_branch → testing" >&2
    # 恢复 testing 分支
    git checkout - 2>/dev/null || true
    return 1
  fi

  echo "OK: Merged feature branch to testing: $feature_branch"

  # Push testing 分支
  if ! timeout "$timeout_sec" git push origin testing 2>/dev/null; then
    echo "ERROR: Failed to push testing branch" >&2
    return 1
  fi

  echo "OK: Pushed testing branch"

  # 切回原分支
  git checkout - 2>/dev/null || true

  return 0
}

#===============================================================================
# _verify_worktree_state — 验证 worktree 状态
#===============================================================================
_verify_worktree_state() {
  local worktree_path="$1"

  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: Worktree path does not exist: $worktree_path" >&2
    return 1
  fi

  (
    cd "$worktree_path" 2>/dev/null || {
      echo "ERROR: Cannot cd to worktree: $worktree_path" >&2
      return 1
    }

    # 检查 git 状态
    local git_status
    git_status="$(git status --porcelain 2>/dev/null)" || {
      echo "ERROR: Not a git repository: $worktree_path" >&2
      return 1
    }

    if [[ -n "$git_status" ]]; then
      echo "WARN: Worktree has uncommitted changes: $worktree_path"
      echo "$git_status"
      return 2  # Warning, not error
    fi

    # 检查分支
    local current_branch
    current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
      echo "ERROR: Cannot determine branch" >&2
      return 1
    }

    # 检查 upstream
    local has_upstream=false
    if git rev-parse --abbrev-ref @{upstream} 2>/dev/null >/dev/null; then
      has_upstream=true
    fi

    echo "OK: Worktree state verified: $worktree_path"
    echo "  Branch: $current_branch"
    echo "  Has upstream: $has_upstream"

    return 0
  )
}

#===============================================================================
# _full_sync — 完整同步流程
#===============================================================================
_full_sync() {
  local worktree_path="$1"

  _worktree_sync_init || return 1

  # Step 1: 验证 worktree 状态
  echo "STEP 1: Verifying worktree state..."
  if ! _verify_worktree_state "$worktree_path"; then
    echo "ERROR: Worktree state verification failed" >&2
    return 1
  fi

  # Step 2: Push feature branch
  echo "STEP 2: Pushing feature branch..."
  if ! _git_push_to_feature "$worktree_path"; then
    echo "ERROR: Push to feature branch failed" >&2
    return 1
  fi

  # Step 3: 获取分支名并 merge 到 testing
  echo "STEP 3: Merging to testing..."
  local branch
  branch="$(cd "$worktree_path" 2>/dev/null && git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
    echo "ERROR: Cannot determine branch" >&2
    return 1
  }

  if ! _git_merge_to_testing "$branch"; then
    echo "ERROR: Merge to testing failed" >&2
    return 1
  fi

  # Step 4: 更新同步状态
  local sync_file
  sync_file="$(_worktree_sync_path "$worktree_path")"
  echo "SYNC-STATUS: OK" > "$sync_file"
  echo "SYNC-TIME: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$sync_file"
  echo "SYNC-BRANCH: $branch" >> "$sync_file"
  echo "SYNC-WORKTREE: $worktree_path" >> "$sync_file"
  chmod 600 "$sync_file"

  echo "OK: Full sync completed: $worktree_path"
  return 0
}

#===============================================================================
# worktree_sync performer_push <worktree_path>
# Performer commit push 到 feature branch
#===============================================================================
worktree_sync_performer_push() {
  local worktree_path="$1"

  if [[ -z "$worktree_path" ]]; then
    echo "ERROR: Worktree path required" >&2
    return 1
  fi

  _worktree_sync_init || return 1

  if ! _git_push_to_feature "$worktree_path"; then
    echo "ERROR: Performer push failed" >&2
    return 1
  fi

  return 0
}

#===============================================================================
# worktree_sync master_merge <feature_branch>
# Master merge feature → testing
#===============================================================================
worktree_sync_master_merge() {
  local feature_branch="$1"

  if [[ -z "$feature_branch" ]]; then
    echo "ERROR: Feature branch name required" >&2
    return 1
  fi

  _worktree_sync_init || return 1

  if ! _git_merge_to_testing "$feature_branch"; then
    echo "ERROR: Master merge failed" >&2
    return 1
  fi

  return 0
}

#===============================================================================
# worktree_sync verify_state <worktree_path>
# 验证 worktree 状态
#===============================================================================
worktree_sync_verify_state() {
  local worktree_path="$1"

  if [[ -z "$worktree_path" ]]; then
    echo "ERROR: Worktree path required" >&2
    return 1
  fi

  _worktree_sync_init || return 1

  if ! _verify_worktree_state "$worktree_path"; then
    echo "ERROR: Worktree state verification failed" >&2
    return 1
  fi

  return 0
}

#===============================================================================
# worktree_sync full_sync <worktree_path>
# 完整同步流程
#===============================================================================
worktree_sync_full_sync() {
  local worktree_path="$1"

  if [[ -z "$worktree_path" ]]; then
    echo "ERROR: Worktree path required" >&2
    return 1
  fi

  if ! _full_sync "$worktree_path"; then
    echo "ERROR: Full sync failed" >&2
    return 1
  fi

  return 0
}

#===============================================================================
# worktree_sync status <worktree_path>
# 获取同步状态
#===============================================================================
worktree_sync_status() {
  local worktree_path="$1"

  if [[ -z "$worktree_path" ]]; then
    echo "ERROR: Worktree path required" >&2
    return 1
  fi

  _worktree_sync_init || return 1

  local sync_file
  sync_file="$(_worktree_sync_path "$worktree_path")"

  if [[ -f "$sync_file" ]]; then
    echo "Sync status:"
    cat "$sync_file"
  else
    echo "No sync status found for: $worktree_path"
  fi

  return 0
}

#===============================================================================
# 导出函数供 source 调用
#===============================================================================
export -f worktree_sync_performer_push
export -f worktree_sync_master_merge
export -f worktree_sync_verify_state
export -f worktree_sync_full_sync
export -f worktree_sync_status

# 如果直接执行此脚本 (非 source), 打印帮助
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-state-sync.sh — Worktree state synchronization (Rule 17 Step 5)"
  echo ""
  echo "用法:"
  echo "  source scripts/master/worktree-state-sync.sh"
  echo "  worktree_sync performer_push <worktree>   # Performer push feature branch"
  echo "  worktree_sync master_merge <branch>       # Master merge feature → testing"
  echo "  worktree_sync verify_state <worktree>     # 验证 worktree 状态"
  echo "  worktree_sync full_sync <worktree>        # 完整同步流程"
  echo "  worktree_sync status <worktree>          # 获取同步状态"
  echo ""
  echo "注意: $(_has_git && echo "git 可用" || echo "git 不可用")"
  exit 0
fi