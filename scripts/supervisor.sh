#!/usr/bin/env bash
# KALLAX Supervisor — daemon wrapper that auto-restarts the API server on crash
# Usage: ./scripts/supervisor.sh [--max-restarts 5] [--restart-delay 2]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/.kallax/logs"
MAX_RESTARTS=5
RESTART_DELAY=2

for arg in "$@"; do
  case "$arg" in
    --max-restarts=*) MAX_RESTARTS="${arg#*=}" ;;
    --restart-delay=*) RESTART_DELAY="${arg#*=}" ;;
  esac
done

mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $*"; }
fail()  { echo -e "${RED}[$(date +%H:%M:%S)]${NC} $*"; }

SUPERVISOR_PID_FILE="${LOG_DIR}/supervisor.pid"
SERVER_LOG="${LOG_DIR}/server.log"

echo "=== KALLAX Supervisor ==="
echo "  Max restarts: ${MAX_RESTARTS}"
echo "  Restart delay: ${RESTART_DELAY}s"
echo "  Server log: ${SERVER_LOG}"
echo "  PID file: ${SUPERVISOR_PID_FILE}"
echo ""

# Write our PID
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"; info "Supervisor stopped"' EXIT

# Determine the server command
SERVER_CMD=""
if [ -x "${PROJECT_ROOT}/node/bin/server.js" ]; then
  SERVER_CMD="node ${PROJECT_ROOT}/node/bin/server.js"
elif [ -f "${PROJECT_ROOT}/node/package.json" ]; then
  # Try npm start
  SERVER_CMD="npm --prefix ${PROJECT_ROOT}/node run start"
elif [ -x "${PROJECT_ROOT}/rust/target/release/kallax-server" ]; then
  SERVER_CMD="${PROJECT_ROOT}/rust/target/release/kallax-server"
elif [ -x "${PROJECT_ROOT}/rust/target/debug/kallax-server" ]; then
  SERVER_CMD="${PROJECT_ROOT}/rust/target/debug/kallax-server"
else
  # Fallback: try cargo run
  SERVER_CMD="cd ${PROJECT_ROOT}/rust && cargo run"
fi

info "Server command: ${SERVER_CMD}"
info "Starting supervision (max ${MAX_RESTARTS} restarts)..."
echo ""

RESTART_COUNT=0

while [ $RESTART_COUNT -le $MAX_RESTARTS ]; do
  if [ $RESTART_COUNT -gt 0 ]; then
    warn "Restart #${RESTART_COUNT}/${MAX_RESTARTS} after ${RESTART_DELAY}s delay..."
    sleep "$RESTART_DELAY"
  fi

  info "Starting server..."
  START_TIME=$(date +%s)

  # Execute server in background, capture PID
  # EPIC-070-B2: 删 eval (环境注入即 RCE), 改用 bash -c 单引号包裹
  bash -c "$SERVER_CMD" >> "$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  info "Server PID: ${SERVER_PID}"

  # Health check loop — wait up to 10s for /live endpoint
  HEALTHY=false
  for i in $(seq 1 20); do
    if curl -sf "http://127.0.0.1:9877/live" >/dev/null 2>&1; then
      HEALTHY=true
      break
    fi
    sleep 0.5
  done
  if [ "$HEALTHY" = true ]; then
    info "Server health check passed (${i}x0.5s)"
  else
    warn "Server health check did not pass within 10s — will still monitor process"
  fi

  # Wait for process (blocking)
  wait $SERVER_PID 2>/dev/null || true
  EXIT_CODE=$?
  END_TIME=$(date +%s)
  UPTIME=$(( END_TIME - START_TIME ))

  if [ $EXIT_CODE -eq 0 ]; then
    info "Server exited cleanly (exit: 0, uptime: ${UPTIME}s)"
    exit 0
  fi

  warn "Server crashed (exit: ${EXIT_CODE}, uptime: ${UPTIME}s)"
  RESTART_COUNT=$((RESTART_COUNT + 1))
done

fail "Server crashed ${MAX_RESTARTS} times — giving up"
exit 1
