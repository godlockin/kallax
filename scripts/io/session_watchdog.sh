#!/bin/bash
#===============================================================================
# session_watchdog.sh — Session Timeout Watchdog (Rule 23, BE-14 防御)
#
# 功能:
#   - 30min timeout 自动 abort (跟 BE-14 API Error 卡住 2 subagent 联合)
#   - API Error retry 3 次, 仍失败 abort
#   - 12h cap 80% (9.6h) 告警
#   - 集成到 session_start.sh + pre-commit hook
#
# 用法:
#   source scripts/io/session_watchdog.sh
#   session_watchdog start <session_id>           # 启动监控
#   session_watchdog check                        # 检查超时/告警
#   session_watchdog stop                         # 停止监控
#   session_watchdog status                      # 查看状态
#
# 环境变量:
#   SESSION_WATCHDOG_TIMEOUT=1800    # 超时秒数 (默认 30min)
#   SESSION_WATCHDOG_WARNING=34560   # 12h cap 80% 告警 (默认 9.6h = 34560s)
#   SESSION_WATCHDOG_RETRY=3          # API Error retry 次数 (默认 3)
#   SESSION_WATCHDOG_STATE_DIR       # 状态文件目录
#===============================================================================

set -euo pipefail
umask 077

# 默认配置
SESSION_WATCHDOG_TIMEOUT="${SESSION_WATCHDOG_TIMEOUT:-1800}"   # 30min
SESSION_WATCHDOG_WARNING="${SESSION_WATCHDOG_WARNING:-34560}"   # 9.6h (12h * 0.8 = 34560s)
SESSION_WATCHDOG_RETRY="${SESSION_WATCHDOG_RETRY:-3}"            # 3 retry
SESSION_WATCHDOG_STATE_DIR="${SESSION_WATCHDOG_STATE_DIR:-/tmp/kallax-session-watchdog}"
SESSION_WATCHDOG_API_ERRORS=0

# 检测是否在 worktree 内
_has_worktree() {
  local pwd_worktree
  pwd_worktree="$(git worktree list 2>/dev/null | grep -F "$(pwd)" || echo "")"
  [[ -n "$pwd_worktree" ]]
}

# 状态目录初始化 (BE-7: umask 077 + install -m 700)
_session_watchdog_init() {
  install -d -m 700 "$SESSION_WATCHDOG_STATE_DIR" 2>/dev/null || true
}

# 生成状态文件路径
_session_watchdog_state_file() {
  local session_id="${1:-$$}"
  echo "$SESSION_WATCHDOG_STATE_DIR/session.$session_id.state"
}

#===============================================================================
# session_watchdog start <session_id>
# 启动 session 监控 (记录开始时间)
#===============================================================================
session_watchdog_start() {
  local session_id="${1:-$$}"
  _session_watchdog_init

  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  # 检查是否已在监控
  if [[ -f "$state_file" ]]; then
    local existing_pid
    existing_pid="$(cat "$state_file" 2>/dev/null | grep '^PID=' | cut -d= -f2)"
    if kill -0 "$existing_pid" 2>/dev/null; then
      echo "WARN: session $session_id already monitored by PID $existing_pid" >&2
      return 0
    fi
  fi

  # 写入开始时间 + PID
  echo "PID=$$" > "$state_file"
  echo "SESSION_ID=$session_id" >> "$state_file"
  echo "START_TIME=$(date +%s)" >> "$state_file"
  echo "START_TIME_HUMAN=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$state_file"
  echo "API_ERRORS=0" >> "$state_file"
  chmod 600 "$state_file"

  echo "OK: session_watchdog started for session $session_id (PID=$$)"
}

#===============================================================================
# session_watchdog check
# 检查 session 是否超时/告警
# 返回: 0=正常, 1=超时/需 abort, 2=warning (12h cap 80%)
#===============================================================================
session_watchdog_check() {
  _session_watchdog_init

  local session_id="${1:-$$}"
  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  # 无状态文件 = 未启动
  if [[ ! -f "$state_file" ]]; then
    return 0
  fi

  # 读取开始时间
  local start_time
  start_time="$(grep '^START_TIME=' "$state_file" 2>/dev/null | cut -d= -f2)"
  if [[ -z "$start_time" ]]; then
    return 0
  fi

  local now
  now="$(date +%s)"
  local elapsed=$((now - start_time))

  # 检查 12h cap 80% warning
  if (( elapsed >= SESSION_WATCHDOG_WARNING )); then
    echo "WARNING: session $session_id elapsed $((elapsed / 3600))h, approaching 12h cap (80% threshold)" >&2
    echo "WARNING: Consider wrapping up or requesting extension" >&2
    return 2
  fi

  # 检查 30min timeout
  if (( elapsed >= SESSION_WATCHDOG_TIMEOUT )); then
    echo "ERROR: session $session_id TIMEOUT after $((elapsed / 60))min (threshold: 30min)" >&2
    echo "ERROR: Session will be aborted" >&2
    return 1
  fi

  # 正常
  echo "OK: session $session_id elapsed $((elapsed / 60))min (timeout in $(((SESSION_WATCHDOG_TIMEOUT - elapsed) / 60))min)"
  return 0
}

