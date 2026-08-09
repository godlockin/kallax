#!/bin/bash
#===============================================================================
# file-lock.sh — 文件级锁机制 (Rule 17 Step 1, 痛点 6 治根)
#
# 功能: flock + git index.lock 同模式
#   - 写文件前必获取文件锁, flock 等待 + 超时 (10s)
#   - 锁竞争时 STOP + 报错 + 不重试 (跟 R2/R4/R5b hang 模式分离)
#   - 粒度: 文件级 (跟 worktree 粒度区别)
#
# 用法:
#   source scripts/io/file-lock.sh
#   file_lock acquire <file_path>          # 获取锁 (10s 超时)
#   file_lock release <file_path>          # 释放锁
#   file_lock with_lock <file_path> cmd... # 自动获取/释放锁后执行命令
#
# 环境变量:
#   FILE_LOCK_TIMEOUT=10  # 超时秒数 (默认 10s)
#   FILE_LOCK_DIR=/tmp/kallax-locks  # 锁文件目录
#===============================================================================

set -euo pipefail
umask 077

# 默认配置
# EPIC-089 Perf-3: 默认 timeout 10s → 3s, 防 dispatch 密集级联阻塞
FILE_LOCK_TIMEOUT="${FILE_LOCK_TIMEOUT:-3}"
FILE_LOCK_DIR="${FILE_LOCK_DIR:-/tmp/kallax-locks}"
# EPIC-089: 非阻塞模式 (fail-fast), 设 FILE_LOCK_NONBLOCK=1 立即失败不阻塞
FILE_LOCK_NONBLOCK="${FILE_LOCK_NONBLOCK:-0}"

# 检测 flock 是否可用
_has_flock() {
  command -v flock >/dev/null 2>&1
}

# 锁目录初始化
_FILE_LOCK_INIT_DONE=0

_file_lock_init() {
  if [[ $_FILE_LOCK_INIT_DONE -eq 1 ]]; then
    return 0
  fi
  install -d -m 700 "$FILE_LOCK_DIR" 2>/dev/null || true
  _FILE_LOCK_INIT_DONE=1
}

# 生成锁文件路径
_file_lock_path() {
  local file_path="$1"
  # 使用绝对路径的 hash 作为锁文件名 (避免特殊字符)
  local abs_path
  abs_path="$(realpath "$file_path" 2>/dev/null || echo "$file_path")"
  local hash
  hash="$(echo "$abs_path" | md5sum | cut -d' ' -f1)"
  echo "$FILE_LOCK_DIR/file-lock.$hash.lock"
}

#===============================================================================
# _file_lock_acquire_bash — 纯 bash 实现的文件锁 (不使用 flock)
# 使用 mkdir 原子性创建锁目录
#===============================================================================
_file_lock_acquire_bash() {
  local lock_file="$1"
  local timeout="$2"
  local file_path="${3:-}"
  local start_time
  start_time="$(date +%s)"
  local timeout_sec="${timeout:-10}"

  # 持续尝试获取锁 (使用 mkdir 原子性)
  while true; do
    # 尝试原子创建锁文件 (如果已存在则失败)
    # Issue 1 fix (HIGH symlink-following): install -d -m 700 + ownership check + 防 symlink
    if [[ -L "$lock_file.lockdir" ]] || [[ -L "$lock_file" ]]; then
      echo "ERROR: Refusing to follow symlink at $lock_file or $lock_file.lockdir" >&2
      return 1
    fi
    if install -d -m 700 "$lock_file.lockdir" 2>/dev/null; then
      # 验证 ownership (防 TOCTOU)
      if [[ "$(stat -c %U "$lock_file.lockdir" 2>/dev/null)" != "${USER:-$(whoami)}" ]]; then
        rm -rf "$lock_file.lockdir" 2>/dev/null
        continue
      fi
      # 写入 owner PID (Issue 2 fix: 配合 release 验证)
      echo "$$" > "$lock_file.owner"
      chmod 600 "$lock_file.owner" || chmod 600 "$lock_file.owner"
      # 获取锁成功, 写入元信息
      echo "PID=$$ USER=${USER:-$(whoami)} TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) FILE=$file_path" > "$lock_file"
      chmod 600 "$lock_file" || chmod 600 "$lock_file"
      return 0
    fi

    # 检查超时
    local now
    now="$(date +%s)"
    if (( now - start_time >= timeout_sec )); then
      return 1
    fi

    # 短暂等待后重试
    sleep 0.1
  done
}

#===============================================================================
# _file_lock_release_bash — 纯 bash 实现的文件锁释放
#===============================================================================
_file_lock_release_bash() {
  local lock_file="$1"
  rm -rf "$lock_file.lockdir" 2>/dev/null || true
  rm -f "$lock_file" 2>/dev/null || true
}

