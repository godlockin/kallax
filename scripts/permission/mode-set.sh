#!/bin/bash
# mode-set.sh — write state.json mode + mode_lock
# EPIC-029-A: state.json mode + mode_lock schema + mode-set.sh CLI
# 3 模式: ai-auto | ai-copilot | manual (跟 docs/architecture/3-MODES.md §3 1:1)
# Ticket: jira/tickets/EPIC-029-A/ticket.json
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_LOCK_FILE="${KALLAX_ROOT}/.kallax/state/mode.lock"

usage() {
  cat <<EOF
Usage: $0 --mode <ai-auto|ai-copilot|manual> [--actor <name>]
  --mode    required, one of ai-auto, ai-copilot, manual
  --actor   optional, audit field, defaults to current user
EOF
  exit 1
}

MODE=""
ACTOR="${USER:-unknown}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: --mode required"
  usage
fi

# L2: validate mode value
case "$MODE" in
  ai-auto|ai-copilot|manual) ;;
  *) echo "ERROR: mode must be ai-auto|ai-copilot|manual, got: $MODE"; exit 1 ;;
esac

# L2: mode_lock conflict detection via kill -0
if [[ -f "$MODE_LOCK_FILE" ]]; then
  LOCK_PID=$(cat "$MODE_LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "ERROR: mode locked by PID $LOCK_PID, abort"
    exit 1
  fi
  rm -f "$MODE_LOCK_FILE"
fi

# L2: write state.json mode + mode_set_at
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
TMP="${STATE_FILE}.tmp.$$"

if [[ -f "$STATE_FILE" ]]; then
  jq --arg m "$MODE" --arg t "$TIMESTAMP" \
    '. + {mode: $m, mode_set_at: $t}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
else
  echo "ERROR: $STATE_FILE not found" >&2
  exit 1
fi

# L2: write mode_lock (current shell PID)
echo "$$" > "$MODE_LOCK_FILE"

echo "OK: mode=$MODE set at $TIMESTAMP by $ACTOR"