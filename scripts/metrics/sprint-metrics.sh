#!/usr/bin/env bash
# scripts/metrics/sprint-metrics.sh
# EPIC-023-C 北极星指标 CLI
#
# Usage:
#   kallax metrics:sprint --epic EPIC-XXX [--format json|markdown|both] [--output PATH]
#
# 4 北极星指标:
#   1. expert_activation_rate   ≥5 distinct experts / EPIC
#   2. cross_epic_reuse_rate    ≥60% 跨 EPIC 文件复用
#   3. ab_hit_rate (mismatch)   <15% 2-Group review 推荐 vs 实际
#   4. mis_dispatch_rate        <10% Performer 错派率
#
# Exit codes (跟 Performer Hard Rule 6 联合, 透明可验证):
#   0 = all 4 metrics PASS
#   1 = at least 1 metric FAIL (or invalid args)
#   2 = NO_DATA on all 4 metrics (环境异常, 数据源缺失)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/lib/metrics.sh"

if [ ! -f "$LIB" ]; then
  echo "FATAL: metrics lib not found at $LIB" >&2
  exit 2
fi

# shellcheck source=lib/metrics.sh
source "$LIB"

# ─── 依赖检查 ────────────────────────────────────────────────────────────────

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FATAL: required command not found: $cmd" >&2
    exit 2
  fi
}

require_cmd jq

# ─── Help text ───────────────────────────────────────────────────────────────

print_help() {
  cat <<'EOF'
kallax metrics:sprint — 北极星指标 CLI (EPIC-023-C)

USAGE:
  bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX [options]

REQUIRED:
  --epic EPIC-XXX          Target EPIC ID (e.g., EPIC-021)

OPTIONS:
  --format <fmt>           Output format: json (default) | markdown | both
  --output <path>          Write to file instead of stdout (json/md extension inferred)
  -h, --help               Show this help

EXAMPLES:
  # JSON output to stdout
  bash scripts/metrics/sprint-metrics.sh --epic EPIC-021

  # Markdown table (human-readable for master/conductor)
  bash scripts/metrics/sprint-metrics.sh --epic EPIC-021 --format markdown

  # Both formats to files
  bash scripts/metrics/sprint-metrics.sh --epic EPIC-021 --format both \
    --output .kallax/reports/sprint-EPIC-021

EXIT CODES:
  0  All 4 metrics PASS
  1  At least 1 metric FAIL or invalid args
  2  NO_DATA on all metrics (data sources missing)
EOF
}

# ─── Args 解析 ───────────────────────────────────────────────────────────────

EPIC_ID=""
FORMAT="json"
OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --epic)
      EPIC_ID="${2:-}"
      shift 2
      ;;
    --epic=*)
      EPIC_ID="${1#*=}"
      shift
      ;;
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#*=}"
      shift
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --output=*)
      OUTPUT="${1#*=}"
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      print_help >&2
      exit 1
      ;;
  esac
done

if [ -z "$EPIC_ID" ]; then
  echo "ERROR: --epic is required" >&2
  print_help >&2
  exit 1
fi

case "$FORMAT" in
  json|markdown|both) ;;
  *)
    echo "ERROR: --format must be one of: json | markdown | both (got: $FORMAT)" >&2
    exit 1
    ;;
esac

# ─── Init paths ──────────────────────────────────────────────────────────────

resolve_paths

if ! validate_epic_id "$EPIC_ID"; then
  exit 1
fi

log_info "sprint-metrics" "epic=${EPIC_ID} format=${FORMAT} output=${OUTPUT:-stdout} worktree=${WORKTREE_ROOT}"

# ─── Compute + output ────────────────────────────────────────────────────────

# 检查是否所有 metric 都 NO_DATA (exit 2)
is_all_no_data() {
  local j="$1"
  local total n
  total="$(printf '%s' "$j" | jq '.metrics | length')"
  n="$(printf '%s' "$j" | jq '[.metrics[] | select(.status == "NO_DATA")] | length')"
  [ "$n" -eq "$total" ]
}

# 任一 FAIL → exit 1; 全 PASS → exit 0
has_any_fail() {
  local j="$1"
  local n
  n="$(printf '%s' "$j" | jq '[.metrics[] | select(.status == "FAIL")] | length')"
  [ "$n" -gt 0 ]
}

JSON_OUT=""
MARKDOWN_OUT=""

# Exit-code 判定需先 compute JSON (无论 format 选项, 都基于 4 metric 状态)
JSON_OUT="$(format_json_metrics "$EPIC_ID")"

if [ "$FORMAT" = "markdown" ] || [ "$FORMAT" = "both" ]; then
  MARKDOWN_OUT="$(format_markdown_metrics "$EPIC_ID")"
fi

# 输出到文件 / stdout
if [ -n "$OUTPUT" ]; then
  if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "both" ]; then
    local_json="${OUTPUT}.json"
    printf '%s\n' "$JSON_OUT" > "${local_json}"
    log_info "output" "path=${local_json}"
  fi
  if [ "$FORMAT" = "markdown" ] || [ "$FORMAT" = "both" ]; then
    local_md="${OUTPUT}.md"
    printf '%s\n' "$MARKDOWN_OUT" > "${local_md}"
    log_info "output" "path=${local_md}"
  fi
else
  if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "both" ]; then
    printf '%s\n' "$JSON_OUT"
  fi
  if [ "$FORMAT" = "markdown" ] || [ "$FORMAT" = "both" ]; then
    printf '%s\n' "$MARKDOWN_OUT"
  fi
fi

# ─── Exit code ───────────────────────────────────────────────────────────────

if [ -n "$JSON_OUT" ]; then
  if is_all_no_data "$JSON_OUT"; then
    log_warn "sprint-metrics" "epic=${EPIC_ID} status=ALL_NO_DATA"
    exit 2
  fi
  if has_any_fail "$JSON_OUT"; then
    log_info "sprint-metrics" "epic=${EPIC_ID} status=HAS_FAIL"
    exit 1
  fi
fi

log_info "sprint-metrics" "epic=${EPIC_ID} status=ALL_PASS"
exit 0