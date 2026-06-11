#!/bin/bash
# kallax-dispatch.sh — 一键 Approve CLI (Performer convenience wrapper)
# 主公 2026-06-11 B 决策: 40% 人工简化, 一键 Approve
# 依赖: EPIC-031-A (conductor/dispatch.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认参数
TICKET_ID=""
REQUIRED_EXPERTISE=""
DECISION="accept"  # 默认 accept (主公 拍: 一键 Approve 60% AI 让渡)
OVERRIDE_TO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ticket) TICKET_ID="$2"; shift 2 ;;
    --expertise) REQUIRED_EXPERTISE="$2"; shift 2 ;;
    --algo-accept) DECISION="accept"; shift ;;
    --veto) DECISION="veto"; shift ;;
    --dispatch-to) DECISION="override"; OVERRIDE_TO="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 --ticket <TICKET_ID> --expertise <EXPERTISE> [OPTIONS]

Required:
  --ticket <TICKET_ID>       Ticket identifier
  --expertise <EXPERTISE>    Required expertise (e.g. bash, python, rust)

Decision (mutually exclusive):
  --algo-accept              Accept ALGO_SUGGEST (default)
  --veto Reject / veto
  --dispatch-to <id>         Override with specific performer ID

Default: --algo-accept (主公 B 决策: 一键 Approve, 60% AI 让渡)

Examples:
  $0 --ticket EPIC-031-T001 --expertise bash
  $0 --ticket EPIC-031-T001 --expertise bash --algo-accept
  $0 --ticket EPIC-031-T001 --expertise python --veto
  $0 --ticket EPIC-031-T001 --expertise bash --dispatch-to performer-beta
EOF
      exit 0
      ;;
    *) echo "ERROR: Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TICKET_ID" ]]; then
  echo "ERROR: --ticket is required" >&2
  echo "Usage: $0 --ticket <TICKET_ID> [--expertise <EXP>] [--algo-accept|--veto|--dispatch-to <id>]" >&2
  exit 1
fi

if [[ "$DECISION" == "override" ]] && [[ -z "$OVERRIDE_TO" ]]; then
  echo "ERROR: --dispatch-to requires a performer ID" >&2
  exit 1
fi

# 调 conductor dispatch.sh (A 已就位)
# 使用 KALLAX_TEST_FIXTURES=1 在 test/CI 环境下使用 fixtures
if [[ "$DECISION" == "override" ]]; then
  bash "${KALLAX_ROOT}/scripts/conductor/dispatch.sh" "$TICKET_ID" "$REQUIRED_EXPERTISE" "$DECISION" "$OVERRIDE_TO"
else
  bash "${KALLAX_ROOT}/scripts/conductor/dispatch.sh" "$TICKET_ID" "$REQUIRED_EXPERTISE" "$DECISION"
fi