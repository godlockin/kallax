#!/bin/bash
#===============================================================================
# outbox-isolation.sh — Outbox directory isolation per subagent
# Rule 17 Step 4: IO layer outbox isolation
# 痛点 6 治根：路径冲突防护 (表现 4: 路径冲突)
#
# 功能:
#   - subagent 各 own outbox 目录 (outbox/<role>_<instance_id>/)
#   - 写时检查路径冲突, 冲突 STOP + 报错
#   - 跟 file-lock.sh (Step 1) + atomic-write.sh (Step 2) + conflict-detect.sh (Step 3) 联动
#
# 用法:
#   source scripts/io/outbox-isolation.sh
#   outbox_init <role> <instance_id>          # 初始化 outbox 目录
#   outbox_check_ownership <file_path>       # 检查文件是否属于当前 subagent
#   outbox_resolve_path <relative_path>       # 解析为绝对路径 (带 outbox 前缀)
#   outbox_validate_write <file_path>        # 验证写操作权限
#
# 环境变量:
#   OUTBOX_BASE="${OUTBOX_BASE:-.kallax/queue/outbox}"  # outbox 根目录
#   OUTBOX_MODE=700                                   # 目录权限
#===============================================================================

set -euo pipefail
umask 077

# 默认配置
OUTBOX_BASE="${OUTBOX_BASE:-.kallax/queue/outbox}"
OUTBOX_MODE="${OUTBOX_MODE:-700}"

# 当前 subagent 身份
_OUTBOX_ROLE="${OUTBOX_ROLE:-}"
_OUTBOX_INSTANCE_ID="${OUTBOX_INSTANCE_ID:-}"
_OUTBOX_INIT_DONE=0

#===============================================================================
# _get_outbox_dir — 获取当前 subagent 的 outbox 目录
#===============================================================================
_get_outbox_dir() {
  local role="$1"
  local instance_id="$2"
  echo "${OUTBOX_BASE}/${role}_${instance_id}"
}

#===============================================================================
# _outbox_init — 初始化 outbox 目录 (BE-7 修复模式)
# Issue 1 fix (HIGH symlink-following): install -d -m 700 + ownership check + 防 symlink
#===============================================================================
_outbox_init() {
  local role="${1:-}"
  local instance_id="${2:-}"

  if [[ -z "$role" ]] || [[ -z "$instance_id" ]]; then
    echo "ERROR: outbox-isolation.sh: role and instance_id required" >&2
    return 1
  fi

  # 防 symlink 攻击 (BE-7 Issue 1)
  if [[ -L "$OUTBOX_BASE" ]] || [[ -L "$OUTBOX_BASE.outboxdir" ]]; then
    echo "ERROR: Refusing to follow symlink at $OUTBOX_BASE" >&2
    return 1
  fi

  local outbox_dir
  outbox_dir="$(_get_outbox_dir "$role" "$instance_id")"

  # 防 symlink 攻击
  if [[ -L "$outbox_dir" ]] || [[ -L "$outbox_dir.outboxdir" ]]; then
    echo "ERROR: Refusing to follow symlink at $outbox_dir" >&2
    return 1
  fi

  # Issue 1 fix (BE-7): install -d -m 700 + ownership check
  if ! install -d -m 700 "$outbox_dir" 2>/dev/null; then
    echo "ERROR: outbox-isolation.sh: Failed to create outbox directory: $outbox_dir" >&2
    return 1
  fi

  # 验证 ownership (防 TOCTOU) - macOS/Linux 兼容
  local dir_owner
  case "$(uname -s)" in
    Darwin) dir_owner="$(stat -f "%Su" "$outbox_dir" 2>/dev/null)" ;;
    *) dir_owner="$(stat -c %U "$outbox_dir" 2>/dev/null)" ;;
  esac

  if [[ -n "$dir_owner" ]] && [[ "$dir_owner" != "${USER:-$(whoami)}" ]]; then
    rm -rf "$outbox_dir" 2>/dev/null
    echo "ERROR: Ownership mismatch for $outbox_dir (expected: ${USER:-$(whoami)}, got: $dir_owner)" >&2
    return 1
  fi

  # 保存身份到全局变量
  _OUTBOX_ROLE="$role"
  _OUTBOX_INSTANCE_ID="$instance_id"
  _OUTBOX_INIT_DONE=1

  echo "OK: outbox-isolation.sh: Initialized outbox: $outbox_dir"
  return 0
}