#===============================================================================
# session_watchdog api_error
# 记录 API error, 超过 3 次触发 abort
#===============================================================================
session_watchdog_api_error() {
  _session_watchdog_init

  local session_id="${1:-$$}"
  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  if [[ ! -f "$state_file" ]]; then
    echo "WARN: session $session_id not monitored, skipping api_error" >&2
    return 0
  fi

  # 增加 API error 计数
  local current_errors
  current_errors="$(grep '^API_ERRORS=' "$state_file" 2>/dev/null | cut -d= -f2 || echo "0")"
  SESSION_WATCHDOG_API_ERRORS=$((current_errors + 1))

  # 更新状态文件 (使用 atomic write, 兼容 macOS sed -i)
  {
    grep -v '^API_ERRORS=' "$state_file" 2>/dev/null || true
    echo "API_ERRORS=$SESSION_WATCHDOG_API_ERRORS"
  } > "$state_file.tmp.$$" && mv "$state_file.tmp.$$" "$state_file"

  if (( SESSION_WATCHDOG_API_ERRORS >= SESSION_WATCHDOG_RETRY )); then
    echo "ERROR: session $session_id API_ERROR count $SESSION_WATCHDOG_API_ERRORS >= $SESSION_WATCHDOG_RETRY, aborting" >&2
    session_watchdog_stop "$session_id"
    return 1
  fi

  echo "WARN: session $session_id API_ERROR $SESSION_WATCHDOG_API_ERRORS/$SESSION_WATCHDOG_RETRY, retry allowed"
  return 0
}

#===============================================================================
# session_watchdog stop
# 停止 session 监控
#===============================================================================
session_watchdog_stop() {
  local session_id="${1:-$$}"
  _session_watchdog_init

  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  rm -f "$state_file" 2>/dev/null || true
  echo "OK: session_watchdog stopped for session $session_id"
}

#===============================================================================
# session_watchdog status
# 查看 session 状态
#===============================================================================
session_watchdog_status() {
  _session_watchdog_init

  local session_id="${1:-$$}"
  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  if [[ ! -f "$state_file" ]]; then
    echo "INFO: session $session_id not monitored"
    return 0
  fi

  echo "=== Session Watchdog Status ==="
  cat "$state_file" 2>/dev/null || echo "Unable to read state"

  local start_time
  start_time="$(grep '^START_TIME=' "$state_file" 2>/dev/null | cut -d= -f2)"
  if [[ -n "$start_time" ]]; then
    local now
    now="$(date +%s)"
    local elapsed=$((now - start_time))
    echo ""
    echo "Elapsed: $((elapsed / 60))min (timeout: 30min, warning: 9.6h)"
  fi
}

#===============================================================================
# session_watchdog abort
# 强制 abort 当前 session (用于超时/失败时)
#===============================================================================
session_watchdog_abort() {
  local session_id="${1:-$$}"
  local reason="${2:-timeout}"
  _session_watchdog_init

  local state_file
  state_file="$(_session_watchdog_state_file "$session_id")"

  echo "ABORT: session $session_id aborted due to $reason at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$state_file.abort.log" 2>/dev/null || true

  session_watchdog_stop "$session_id"

  echo "ERROR: Session watchdog abort triggered (reason: $reason)" >&2
  echo "ERROR: Subagent must report FAIL and exit" >&2

  # 返回非 0, 通知调用方 abort
  return 42
}

#===============================================================================
# 导出函数供 source 调用
#===============================================================================
export -f session_watchdog_start
export -f session_watchdog_check
export -f session_watchdog_api_error
export -f session_watchdog_stop
export -f session_watchdog_status
export -f session_watchdog_abort

# 如果直接执行此脚本 (非 source), 打印帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "session_watchdog.sh — Session Timeout Watchdog (Rule 23, BE-14 防御)"
  echo ""
  echo "用法:"
  echo "  source scripts/io/session_watchdog.sh"
  echo "  session_watchdog start <session_id>  # 启动监控"
  echo "  session_watchdog check               # 检查超时/告警"
  echo "  session_watchdog api_error            # 记录 API error"
  echo "  session_watchdog stop                 # 停止监控"
  echo "  session_watchdog status              # 查看状态"
  echo "  session_watchdog abort <session_id> <reason>  # 强制 abort"
  echo ""
  echo "配置:"
  echo "  SESSION_WATCHDOG_TIMEOUT=1800      # 30min 超时 (默认)"
  echo "  SESSION_WATCHDOG_WARNING=345600    # 12h cap 80% 告警 (默认 9.6h)"
  echo "  SESSION_WATCHDOG_RETRY=3           # API Error retry 次数 (默认 3)"
  echo ""
  echo "集成:"
  echo "  - session_start.sh: 启动时自动调用 session_watchdog_start"
  echo "  - pre-commit hook: commit 前自动调用 session_watchdog_check"
  exit 0
fi