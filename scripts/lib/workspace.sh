#!/usr/bin/env bash
# scripts/lib/workspace.sh — EPIC-122-I: KALLAX Workspace 抽象层
#
# 参照 grok-build xai-grok-workspace/src/session/ 的 WorkspaceSession。
# 封装 4 个接口: fs / vcs / exec / checkpoint。
#
# 设计原则:
#   - 每个操作都是幂等的
#   - 操作失败返回友好错误，不 abort
#   - 所有外部命令用 || true 包裹，由 caller 决定是否 fail-fast
#
# Usage:
#   source scripts/lib/workspace.sh
#   workspace_init "/path/to/cwd"
#   workspace_fs_read "README.md"
#   workspace_vcs_status
#   workspace_exec "git log --oneline -5"
#   workspace_checkpoint_save "before-refactor"

set -euo pipefail

WORKSPACE_CWD=""
WORKSPACE_HOME="${HOME}/.kallax/workspace"
CHECKPOINT_DIR=""

# === Init ===
workspace_init() {
  WORKSPACE_CWD="${1:?workspace_init requires cwd}"
  CHECKPOINT_DIR="${WORKSPACE_HOME}/$(echo "$WORKSPACE_CWD" | tr '/' '_')/checkpoints"
  mkdir -p "$CHECKPOINT_DIR" 2>/dev/null || true
}

# === Filesystem Operations ===

workspace_fs_read() {
  local path="$1"
  local full_path="${WORKSPACE_CWD}/${path}"
  if [[ ! -f "$full_path" ]]; then
    echo "ERROR: file not found: $full_path" >&2
    return 1
  fi
  cat "$full_path"
}

workspace_fs_write() {
  local path="$1"
  local content="$2"
  local full_path="${WORKSPACE_CWD}/${path}"
  mkdir -p "$(dirname "$full_path")" 2>/dev/null || true
  # EPIC-122-D: use temp+mv for atomic write (参照 CheckpointStore)
  local tmp="${full_path}.tmp.$$"
  printf '%s' "$content" > "$tmp" || return 1
  mv "$tmp" "$full_path" || return 1
}

workspace_fs_exists() {
  local path="$1"
  local full_path="${WORKSPACE_CWD}/${path}"
  [[ -f "$full_path" ]]
}

workspace_fs_list() {
  local pattern="${1:-*}"
  ls "${WORKSPACE_CWD}/${pattern}" 2>/dev/null || true
}

workspace_fs_stat() {
  local path="$1"
  local full_path="${WORKSPACE_CWD}/${path}"
  if [[ ! -e "$full_path" ]]; then
    echo "ERROR: path not found: $full_path" >&2
    return 1
  fi
  stat -f "%N %z %m" "$full_path" 2>/dev/null || stat --format="%n %s %Y" "$full_path" 2>/dev/null
}

# === VCS (Git) Operations ===

workspace_vcs_status() {
  # Returns git status as JSON
  if ! command -v git &>/dev/null; then
    echo '{"error":"git not found"}'
    return 1
  fi
  if [[ ! -d "${WORKSPACE_CWD}/.git" ]]; then
    echo '{"error":"not a git repository"}'
    return 1
  fi
  cd "$WORKSPACE_CWD"
  local branch status staged unstaged untracked
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  status=$(git status --porcelain 2>/dev/null || echo "")
  staged=$(echo "$status" | grep "^.[^ ]" | wc -l | tr -d ' ')
  unstaged=$(echo "$status" | grep "^ [^.]" | wc -l | tr -d ' ')
  untracked=$(echo "$status" | grep "^??" | wc -l | tr -d ' ')
  jq -n \
    --arg branch "$branch" \
    --argjson staged "$staged" \
    --argjson unstaged "$unstaged" \
    --argjson untracked "$untracked" \
    '{branch: $branch, staged: $staged, unstaged: $unstaged, untracked: $untracked}'
}

workspace_vcs_log() {
  local limit="${1:-10}"
  if ! command -v git &>/dev/null; then
    echo "ERROR: git not found" >&2
    return 1
  fi
  cd "$WORKSPACE_CWD"
  git log --oneline -"$limit" 2>/dev/null || echo "ERROR: git log failed" >&2
}

