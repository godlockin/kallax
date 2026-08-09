#!/bin/bash
#===============================================================================
# conflict-detect.sh — Conflict detection for file modifications
# Rule 17 Step 3: IO layer conflict detection
# 痛点 6 治根：跟 EPIC-036 跨 worktree 联动
#
# 功能:
#   - git diff 比对文件变化 (跨 worktree 检测)
#   - 检测到冲突时 STOP + 报告 + 不自动解决
#   - 跟 file-lock.sh (Step 1) + atomic-write.sh (Step 2) 联动
#
# 用法:
#   source scripts/io/conflict-detect.sh
#   conflict_detect check <file_path>           # 检查文件冲突
#   conflict_detect report <file_path>         # 生成冲突报告
#   conflict_detect clear <file_path>          # 清除冲突标记
#
# 环境变量:
#   CONFLICT_DETECT_DIR=/tmp/kallax-conflicts  # 冲突状态目录
#   CONFLICT_DETECT_TIMEOUT=30                 # git diff 超时秒数
#===============================================================================

set -euo pipefail
umask 077

# 默认配置
CONFLICT_DETECT_DIR="${CONFLICT_DETECT_DIR:-/tmp/kallax-conflicts}"
CONFLICT_DETECT_TIMEOUT="${CONFLICT_DETECT_TIMEOUT:-30}"

# 检测 git 是否可用
_has_git() {
  command -v git >/dev/null 2>&1
}

# 冲突目录初始化
_CONFLICT_DETECT_INIT_DONE=0

_conflict_detect_init() {
  if [[ $_CONFLICT_DETECT_INIT_DONE -eq 1 ]]; then
    return 0
  fi
  # Issue 1 fix (BE-7): install -d -m 700 + ownership check + 防 symlink
  if [[ -L "$CONFLICT_DETECT_DIR" ]] || [[ -L "$CONFLICT_DETECT_DIR.conflictdir" ]]; then
    echo "ERROR: Refusing to follow symlink at $CONFLICT_DETECT_DIR" >&2
    return 1
  fi
  if install -d -m 700 "$CONFLICT_DETECT_DIR" 2>/dev/null; then
    # 验证 ownership (防 TOCTOU) - macOS/ Linux 兼容
    local dir_owner
    case "$(uname -s)" in
      Darwin) dir_owner="$(stat -f "%Su" "$CONFLICT_DETECT_DIR" 2>/dev/null)" ;;
      *) dir_owner="$(stat -c %U "$CONFLICT_DETECT_DIR" 2>/dev/null)" ;;
    esac
    if [[ -n "$dir_owner" ]] && [[ "$dir_owner" != "${USER:-$(whoami)}" ]]; then
      rm -rf "$CONFLICT_DETECT_DIR" 2>/dev/null
      echo "ERROR: Ownership mismatch for $CONFLICT_DETECT_DIR" >&2
      return 1
    fi
    _CONFLICT_DETECT_INIT_DONE=1
    return 0
  fi
  echo "ERROR: Failed to create conflict detection directory: $CONFLICT_DETECT_DIR" >&2
  return 1
}

# 生成冲突状态文件路径
_conflict_detect_path() {
  local file_path="$1"
  local abs_path
  abs_path="$(realpath "$file_path" 2>/dev/null || echo "$file_path")"
  local hash
  hash="$(echo "$abs_path" | md5sum | cut -d' ' -f1)"
  echo "$CONFLICT_DETECT_DIR/conflict.$hash.state"
}

#===============================================================================
# _git_diff_check — 使用 git diff 检测文件变化
#===============================================================================
_git_diff_check() {
  local file_path="$1"
  local timeout_sec="${2:-30}"

  if ! _has_git; then
    echo "ERROR: git not available" >&2
    return 1
  fi

  # 检查文件是否在 git 仓库中
  local git_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || {
    echo "ERROR: Not in a git repository" >&2
    return 1
  }

  # 使用 git diff 检测工作区是否有未提交的更改
  # --quiet: 只返回退出码, 不输出
  # -- <file>: 只检查特定文件
  if ! git diff --quiet -- "$file_path" 2>/dev/null; then
    echo "CONFLICT: Unstaged changes detected: $file_path" >&2
    return 1
  fi

  # 检查 staged 是否有变化
  if ! git diff --cached --quiet -- "$file_path" 2>/dev/null; then
    echo "CONFLICT: Staged changes detected: $file_path" >&2
    return 1
  fi

  return 0
}