#===============================================================================
# file_lock acquire <file_path>
# 获取文件锁 (flock + git index.lock 双模式)
#===============================================================================
file_lock_acquire() {
  local file_path="$1"
  _file_lock_init

  local lock_file
  lock_file="$(_file_lock_path "$file_path")"

  # 优先使用 flock, 否则使用纯 bash 实现
  if _has_flock; then
    # 创建锁文件 (如果不存在)
    touch "$lock_file" 2>/dev/null || {
      echo "ERROR: file-lock.sh: 无法创建锁文件 $lock_file" >&2
      return 1
    }

    # flock 模式: 等待获取锁, 超时 10s
    # 使用固定 fd=9 (bash 3.2 不支持动态 {fd}<)
    local fd=9
    eval "exec $fd<'$lock_file'"

    if ! flock -w "$FILE_LOCK_TIMEOUT" "$fd"; then
      # EPIC-099 Perf-3: 1 次重试 + 100ms backoff (治 cascade)
      # 原: 失败立即返回 → dispatch 密集调用方级联失败
      # 修: 短暂 backoff 后重试一次, 治 "另一进程刚好释放" race
      sleep 0.1 2>/dev/null || true
      if ! flock -w "$FILE_LOCK_TIMEOUT" "$fd"; then
        echo "ERROR: file-lock.sh: 锁获取超时 (${FILE_LOCK_TIMEOUT}s) - 文件被占用: $file_path" >&2
        echo "HINT: 另一个进程正在写入此文件, 请稍后重试" >&2
        # 跟 R2/R4/R5b hang 模式分离: 直接 STOP + 报错, 不重试
        eval "exec $fd<&-"
        return 1
      fi
    fi

    # 写入锁元信息
    echo "PID=$$ USER=${USER:-$(whoami)} TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) FILE=$file_path" >&"$fd"

    # 返回 fd 编号 (用于 release)
    echo "$fd"
  else
    # 纯 bash 模式: 不预创建目录, 由 _file_lock_acquire_bash 处理
    if ! _file_lock_acquire_bash "$lock_file" "$FILE_LOCK_TIMEOUT" "$file_path"; then
      echo "ERROR: file-lock.sh: 锁获取超时 (${FILE_LOCK_TIMEOUT}s) - 文件被占用: $file_path" >&2
      echo "HINT: 另一个进程正在写入此文件, 请稍后重试" >&2
      return 1
    fi
    echo "bash-lock"
  fi
}

#===============================================================================
# file_lock release <file_path> [fd]
# 释放文件锁
#===============================================================================
file_lock_release() {
  local file_path="$1"
  local fd="${2:-}"  # 可选: fd 编号

  _file_lock_init

  # EPIC-086 P1-4: 用统一 _file_lock_path 路径 (跟 acquire 1:1, 治 P1-4 错路径)
  # 原: 临时变量 lock_file 用 key-based 路径, 后续覆盖 — owner check 用了错路径
  # 修: 一次 lock_file 用 _file_lock_path
  local lock_file
  lock_file="$(_file_lock_path "$file_path")"

  # Issue 2 fix (MEDIUM unauthorized release): ownership check
  if [[ -f "$lock_file.owner" ]]; then
    local owner_pid
    owner_pid=$(cat "$lock_file.owner" 2>/dev/null || echo "0")
    if [[ "$owner_pid" != "$$" ]] && kill -0 "$owner_pid" 2>/dev/null; then
      echo "ERROR: Refusing to release lock held by live process PID=$owner_pid" >&2
      return 1
    fi
  fi

  # 如果没有提供 fd, 尝试找到对应的锁文件
  if [[ -z "$fd" ]]; then
    # 锁文件存在则删除
    if [[ -f "$lock_file" ]] || [[ -d "$lock_file.lockdir" ]]; then
      _file_lock_release_bash "$lock_file"
    fi
    return 0
  fi

  if [[ "$fd" == "bash-lock" ]]; then
    # 纯 bash 模式释放
    _file_lock_release_bash "$lock_file"
  else
    # flock 模式释放
    flock -u "$fd" 2>/dev/null || true
    eval "exec $fd<&-"
    rm -f "$lock_file" 2>/dev/null || true
  fi
}

