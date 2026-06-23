#!/usr/bin/env bash
# node/scripts/replication/stop-litestream.sh — Stop litestream gracefully
# EPIC-060-A Phase 2: WAL replication
# 跟 eket 4 级降级 模式 联合 (L1 litestream 停 → L2 本地 SQLite 接管)
#
# Usage: bash node/scripts/replication/stop-litestream.sh [timeout_secs]
#   LITESTREAM_PID_FILE    — override pid file (default: $KALLAX_ROOT/.kallax/run/litestream.pid)
#   timeout_secs (arg)     — SIGKILL timeout  (default: 10)
#
# Returns 0 if stopped, 1 if not running, 2 on force-kill.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly DEFAULT_GRACE_SECS=10
readonly DEFAULT_PID_DIR=".kallax/run"
readonly KILL_POLL_INTERVAL=0.2

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
GRACE_SECS="${1:-${DEFAULT_GRACE_SECS}}"

LITESTREAM_PID_FILE="${LITESTREAM_PID_FILE:-${KALLAX_ROOT}/${DEFAULT_PID_DIR}/litestream.pid}"

# ── Helpers ────────────────────────────────────────────────────────────
err()  { echo "[ERR] $*" >&2; }
info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }

# ── Main ───────────────────────────────────────────────────────────────
main() {
    if [ ! -f "$LITESTREAM_PID_FILE" ]; then
        info "No pid file at $LITESTREAM_PID_FILE — litestream not running"
        exit 1
    fi

    local pid
    pid="$(cat "$LITESTREAM_PID_FILE" 2>/dev/null || true)"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        info "Stale pid file (pid=$pid) — cleaning up"
        rm -f "$LITESTREAM_PID_FILE"
        exit 1
    fi

    info "Sending SIGTERM to litestream pid $pid (grace ${GRACE_SECS}s)"
    kill -TERM "$pid" 2>/dev/null || true

    local elapsed=0
    while [ "$elapsed" -lt "$GRACE_SECS" ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$LITESTREAM_PID_FILE"
            # Cleanup any stale resolved configs from previous starts (跟"不埋坑" 联合)
            find /tmp -maxdepth 1 -name 'litestream-config-XXXXXX*.yml' -type f -mmin +60 \
                -delete 2>/dev/null || true
            ok "litestream stopped gracefully (pid $pid)"
            exit 0
        fi
        sleep "$KILL_POLL_INTERVAL"
        elapsed=$(awk "BEGIN{print $elapsed + $KILL_POLL_INTERVAL}")
    done

    info "Grace expired; sending SIGKILL to pid $pid"
    kill -KILL "$pid" 2>/dev/null || true
    rm -f "$LITESTREAM_PID_FILE"
    err "litestream force-killed (pid $pid)"
    exit 2
}

main "$@"