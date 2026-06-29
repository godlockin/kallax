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

# Issue 2附加: redaction函数 — 剥离 Authorization/Bearer/password/token/Token/X-Auth-Token
# Single-pass combined regex + basic auth URL + 兜底长串
# Issue 1: broadened to cover Token/X-Auth-Token/basic auth URL/long hex/base64
# Issue 2: Authorization/Bearer 合并为单 regex, 避免 2-pass 互相干扰
# Issue 1+2+3 (Round 3): 8-pass redaction — header(:) / CLI flag(=) / GNU style / -a-p short / URL scheme扩 / known prefix / JWT / env-var
redact_cmd() {
  local cmd="$1"

  # 1. Header (curl -H "Authorization: ..." / "Token: ..." / "X-Auth-Token: ...")
  #    保留原始 `:` 分隔符, Bearer 也可保留
  cmd=$(echo "$cmd" | sed -E 's/(Authorization|Token|X-Auth-Token):[[:space:]]*(Bearer[[:space:]]+)?[^[:space:]]+/\1: \2[REDACTED]/gI')

  # 2. CLI flag (--password=xxx / password=xxx) — 保留原 `=`
  cmd=$(echo "$cmd" | sed -E 's/(password|secret)=[[:space:]]*[^[:space:]]+/\1=[REDACTED]/gI')

  # 3. GNU-style --password value (无 `=`, 空格分隔)
  cmd=$(echo "$cmd" | sed -E 's/--password[[:space:]]+[^[:space:]]+/--password [REDACTED]/gI')

  # 4. -a / -p 短 flag (curl/psql 等)
  cmd=$(echo "$cmd" | sed -E 's/(-a|-p)[[:space:]]+([^[:space:]-][^[:space:]]+)/\1 [REDACTED]/g')

  # 5. Basic auth URL — 扩 scheme list (https / postgres(ql)? / mysql / mongodb(+srv)? / redis / amqp / amqps)
  cmd=$(echo "$cmd" | sed -E 's#(https?|postgres(ql)?|mysql|mongodb(\+srv)?|redis|amqps?)://[^:/@]+:[^@]+@#\1://[REDACTED]:[REDACTED]@#gI')

  # 6. 已知 token prefix (ghp_/gho_/github_pat_/sk-/sk-ant-/sk_live_/xox[abp]-/AKIA[0-9A-Z]{16}/cognito/aws_cognito)
  cmd=$(echo "$cmd" | sed -E 's/(ghp_|gho_|github_pat_|sk-ant-|sk-|sk_live_|xox[abp]-|AKIA[0-9A-Z]{16}|us-east-1:[a-f0-9-]+)[A-Za-z0-9_=:-]+/\1[REDACTED]/g')

  # 6b. GCP OAuth 2.0 tokens (ya29./Cik./1//)
  cmd=$(echo "$cmd" | sed -E 's/(ya29\.|Cik\.|1\/\w{10,})[A-Za-z0-9_.-]+/\1[REDACTED]/g')

  # 7. JWT pattern
  cmd=$(echo "$cmd" | sed -E 's/eyJ[A-Za-z0-9_=-]+\.eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+/[REDACTED-JWT]/g')

  # 8. Env-var assignment (KEY=value, 16+ hex / 20+ base64)
  cmd=$(echo "$cmd" | sed -E 's/([[:space:]]|^)([A-Z_][A-Z0-9_]+)=([A-Fa-f0-9]{16,}|[A-Za-z0-9+/=]{20,})/\1\2=[REDACTED-ENV]/g')

  # 9. Fallback: 24+ alphanumeric string with at least 1 digit (catches tokens; avoids over-redacting commit msgs)
  cmd=$(echo "$cmd" | sed -E 's/[A-Za-z0-9]*[0-9][A-Za-z0-9]{23,}/[REDACTED]/g')

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

# Iter 10: 打印决策矩阵 (Q18 决策模型 5×5 = 25 cells) — opt-in via DECISION_MATRIX_PRINT=1
# 默认不打印 (避免输出太长, 干扰 decision-gate-test.sh)
# 设置 DECISION_MATRIX_PRINT=1 启动时打印 (帮 Conductor 知道何时该问主公)
DECISION_MATRIX="${KALLAX_ROOT}/scripts/permission/decision-matrix.sh"
if [[ "${DECISION_MATRIX_PRINT:-0}" == "1" && -x "$DECISION_MATRIX" ]]; then
  echo "--- Decision Matrix (Q18 5 levels × 5 roles) ---"
  bash "$DECISION_MATRIX" --format markdown 2>/dev/null || true
  echo "--- End Decision Matrix ---"
  echo ""
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
# 武器 1 (Iter 4): 用 audit-chain.sh append 替代 raw >>, 加 prev_hash + chain_hash
AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
REDACTED_CMD=$(redact_cmd "$CMD")
AUDIT_ENTRY=$(jq -n --arg ts "$TIMESTAMP" --arg actor "$ACTOR" --arg mode "$MODE" \
  --arg action "$ACTION" --arg cmd "$REDACTED_CMD" --argjson ctx "$CONTEXT" \
  '{timestamp:$ts, actor:$actor, mode:$mode, action:$action, cmd:$cmd, context:$ctx}' \
  | jq -c)
AUDIT_CHAIN="${KALLAX_ROOT}/scripts/audit/audit-chain.sh"
if [[ -x "$AUDIT_CHAIN" ]]; then
    bash "$AUDIT_CHAIN" append "$AUDIT_FILE" "$AUDIT_ENTRY" || {
        echo "WARN: audit-chain append failed, falling back to raw write" >&2
        echo "$AUDIT_ENTRY" >> "$AUDIT_FILE"
        chmod 600 "$AUDIT_FILE" 2>/dev/null || true
    }
else
    echo "$AUDIT_ENTRY" >> "$AUDIT_FILE"
    chmod 600 "$AUDIT_FILE" 2>/dev/null || true
fi

echo "ASK: action=$ACTION mode=$MODE → wrote $ASK_FILE"
exit 2
