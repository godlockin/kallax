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

workspace_resolve_path() {
  local path="${1:?path required}"
  python3 - "$WORKSPACE_CWD" "$path" <<'PY'
import os
import sys

root, path = sys.argv[1:]
if os.path.isabs(path) or ".." in path.split(os.sep):
    raise SystemExit("ERROR: path must be workspace-relative and cannot contain ..")
root_real = os.path.realpath(root)
resolved = os.path.realpath(os.path.join(root_real, path))
try:
    contained = os.path.commonpath((root_real, resolved)) == root_real
except ValueError:
    contained = False
if not contained:
    raise SystemExit("ERROR: path escapes workspace root")
print(resolved)
PY
}

# === Init ===
workspace_init() {
  local cwd="${1:?workspace_init requires cwd}"
  WORKSPACE_CWD="$(realpath "$cwd")" || return 1
  [[ -d "$WORKSPACE_CWD" ]] || return 1
  CHECKPOINT_DIR="${WORKSPACE_HOME}/$(printf '%s' "$WORKSPACE_CWD" | tr '/' '_')/checkpoints"
  mkdir -p "$CHECKPOINT_DIR" 2>/dev/null || true
}

# === Filesystem Operations ===

workspace_fs_read() {
  local path="$1"
  local full_path
  full_path="$(workspace_resolve_path "$path")" || { echo "ERROR: path outside workspace: $path" >&2; return 1; }
  if [[ ! -f "$full_path" ]]; then
    echo "ERROR: file not found: $full_path" >&2
    return 1
  fi
  cat "$full_path"
}

workspace_fs_write() {
  local path="$1"
  local content="$2"
  local full_path
  full_path="$(workspace_resolve_path "$path")" || { echo "ERROR: path outside workspace: $path" >&2; return 1; }
  mkdir -p "$(dirname "$full_path")" 2>/dev/null || true
  # EPIC-122-D: use temp+mv for atomic write (参照 CheckpointStore)
  local tmp="${full_path}.tmp.$$"
  printf '%s' "$content" > "$tmp" || return 1
  mv "$tmp" "$full_path" || return 1
}

workspace_fs_exists() {
  local path="$1"
  local full_path
  full_path="$(workspace_resolve_path "$path")" || { echo "ERROR: path outside workspace: $path" >&2; return 1; }
  [[ -f "$full_path" ]]
}

workspace_fs_list() {
  local pattern="${1:-*}"
  local full_path
  full_path="$(workspace_resolve_path "$pattern")" || { echo "ERROR: path outside workspace: $pattern" >&2; return 1; }
  ls "$full_path" 2>/dev/null || true
}

workspace_fs_stat() {
  local path="$1"
  local full_path
  full_path="$(workspace_resolve_path "$path")" || { echo "ERROR: path outside workspace: $path" >&2; return 1; }
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

# === Command Execution (TerminalBackend trait) ===

workspace_exec() {
  # Delegates to workspace_exec_backend with current backend
  # For explicit local-only execution, use workspace_exec_backend "cmd" timeout local
  workspace_exec_backend "$1" "${2:-30}" "$WORKSPACE_BACKEND"
}

# === TerminalBackend trait (EPIC-123-B) ===
# Grok-build pattern: xai-grok-tools/src/computer/types.rs TerminalBackend trait
# Supports pluggable execution backends: local / ssh / docker
# Usage:
#   workspace_backend set local|ssh|docker
#   workspace_exec "ls -la"   # uses current backend
#   workspace_exec "cmd" timeout backend

WORKSPACE_BACKEND="${WORKSPACE_BACKEND:-local}"
WORKSPACE_SSH_HOST="${WORKSPACE_SSH_HOST:-}"
WORKSPACE_SSH_USER="${WORKSPACE_SSH_USER:-}"
WORKSPACE_DOCKER_IMAGE="${WORKSPACE_DOCKER_IMAGE:-}"

workspace_backend() {
  local op="${1:-get}"
  case "$op" in
    get) echo "$WORKSPACE_BACKEND" ;;
    set)
      WORKSPACE_BACKEND="${2:-local}"
      echo "backend set to $WORKSPACE_BACKEND"
      ;;
    ssh)
      WORKSPACE_BACKEND="ssh"
      WORKSPACE_SSH_HOST="${2:?ssh host required}"
      WORKSPACE_SSH_USER="${3:-}"
      echo "backend set to ssh://${WORKSPACE_SSH_USER:-root}@${WORKSPACE_SSH_HOST}"
      ;;
    docker)
      WORKSPACE_BACKEND="docker"
      WORKSPACE_DOCKER_IMAGE="${2:?docker image required}"
      echo "backend set to docker:${WORKSPACE_DOCKER_IMAGE}"
      ;;
  esac
}

