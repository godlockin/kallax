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

# Issue 2附加: redaction函数 — 剥离 Authorization/Bearer/password/token
# Order: Bearer BEFORE Authorization to avoid Authorization consuming Bearer token
redact_cmd() {
  local cmd="$1"
  # Bearer first (avoids Authorization pattern consuming the Bearer keyword)
  cmd=$(echo "$cmd" | sed -E 's/(Bearer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/gI')
  # Authorization after Bearer (now safe since Bearer already replaced)
  cmd=$(echo "$cmd" | sed -E 's/(Authorization:[[:space:]]*)[^[:space:]]+/\1[REDACTED]/gI')
  cmd=$(echo "$cmd" | sed -E 's/(password[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1[REDACTED]/gI')
  cmd=$(echo "$cmd" | sed -E 's/(token[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1[REDACTED]/gI')
  echo "$cmd"
}

# Issue 3: 严格 membership check — 替代 case glob
KNOWN_ACTIONS="danger.miao_modify danger.security_failing danger.data_destruction block.ambiguous_options block.performer_failure block.rule_exception block.epic_critical block.high_impact"

usage() {
  cat <<EOF
Usage: $0 --action <action-id> [--cmd <command>] [--context <json>]
  --action   必填, 8 个已知 action 之一
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

# Issue 1: PATH_TRAVERSAL — action 格式校验 (regex)
# Issue 3: fail-closed — 未知 action exit 2
if [[ ! "$ACTION" =~ ^(danger|block)\.[a-z_]+$ ]]; then
  echo "ERROR: invalid action id format: $ACTION" >&2
  exit 2
fi

# Issue 3: membership check (严格 allowlist)
if [[ " $KNOWN_ACTIONS " != *" $ACTION "* ]]; then
  echo "ERROR: unknown action id: $ACTION" >&2
  exit 2
fi

# Issue 2 附加(a): --cmd 拒绝含换行/控制字符
if [[ -n "$CMD" && "$CMD" =~ [[:cntrl:]] ]]; then
  echo "ERROR: --cmd cannot contain control characters" >&2
  exit 2
fi

# Issue 2 附加(c): --context 验证合法 JSON
if ! jq -e . <<< "$CONTEXT" >/dev/null 2>&1; then
  echo "ERROR: --context must be valid JSON" >&2
  exit 2
fi

# 读 mode + role
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
ACTOR=$(jq -r '.actor // "unknown"' "$STATE_FILE" 2>/dev/null)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

# Issue 3: membership check 命中 → IS_DECISION=yes
IS_DECISION="yes"

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

# Issue 2: JSONL injection 防御 — 改用 jq -n 构建审计记录
# Note: jq -n with object literal outputs pretty-printed JSON, pipe through jq -c for compact
AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
REDACTED_CMD=$(redact_cmd "$CMD")
jq -n --arg ts "$TIMESTAMP" --arg actor "$ACTOR" --arg mode "$MODE" \
  --arg action "$ACTION" --arg cmd "$REDACTED_CMD" --argjson ctx "$CONTEXT" \
  '{timestamp:$ts, actor:$actor, mode:$mode, action:$action, cmd:$cmd, context:$ctx}' \
  | jq -c \
  >> "$AUDIT_FILE"

echo "ASK: action=$ACTION mode=$MODE → wrote $ASK_FILE"
exit 2