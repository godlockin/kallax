#!/usr/bin/env bash
# scripts/lib/session-start-safety.sh
# EPIC-026-B: session_start.sh 黑洞风险防 — 启动前 5 项 safety check
# fail-closed: 任何一项失败则 exit 1 + 明确错误信息
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"

# ============================================================
# 5 项 safety check — 全部通过才返回 0
# ============================================================

# check_1: fd 0/1/2 全部指向 tty 或 file, 不指向 pipe
check_fd_safety() {
  # 检查 fd 0 (stdin)
  if [ -e "/dev/stdin" ]; then
    if [ ! -t "/dev/stdin" ]; then
      # 不是 tty, 检查是否是 pipe/FIFO
      if [ -p "/dev/stdin" ] 2>/dev/null; then
        echo "[safety] FAIL: fd 0 (stdin) is a pipe/FIFO — risk of blocking" >&2
        return 1
      fi
    fi
  fi

  # 检查 fd 1 (stdout) — 如果不是 tty 且是 pipe, 警告
  if [ -e "/dev/stdout" ]; then
    if [ ! -t "/dev/stdout" ]; then
      if [ -p "/dev/stdout" ] 2>/dev/null; then
        echo "[safety] WARN: fd 1 (stdout) is a pipe — may block if reader closes" >&2
        # Warning 不是 fail-closed, 继续
      fi
    fi
  fi

  # 检查 fd 2 (stderr)
  if [ -e "/dev/stderr" ]; then
    if [ ! -t "/dev/stderr" ]; then
      if [ -p "/dev/stderr" ] 2>/dev/null; then
        echo "[safety] FAIL: fd 2 (stderr) is a pipe/FIFO — risk of blocking" >&2
        return 1
      fi
    fi
  fi

  return 0
}

# check_2: no zombie heartbeat-daemon
check_no_zombie_daemon() {
  local zombie_pids
  zombie_pids=$(pgrep -f "heartbeat-daemon" 2>/dev/null | head -5 || true)
  if [ -n "$zombie_pids" ]; then
    for pid in $zombie_pids; do
      # zombie 状态: 进程已退出但未被 wait
      # 检查进程是否存在 (如果不存在说明是 zombie 或已清理)
      if ! kill -0 "$pid" 2>/dev/null; then
        # 进程不存在 (zombie 或已退出)
        echo "[safety] FAIL: zombie heartbeat-daemon found (pid=$pid)" >&2
        return 1
      fi
    done
  fi
  return 0
}

# check_3: no stale .kallax/state/*.lock
check_no_stale_locks() {
  local lock_dir="${KALLAX_ROOT}/state"
  if [ ! -d "$lock_dir" ]; then
    return 0  # 没有 lock 目录, 通过
  fi

  local stale_locks
  stale_locks=$(find "$lock_dir" -name "*.lock" -type f 2>/dev/null | head -5 || true)
  if [ -n "$stale_locks" ]; then
    # 检查每个 lock 文件是否超过 5 分钟
    local now
    now=$(date +%s)
    for lock_file in $stale_locks; do
      local mtime
      mtime=$(stat -f %m "$lock_file" 2>/dev/null || stat -c %Y "$lock_file" 2>/dev/null || echo 0)
      local age=$((now - mtime))
      if [ "$age" -gt 300 ]; then  # 5 分钟
        echo "[safety] FAIL: stale lock file found: $lock_file (age=${age}s)" >&2
        return 1
      fi
    done
  fi
  return 0
}

# check_4: .kallax/state/ 写入权限
check_state_writeable() {
  if [ ! -d "${KALLAX_ROOT}/state" ]; then
    # 目录不存在, 尝试创建
    mkdir -p "${KALLAX_ROOT}/state" 2>/dev/null || {
      echo "[safety] FAIL: cannot create ${KALLAX_ROOT}/state/" >&2
      return 1
    }
  fi

  # 测试写入权限
  local test_file="${KALLAX_ROOT}/state/.write_test.$$"
  if ! touch "$test_file" 2>/dev/null; then
    echo "[safety] FAIL: no write permission for ${KALLAX_ROOT}/state/" >&2
    return 1
  fi
  rm -f "$test_file"
  return 0
}

# check_5: session_start.sh bash -n 通过
check_syntax() {
  local session_start_script="${KALLAX_ROOT}/hooks/session_start.sh"
  if [ ! -f "$session_start_script" ]; then
    echo "[safety] FAIL: session_start.sh not found at $session_start_script" >&2
    return 1
  fi

  if ! bash -n "$session_start_script" 2>&1; then
    echo "[safety] FAIL: session_start.sh has syntax errors (bash -n failed)" >&2
    return 1
  fi

  return 0
}

# ============================================================
# session_start_safety — 执行全部 5 项检查
# 返回: 0 = 通过, 1 = 失败
# ============================================================
session_start_safety() {
  local check_num=1
  local failed=0

  echo "[safety] Running 5-point safety check for session_start.sh..." >&2

  # Check 1: fd safety
  echo "[safety]   Check $check_num: fd 0/1/2 safety..." >&2
  if ! check_fd_safety; then
    failed=1
  fi
  check_num=$((check_num + 1))

  # Check 2: no zombie daemon
  echo "[safety]   Check $check_num: no zombie heartbeat-daemon..." >&2
  if ! check_no_zombie_daemon; then
    failed=1
  fi
  check_num=$((check_num + 1))

  # Check 3: no stale locks
  echo "[safety]   Check $check_num: no stale *.lock files..." >&2
  if ! check_no_stale_locks; then
    failed=1
  fi
  check_num=$((check_num + 1))

  # Check 4: state writeable
  echo "[safety]   Check $check_num: .kallax/state/ writeable..." >&2
  if ! check_state_writeable; then
    failed=1
  fi
  check_num=$((check_num + 1))

  # Check 5: syntax check
  echo "[safety]   Check $check_num: session_start.sh syntax..." >&2
  if ! check_syntax; then
    failed=1
  fi

  if [ "$failed" -eq 1 ]; then
    echo "[safety] FAIL: session_start_safety failed — fail-closed, not starting session" >&2
    return 1
  fi

  echo "[safety] PASS: all 5 safety checks passed" >&2
  return 0
}

# 如果直接运行此脚本, 执行 safety check
if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  session_start_safety
  exit $?
fi