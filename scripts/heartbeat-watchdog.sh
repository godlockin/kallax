#!/usr/bin/env bash
# scripts/heartbeat-watchdog.sh
# EPIC-026-B: session_start.sh 黑洞风险防 — watchdog 监控
# 监控 session_start.sh 启动耗时, > 5s 报警 + kill -9
# 写 .kallax/logs/session_start_hang.jsonl 审计日志
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
LOG_DIR="${KALLAX_ROOT}/logs"
SESSION_START_TIMEOUT="${SESSION_START_TIMEOUT:-5}"  # 秒

# 确保 log 目录存在
mkdir -p "$LOG_DIR"

# log 文件路径
HANG_LOG="${LOG_DIR}/session_start_hang.jsonl"

# log_hang <pid> <elapsed_seconds> <reason>
log_hang() {
  local pid="$1"
  local elapsed="$2"
  local reason="$3"
  printf '{"ts":"%s","event":"session_start_hang","pid":%s,"elapsed":%s,"reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pid" "$elapsed" "$reason" \
    >> "$HANG_LOG" 2>/dev/null || true
}

# kill_session_start <pid>
kill_session_start() {
  local pid="$1"
  kill -9 "$pid" 2>/dev/null || true
  log_hang "$pid" "$2" "timeout_exceeded"
}

# watch_pid <pid>: 监控指定 PID, 超时则 kill
watch_pid() {
  local pid="$1"
  local start_time
  start_time=$(date +%s)
  local elapsed=0

  # 检查 PID 是否还在运行
  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$(($(date +%s) - start_time))
    if [ "$elapsed" -gt "$SESSION_START_TIMEOUT" ]; then
      echo "[watchdog] session_start.sh (pid=$pid) exceeded ${SESSION_START_TIMEOUT}s timeout, killing..." >&2
      kill_session_start "$pid" "$elapsed"
      return 124  # timeout exit code
    fi
    # 每 0.5s 检查一次
    sleep 0.5 2>/dev/null || sleep 1
  done

  # 进程已退出, 正常返回
  return 0
}

# 主函数: 接受 PID 作为参数
main() {
  local pid="${1:-}"
  if [ -z "$pid" ]; then
    echo "Usage: heartbeat-watchdog.sh <session_start_pid>" >&2
    exit 1
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "[watchdog] PID $pid does not exist or already exited" >&2
    exit 0
  fi

  echo "[watchdog] monitoring session_start.sh pid=$pid (timeout=${SESSION_START_TIMEOUT}s)" >&2
  watch_pid "$pid"
  local rc=$?

  if [ "$rc" -eq 124 ]; then
    echo "[watchdog] killed hung session_start.sh (pid=$pid)" >&2
    exit 124
  fi

  exit 0
}

main "$@"