#===============================================================================
# _cross_worktree_diff — 跨 worktree 检测 (EPIC-036 联动)
# 检测其他 worktree 是否修改了同一文件
#===============================================================================
_cross_worktree_diff() {
  local file_path="$1"

  if ! _has_git; then
    return 0
  fi

  # 获取当前 worktree 的根目录
  local current_root
  current_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0

  # 检查同一仓库的其他 worktree
  # 使用 git worktree list 获取所有 worktree
  local other_worktrees
  other_worktrees="$(git worktree list 2>/dev/null | grep -v "^$current_root" | grep -v "^$HOME" | awk '{print $1}')" || return 0

  if [[ -z "$other_worktrees" ]]; then
    return 0
  fi

  # 获取当前文件的相对路径
  local rel_path
  rel_path="$(realpath --relative-to="$current_root" "$file_path" 2>/dev/null || echo "$file_path")"

  # 检查其他 worktree 是否有不同的 commit
  local current_commit
  current_commit="$(git rev-parse HEAD 2>/dev/null)" || return 0

  while IFS= read -r wt_path; do
    [[ -z "$wt_path" ]] && continue

    # 跳过当前 worktree
    [[ "$wt_path" == "$current_root" ]] && continue

    # 在其他 worktree 中检查同一文件
    if [[ -f "$wt_path/$rel_path" ]]; then
      (
        cd "$wt_path" 2>/dev/null || return 0
        local wt_commit
        wt_commit="$(git rev-parse HEAD 2>/dev/null)" || return 0
        if [[ "$wt_commit" != "$current_commit" ]]; then
          echo "CONFLICT: File modified in other worktree: $file_path (worktree: $wt_path, commit: $wt_commit)" >&2
          return 1
        fi
      )
      [[ ${PIPESTATUS[0]} -eq 1 ]] && return 1
    fi
  done <<< "$other_worktrees"

  return 0
}

#===============================================================================
# conflict_detect check <file_path>
# 检查文件是否有冲突
#===============================================================================
conflict_detect_check() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    echo "ERROR: File path required" >&2
    return 1
  fi

  if [[ ! -f "$file_path" ]]; then
    echo "ERROR: File does not exist: $file_path" >&2
    return 1
  fi

  _conflict_detect_init || return 1

  # Step 1: 检查 git diff
  if ! _git_diff_check "$file_path" "$CONFLICT_DETECT_TIMEOUT"; then
    return 1
  fi

  # Step 2: 跨 worktree 检测 (EPIC-036 联动)
  if ! _cross_worktree_diff "$file_path"; then
    return 1
  fi

  return 0
}

#===============================================================================
# conflict_detect report <file_path>
# 生成冲突报告
#===============================================================================
conflict_detect_report() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    echo "ERROR: File path required" >&2
    return 1
  fi

  _conflict_detect_init || return 1

  local conflict_file
  conflict_file="$(_conflict_detect_path "$file_path")"

  local report="CONFLICT-REPORT: $file_path"
  report+=$'\n'"TIME: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report+=$'\n'"USER: ${USER:-$(whoami)}"
  report+=$'\n'"PID: $$"

  # 获取 git 状态
  if _has_git; then
    local git_status
    git_status="$(git status --porcelain "$file_path" 2>/dev/null)" || git_status="unknown"
    report+=$'\n'"GIT-STATUS: $git_status"

    local git_diff
    git_diff="$(git diff "$file_path" 2>/dev/null)" || git_diff="none"
    report+=$'\n'"GIT-DIFF: $git_diff"
  fi

  # 写入冲突报告
  echo "$report" > "$conflict_file"
  chmod 600 "$conflict_file" || chmod 600 "$conflict_file"

  echo "OK: Conflict report generated: $conflict_file"
  cat "$conflict_file"
}

#===============================================================================
# conflict_detect clear <file_path>
# 清除冲突标记
#===============================================================================
conflict_detect_clear() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    echo "ERROR: File path required" >&2
    return 1
  fi

  _conflict_detect_init || return 1

  local conflict_file
  conflict_file="$(_conflict_detect_path "$file_path")"

  if [[ -f "$conflict_file" ]]; then
    rm -f "$conflict_file" 2>/dev/null || {
      echo "ERROR: Failed to clear conflict state: $conflict_file" >&2
      return 1
    }
    echo "OK: Conflict state cleared: $file_path"
  else
    echo "OK: No conflict state found: $file_path"
  fi

  return 0
}

#===============================================================================
# conflict_detect verify <file_path>
# 验证文件无冲突后写入 (集成到 file-lock.sh + atomic-write.sh 流程)
#===============================================================================
conflict_detect_verify() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    echo "ERROR: File path required" >&2
    return 1
  fi

  # 检查冲突
  if ! conflict_detect_check "$file_path"; then
    echo "ERROR: Conflict detected, refusing to write: $file_path" >&2
    conflict_detect_report "$file_path"
    return 1
  fi

  echo "OK: No conflict detected: $file_path"
  return 0
}

#===============================================================================
# 导出函数供 source 调用
#===============================================================================
export -f conflict_detect_check
export -f conflict_detect_report
export -f conflict_detect_clear
export -f conflict_detect_verify

# 如果直接执行此脚本 (非 source), 打印帮助
# BASH_SOURCE[0] 在 source 时可能为空, 使用 ${BASH_SOURCE[0]:-} 处理
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "conflict-detect.sh — Conflict detection (Rule 17 Step 3)"
  echo ""
  echo "用法:"
  echo "  source scripts/io/conflict-detect.sh"
  echo "  conflict_detect check <file>     # 检查冲突"
  echo "  conflict_detect report <file>    # 生成冲突报告"
  echo "  conflict_detect clear <file>     # 清除冲突标记"
  echo "  conflict_detect verify <file>    # 验证后写入"
  echo ""
  echo "注意: $(_has_git && echo "git 可用" || echo "git 不可用, 跳过 git 检测")"
  exit 0
fi
