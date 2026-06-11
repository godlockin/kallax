#!/bin/bash
# scoring-trace.sh — scoring_trace.jsonl 每日轮转审计
# 依赖: EPIC-030-A (best-matching-slaver.sh 调此脚本记录决策)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

#写一条审计记录到当日 scoring-YYYY-MM-DD.jsonl
# 用法: append_scoring_trace <algo_suggest> <slaver_id> <trust_score> <factors_json> <decision>
# decision: suggested | overridden | auto-dispatched
append_scoring_trace() {
  local algo_suggest="$1"
  local slaver_id="$2"
  local trust_score="$3"
  local factors="$4" # JSON array, e.g. '[0.85, 0.9, 0.7, 0.05]'
  local decision="$5"  # suggested | overridden | auto-dispatched
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  mkdir -p "$AUDIT_DIR"
  local audit_file="${AUDIT_DIR}/scoring-$(date -u +%Y-%m-%d).jsonl"

  # jq -n 构建审计记录，防 JSON injection（跟 EPIC-029 决策门一致）
  local entry
  entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg sug "$algo_suggest" \
    --arg sid "$slaver_id" \
    --argjson ts_score "$trust_score" \
    --argjson fac "$factors" \
    --arg dec "$decision" \
    '{timestamp:$ts, algo_suggest:$sug, slaver_id:$sid, trust_score:$ts_score, factors:$fac, decision:$dec}')
  printf '%s\n' "$entry" >> "$audit_file"
}

# 读当日 scoring-YYYY-MM-DD.jsonl 内容
# 用法: read_scoring_trace [YYYY-MM-DD]
read_scoring_trace() {
  local date_arg="${1:-$(date -u +%Y-%m-%d)}"
  local audit_file="${AUDIT_DIR}/scoring-${date_arg}.jsonl"
  if [[ -f "$audit_file" ]]; then
    cat "$audit_file"
  fi
}

# 入口
case "${1:-}" in
  append)
    shift
    append_scoring_trace "$@"
    ;;
  read)
    shift
    read_scoring_trace "$@"
    ;;
  *)
    echo "Usage: $0 {append|read} [args...]" >&2
    exit 1
    ;;
esac