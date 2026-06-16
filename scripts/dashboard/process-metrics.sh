#!/usr/bin/env bash
# scripts/dashboard/process-metrics.sh — CLI wrapper for EPIC-056-B 3 KPI
#
# 跟 node/src/core/process-metrics.ts 联合 (单一真相来源)
# 跟 EPIC-053-D dispatch-dashboard.sh 联动 (互不抢 web dashboard)
# Rule 9 KPI X/Y 格式: 6/6 = 100.0% (no estimate, exact, 1 decimal)
#
# Usage:
#   process-metrics.sh <subcommand> [--tickets-dir <path>]
#
# Subcommands:
#   dispatch-rate  — 派单成功率 (X/Y 格式)
#   cycle-time     — 平均周期 (Xh 格式)
#   violation-rate — 越界率 (X/Y 格式, 跟 BE-1/6/11 联合)
#   trend          — 历史趋势 (按 EPIC 分桶)
#   check-targets  — 目标值校验 (95% / 8h / 0%)
#   dashboard      — 完整仪表盘 (3 KPI + 历史 + 告警 + 目标)
#
# Env:
#   KALLAX_TICKETS_DIR — default tickets dir (default: jira/tickets)
#
# Exit codes:
#   0 = success (check-targets: all targets met)
#   1 = check-targets: at least one target NOT met
#   2 = invalid arguments

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PROCESS_METRICS_TS="$KALLAX_ROOT/node/src/core/process-metrics.ts"
readonly NODE_BIN="${NODE_BIN:-node}"

# -------------------------------------------------------
# Help / usage
# -------------------------------------------------------
usage() {
    cat <<'USAGE'
Usage: process-metrics.sh <subcommand> [--tickets-dir <path>]

Subcommands:
  dispatch-rate    Performer dispatch success rate (X/Y format, target >= 95%)
  cycle-time       Average cycle time in hours (target <= 8.0h)
  violation-rate   Scope violation rate (X/Y format, target <= 0%)
  trend            Historical trend by EPIC bucket
  check-targets    Validate all 3 KPIs against targets (exit 0=PASS, 1=FAIL)
  dashboard        Full 3 KPI dashboard output (text)

Env:
  KALLAX_TICKETS_DIR   Default --tickets-dir (default: jira/tickets)

Examples:
  process-metrics.sh dashboard --tickets-dir /tmp/fixtures/tickets
  process-metrics.sh dispatch-rate
  KALLAX_TICKETS_DIR=/var/kallax/tickets process-metrics.sh check-targets

Rule alignment:
  Rule 9  — KPI X/Y format precision (1 decimal, no estimate)
  Rule 11 — Master 强验证 (跟 11 BE 累计 + 6 痛点 联合)
  Rule 15 — file_scope 边界 (本脚本只读 tickets, 不动 docs/PROCESS.md)
  Rule 16 — Subagent 流程 闭环 (本 ticket 是 P3 治根)
USAGE
}

# -------------------------------------------------------
# Validate environment
# -------------------------------------------------------
if [ ! -f "$PROCESS_METRICS_TS" ]; then
    echo "ERROR: $PROCESS_METRICS_TS not found" >&2
    exit 2
fi

if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
    echo "ERROR: $NODE_BIN not found in PATH" >&2
    exit 2
fi

# -------------------------------------------------------
# Parse arguments
# -------------------------------------------------------
SUBCOMMAND="${1:-}"
if [ -z "$SUBCOMMAND" ] || [ "$SUBCOMMAND" = "-h" ] || [ "$SUBCOMMAND" = "--help" ]; then
    usage
    exit 0
fi

shift || true

TICKETS_DIR="${KALLAX_TICKETS_DIR:-$KALLAX_ROOT/jira/tickets}"

while [ $# -gt 0 ]; do
    case "$1" in
        --tickets-dir)
            TICKETS_DIR="${2:-}"
            if [ -z "$TICKETS_DIR" ]; then
                echo "ERROR: --tickets-dir requires a path argument" >&2
                exit 2
            fi
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ ! -d "$TICKETS_DIR" ]; then
    echo "ERROR: tickets dir not found: $TICKETS_DIR" >&2
    exit 2
fi

# -------------------------------------------------------
# Dispatch to Node.js CLI
# -------------------------------------------------------
case "$SUBCOMMAND" in
    dispatch-rate|cycle-time|violation-rate|trend|check-targets|dashboard)
        exec "$NODE_BIN" --experimental-strip-types "$PROCESS_METRICS_TS" \
            "$SUBCOMMAND" --tickets-dir "$TICKETS_DIR"
        ;;
    *)
        echo "ERROR: unknown subcommand: $SUBCOMMAND" >&2
        usage >&2
        exit 2
        ;;
esac