workspace_vcs_diff() {
  local ref="${1:-HEAD}"
  if ! command -v git &>/dev/null; then
    echo "ERROR: git not found" >&2
    return 1
  fi
  cd "$WORKSPACE_CWD"
  git diff "$ref" 2>/dev/null || echo "ERROR: git diff failed" >&2
}

# === Command Execution ===

workspace_exec() {
  local cmd="$1"
  local timeout="${2:-30}"
  if [[ -z "$WORKSPACE_CWD" ]]; then
    echo "ERROR: workspace not initialized. Call workspace_init() first." >&2
    return 1
  fi
  cd "$WORKSPACE_CWD"
  # Timeout: kill after N seconds
  if command -v timeout &>/dev/null; then
    timeout "$timeout" bash -c "$cmd" 2>&1 || {
      local rc=$?
      if [[ $rc -eq 124 ]]; then
        echo "ERROR: command timed out after ${timeout}s: $cmd" >&2
      fi
      return $rc
    }
  else
    bash -c "$cmd" 2>&1
  fi
}

# === Checkpoint Operations ===
# 参照 grok-build CheckpointStore: temp-file + fsync + rename

workspace_checkpoint_save() {
  local name="${1:?checkpoint name required}"
  if [[ -z "$CHECKPOINT_DIR" ]]; then
    echo "ERROR: workspace not initialized" >&2
    return 1
  fi

  local checkpoint_file="${CHECKPOINT_DIR}/${name}.json"
  local tmp="${checkpoint_file}.tmp.$$"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Capture current workspace state
  local git_branch git_status
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  git_status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  local cwd_files
  cwd_files=$(ls -la "$WORKSPACE_CWD" 2>/dev/null | wc -l | tr -d ' ')

  jq -n \
    --arg name "$name" \
    --arg ts "$timestamp" \
    --arg branch "$git_branch" \
    --argjson git_status "$git_status" \
    --argjson file_count "$cwd_files" \
    --arg cwd "$WORKSPACE_CWD" \
    '{
      checkpoint_name: $name,
      created_at: $ts,
      branch: $branch,
      git_status_lines: $git_status,
      file_count: $file_count,
      cwd: $cwd
    }' > "$tmp" || return 1

  # EPIC-122-D: fsync before rename (grok-build CheckpointStore pattern)
  if command -v sync &>/dev/null; then
    sync "$tmp" 2>/dev/null || true
  fi
  mv "$tmp" "$checkpoint_file" || return 1
  echo "{\"checkpoint\":\"$name\",\"path\":\"$checkpoint_file\"}"
}

workspace_checkpoint_list() {
  if [[ -z "$CHECKPOINT_DIR" || ! -d "$CHECKPOINT_DIR" ]]; then
    echo "[]"
    return
  fi
  local list="[]"
  for f in "${CHECKPOINT_DIR}"/*.json; do
    [[ -f "$f" ]] || continue
    local name
    name=$(basename "$f" .json)
    local ts
    ts=$(jq -r '.created_at // empty' "$f" 2>/dev/null || echo "")
    list=$(echo "$list" | jq ". + [{\"name\":\"$name\",\"file\":\"$f\",\"created_at\":\"$ts\"}]")
  done
  echo "$list"
}

workspace_checkpoint_load() {
  local name="$1"
  if [[ -z "$CHECKPOINT_DIR" ]]; then
    echo "ERROR: workspace not initialized" >&2
    return 1
  fi
  local checkpoint_file="${CHECKPOINT_DIR}/${name}.json"
  if [[ ! -f "$checkpoint_file" ]]; then
    echo "ERROR: checkpoint not found: $name" >&2
    return 1
  fi
  cat "$checkpoint_file"
}

# === Health ===

workspace_health() {
  jq -n \
    --arg cwd "$WORKSPACE_CWD" \
    --arg home "$WORKSPACE_HOME" \
    --arg checkpoint_dir "$CHECKPOINT_DIR" \
    --arg has_git "$([ -d "${WORKSPACE_CWD}/.git" ] && echo "true" || echo "false")" \
    '{cwd: $cwd, home: $home, checkpoint_dir: $checkpoint_dir, is_git_repo: $has_git}'
}
