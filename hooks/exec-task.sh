#!/usr/bin/env bash
# exec-task.sh - 全局 CLI 执行模板(配合 ~/.claude/CLAUDE.md rule)
#
# 用法:
#   bash ~/.claude/exec-task.sh "<task-name>" "<command> [args...]"
#   bash ~/.claude/exec-task.sh --tail 20 "<name>" "<cmd>"   # 自定义 tail 行数
#
# 行为(强制):
#   1. 后台执行(输出到 tmp 日志)
#   2. 日志路径: /tmp/claude-tasks/<task-name>-<timestamp>.log
#   3. 等待结束,check exit code
#   4. 成功 → stdout "OK success",日志路径
#   5. 失败 → stdout "FAILED exit=<N>" + 日志路径 + 自动 tail -10
#   6. 永不返回大段日志(避免污染大模型上下文)
#
# 失败时自动返回:
#   FAILED exit=1
#   log: /tmp/claude-tasks/<name>-<ts>.log
#   --- last 10 lines ---
#   <实际日志 10 行>
#   --- end ---
#   hint: bash ~/.claude/exec-task.sh --tail 20 ...  (不够再追加 10 行)
#
# === 完整性自校验 / Integrity Self-Check ===
# 此 hash 在 commit 时由 verify-rule.sh 记录,运行时校验:
# 如被修改,启动时会警告(但不阻止 — 由 hook 强制拦截)
EXEC_TASK_INTEGRITY_v1="f436d7a7d6bf553c8c333d3f417fc538cf6734054062781c7c6405b01620dd0e"

set -uo pipefail

# === 自校验(修改后提醒) ===
# 自校验:marker 必须存在
if ! grep -qF "EXEC_TASK_INTEGRITY_v1" "$0" 2>/dev/null; then
  echo "⚠️  exec-task.sh 完整性标记缺失!可能被修改或截断" >&2
  echo "   用 bash ~/.claude/verify-rule.sh verify 检查规则完整性" >&2
fi

# 默认 tail 行数
DEFAULT_TAIL=10

# 解析参数(支持 --tail N 在最前面)
if [[ "${1:-}" == "--tail" ]]; then
  DEFAULT_TAIL="${2:-10}"
  shift 2
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: bash exec-task.sh [--tail N] '<task-name>' '<command> [args...]'" >&2
  exit 64
fi

TASK_NAME="$1"
shift

LOG_DIR="/tmp/claude-tasks"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 安全:任务名只允许 [a-zA-Z0-9_-]
SAFE_NAME=$(echo "$TASK_NAME" | tr -cd '[:alnum:]_-')
[[ -z "$SAFE_NAME" ]] && SAFE_NAME="unnamed"
LOG_FILE="$LOG_DIR/${SAFE_NAME}-${TIMESTAMP}.log"

# 写一个 meta 文件(任务名 → 日志路径,便于反向查找)
echo "$LOG_FILE" > "${LOG_DIR}/${SAFE_NAME}-${TIMESTAMP}.meta"

# 后台执行 + 重定向所有输出
# 用 bash -c + 字符串,避免 "$@" 合并问题
CMD_STR=""
sep=""
for arg in "$@"; do
  # 简单转义:含空格/特殊字符的用单引号
  if [[ "$arg" =~ [[:space:]\'\"\|\&\<\>\*\?\$\`\(\)\{\}\[\]\\] ]]; then
    safe=$(echo "$arg" | sed "s/'/'\\\\''/g")
    CMD_STR+="${sep}'${safe}'"
  else
    CMD_STR+="${sep}${arg}"
  fi
  sep=" "
done

bash -c "$CMD_STR" > "$LOG_FILE" 2>&1 &
TASK_PID=$!

# 同步等待(用 wait 不用 polling,polling 算"监控")
wait "$TASK_PID"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK success"
  # 成功后删除日志(节省 /tmp 空间,符合 Rule 5 "成功后立即清理")
  rm -f "$LOG_FILE" "${LOG_DIR}/${SAFE_NAME}-${TIMESTAMP}.meta" 2>/dev/null || true
else
  echo "FAILED exit=$EXIT_CODE"
  echo "log: $LOG_FILE"
  echo "--- last $DEFAULT_TAIL lines ---"
  tail -n "$DEFAULT_TAIL" "$LOG_FILE" 2>/dev/null || echo "(log empty)"
  echo "--- end ---"
  echo "hint: bash ~/.claude/exec-task.sh --tail $((DEFAULT_TAIL + 10)) '$TASK_NAME' '<cmd>'  (追加 10 行)"
  echo "      cat $LOG_FILE  (看完整日志)"
fi

exit $EXIT_CODE