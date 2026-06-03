#!/usr/bin/env bash
# KALLAX Heartbeat Monitor — detects Conductor heartbeat timeout
# Checks .kallax/state/last_heartbeat timestamp and alerts if stale
# Usage: ./scripts/heartbeat-monitor.sh [--timeout 300] [--alert-command "cmd"]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEARTBEAT_FILE="${PROJECT_ROOT}/.kallax/state/last_heartbeat"
TIMEOUT_SECONDS=300  # default: 5 minutes
ALERT_COMMAND=""

for arg in "$@"; do
  case "$arg" in
    --timeout=*) TIMEOUT_SECONDS="${arg#*=}" ;;
    --alert-command=*) ALERT_COMMAND="${arg#*=}" ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

echo "=== KALLAX Heartbeat Monitor ==="
echo "  Timeout: ${TIMEOUT_SECONDS}s"
echo "  Heartbeat file: ${HEARTBEAT_FILE}"
echo ""

# Ensure heartbeat file directory exists
mkdir -p "$(dirname "$HEARTBEAT_FILE")"

# If heartbeat file does not exist, create one with current time
if [ ! -f "$HEARTBEAT_FILE" ]; then
  date +%s > "$HEARTBEAT_FILE"
  info "Heartbeat file initialized to current time"
fi

CURRENT_TIME=$(date +%s)
LAST_HEARTBEAT=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo 0)
ELAPSED=$(( CURRENT_TIME - LAST_HEARTBEAT ))
LAST_DATE=$(date -r "$LAST_HEARTBEAT" 2>/dev/null || echo "unknown")

echo "  Last heartbeat: ${LAST_DATE} (${ELAPSED}s ago)"

if [ "$ELAPSED" -gt "$TIMEOUT_SECONDS" ]; then
  fail "Heartbeat timeout! No signal for ${ELAPSED}s (threshold: ${TIMEOUT_SECONDS}s)"

  # Execute alert command if configured
  if [ -n "$ALERT_COMMAND" ]; then
    info "Executing alert command..."
    eval "$ALERT_COMMAND" || warn "Alert command failed (exit: $?)"
  fi

  exit 1
else
  REMAINING=$(( TIMEOUT_SECONDS - ELAPSED ))
  pass "Heartbeat alive — ${REMAINING}s until timeout"
  exit 0
fi
