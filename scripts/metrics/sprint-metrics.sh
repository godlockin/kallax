#!/usr/bin/env bash
# scripts/metrics/sprint-metrics.sh
# KALLAX 北极星指标主入口 (EPIC-023-C)
# 用法: kallax metrics:sprint --epic EPIC-XXX [--json|--markdown]
#
# 4指标:
# - expert_activation_rate: 5 expert 在 EPIC 内的激活频次
# - cross_epic_reuse_rate: 跨 EPIC 复用率
# - ab_hit_rate: 2-Group review 推荐 vs 实际命中率
# - mis_dispatch_rate: Performer 错派率

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source metrics library
# shellcheck source=scripts/metrics/lib/metrics.sh
source "${LIB_DIR}/metrics.sh"

# CLI parsing
parse_args() {
  EPIC=""
  FORMAT="markdown"

  while [ $# -gt 0 ]; do
    case "$1" in
      --epic)
        EPIC="$2"
        shift 2
        ;;
      --json)
        FORMAT="json"
        shift
        ;;
      --markdown)
        FORMAT="markdown"
        shift
        ;;
      --help|-h)
        echo "Usage: $0 [--epic EPIC-XXX] [--json|--markdown]"
        echo "  --epic EPIC-XXX   Specify EPIC to analyze (default: EPIC-023)"
        echo "  --json            Output JSON format"
        echo "  --markdown        Output Markdown table (default)"
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done

  # Default EPIC if not specified
  if [ -z "$EPIC" ]; then
    EPIC="EPIC-023"
  fi
}

main() {
  parse_args "$@"

  case "$FORMAT" in
    json)
      output_json "$EPIC"
      ;;
    markdown)
      output_markdown "$EPIC"
      ;;
  esac
}

main "$@"