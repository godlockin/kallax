#!/usr/bin/env bash
# KALLAX Heartbeat Conductor — EPIC-218 (借鉴 prime-agent heartbeat 原语)
# 跨 worktree 聚合状态, 主公 Sprint 期间无需手动 polling 也看 Sprint 进展.
#
# Usage:
#   heartbeat-conductor.sh tick [--interval=300]  # 一次 tick, 默认 5min
#   heartbeat-conductor.sh watch [--interval=60]  # 持续 watch, 默认 1min
#   heartbeat-conductor.sh status                 # 看当前 conductor 状态
#   heartbeat-conductor.sh --headless             # JSON 输出, CI/脚本用
#
# 借鉴 (跟 confluence/decisions/prime-agent-research-2026-08-08.md 1:1):
# - prime-agent 4 长跑原语 (heartbeat/schedule/goal/autonomous) 中的 heartbeat
# - 仅聚合状态, 0 持久化 Python kernel (跟 KALLAX Rust/Node 栈 1:1)
# - 跟现有 scripts/heartbeat-daemon.sh (per-instance) 互补, 不替代
#
# 数据源:
# - .worktrees/ 目录扫描 + 各 worktree git status --short
# - 跟 EPIC-205 retrospective + EPIC-194 北极星 metrics 数据流一致
#
# Exit codes (跟 5 immutable scripts 1:1):
#   0 = OK, 1 = FAIL (跟现有心跳检测退出码契约一致)
set -euo pipefail

MODE="interactive"
COMMAND="tick"
INTERVAL=300

# Parse args
for arg in "$@"; do
  case "$arg" in
    --headless) MODE="headless"; shift ;;
    --interval=*) INTERVAL="${arg#*=}" ;;
    tick|watch|status) COMMAND="$arg"; shift ;;
    *) ;;
  esac
done

if [ "$MODE" = "headless" ]; then
  exec 1>/dev/null 2>/dev/null
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WORKTREES_DIR="${REPO_ROOT}/.worktrees"

# 收集跨 worktree 状态 (核心聚合逻辑)
collect_state() {
  local worktrees="$1"
  local state_json="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"worktrees\":["
  local first=1
  for wt in "$worktrees"/*/; do
    [ -d "$wt" ] || continue
    local wt_name
    wt_name=$(basename "$wt")
    local branch dirty ahead behind
    branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo "detached")
    dirty=$(git -C "$wt" status --short 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git -C "$wt" rev-list --count origin/"$branch"..HEAD 2>/dev/null || echo "0")
    behind=$(git -C "$wt" rev-list --count HEAD..origin/"$branch" 2>/dev/null || echo "0")
    if [ "$first" -eq 1 ]; then first=0; else state_json+=","; fi
    state_json+="{\"name\":\"$wt_name\",\"branch\":\"$branch\",\"dirty\":$dirty,\"ahead\":$ahead,\"behind\":$behind}"
  done
  state_json+="]}"
  echo "$state_json"
}

case "$COMMAND" in
  tick|watch)
    state=$(collect_state "$WORKTREES_DIR")
    if [ "$MODE" = "interactive" ]; then
      echo "KALLAX heartbeat tick @ $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "$state" | jq -r '.worktrees[] | "  \(.name): branch=\(.branch) dirty=\(.dirty) ahead=\(.ahead) behind=\(.behind)"'
    else
      echo "$state"
    fi
    if [ "$COMMAND" = "watch" ]; then
      sleep "$INTERVAL"
      exec "$0" watch --interval="$INTERVAL"
    fi
    ;;
  status)
    state=$(collect_state "$WORKTREES_DIR")
    echo "$state" | jq .
    ;;
esac