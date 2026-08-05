#!/usr/bin/env bash
# scripts/heartbeat/heartbeat-daemon.sh — EPIC-166 Heartbeat Daemon
#
# 借鉴 loopx heartbeat-prompt 1:1:
#   后台 daemon, 定时调 quota should-run, 返回 next allowed transition
#   默认 60s 间隔 (可调)
#
# 退出码契约 (跟 scan-dead-code 1:1):
#   0 = PASS (continue)
#   1 = FAIL (stop, 报 Master)
#   2 = BLOCKED-env (环境缺失)
#
# Usage:
#   heartbeat-daemon.sh start [--interval=SECONDS] [--quota-only]
#   heartbeat-daemon.sh stop
#   heartbeat-daemon.sh status
#   heartbeat-daemon.sh should-run <ticket_id>
#   heartbeat-daemon.sh next-transition <ticket_id>
#   heartbeat-daemon.sh emit <event_type> <ticket_id> [payload_json]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${STATE_DIR}/run-history.jsonl"
PID_FILE="${STATE_DIR}/heartbeat-daemon.pid"
LOG_FILE="${STATE_DIR}/heartbeat-daemon.log"

# Defaults
INTERVAL="${HEARTBEAT_INTERVAL:-60}"
QUOTA_SCRIPT="${SCRIPT_DIR}/quota.sh"
SCHEDULER_SCRIPT="${SCRIPT_DIR}/scheduler-hint.sh"
RUN_HISTORY_SCRIPT="${SCRIPT_DIR}/run-history.sh"

# Exit code constants
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# ── Helpers ─────────────────────────────────────────────────────────────────

log() {
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[${ts}] $*" >> "$LOG_FILE"
}

ensure_state_dir() {
    if [ ! -d "$STATE_DIR" ]; then
        mkdir -p "$STATE_DIR" || {
            echo "BLOCKED: cannot create state dir: $STATE_DIR" >&2
            exit $EXIT_BLOCKED_ENV
        }
    fi
}

ensure_ledger() {
    if [ ! -f "$LEDGER" ]; then
        touch "$LEDGER" || {
            echo "BLOCKED: cannot create ledger: $LEDGER" >&2
            exit $EXIT_BLOCKED_ENV
        }
    fi
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_start() {
    local interval="${1:-$INTERVAL}"
    local quota_only="${2:-false}"

    ensure_state_dir
    ensure_ledger

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            echo "Already running with PID $old_pid"
            exit $EXIT_PASS
        fi
        rm -f "$PID_FILE"
    fi

    # Daemonize
    (
        exec 2>> "$LOG_FILE"
        log "heartbeat-daemon starting (interval=${interval}s)"

        # Write PID
        echo "$$" > "$PID_FILE"

        while true; do
            sleep "$interval"

            # Emit heartbeat accounting event
            "$RUN_HISTORY_SCRIPT" emit accounting "heartbeat-daemon" "{}" >> "$LOG_FILE" 2>&1 || true

            # Quota check
            local quota_result
            quota_result=$("$QUOTA_SCRIPT" should-run 2>&1) || {
                log "quota check failed: $quota_result"
                continue
            }

            if [ -n "$quota_result" ]; then
                log "quota: $quota_result"

                # Scheduler hint
                local hint
                hint=$("$SCHEDULER_SCRIPT" next "$quota_result" 2>&1) || {
                    log "scheduler hint failed: $hint"
                    continue
                }

                if [ -n "$hint" ]; then
                    log "scheduler: $hint"
                fi
            fi

            # Check for env blocks
            if ! command -v jq >/dev/null 2>&1; then
                log "BLOCKED-env: jq not found"
                exit $EXIT_BLOCKED_ENV
            fi
        done
    ) &

    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"
    echo "Started heartbeat-daemon with PID $daemon_pid"
    exit $EXIT_PASS
}

cmd_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon not running (no PID file)"
        exit $EXIT_PASS
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        echo "Daemon not running"
        exit $EXIT_PASS
    fi

    kill "$pid" 2>/dev/null || true
    sleep 1
    rm -f "$PID_FILE"
    echo "Stopped heartbeat-daemon"
    exit $EXIT_PASS
}

cmd_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Status: not running"
        exit $EXIT_PASS
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        echo "Status: not running (stale PID file)"
        exit $EXIT_PASS
    fi

    echo "Status: running (PID=$pid, interval=${INTERVAL}s)"
    echo "Log: $LOG_FILE"
    exit $EXIT_PASS
}

cmd_should_run() {
    local ticket_id="${1:?Usage: heartbeat-daemon.sh should-run <ticket_id>}"
    ensure_state_dir
    "$QUOTA_SCRIPT" should-run "$ticket_id"
}

cmd_next_transition() {
    local ticket_id="${1:?Usage: heartbeat-daemon.sh next-transition <ticket_id>}"
    ensure_state_dir
    local eligible
    eligible=$("$QUOTA_SCRIPT" should-run "$ticket_id" 2>/dev/null) || exit $EXIT_FAIL
    "$SCHEDULER_SCRIPT" next "$eligible"
}

cmd_emit() {
    local event_type="${1:?Usage: heartbeat-daemon.sh emit <event_type> <ticket_id> [payload_json]}"
    local ticket_id="${2:?Usage: heartbeat-daemon.sh emit <event_type> <ticket_id> [payload_json]}"
    local payload="${3:-{}}"
    ensure_state_dir
    "$RUN_HISTORY_SCRIPT" emit "$event_type" "$ticket_id" "$payload"
}

# ── Main ─────────────────────────────────────────────────────────────────────

CMD="${1:-status}"
shift || true

case "$CMD" in
    start)    cmd_start "$@" ;;
    stop)     cmd_stop ;;
    status)   cmd_status ;;
    should-run)   cmd_should_run "$@" ;;
    next-transition) cmd_next_transition "$@" ;;
    emit)     cmd_emit "$@" ;;
    -h|--help)
        cat <<EOF
heartbeat-daemon.sh — EPIC-166 Heartbeat Daemon

Usage:
  heartbeat-daemon.sh start [--interval=SECONDS] [--quota-only]
  heartbeat-daemon.sh stop
  heartbeat-daemon.sh status
  heartbeat-daemon.sh should-run <ticket_id>
  heartbeat-daemon.sh next-transition <ticket_id>
  heartbeat-daemon.sh emit <event_type> <ticket_id> [payload_json]

Exit codes:
  0 = PASS (continue)
  1 = FAIL (stop, 报 Master)
  2 = BLOCKED-env (环境缺失)

4 Event types: work, decision, accounting, evidence
EOF
        exit 0
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit $EXIT_FAIL
        ;;
esac
