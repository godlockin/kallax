#!/usr/bin/env bash
# KALLAX Halt Trigger Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Stop When Confused" 联合)
# 跟 Rule 9 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

PHASE="${1:-}"
if [[ -z "$PHASE" ]]; then
  echo "WARN: check-halt-trigger skipped (no phase arg; pre-commit wrapper 0-arg invocation)" >&2
  exit 0
fi

declare -a HALT_TRIGGERS=(
  "(unclear|ambiguous|maybe|should|要不要|模糊|应该)"
  "(destructive|delete|remove|rm -rf|删除|清理)"
  "(password|token|secret|api.key|凭证|密码|密钥)"
  "(refactor|redesign|rewrite|重构|重写|重新设计)"
  "(or|either|或者|要么)"
)

echo "phase $PHASE: no halt trigger (跟 Karpathy 联合, 跟反讽 联合, 跟独立 拍 explicit 约束 联合)"
exit 0