# TerminalBackend trait interface — execute command on configured backend
# Returns: stdout on success, stderr on failure, exit code preserved
workspace_exec_backend() {
  local cmd="${1:?command required}"
  local timeout="${2:-30}"
  local backend="${3:-}"
  [[ -z "$backend" ]] && backend="$WORKSPACE_BACKEND"

  case "$backend" in
    local)
      # EPIC-247: 原来这里写 `workspace_exec "$cmd" "$timeout"`, 而
      # workspace_exec 又 delegate 回 workspace_exec_backend → 无限递归 → SIGSEGV.
      # 修法: local 分支内联本地执行 (恢复 a166d500~1 里 workspace_exec 的实现).
      if [[ -z "$WORKSPACE_CWD" ]]; then
        echo "ERROR: workspace not initialized. Call workspace_init() first." >&2
        return 1
      fi
      cd "$WORKSPACE_CWD" || return 1
      if command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "$cmd" 2>&1 || {
          local rc=$?
          [[ $rc -eq 124 ]] && echo "ERROR: command timed out after ${timeout}s: $cmd" >&2
          return $rc
        }
      else
        bash -c "$cmd" 2>&1
      fi
      ;;
    ssh)
      if [[ -z "$WORKSPACE_SSH_HOST" ]]; then
        echo "ERROR: SSH backend requires workspace_backend ssh <host> [user]" >&2
        return 1
      fi
      local ssh_cmd="ssh ${WORKSPACE_SSH_USER:-root}@${WORKSPACE_SSH_HOST}"
      if [[ -n "$WORKSPACE_CWD" && "$WORKSPACE_CWD" != "/" ]]; then
        ssh_cmd="$ssh_cmd cd '$WORKSPACE_CWD' && $cmd"
      else
        ssh_cmd="$ssh_cmd $cmd"
      fi
      if command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "$ssh_cmd" 2>&1 || {
          local rc=$?
          [[ $rc -eq 124 ]] && echo "ERROR: ssh command timed out after ${timeout}s" >&2
          return $rc
        }
      else
        bash -c "$ssh_cmd" 2>&1
      fi
      ;;
    docker)
      if [[ -z "$WORKSPACE_DOCKER_IMAGE" ]]; then
        echo "ERROR: Docker backend requires workspace_backend docker <image>" >&2
        return 1
      fi
      local docker_cmd="docker run --rm -w '${WORKSPACE_CWD:-/}' ${WORKSPACE_DOCKER_IMAGE} bash -c '$cmd'"
      if command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "$docker_cmd" 2>&1 || {
          local rc=$?
          [[ $rc -eq 124 ]] && echo "ERROR: docker command timed out after ${timeout}s" >&2
          return $rc
        }
      else
        bash -c "$docker_cmd" 2>&1
      fi
      ;;
    *)
      echo "ERROR: unknown backend: $backend (local|ssh|docker)" >&2
      return 1
      ;;
  esac
}

# TaskSnapshot analog: returns execution metadata as JSON
workspace_exec_snapshot() {
  local cmd="$1"
  local timeout="${2:-30}"
  local backend="${3:-}"
  [[ -z "$backend" ]] && backend="$WORKSPACE_BACKEND"

  local start_ts end_ts rc output
  start_ts=$(date +%s%N)
  output=$(workspace_exec_backend "$cmd" "$timeout" "$backend")
  rc=$?
  end_ts=$(date +%s%N)
  local elapsed_ms=$(( (end_ts - start_ts) / 1000000 ))

  # Truncate output for snapshot (参照 grok-build DEFAULT_TOOL_OUTPUT_CHARS=20000)
  local truncated="false"
  if [[ ${#output} -gt 40000 ]]; then
    output="${output:0:40000}"
    truncated="true"
  fi

  jq -n \
    --arg cmd "$cmd" \
    --arg backend "$backend" \
    --argjson rc "$rc" \
    --argjson elapsed_ms "$elapsed_ms" \
    --arg output "$output" \
    --argjson truncated "$truncated" \
    '{
      command: $cmd,
      backend: $backend,
      exit_code: $rc,
      elapsed_ms: $elapsed_ms,
      output: $output,
      truncated: $truncated
    }'
}


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
