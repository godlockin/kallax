#!/bin/bash
# waiting-for-expert.sh — 自动降级 + inbox 提示
# 依赖: EPIC-030-A (best-matching-slaver.sh 匹配失败时调用)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Respect KALLAX_ROOT env var if set (for test isolation), else compute from script location
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
WAITING_FILE="${KALLAX_ROOT}/.kallax/state/waiting-for-expert.json"
INBOX_DIR="${KALLAX_ROOT}/.kallax/inbox"

# append_waiting_for_expert — 写 waiting-for-expert.json + inbox 提示
# 用法: append_waiting_for_expert <TICKET_ID> <REQUIRED_EXPERTISE>
append_waiting_for_expert() {
  local ticket_id="$1"
  local required_expertise="$2"

  mkdir -p "${KALLAX_ROOT}/.kallax/state" "${INBOX_DIR}"

  # 初始化空 JSON 如果不存在
  if [[ ! -f "$WAITING_FILE" ]]; then
    printf '{}' > "$WAITING_FILE"
  fi

  # 读取当前重试次数 (jq 兼容 bash 3.2)
  local retries
  retries=$(jq -r --arg tid "$ticket_id" '.[$tid].retries // 0' "$WAITING_FILE" 2>/dev/null || echo "0")
  local new_retries=$((retries + 1))

  # 更新 waiting-for-expert.json (jq -n 防 injection)
  local tmp_file="${WAITING_FILE}.tmp"
  jq -n \
    --arg tid "$ticket_id" \
    --arg exp "$required_expertise" \
    --argjson r "$new_retries" \
    --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --argjson existing "$(cat "$WAITING_FILE")" \
    'def merge_existing($e; $t; $r; $n):
      if ($e | has($t)) then
        $e | .[$t].retries = $r | .[$t].last_attempt = $n
      else
        $e + {($t): {required_expertise: $exp, retries: $r, last_attempt: $n}}
      end;
    merge_existing($existing; $tid; $r; $now)' \
    > "$tmp_file"
  mv "$tmp_file" "$WAITING_FILE"

  # 写 inbox 提示
  cat > "${INBOX_DIR}/need-expert-${ticket_id}.md" <<EOF
# Need Expert: ${ticket_id}

## 任务
TICKET: ${ticket_id}
Required Expertise: ${required_expertise}
Retries: ${new_retries}

## 建议
1. 手动注册匹配 expert (worktree_role / skills 字段)
2. 修改 ticket 的 required_expertise 字段
3. 接受 fallback 标签评分
EOF

  echo "INFO: appended ${ticket_id} to waiting-for-expert (retries=${new_retries})"
}

# get_priority_waiting — 下次 heartbeat 优先重试 (retries DESC)
# 用法: get_priority_waiting
# 输出: 每行一个 ticket_id，按重试次数降序
get_priority_waiting() {
  if [[ ! -f "$WAITING_FILE" ]]; then
    return
  fi
  jq -r 'to_entries | sort_by(-.value.retries) | .[].key' "$WAITING_FILE" 2>/dev/null || true
}

# remove_from_waiting — 匹配成功后删除
# 用法: remove_from_waiting <TICKET_ID>
remove_from_waiting() {
  local ticket_id="$1"
  if [[ ! -f "$WAITING_FILE" ]]; then
    return
  fi
  local tmp_file="${WAITING_FILE}.tmp"
  jq --arg tid "$ticket_id" 'del(.[$tid])' "$WAITING_FILE" > "$tmp_file" && mv "$tmp_file" "$WAITING_FILE"
  echo "INFO: removed ${ticket_id} from waiting-for-expert"
}

# 入口点: 根据参数调用对应函数
main() {
  local command="${1:-}"
  case "$command" in
    append)
      append_waiting_for_expert "${2:-}" "${3:-}"
      ;;
    list)
      get_priority_waiting
      ;;
    remove)
      remove_from_waiting "${2:-}"
      ;;
    *)
      echo "Usage: waiting-for-expert.sh <append|list|remove> [args...]"
      echo "  append <TICKET_ID> <REQUIRED_EXPERTISE>  — 添加到等待队列"
      echo "  list                                   — 按优先级列出所有等待的 ticket"
      echo "  remove <TICKET_ID>                     — 从等待队列移除"
      exit 1
      ;;
  esac
}

# 如果直接执行 (非 source)，调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi