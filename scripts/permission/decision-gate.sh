#!/bin/bash
# decision-gate.sh — Block 决策 + 危险操作统一检查
# 5 类 Block: ambiguous_options / performer_failure / rule_exception / epic_critical / high_impact
# 3 类 Danger: miao_modify / security_failing / data_destruction
# 3 模式都触发, 命中即 exit 2 写 ask file
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

usage() {
  cat <<EOF
Usage: $0 --action <action-id> [--cmd <command>] [--context <json>]
  --action   必填, 5 block + 3 danger 之一
  --cmd      可选, 触发命令 (写 audit 用)
  --context  可选, JSON 上下文
EOF
  exit 1
}

ACTION=""
CMD=""
CONTEXT="{}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --cmd) CMD="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  echo "ERROR: --action required"
  usage
fi

# 读 mode + role
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
ACTOR=$(jq -r '.actor // "unknown"' "$STATE_FILE" 2>/dev/null)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

# 分类 action
DANGER_ACTIONS="danger.miao_modify danger.security_failing danger.data_destruction"
BLOCK_ACTIONS="block.ambiguous_options block.performer_failure block.rule_exception block.epic_critical block.high_impact"

IS_DECISION=""
case "$ACTION" in
  danger.*|block.*) IS_DECISION="yes" ;;
  *) echo "ALLOW: action=$ACTION (not in block/danger list)"; exit 0 ;;
esac

# 写 ask file
ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/decision-${ACTION//./_}-$(date +%s).md"
mkdir -p "$(dirname "$ASK_FILE")" "$AUDIT_DIR"

cat > "$ASK_FILE" <<EOF
# Decision Required: $ACTION

## Context
- Mode: $MODE
- Actor: $ACTOR
- Time: $TIMESTAMP
- Command: $CMD
- Context: $CONTEXT

## 选项
1. Approve — 继续执行
2. Reject — 中止操作
3. Defer — 推迟到主公明确指示
EOF

# 写 audit JSONL
AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
echo "{\"timestamp\":\"$TIMESTAMP\",\"actor\":\"$ACTOR\",\"mode\":\"$MODE\",\"action\":\"$ACTION\",\"cmd\":\"$CMD\",\"context\":$CONTEXT}" >> "$AUDIT_FILE"

echo "ASK: action=$ACTION mode=$MODE → wrote $ASK_FILE"
exit 2