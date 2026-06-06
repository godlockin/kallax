#!/usr/bin/env bash
# KALLAX Heartbeat Daemon — EPIC-015 Phase 1.5
# Governance layer: periodic heartbeat tick, independent of LLM.
# Usage: heartbeat-daemon.sh <instance_id> [instances_dir] [interval_seconds]
set -euo pipefail

INSTANCE_ID="${1:?Usage: heartbeat-daemon.sh <instance_id>}"
INSTANCES_DIR="${2:-.kallax/instances}"
INTERVAL="${3:-60}"
STATE_FILE="${INSTANCES_DIR}/${INSTANCE_ID}/state.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: state.json not found at ${STATE_FILE}" >&2
  exit 1
fi

# Trap cleanup on exit
cleanup() {
  # Mark session as CLOSING on exit
  if [ -f "${STATE_FILE}" ]; then
    python3 -c "
import json
try:
  with open('${STATE_FILE}') as f: s = json.load(f)
  s['status'] = 'CLOSING'
  with open('${STATE_FILE}', 'w') as f: json.dump(s, f, indent=2)
except: pass
" 2>/dev/null || true
  fi
  echo "[heartbeat] daemon stopped for ${INSTANCE_ID}"
}
trap cleanup EXIT INT TERM

echo "[heartbeat] daemon started for ${INSTANCE_ID} (interval=${INTERVAL}s, pid=$$)"

while true; do
  sleep "${INTERVAL}"

  if [ ! -f "${STATE_FILE}" ]; then
    echo "[heartbeat] state.json missing, exiting" >&2
    exit 1
  fi

  # Atomic heartbeat update
  python3 -c "
import json, os, sys
try:
  with open('${STATE_FILE}') as f: s = json.load(f)
  now = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
  s['heartbeat']['last_beat'] = now
  s['heartbeat']['missed_count'] = 0

  # Check if previously STALE → revive
  if s.get('status') == 'STALE':
    s['status'] = 'ACTIVE'

  tmp = '${STATE_FILE}.tmp'
  with open(tmp, 'w') as f: json.dump(s, f, indent=2)
  os.replace(tmp, '${STATE_FILE}')
except Exception as e:
  print(f'[heartbeat] update failed: {e}', file=sys.stderr)
" 2>/dev/null
done
