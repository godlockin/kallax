#!/usr/bin/env bash
# KALLAX Standard Daemon Library -- EPIC-016-R AC3
# Provides run_daemon() with proper stdin/stdout/stderr isolation.
# Four elements: stdin/stdout/stderr redirect + setsid + disown.
set -uo pipefail

# run_daemon <name> <script> [args...]
# Creates a fully-disconnected daemon process.
# Writes PID to $STATE_FILE.heartbeat.${name}_pid
# Returns 0 on success (daemon confirmed within 3s), 1 on failure.
run_daemon() {
  local name="$1"; shift
  local script="$1"; shift
  local args=("$@")

  if [ ! -x "$script" ]; then
    echo "[daemon] run_daemon: $script not executable or not found" >&2
    return 1
  fi

  # Three-part stdio isolation + setsid + disown + line-buffering
  # stdbuf -oL -eL prevents output buffering that could block the daemon
  stdbuf -oL -eL setsid "$script" "${args[@]}" </dev/null >/dev/null 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true

  # Wait up to 3s for daemon to confirm in state.json
  local timeout=3
  while [ "$timeout" -gt 0 ]; do
    if jq -e --argjson p "$pid" '.heartbeat.heartbeat_daemon_pid == $p' \
      "${STATE_FILE}" >/dev/null 2>&1; then
      echo "[daemon] $name started (pid=$pid)"
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done
  echo "[daemon] $name FAILED to confirm within 3s (pid=$pid)" >&2
  kill "$pid" 2>/dev/null || true
  return 1
}