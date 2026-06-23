#!/usr/bin/env bash
# node/scripts/replication/start-litestream.sh — Start litestream replication
# EPIC-060-A Phase 2: WAL replication
# 跟 eket 4 级降级 模式 联合 (L1 litestream 主用 + L2 本地 SQLite 备)
# 跟"不埋坑" 战略 联合 (env-driven paths, 0 hardcoded)
#
# Usage: bash node/scripts/replication/start-litestream.sh
#   LITESTREAM_BIN         — override binary path  (default: $KALLAX_ROOT/.kallax/bin/litestream)
#   LITESTREAM_CONFIG      — override config path  (default: $KALLAX_ROOT/config/litestream.yml)
#   LITESTREAM_PID_FILE    — override pid file     (default: $KALLAX_ROOT/.kallax/run/litestream.pid)
#   LITESTREAM_LOG_FILE    — override log file     (default: $KALLAX_ROOT/.kallax/log/litestream.log)
#
# Returns 0 if started, 1 if already running, 2 on failure.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly DEFAULT_PID_DIR=".kallax/run"
readonly DEFAULT_LOG_DIR=".kallax/log"
readonly STARTUP_TIMEOUT_SECS=5
readonly STARTUP_POLL_INTERVAL=0.2

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

LITESTREAM_BIN="${LITESTREAM_BIN:-${KALLAX_ROOT}/.kallax/bin/litestream}"
LITESTREAM_CONFIG="${LITESTREAM_CONFIG:-${KALLAX_ROOT}/config/litestream.yml}"
LITESTREAM_PID_FILE="${LITESTREAM_PID_FILE:-${KALLAX_ROOT}/${DEFAULT_PID_DIR}/litestream.pid}"
LITESTREAM_LOG_FILE="${LITESTREAM_LOG_FILE:-${KALLAX_ROOT}/${DEFAULT_LOG_DIR}/litestream.log}"
TMP_RESOLVED_CONFIG="${TMP_RESOLVED_CONFIG:-$(mktemp -t litestream-config-XXXXXX.yml)}"
# NOTE: do NOT trap-rm TMP_RESOLVED_CONFIG — litestream process still needs
# the file after start script exits. Cleanup happens via stop script (and
# at next start, old files in /tmp are overwritten on mktemp -t).

# ── Helpers ────────────────────────────────────────────────────────────
err()  { echo "[ERR] $*" >&2; }
info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }

# Resolve env vars in config (envsubst pattern, 跟 12-factor 联合)
resolve_config() {
    local resolved="$TMP_RESOLVED_CONFIG"
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "$LITESTREAM_CONFIG" > "$resolved"
    else
        # Fallback: simple ${VAR:-default} substitution via awk
        awk '{
            while (match($0, /\$\{[A-Z_][A-Z0-9_]*:-[^}]*\}/)) {
                expr = substr($0, RSTART, RLENGTH)
                var = expr
                sub(/^\$\{/, "", var)
                sub(/:-.*\}$/, "", var)
                def = expr
                sub(/^\$\{[A-Z_][A-Z0-9_]*:-/, "", def)
                sub(/\}$/, "", def)
                val = (ENVIRON[var] != "") ? ENVIRON[var] : def
                gsub("\\$\\{[A-Z_][A-Z0-9_]*:-[^}]*\\}", val)
            }
            print
        }' "$LITESTREAM_CONFIG" > "$resolved"
    fi
    echo "$resolved"
}

# ── Pre-flight checks ──────────────────────────────────────────────────
preflight() {
    if [ ! -x "$LITESTREAM_BIN" ]; then
        err "litestream binary not found: $LITESTREAM_BIN"
        err "Run: bash node/scripts/replication/install-litestream.sh"
        return 2
    fi
    if [ ! -f "$LITESTREAM_CONFIG" ]; then
        err "litestream config not found: $LITESTREAM_CONFIG"
        return 2
    fi
    return 0
}

# ── Check if already running ───────────────────────────────────────────
is_running() {
    if [ -f "$LITESTREAM_PID_FILE" ]; then
        local pid
        pid="$(cat "$LITESTREAM_PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$LITESTREAM_PID_FILE"
    fi
    return 1
}

# ── Wait until pid is alive (or timeout) ───────────────────────────────
wait_for_start() {
    local pid="$1"
    local elapsed=0
    while [ "$elapsed" -lt "$STARTUP_TIMEOUT_SECS" ]; do
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep "$STARTUP_POLL_INTERVAL"
        elapsed=$(awk "BEGIN{print $elapsed + $STARTUP_POLL_INTERVAL}")
    done
    return 1
}

# ── Main ───────────────────────────────────────────────────────────────
main() {
    if ! preflight; then
        exit 2
    fi

    if is_running; then
        info "litestream already running (pid $(cat "$LITESTREAM_PID_FILE"))"
        exit 1
    fi

    mkdir -p "$(dirname "$LITESTREAM_PID_FILE")" "$(dirname "$LITESTREAM_LOG_FILE")"

    local resolved_config
    resolved_config="$(resolve_config)"
    info "Starting litestream: $LITESTREAM_BIN replicate -config $resolved_config"
    "$LITESTREAM_BIN" replicate -config "$resolved_config" \
        > "$LITESTREAM_LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$LITESTREAM_PID_FILE"

    if wait_for_start "$pid"; then
        ok "litestream started (pid $pid, log $LITESTREAM_LOG_FILE)"
        exit 0
    else
        err "litestream failed to start within ${STARTUP_TIMEOUT_SECS}s (log $LITESTREAM_LOG_FILE)"
        rm -f "$LITESTREAM_PID_FILE"
        exit 2
    fi
}

main "$@"