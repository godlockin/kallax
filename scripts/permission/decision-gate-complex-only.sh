#!/usr/bin/env bash
# scripts/permission/decision-gate-complex-only.sh — ai-copilot "复杂才问" 实现
# 依据 Rule 33 (decision-gate 复杂才问 软限制落地)
# 依据 ACCUMULATED-LESSONS-2026-06-13.md §1.5 (UX 视角)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# EPIC-236: state.json 路径走共享 lib (worktree fallback, fail-closed)
_STATE_LIB="${KALLAX_ROOT}/scripts/permission/lib/state-path.sh"
if [[ -f "$_STATE_LIB" ]]; then
  . "$_STATE_LIB"
  STATE_FILE="$(kallax_resolve_state_file "$KALLAX_ROOT")"
else
  echo "ERROR: state-path.sh lib not found: $_STATE_LIB" >&2
  exit 1
fi

# 读取 mode (默认 ai-copilot)
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
# 读取 stage (默认 in_progress, 从环境变量或 context 传入)
STAGE="${CONTEXT_STAGE:-in_progress}"

# ai-copilot 模式: 只有复杂阶段才 block
if [[ "$MODE" == "ai-copilot" ]]; then
    case "$STAGE" in
        claim|in_progress)
            # 简单阶段: AI 自主, 不 block
            echo "OK: ai-copilot simple stage '$STAGE', AI handles autonomously"
            exit 0
            ;;
        analysis|test|review)
            # 复杂阶段: 触发原 decision-gate.sh 逻辑
            ;;
    esac
fi

# 其他模式 (ai-auto/manual) 或 复杂阶段: 调用原 decision-gate.sh
exec "$SCRIPT_DIR/decision-gate.sh" "$@"
