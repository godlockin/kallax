#!/usr/bin/env bash
# scripts/dashboard/dispatch-dashboard.sh — EPIC-053-D Performer 派单成功率 CLI 仪表盘
#
# 输出 (跟 AC 1:1):
#   - 每 EPIC 派单成功率 (X/Y 格式, Rule 9 精确)
#   - 越界事件 (BE-1/6/11, 跟 Rule 15 联动)
#   - 假 PASS 计数 (跟 EPIC-053-B 4-Level 证据链 联动)
#   - 历史 baseline 对比 (line 43 PROJECT-STATUS: 7/12 58.3% → 目标 95%+)
#
# Usage:
#   bash scripts/dashboard/dispatch-dashboard.sh                    # 默认 (.kallax/queue/outbox)
#   bash scripts/dashboard/dispatch-dashboard.sh --mock-dir DIR     # mock 测试
#   KALLAX_DASHBOARD_MOCK_DIR=DIR bash scripts/dashboard/dispatch-dashboard.sh
#
# Env overrides:
#   KALLAX_DASHBOARD_MOCK_DIR — override outbox + scope-creep + evidence-chain paths

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly SCRIPT_DIR KALLAX_ROOT

# Parse args
MOCK_DIR="${KALLAX_DASHBOARD_MOCK_DIR:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mock-dir)
            MOCK_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--mock-dir DIR]"
            echo ""
            echo "Performer dispatch success rate dashboard (EPIC-053-D)."
            echo "Output format: X/Y (P.P%) per Rule 9 KPI precision."
            echo "Baseline: PROJECT-STATUS-AND-LESSONS-2026-06-13.md line 43 (58.3%)"
            echo "Target: 95%+"
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 2
            ;;
    esac
done

# Dispatch to TypeScript core (handles both production CLI and test cases)
export KALLAX_DASHBOARD_MOCK_DIR="$MOCK_DIR"

CORE_TS="$KALLAX_ROOT/node/src/core/dispatch-dashboard.ts"
if [ ! -f "$CORE_TS" ]; then
    echo "ERROR: core not found at $CORE_TS" >&2
    exit 2
fi

exec node --experimental-strip-types --no-warnings "$CORE_TS"
