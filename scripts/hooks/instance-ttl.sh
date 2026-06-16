#!/usr/bin/env bash
# scripts/hooks/instance-ttl.sh — Session-start hook to trigger instance TTL cleanup
# EPIC-054-B AC4: 每次 session 启动时跑 TTL 清理 (dry-run, 不阻塞)
#
# Usage: bash scripts/hooks/instance-ttl.sh
# Exit: always 0 (hook never blocks session start)
#
# Strategy:
#   1. Find repo root via git rev-parse
#   2. Call cleanup.sh --dry-run (informational)
#   3. Log to .kallax/logs/hook-instance-ttl-YYYYMMDD.log
#   4. Always exit 0 (session startup not blocked)
#
# Installation: call from session-init scripts (e.g., conductor-session-init.sh,
# performer-session-init.sh). Or wire into git pre-commit via symlink.

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly CLEANUP_SCRIPT="$KALLAX_ROOT/scripts/instance/cleanup.sh"
readonly LOG_DIR="${KALLAX_LOG_DIR:-$KALLAX_ROOT/.kallax/logs}"
readonly HOOK_LOG="$LOG_DIR/hook-instance-ttl-$(date -u +%Y%m%d).log"

# Helper: structured log line (JSON per observable architecture)
log_line() {
    local level="$1"
    local event="$2"
    local msg="$3"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local json
    json=$(jq -n \
        --arg ts "$ts" \
        --arg lvl "$level" \
        --arg ev "$event" \
        --arg msg "$msg" \
        '{timestamp: $ts, level: $lvl, event: $ev, message: $msg}')
    echo "$json" | tee -a "$HOOK_LOG" >&2
}

# Ensure log dir exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

log_line "info" "instance_ttl_hook_start" "EPIC-054-B session-start hook triggered"

# Verify cleanup script exists
if [ ! -x "$CLEANUP_SCRIPT" ]; then
    log_line "error" "cleanup_script_missing" "path=$CLEANUP_SCRIPT"
    # Hook never blocks session start — exit 0
    exit 0
fi

# Run cleanup in dry-run mode (never modify during hook)
CLEANUP_OUTPUT=$(bash "$CLEANUP_SCRIPT" --dry-run --ttl-days=7 2>&1) || true
CLEANUP_EXIT=$?

# Parse summary
TOTAL=$(echo "$CLEANUP_OUTPUT" | grep -oE 'cleaned=[0-9]+' | head -1 | cut -d'=' -f2 || echo "0")
RETAINED=$(echo "$CLEANUP_OUTPUT" | grep -oE 'retained=[0-9]+' | head -1 | cut -d'=' -f2 || echo "0")

log_line "info" "instance_ttl_hook_complete" \
    "cleanup_exit=$CLEANUP_EXIT cleaned=${TOTAL:-0} retained=${RETAINED:-0} ttl_days=7 dry_run=true"

# Hook never blocks session start — exit 0 unconditionally
exit 0
