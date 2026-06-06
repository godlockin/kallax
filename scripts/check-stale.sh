#!/usr/bin/env bash
# KALLAX Stale Instance Checker — EPIC-015 Phase 1.5
# Governance layer: detect instances with missed heartbeats.
# Runs via cron or manual trigger. Does NOT depend on LLM.
# Usage: check-stale.sh [instances_dir] [max_missed]
set -euo pipefail

INSTANCES_DIR="${1:-.kallax/instances}"
MAX_MISSED="${2:-3}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STALE_COUNT=0

echo "Checking for stale instances (max_missed=${MAX_MISSED})..."
echo ""

for state_file in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "${state_file}" ] || continue

  # Read state
  eval "$(python3 -c "
import json
with open('${state_file}') as f: s = json.load(f)
hb = s.get('heartbeat', {})
print(f'INSTANCE_ID={s[\"instance_id\"]}')
print(f'ROLE={s[\"role\"]}')
print(f'STATUS={s[\"status\"]}')
print(f'LAST_BEAT={hb.get(\"last_beat\", \"unknown\")}')
print(f'MISSED={hb.get(\"missed_count\", 0)}')
" 2>/dev/null)"

  # Increment missed count for active instances
  if [ "${STATUS}" = "ACTIVE" ] || [ "${STATUS}" = "HEARTBEATING" ]; then
    NEW_MISSED=$((MISSED + 1))
    python3 -c "
import json, os
with open('${state_file}') as f: s = json.load(f)
s['heartbeat']['missed_count'] = ${NEW_MISSED}
if ${NEW_MISSED} >= ${MAX_MISSED}:
  s['status'] = 'STALE'
tmp = '${state_file}.tmp'
with open(tmp, 'w') as f: json.dump(s, f, indent=2)
os.replace(tmp, '${state_file}')
" 2>/dev/null

    if [ "${NEW_MISSED}" -ge "${MAX_MISSED}" ]; then
      STALE_COUNT=$((STALE_COUNT + 1))
      echo "  STALE  ${INSTANCE_ID} (${ROLE}) — last beat: ${LAST_BEAT}, missed: ${NEW_MISSED}"
    fi
  elif [ "${STATUS}" = "STALE" ]; then
    STALE_COUNT=$((STALE_COUNT + 1))
    echo "  STALE  ${INSTANCE_ID} (${ROLE}) — already stale, last beat: ${LAST_BEAT}"
  fi
done

echo ""
if [ "${STALE_COUNT}" -eq 0 ]; then
  echo "All instances healthy."
else
  echo "${STALE_COUNT} stale instance(s) detected."
fi
