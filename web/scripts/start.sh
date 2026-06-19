#!/usr/bin/env bash
# web/scripts/start.sh — start web dashboard on port 8080 (background)
#
# EPIC-058-C — web dashboard deployment-ready
# Usage: bash web/scripts/start.sh [port]
#   port (optional, default 8080)
# Writes PID to web/.dashboard.pid and logs to web/.dashboard.log
# 跟 KALLAX API server (port 9877) 端口隔离, 跟 verify-deploy.sh 联合

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEFAULT_PORT=8080

readonly PORT="${1:-$DEFAULT_PORT}"
readonly PID_FILE="$WEB_ROOT/.dashboard.pid"
readonly LOG_FILE="$WEB_ROOT/.dashboard.log"

readonly STARTUP_WAIT_SEC=2

# Stop existing instance if PID file present
if [ -f "$PID_FILE" ]; then
  readonly OLD_PID="$(cat "$PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$PID_FILE"
fi

# Install deps if node_modules absent
if [ ! -d "$WEB_ROOT/node_modules/http-server" ]; then
  (cd "$WEB_ROOT" && npm install --no-audit --no-fund >/dev/null 2>&1) || {
    echo "ERROR: npm install failed in $WEB_ROOT" >&2
    exit 1
  }
fi

# Launch http-server (background, fully detached: closed FDs + disown)
cd "$WEB_ROOT"
nohup npx http-server src/dashboard -p "$PORT" -c-1 --silent \
  </dev/null >>"$LOG_FILE" 2>&1 &
DASHBOARD_PID=$!
disown "$DASHBOARD_PID" 2>/dev/null || true
cd - >/dev/null 2>&1 || true
sleep "$STARTUP_WAIT_SEC"

# Locate PID by port (cross-platform: lsof preferred, fallback to pgrep)
if command -v lsof >/dev/null 2>&1; then
  DASHBOARD_PID="$(lsof -ti :"$PORT" 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$DASHBOARD_PID" ] && command -v pgrep >/dev/null 2>&1; then
  DASHBOARD_PID="$(pgrep -f "http-server src/dashboard -p $PORT" | head -n 1 || true)"
fi

if [ -z "$DASHBOARD_PID" ]; then
  echo "ERROR: dashboard did not start on port $PORT (see $LOG_FILE)" >&2
  exit 1
fi

# Validate the PID actually corresponds to a running process
if ! kill -0 "$DASHBOARD_PID" 2>/dev/null; then
  echo "ERROR: dashboard pid $DASHBOARD_PID not alive (see $LOG_FILE)" >&2
  exit 1
fi

echo "$DASHBOARD_PID" > "$PID_FILE"
echo "Dashboard started on port $PORT (pid=$DASHBOARD_PID, log=$LOG_FILE)"