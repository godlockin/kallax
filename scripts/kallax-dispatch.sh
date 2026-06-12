#!/bin/bash
# kallax-dispatch.sh — 一键 Approve CLI (Performer convenience wrapper)
# 主公 2026-06-11 D2 决策: 派发权 60%→80% AI 渐进升级, 默认 80% AI + 20% 人工 override
# 依赖: EPIC-031-A (conductor/dispatch.sh) + EPIC-033-A (KALLAX_AI_DELEGATION_RATIO)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认参数
TICKET_ID=""
REQUIRED_EXPERTISE=""
DECISION="accept"  # 默认 accept (主公 D2: 80% AI 让渡 + 20% 人工 override)
OVERRIDE_TO=""

# Mode-aware 默认行为 (EPIC-033-A 新增)
# ai-auto:   100% AI, override 必填
# ai-copilot (默认 80%): 80% AI 默认 Accept, 20% 人工 override 显式必填
# manual:    100% 人工, override 必填, 不接受默认 Accept
# KALLAX_MODE_EXPLICIT: track if user explicitly set KALLAX_MODE (not just default)
KALLAX_MODE_EXPLICIT="${KALLAX_MODE_EXPLICIT:-0}"
if [[ -z "${KALLAX_MODE:-}" ]]; then
  # KALLAX_MODE not set: default to ai-copilot for backward compat
  KALLAX_MODE="ai-copilot"
  KALLAX_MODE_EXPLICIT=0
else
  KALLAX_MODE_EXPLICIT=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ticket) TICKET_ID="$2"; shift 2 ;;
    --expertise) REQUIRED_EXPERTISE="$2"; shift 2 ;;
    --algo-accept) DECISION="accept"; shift ;;
    --veto) DECISION="veto"; shift ;;
    --dispatch-to) DECISION="override"; OVERRIDE_TO="${2:-}"; shift 2 ;;
    --human-override-required)
      # 20% 人工 override 场景: 显式必填 override_to (EPIC-033-A 新增)
      DECISION="override"
      OVERRIDE_TO="${2:-}"
      if [[ -z "$OVERRIDE_TO" ]]; then
        echo "ERROR: --human-override-required requires override_to argument" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 --ticket <TICKET_ID> --expertise <EXPERTISE> [OPTIONS]

Required:
  --ticket <TICKET_ID>       Ticket identifier
  --expertise <EXPERTISE>    Required expertise (e.g. bash, python, rust)

Decision (mutually exclusive):
  --algo-accept              Accept ALGO_SUGGEST (default, 80% AI mode)
  --veto                     Reject / veto
  --dispatch-to <id>         Override with specific performer ID
  --human-override-required <id>  Force human override (20% AI mode, override_to required)

Mode-aware default behavior (via KALLAX_MODE env var):
  ai-auto     (100% AI):  default Accept ALGO, override required for human decision
  ai-copilot  (80% AI, default): default Accept ALGO, 20% human override via --dispatch-to
  manual      (100% human): override required, no default Accept

AI delegation ratio: KALLAX_AI_DELEGATION_RATIO=80 (60/80/90, default 80)
  60 = 60% AI + 40% human
  80 = 80% AI + 20% human (default, 主公 D2 决策)
  90 = 90% AI + 10% human

Examples:
  $0 --ticket EPIC-033-T001 --expertise bash
  $0 --ticket EPIC-033-T001 --expertise bash --algo-accept
  $0 --ticket EPIC-033-T001 --expertise python --veto
  $0 --ticket EPIC-033-T001 --expertise bash --dispatch-to performer-beta
  KALLAX_MODE=ai-auto $0 --ticket EPIC-033-T001 --expertise bash --dispatch-to performer-beta
  KALLAX_MODE=manual $0 --ticket EPIC-033-T001 --expertise bash --dispatch-to performer-beta
EOF
      exit 0
      ;;
    *) echo "ERROR: Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TICKET_ID" ]]; then
  echo "ERROR: --ticket is required" >&2
  echo "Usage: $0 --ticket <TICKET_ID> [--expertise <EXP>] [--algo-accept|--veto|--dispatch-to <id>|--human-override-required <id>]" >&2
  exit 1
fi

if [[ "$DECISION" == "override" ]] && [[ -z "$OVERRIDE_TO" ]]; then
  echo "ERROR: --dispatch-to requires a performer ID" >&2
  exit 1
fi

# Mode-aware 默认行为强制检查
if [[ "$DECISION" == "accept" ]]; then
  case "$KALLAX_MODE" in
    ai-auto)
      # 100% AI 模式: 默认 Accept ALGO
      DECISION="accept"
      ;;
    ai-copilot)
      # 80% AI 模式 (默认): 默认 Accept ALGO, 20% 人工 override 显式走 --dispatch-to
      DECISION="accept"
      ;;
    manual)
      # 100% 人工模式: 不接受默认 Accept, 必须显式 override
      echo "ERROR: KALLAX_MODE=manual requires explicit --dispatch-to (no default Accept)" >&2
      exit 1
      ;;
    *)
      # 未知 mode 默认走 80% AI
      DECISION="accept"
      ;;
  esac
fi

# 调 conductor dispatch.sh (A 已就位)
# 使用 KALLAX_TEST_FIXTURES=1 在 test/CI 环境下使用 fixtures
if [[ "$DECISION" == "override" ]]; then
  bash "${KALLAX_ROOT}/scripts/conductor/dispatch.sh" "$TICKET_ID" "$REQUIRED_EXPERTISE" "$DECISION" "$OVERRIDE_TO"
else
  bash "${KALLAX_ROOT}/scripts/conductor/dispatch.sh" "$TICKET_ID" "$REQUIRED_EXPERTISE" "$DECISION"
fi