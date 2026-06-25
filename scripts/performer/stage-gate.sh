#!/bin/bash
# stage-gate.sh — Performer 5 阶段协商, 3 模式分流
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

usage() {
  cat <<EOF
Usage: $0 --stage <claim|analysis|in_progress|test|review> --ticket <TASK-XXX>
EOF
  exit 1
}

STAGE=""
TICKET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage) STAGE="$2"; shift 2 ;;
    --ticket) TICKET="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$STAGE" ]] || [[ -z "$TICKET" ]] && { echo "ERROR: --stage and --ticket required"; usage; }

MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)

# Map stage to complexity (bash 3.2 compat: no declare -A)
case "$STAGE" in
  claim|in_progress) STAGE_COMPLEXITY=simple ;;
  analysis|test|review) STAGE_COMPLEXITY=complex ;;
  *) STAGE_COMPLEXITY=unknown ;;
esac
[[ "$STAGE_COMPLEXITY" == "unknown" ]] && { echo "ERROR: unknown stage $STAGE"; exit 1; }

# Simple stages (claim/in_progress): AI handles autonomously in ALL 3 modes
# (manual mode "ask every stage" is enforced at orchestration layer via decision-gate.sh,
#  not at this stage-gate layer — 跟 AC L2 一致)
if [[ "$STAGE_COMPLEXITY" == "simple" ]]; then
  case "$MODE" in
    ai-auto|ai-copilot|manual)
      echo "ALLOW: stage=$STAGE mode=$MODE (simple)"
      exit 0
      ;;
    *)
      echo "ERROR: unknown mode $MODE" >&2
      exit 1
      ;;
  esac
fi

# complex stages: ai-auto allows, ai-copilot/manual ask
case "$MODE" in
  ai-auto)
    echo "ALLOW: stage=$STAGE mode=$MODE (complex but auto)"
    exit 0
    ;;
  ai-copilot)
    ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/ask-stage-${TICKET}-${STAGE}.md"
    mkdir -p "$(dirname "$ASK_FILE")"
    cat > "$ASK_FILE" <<EOF
# Ask: stage=$STAGE ticket=$TICKET

## Context
- Mode: ai-copilot
- Stage: $STAGE (complex)
- Time: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

## 选项
1. Approve — 继续执行
2. Modify — 调整后继续
3. Reject — 回退到上一阶段
EOF
    echo "ASK: stage=$STAGE ticket=$TICKET → wrote $ASK_FILE, exit 2"
    exit 2
    ;;
  manual)
    ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/ask-manual-${TICKET}-${STAGE}.md"
    mkdir -p "$(dirname "$ASK_FILE")"
    cat > "$ASK_FILE" <<EOF
# Manual Confirm: stage=$STAGE ticket=$TICKET

## Mode: manual (主公确认每阶段)

### 选项
1. Approve — 继续执行
2. Cancel — 终止 ticket
EOF
    echo "ASK_MANUAL: stage=$STAGE ticket=$TICKET → wrote $ASK_FILE, exit 2"
    exit 2
    ;;
  *)
    echo "ERROR: unknown mode $MODE"
    exit 1
    ;;
esac