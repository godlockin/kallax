#!/usr/bin/env bash
# KALLAX Audit Log Analyzer — scan and summarize audit logs
# Usage: ./scripts/audit-logs.sh [--since <days>] [--action <name>] [--json]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SINCE_DAYS="${2:-7}"
FILTER_ACTION="${4:-}"
JSON_OUT="${5:-}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=== KALLAX Audit Log Analyzer ==="
echo ""

# Validate DB
[ -f "$DB_PATH" ] || { echo "ERROR: Database not found at ${DB_PATH}"; exit 1; }

# Check sqlite3
command -v sqlite3 &>/dev/null || { echo "ERROR: sqlite3 not found"; exit 1; }

SINCE_DATE=$(date -v-${SINCE_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${SINCE_DAYS} days" +%Y-%m-%d 2>/dev/null || echo "1970-01-01")
info "Analyzing logs since ${SINCE_DATE} (${SINCE_DAYS} days)"

# Summary
echo ""
echo "--- Summary ---"
sqlite3 "$DB_PATH" "
  SELECT action, COUNT(*) as count,
         ROUND(AVG(1.0)) as avg_per_day
  FROM audit_log
  WHERE created_at >= '${SINCE_DATE}'
  ${FILTER_ACTION:+AND action = '${FILTER_ACTION}'}
  GROUP BY action
  ORDER BY count DESC
  LIMIT 20;
" 2>/dev/null | column -t -s'|' || echo "  No audit log entries found"

# Error actions
echo ""
echo "--- Errors & Failures ---"
sqlite3 "$DB_PATH" "
  SELECT created_at, action, actor, target
  FROM audit_log
  WHERE created_at >= '${SINCE_DATE}'
    AND (action LIKE '%fail%' OR action LIKE '%error%' OR action LIKE '%reject%')
  ORDER BY created_at DESC
  LIMIT 10;
" 2>/dev/null | column -t -s'|' || echo "  No errors found"

# Most active performers
echo ""
echo "--- Most Active Instances ---"
sqlite3 "$DB_PATH" "
  SELECT actor, COUNT(*) as actions
  FROM audit_log
  WHERE created_at >= '${SINCE_DATE}'
    AND actor IS NOT NULL
  GROUP BY actor
  ORDER BY actions DESC
  LIMIT 5;
" 2>/dev/null | column -t -s'|' || echo "  No actor data"

# Total log size
echo ""
TOTAL=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM audit_log WHERE created_at >= '${SINCE_DATE}';" 2>/dev/null || echo "0")
info "Total entries in period: ${TOTAL}"

# JSON output
if [ "$JSON_OUT" = "--json" ]; then
  sqlite3 "$DB_PATH" -json "
    SELECT action, COUNT(*) as count
    FROM audit_log
    WHERE created_at >= '${SINCE_DATE}'
    GROUP BY action
    ORDER BY count DESC;
  " 2>/dev/null || echo '[]'
fi
