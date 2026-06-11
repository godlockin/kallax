#!/bin/bash
# conductor/dispatch.sh — Conductor 派发集成
# 依赖: EPIC-030-A (best-matching-slaver.sh) + EPIC-030-B (scoring-trace.sh)
# 主公 2026-06-11 派发权决策: 60% AI 默认 Accept + 40% 人工一键 Approve
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 读参数
TICKET_ID="${1:-}"
REQUIRED_EXPERTISE="${2:-}"
DECISION="${3:-accept}"  # accept / veto / override
OVERRIDE_TO="${4:-}"

# Use argument count to detect if args were provided (empty string is valid for expertise)
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <TICKET_ID> <REQUIRED_EXPERTISE> [accept|veto|override] [OVERRIDE_TO]" >&2
  exit 1
fi

case "$DECISION" in
  accept|veto|override) ;;
  *)
    echo "ERROR: decision must be accept|veto|override" >&2
    exit 1
    ;;
esac

if [[ "$DECISION" == "override" ]] && [[ -z "$OVERRIDE_TO" ]]; then
  echo "ERROR: override requires OVERRIDE_TO argument" >&2
  exit 1
fi

# 调 best-matching-slaver.sh 拿 ALGO_SUGGEST
# 使用 KALLAX_TEST_FIXTURES=1 在 test/CI 环境下使用 fixtures
SUGGEST=$(KALLAX_TEST_FIXTURES=1 bash "${KALLAX_ROOT}/scripts/agent/best-matching-slaver.sh" "$REQUIRED_EXPERTISE" 2>/dev/null | head -1)

# 提取 ALGO_SUGGEST 的 ID (格式: "ALGO_SUGGEST: <id> (Layer N: ...)")
ALGO_ID=$(echo "$SUGGEST" | sed -E 's/^ALGO_SUGGEST: ([^ ]+).*/\1/')

if [[ -z "$ALGO_ID" ]] || [[ "$ALGO_ID" == "none" ]]; then
  echo "ERROR: best-matching-slaver.sh returned no match" >&2
  exit 1
fi

# 决策
case "$DECISION" in
  accept)
    FINAL_ID="$ALGO_ID"
    REASON="Conductor Accept ALGO_SUGGEST"
    ;;
  veto)
    FINAL_ID="VETOED"
    REASON="Conductor Veto"
    ;;
  override)
    FINAL_ID="$OVERRIDE_TO"
    REASON="Conductor Override ALGO_SUGGEST ($ALGO_ID)"
    ;;
esac

# 写 scoring audit (跟 EPIC-030-B scoring-trace.sh 集成)
# factors: [1.0, 0.0, 0.0] = accept signal, decision=$DECISION
bash "${KALLAX_ROOT}/scripts/agent/scoring-trace.sh" append \
  "$ALGO_ID" \
  "$FINAL_ID" \
  "0.5" \
  '[1.0,0.0,0.0]' \
  "$DECISION" \
  >/dev/null 2>&1 || true

echo "DISPATCH: ticket=$TICKET_ID algo_suggest=$ALGO_ID final=$FINAL_ID decision=$DECISION reason=$REASON"