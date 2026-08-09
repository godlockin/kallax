#!/usr/bin/env bash
# KALLAX state-path.sh — state.json 路径解析 (EPIC-232)
#
# 为什么存在: 12 个 permission/workspace 脚本各自写
#   STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
# 在 worktree 里 KALLAX_ROOT 指向 worktree 自己, 那里从来没有 state.json
# (没有任何机制创建), 于是 jq 返回 exit 2, set -e 中断, 调用方看到非零
# 就报"授权拒绝" — 真因是配置文件缺失, 错误信息指向了错误的方向.
#
# 设计判断: state.json 含 pid / heartbeat / instance_id, 是 runtime 状态.
# 一个 master 进程跑在一处, 不该因为进了 worktree 就变成"没角色".
# 所以 worktree 应共享主仓库的 state, 而不是每个 worktree 一份.
#
# 用法:
#   . "$(dirname "${BASH_SOURCE[0]}")/../lib/state-path.sh"
#   STATE_FILE="$(kallax_resolve_state_file "$KALLAX_ROOT")"
#
# 返回: 解析出的绝对路径 (可能不存在 — 调用方仍需自己检查 -f).
#       优先本地 $root/.kallax/state/state.json,
#       没有则回退主仓库 (git rev-parse --git-common-dir 的父目录).

kallax_resolve_state_file() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi

  local local_state="${root}/.kallax/state/state.json"
  if [[ -f "$local_state" ]]; then
    printf '%s' "$local_state"
    return 0
  fi

  # 回退到主仓库 (worktree 场景)
  local common_dir
  common_dir="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || echo "")"
  if [[ -n "$common_dir" ]]; then
    # --git-common-dir 可能返回相对路径 (".git"), 先转绝对
    if [[ "$common_dir" != /* ]]; then
      common_dir="$(cd "$root/$common_dir" 2>/dev/null && pwd || echo "")"
    fi
    if [[ -n "$common_dir" ]]; then
      local shared_state
      shared_state="$(dirname "$common_dir")/.kallax/state/state.json"
      if [[ -f "$shared_state" ]]; then
        printf '%s' "$shared_state"
        return 0
      fi
    fi
  fi

  # 都没有 — 返回本地路径, 让调用方报"缺失"而不是静默用错的路径
  printf '%s' "$local_state"
  return 0
}

# 读 role, 区分"配置缺失"跟"role 为空".
#
# 为什么不直接 jq: set -euo pipefail 下 jq 读不存在的文件返回 exit 2,
# 赋值语句整体非零 → 脚本在赋值那行就中断, 后面友好的报错永远打不出来.
#
# 退出码: 0 = 拿到 role (stdout), 1 = 文件缺失或 role 为空 (stderr 有原因)
kallax_read_role() {
  local state_file="${1:-}"
  if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
    echo "ERROR: state.json not found: ${state_file:-<empty>}" >&2
    echo "  这不是授权拒绝, 是配置缺失. 检查 .kallax/state/ 是否存在." >&2
    return 1
  fi
  local role
  role="$(jq -r '.role // ""' "$state_file" 2>/dev/null || true)"
  if [[ -z "$role" ]]; then
    echo "ERROR: No role in state.json ($state_file)" >&2
    return 1
  fi
  printf '%s' "$role"
  return 0
}
