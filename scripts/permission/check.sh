#!/bin/bash
# kallax role:check <action> — 验证当前角色是否有权执行 action
#
# P0 修复项:
#   - set -euo pipefail
#   - fail-closed: 任何错误 deny
#   - role 名称 validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: kallax role:check <action>"
  echo "Example: kallax role:check task.claim"
  exit 1
fi

# 获取当前 role: PHASE-002 9c + security review, role 必从 state.json 读，禁止 env 兜底
CURRENT_ROLE="$(cat "$KALLAX_ROOT/.kallax/state/state.json" 2>/dev/null | jq -r '.role // ""')"
if [[ -z "$CURRENT_ROLE" ]]; then
  echo "ERROR: No role in state.json ($KALLAX_ROOT/.kallax/state/state.json)" >&2
  exit 1
fi

# 权限检查函数
check_permission() {
  local role="$1"
  local action="$2"

  case "$role" in
    master)
      # master 有所有权限 (除了 emergency-responder 专有)
      [[ "$action" != "instance.terminate" ]]
      ;;
    conductor)
      [[ "$action" == testing.* ]] || [[ "$action" == task.assign ]] || [[ "$action" == instance.read ]] || [[ "$action" == log.read ]]
      ;;
    performer)
      [[ "$action" == task.claim ]] || [[ "$action" == worktree.create ]] || [[ "$action" == worktree.commit ]] || [[ "$action" == ticket.read ]] || [[ "$action" == log.read ]]
      ;;
    readonly)
      [[ "$action" == *.read ]]
      ;;
    auditor)
      [[ "$action" == *.read ]] || [[ "$action" == audit.export ]]
      ;;
    super-admin)
      # super-admin 有所有权限
      true
      ;;
    emergency-responder)
      # emergency-responder 有所有权限
      true
      ;;
    *)
      echo "ERROR: Unknown role: ${role}" >&2
      return 1  # P0: fail-closed
      ;;
  esac
}

# 执行检查
if check_permission "$CURRENT_ROLE" "$ACTION"; then
  echo "ALLOWED: ${ACTION} for role ${CURRENT_ROLE}"
  exit 0
else
  echo "DENIED: ${ACTION} for role ${CURRENT_ROLE}"
  exit 1  # P0: fail-closed
fi