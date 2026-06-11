#!/bin/bash
# audit/dispatch-audit.sh — 派发决策审计 (EPIC-031-C)
# 主公 C 派: 派发决策可追溯, 跟 EPIC-030-B scoring-trace.sh 集成
# 7 字段: timestamp / ticket_id / algo_suggest / final_slaver / decision / actor / type
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="${AUDIT_DIR:-${KALLAX_ROOT}/.kallax/audit}"

# dispatch_audit — 写一条派发决策审计记录到 scoring-YYYY-MM-DD.jsonl
# 用法: dispatch_audit <ticket_id> <algo_id> <final_id> <decision> [actor]
# decision: accept | veto | override
# actor: conductor | performer | system (default: conductor)
dispatch_audit() {
  local ticket_id="$1"
  local algo_id="$2"
  local final_id="$3"
  local decision="$4"
  local actor="${5:-conductor}"

  case "$decision" in
    accept|veto|override) ;;
    *)
      echo "ERROR: decision must be accept|veto|override" >&2
      return 1
      ;;
    esac

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  mkdir -p "${AUDIT_DIR}"
  local audit_file="${AUDIT_DIR}/scoring-$(date -u +%Y-%m-%d).jsonl"

  # jq -n 防 JSON injection (跟 EPIC-029 决策门一致)
  local entry
  entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg tid "$ticket_id" \
    --arg algo "$algo_id" \
    --arg final "$final_id" \
    --arg dec "$decision" \
    --arg act "$actor" \
    '{timestamp:$ts, ticket_id:$tid, algo_suggest:$algo, final_slaver:$final, decision:$dec, actor:$act, type:"dispatch"}')
  printf '%s\n' "$entry" >> "$audit_file"
}

# read_dispatch_audit — 读当日派发审计记录
# 用法: read_dispatch_audit [YYYY-MM-DD]
read_dispatch_audit() {
  local date_arg="${1:-$(date -u +%Y-%m-%d)}"
  local audit_file="${AUDIT_DIR}/scoring-${date_arg}.jsonl"
  if [[ -f "$audit_file" ]]; then
    # jq -s: slurp all lines (each may be multi-line); select dispatch records; output as compact JSON per line
    jq -rs 'map(select(has("type"))) | .[]' "$audit_file" 2>/dev/null
  fi
}

# count_dispatch_audit — 统计当日派发决策数
# 用法: count_dispatch_audit [YYYY-MM-DD]
count_dispatch_audit() {
  local date_arg="${1:-$(date -u +%Y-%m-%d)}"
  local audit_file="${AUDIT_DIR}/scoring-${date_arg}.jsonl"
  if [[ -f "$audit_file" ]]; then
    # jq -s: slurp all lines; select dispatch records; count
    local count
    count=$(jq -s 'map(select(has("type"))) | length' "$audit_file" 2>/dev/null || echo "0")
    echo "$count"
  else
    echo "0"
  fi
}

# 入口
case "${1:-}" in
  write)
    shift
    dispatch_audit "$@"
    ;;
  read)
    shift
    read_dispatch_audit "$@"
    ;;
  count)
    shift
    count_dispatch_audit "$@"
    ;;
  help|--help|-h)
    echo "Usage: $0 {write <ticket_id> <algo_id> <final_id> <decision> [actor]|read [YYYY-MM-DD]|count [YYYY-MM-DD]}"
    echo "  decision: accept | veto | override"
    echo "  actor: conductor | performer | system (default: conductor)"
    echo "  Output: .kallax/audit/scoring-YYYY-MM-DD.jsonl"
    ;;
  *)
    echo "Usage: $0 {write|read|count} [args...]" >&2
    echo "  write <ticket_id> <algo_id> <final_id> <decision> [actor]"
    echo "  read [YYYY-MM-DD]"
    echo "  count [YYYY-MM-DD]"
    exit 1
    ;;
esac