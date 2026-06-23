#!/usr/bin/env bash
# node/scripts/replication/status-litestream.sh — Report litestream status
# EPIC-060-A Phase 2: WAL replication
# 跟 eket 4 级降级 模式 联合 (L1 litestream 主用 + L2 本地 SQLite 备)
# Status output: 1 line machine-parseable (EXIT_CODE=0 running / 1 not-running / 2 binary-missing)
#
# Usage: bash node/scripts/replication/status-litestream.sh [--json]
#   LITESTREAM_BIN         — override binary path
#   LITESTREAM_CONFIG      — override config path
#   LITESTREAM_PID_FILE    — override pid file
#
# Returns 0 if running, 1 if not-running, 2 if binary missing, 3 if config invalid.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly DEFAULT_PID_DIR=".kallax/run"
readonly DEFAULT_LOG_DIR=".kallax/log"

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

LITESTREAM_BIN="${LITESTREAM_BIN:-${KALLAX_ROOT}/.kallax/bin/litestream}"
LITESTREAM_CONFIG="${LITESTREAM_CONFIG:-${KALLAX_ROOT}/config/litestream.yml}"
LITESTREAM_PID_FILE="${LITESTREAM_PID_FILE:-${KALLAX_ROOT}/${DEFAULT_PID_DIR}/litestream.pid}"
LITESTREAM_LOG_FILE="${LITESTREAM_LOG_FILE:-${KALLAX_ROOT}/${DEFAULT_LOG_DIR}/litestream.log}"

# ── Helpers ────────────────────────────────────────────────────────────
emit_json() {
    local state="$1" pid="$2" binary="$3" config="$4" log="$5" version="$6"
    printf '{"state":"%s","pid":%s,"binary":"%s","config":"%s","log":"%s","version":"%s"}\n' \
        "$state" "${pid:-null}" "$binary" "$config" "$log" "$version"
}

emit_text() {
    local state="$1" pid="$2" binary="$3" config="$4" log="$5" version="$6"
    echo "state=$state pid=${pid:-N/A} binary=$binary config=$config log=$log version=$version"
}

# ── Pre-flight ─────────────────────────────────────────────────────────
if [ ! -x "$LITESTREAM_BIN" ]; then
    if [ "$JSON_MODE" = "1" ]; then
        emit_json "binary-missing" "" "$LITESTREAM_BIN" "$LITESTREAM_CONFIG" "$LITESTREAM_LOG_FILE" ""
    else
        echo "state=binary-missing binary=$LITESTREAM_BIN"
        echo "HINT: bash node/scripts/replication/install-litestream.sh"
    fi
    exit 2
fi

if [ ! -f "$LITESTREAM_CONFIG" ]; then
    if [ "$JSON_MODE" = "1" ]; then
        emit_json "config-invalid" "" "$LITESTREAM_BIN" "$LITESTREAM_CONFIG" "$LITESTREAM_LOG_FILE" ""
    else
        echo "state=config-invalid config=$LITESTREAM_CONFIG"
    fi
    exit 3
fi

VERSION="$("$LITESTREAM_BIN" version 2>/dev/null | head -1 || echo unknown)"

# ── Check process state ────────────────────────────────────────────────
PID=""
STATE="not-running"
if [ -f "$LITESTREAM_PID_FILE" ]; then
    PID="$(cat "$LITESTREAM_PID_FILE" 2>/dev/null || true)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        STATE="running"
    else
        STATE="stale-pid"
        PID=""
    fi
fi

# ── Emit ────────────────────────────────────────────────────────────────
if [ "$JSON_MODE" = "1" ]; then
    emit_json "$STATE" "$PID" "$LITESTREAM_BIN" "$LITESTREAM_CONFIG" "$LITESTREAM_LOG_FILE" "$VERSION"
else
    emit_text "$STATE" "$PID" "$LITESTREAM_BIN" "$LITESTREAM_CONFIG" "$LITESTREAM_LOG_FILE" "$VERSION"
fi

case "$STATE" in
    running) exit 0 ;;
    *)       exit 1 ;;
esac