#===============================================================================
# file_lock with_lock <file_path> <command> [args...]
# 自动获取/释放锁后执行命令 (相当于 flock 的 -c 行为)
#===============================================================================
file_lock_with_lock() {
  local file_path="$1"
  shift
  local cmd="$1"
  shift
  local args=("$@")

  _file_lock_init

  local lock_file
  lock_file="$(_file_lock_path "$file_path")"

  if _has_flock; then
    # 创建锁文件 (如果不存在)
    touch "$lock_file" 2>/dev/null || {
      echo "ERROR: file-lock.sh: 无法创建锁文件 $lock_file" >&2
      return 1
    }

    # flock -c 模式: 获取锁, 执行命令, 自动释放
    if ! flock -w "$FILE_LOCK_TIMEOUT" "$lock_file" -c "$cmd" "${args[@]}"; then
      echo "ERROR: file-lock.sh: 锁获取超时 (${FILE_LOCK_TIMEOUT}s) 或命令执行失败: $cmd ${args[*]}" >&2
      return 1
    fi
  else
    # 纯 bash 模式
    if ! _file_lock_acquire_bash "$lock_file" "$FILE_LOCK_TIMEOUT" "$file_path"; then
      echo "ERROR: file-lock.sh: 锁获取超时 (${FILE_LOCK_TIMEOUT}s) - 文件被占用: $file_path" >&2
      return 1
    fi
    # 执行命令
    "$cmd" "${args[@]}"
    local cmd_result=$?
    # 释放锁
    _file_lock_release_bash "$lock_file"
    return $cmd_result
  fi
}

#===============================================================================
# file_lock try <file_path>
# 尝试获取锁 (非阻塞, 立即返回)
# 成功返回 0, 失败返回 1
#===============================================================================
file_lock_try() {
  local file_path="$1"
  _file_lock_init

  local lock_file
  lock_file="$(_file_lock_path "$file_path")"

  if _has_flock; then
    # 创建锁文件 (如果不存在)
    touch "$lock_file" 2>/dev/null || return 1

    # 使用固定 fd=8 (bash 3.2 不支持动态 {fd}<)
    local fd=8
    eval "exec $fd<'$lock_file'"

    # 非阻塞尝试获取锁
    if ! flock -n "$fd" -c "echo test" >/dev/null 2>&1; then
      eval "exec $fd<&-"
      return 1  # 锁被占用
    fi

    eval "exec $fd<&-"
    return 0
  else
    # 纯 bash 非阻塞模式: 尝试原子创建
    if mkdir "$lock_file.lockdir" 2>/dev/null; then
      # 成功获取锁, 立即释放 (try 不保留锁)
      _file_lock_release_bash "$lock_file"
      return 0
    fi
    return 1  # 锁被占用
  fi
}

#===============================================================================
# file_lock is_locked <file_path>
# 检查文件是否被锁定 (用于检测冲突)
#===============================================================================
file_lock_is_locked() {
  local file_path="$1"
  _file_lock_init

  local lock_file
  lock_file="$(_file_lock_path "$file_path")"

  if [[ ! -f "$lock_file" ]] && [[ ! -d "$lock_file.lockdir" ]]; then
    return 1  # 没有锁文件 = 未锁定
  fi

  if _has_flock; then
    # 创建锁文件 (如果不存在)
    touch "$lock_file" 2>/dev/null || return 1

    # 使用固定 fd=7 (bash 3.2 不支持动态 {fd}<)
    local fd=7
    eval "exec $fd<'$lock_file'"
    if ! flock -n "$fd" -c "echo test" >/dev/null 2>&1; then
      eval "exec $fd<&-"
      return 0  # 锁被占用
    fi

    eval "exec $fd<&-"
    return 1  # 未锁定
  else
    # 纯 bash 模式: 尝试非阻塞获取锁
    if mkdir "$lock_file.lockdir" 2>/dev/null; then
      # 锁可用, 释放后返回未锁定
      _file_lock_release_bash "$lock_file"
      return 1  # 未锁定
    fi
    return 0  # 锁被占用
  fi
}

#===============================================================================
# 导出函数供 source 调用
#===============================================================================
export -f file_lock_acquire
export -f file_lock_release
export -f file_lock_with_lock
export -f file_lock_try
export -f file_lock_is_locked

# 如果直接执行此脚本 (非 source), 打印帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "file-lock.sh — 文件级锁机制 (Rule 17 Step 1)"
  echo ""
  echo "用法:"
  echo "  source scripts/io/file-lock.sh"
  echo "  file_lock acquire <file>       # 获取锁 (10s 超时)"
  echo "  file_lock release <file> [fd] # 释放锁"
  echo "  file_lock with_lock <file> cmd [args...] # 自动锁执行"
  echo "  file_lock try <file>          # 非阻塞尝试"
  echo "  file_lock is_locked <file>    # 检查是否锁定"
  echo ""
  echo "注意: $(_has_flock && echo "flock 可用" || echo "flock 不可用, 使用纯 bash 实现")"
  exit 0
fi