#===============================================================================
# outbox_init <role> <instance_id>
# 初始化 outbox 目录 (供外部调用)
#===============================================================================
outbox_init() {
  _outbox_init "$1" "$2"
}

#===============================================================================
# _outbox_check_ownership — 检查文件是否属于当前 subagent
#===============================================================================
_outbox_check_ownership() {
  local file_path="$1"

  if [[ -z "$_OUTBOX_ROLE" ]] || [[ -z "$_OUTBOX_INSTANCE_ID" ]]; then
    echo "ERROR: outbox-isolation.sh: outbox not initialized (call outbox_init first)" >&2
    return 1
  fi

  if [[ ! -f "$file_path" ]] && [[ ! -d "$file_path" ]]; then
    echo "ERROR: File does not exist: $file_path" >&2
    return 1
  fi

  local outbox_dir
  outbox_dir="$(_get_outbox_dir "$_OUTBOX_ROLE" "$_OUTBOX_INSTANCE_ID")"

  # 获取文件的真实路径 (解析 symlink)
  local real_path
  real_path="$(realpath "$file_path" 2>/dev/null || echo "$file_path")"

  # 获取 outbox 的真实路径
  local real_outbox
  real_outbox="$(realpath "$outbox_dir" 2>/dev/null || echo "$outbox_dir")"

  # 检查文件是否在 outbox 目录内
  case "$real_path" in
    "$real_outbox"/*)
      return 0  # 文件属于当前 subagent
      ;;
    *)
      echo "ERROR: File does not belong to current subagent outbox: $file_path" >&2
      echo "HINT: Expected path prefix: $real_outbox" >&2
      return 1
      ;;
  esac
}

#===============================================================================
# outbox_check_ownership <file_path>
# 检查文件是否属于当前 subagent (供外部调用)
#===============================================================================
outbox_check_ownership() {
  _outbox_check_ownership "$1"
}

#===============================================================================
# _outbox_resolve_path — 解析相对路径为 outbox 内的绝对路径
#===============================================================================
_outbox_resolve_path() {
  local relative_path="$1"

  if [[ -z "$_OUTBOX_ROLE" ]] || [[ -z "$_OUTBOX_INSTANCE_ID" ]]; then
    echo "ERROR: outbox-isolation.sh: outbox not initialized (call outbox_init first)" >&2
    return 1
  fi

  local outbox_dir
  outbox_dir="$(_get_outbox_dir "$_OUTBOX_ROLE" "$_OUTBOX_INSTANCE_ID")"

  # 防止路径遍历攻击 (../../)
  case "$relative_path" in
    *../*)
      echo "ERROR: Refusing path traversal in: $relative_path" >&2
      return 1
      ;;
  esac

  echo "${outbox_dir}/${relative_path}"
}

#===============================================================================
# outbox_resolve_path <relative_path>
# 解析相对路径为 outbox 内的绝对路径 (供外部调用)
#===============================================================================
outbox_resolve_path() {
  _outbox_resolve_path "$1"
}

#===============================================================================
# _outbox_validate_write — 验证写操作权限 (冲突检测)
# Rule 17 Step 4: 写时检查路径冲突, 冲突 STOP + 报错
#===============================================================================
_outbox_validate_write() {
  local file_path="$1"

  if [[ -z "$_OUTBOX_ROLE" ]] || [[ -z "$_OUTBOX_INSTANCE_ID" ]]; then
    echo "ERROR: outbox-isolation.sh: outbox not initialized (call outbox_init first)" >&2
    return 1
  fi

  # Step 1: 防 symlink 攻击
  if [[ -L "$file_path" ]]; then
    echo "ERROR: Refusing to write to symlink: $file_path" >&2
    return 1
  fi

  # Step 2: 检查文件是否已存在且不属于当前 subagent
  if [[ -e "$file_path" ]]; then
    if ! _outbox_check_ownership "$file_path"; then
      echo "ERROR: Path conflict detected: $file_path" >&2
      echo "HINT: Another subagent owns this file" >&2
      # 冲突 STOP + 报错 (跟 R2/R4/R5b hang 模式分离)
      return 1
    fi
  else
    # Step 3: 检查目标目录是否存在且属于当前 subagent
    local target_dir
    target_dir="$(dirname "$file_path")"

    if [[ -e "$target_dir" ]]; then
      if ! _outbox_check_ownership "$target_dir"; then
        echo "ERROR: Directory conflict detected: $target_dir" >&2
        echo "HINT: Another subagent owns this directory" >&2
        return 1
      fi
    else
      # 目录不存在, 检查父目录
      local parent_dir
      parent_dir="$(dirname "$target_dir")"

      if [[ -e "$parent_dir" ]] && [[ ! -L "$parent_dir" ]]; then
        if ! _outbox_check_ownership "$parent_dir"; then
          echo "ERROR: Parent directory conflict detected: $parent_dir" >&2
          echo "HINT: Another subagent owns this directory" >&2
          return 1
        fi
      fi
    fi
  fi

  return 0
}

#===============================================================================
# outbox_validate_write <file_path>
# 验证写操作权限 (供外部调用)
#===============================================================================
outbox_validate_write() {
  _outbox_validate_write "$1"
}

#===============================================================================
# _outbox_list — 列出当前 subagent 的 outbox 内容
#===============================================================================
_outbox_list() {
  if [[ -z "$_OUTBOX_ROLE" ]] || [[ -z "$_OUTBOX_INSTANCE_ID" ]]; then
    echo "ERROR: outbox-isolation.sh: outbox not initialized (call outbox_init first)" >&2
    return 1
  fi

  local outbox_dir
  outbox_dir="$(_get_outbox_dir "$_OUTBOX_ROLE" "$_OUTBOX_INSTANCE_ID")"

  if [[ ! -d "$outbox_dir" ]]; then
    echo "OK: Empty outbox: $outbox_dir"
    return 0
  fi

  echo "OUTBOX-CONTENTS: $outbox_dir"
  ls -la "$outbox_dir" 2>/dev/null || {
    echo "ERROR: Failed to list outbox contents" >&2
    return 1
  }
}

#===============================================================================
# outbox_list — 列出当前 subagent 的 outbox 内容 (供外部调用)
#===============================================================================
outbox_list() {
  _outbox_list
}

#===============================================================================
# _outbox_cleanup — 清理当前 subagent 的 outbox
#===============================================================================
_outbox_cleanup() {
  if [[ -z "$_OUTBOX_ROLE" ]] || [[ -z "$_OUTBOX_INSTANCE_ID" ]]; then
    echo "ERROR: outbox-isolation.sh: outbox not initialized (call outbox_init first)" >&2
    return 1
  fi

  local outbox_dir
  outbox_dir="$(_get_outbox_dir "$_OUTBOX_ROLE" "$_OUTBOX_INSTANCE_ID")"

  if [[ ! -d "$outbox_dir" ]]; then
    echo "OK: Outbox already clean: $outbox_dir"
    return 0
  fi

  # 验证 ownership 后再删除
  local real_outbox
  real_outbox="$(realpath "$outbox_dir" 2>/dev/null || echo "$outbox_dir")"

  # 防 symlink
  if [[ -L "$outbox_dir" ]]; then
    echo "ERROR: Refusing to remove symlink: $outbox_dir" >&2
    return 1
  fi

  rm -rf "$outbox_dir" 2>/dev/null || {
    echo "ERROR: Failed to cleanup outbox: $outbox_dir" >&2
    return 1
  }

  echo "OK: Outbox cleaned: $outbox_dir"
  return 0
}

#===============================================================================
# outbox_cleanup — 清理当前 subagent 的 outbox (供外部调用)
#===============================================================================
outbox_cleanup() {
  _outbox_cleanup
}

#===============================================================================
# 导出函数供 source 调用
#===============================================================================
export -f outbox_init
export -f outbox_check_ownership
export -f outbox_resolve_path
export -f outbox_validate_write
export -f outbox_list
export -f outbox_cleanup

# 如果直接执行此脚本 (非 source), 打印帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "outbox-isolation.sh — Outbox directory isolation (Rule 17 Step 4)"
  echo ""
  echo "用法:"
  echo "  source scripts/io/outbox-isolation.sh"
  echo "  outbox_init <role> <instance_id>         # 初始化 outbox"
  echo "  outbox_check_ownership <file>            # 检查文件归属"
  echo "  outbox_resolve_path <relative_path>      # 解析路径"
  echo "  outbox_validate_write <file>             # 验证写权限"
  echo "  outbox_list                             # 列出内容"
  echo "  outbox_cleanup                          # 清理 outbox"
  echo ""
  echo "示例:"
  echo "  source scripts/io/outbox-isolation.sh"
  echo "  outbox_init conductor performer-12345"
  echo "  outbox_validate_write /path/to/file.txt"
  exit 0
fi