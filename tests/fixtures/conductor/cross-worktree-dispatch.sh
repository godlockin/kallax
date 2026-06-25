#!/bin/bash
# tests/fixtures/conductor/cross-worktree-dispatch.sh
# Test fixture for cross-worktree-dispatch.sh (EPIC-036-B integration test)
# Real implementation: scripts/conductor/cross-worktree-dispatch.sh (EPIC-036-A)
#
# 行为契约 (跟 EPIC-036-A spec 联合, mock for E2E):
# 1. 解析 --source-wt=<wt> --ticket-id=<id> --final-id=<id> --conflict (可选)
# 2. 无冲突: 输出 CWT_DISPATCHED: <source> → <ticket> (<final>), exit 0
# 3. 有冲突: 输出 CWT_CONFLICT: <source> <ticket>, exit 1
# 4. 跟 KALLAX_TEST_FIXTURES=1 fixture 模式 联合 (dispatch.sh 自动切到 fixture 路径)
set -euo pipefail

SOURCE_WT=""
TICKET_ID=""
FINAL_ID=""
CONFLICT=0

for arg in "$@"; do
  case "$arg" in
    --source-wt=*)
      SOURCE_WT="${arg#*=}"
      ;;
    --ticket-id=*)
      TICKET_ID="${arg#*=}"
      ;;
    --final-id=*)
      FINAL_ID="${arg#*=}"
      ;;
    --conflict)
      CONFLICT=1
      ;;
    *)
      echo "ERROR: unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SOURCE_WT" ]] || [[ -z "$TICKET_ID" ]] || [[ -z "$FINAL_ID" ]]; then
  echo "ERROR: --source-wt, --ticket-id, --final-id are required" >&2
  exit 2
fi

if [[ "$CONFLICT" == "1" ]]; then
  echo "CWT_CONFLICT: source=$SOURCE_WT ticket=$TICKET_ID final=$FINAL_ID"
  exit 1
fi

echo "CWT_DISPATCHED: source=$SOURCE_WT ticket=$TICKET_ID final=$FINAL_ID"
exit 0
