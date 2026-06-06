#!/usr/bin/env bash
# KALLAX Stale Instance Checker -- EPIC-015 Phase 1.5
# Governance layer: detect instances with missed heartbeats.
# Pure bash + jq, no Python/Node dependency.
# Usage: check-stale.sh [instances_dir] [max_missed] [--cron]
#
# Modes:
#   Default (human-readable): prints per-instance status with summary
#   --cron: machine-readable output for cron/alerting integration
#           Format: STALE|<instance_id>|<role>|<missed_count>|<last_beat>
#
# Exit codes:
#   0 -- all instances healthy (or no instances found)
#   1 -- one or more STALE instances detected
set -euo pipefail

INSTANCES_DIR=""
MAX_MISSED=""
CRON_MODE=false

# Parse positional and --cron flag (order-independent)
for arg in "$@"; do
  case "$arg" in
    --cron) CRON_MODE=true ;;
    *)
      if [ -z "${INSTANCES_DIR}" ]; then
        INSTANCES_DIR="$arg"
      elif [ -z "${MAX_MISSED}" ]; then
        MAX_MISSED="$arg"
      fi
      ;;
  esac
done
INSTANCES_DIR="${INSTANCES_DIR:-.kallax/instances}"
MAX_MISSED="${MAX_MISSED:-3}"

STALE_COUNT=0
TOTAL_COUNT=0

for state_file in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "${state_file}" ] || continue
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  # Read state via jq
  INSTANCE_ID="$(jq -r '.instance_id // "unknown"' "${state_file}")"
  ROLE="$(jq -r '.role // "unknown"' "${state_file}")"
  STATUS="$(jq -r '.status // "unknown"' "${state_file}")"
  LAST_BEAT="$(jq -r '.heartbeat.last_beat // "never"' "${state_file}")"
  MISSED=$(jq -r '.heartbeat.missed_count // 0' "${state_file}")

  # Increment missed count for active instances
  if [ "${STATUS}" = "ACTIVE" ] || [ "${STATUS}" = "HEARTBEATING" ]; then
    NEW_MISSED=$((MISSED + 1))

    if [ "${NEW_MISSED}" -ge "${MAX_MISSED}" ]; then
      # Mark STALE in state.json
      jq \
        --argjson new_missed "${NEW_MISSED}" \
        '.heartbeat.missed_count = $new_missed | .status = "STALE"' \
        "${state_file}" > "${state_file}.tmp" && \
        mv "${state_file}.tmp" "${state_file}"
      STALE_COUNT=$((STALE_COUNT + 1))
    else
      # Just increment missed_count
      jq \
        --argjson new_missed "${NEW_MISSED}" \
        '.heartbeat.missed_count = $new_missed' \
        "${state_file}" > "${state_file}.tmp" && \
        mv "${state_file}.tmp" "${state_file}"
    fi

    if [ "${NEW_MISSED}" -ge "${MAX_MISSED}" ]; then
      if [ "${CRON_MODE}" = true ]; then
        echo "STALE|${INSTANCE_ID}|${ROLE}|${NEW_MISSED}|${LAST_BEAT}"
      else
        echo "  STALE  ${INSTANCE_ID} (${ROLE}) -- last beat: ${LAST_BEAT}, missed: ${NEW_MISSED}"
      fi
    fi
  elif [ "${STATUS}" = "STALE" ]; then
    STALE_COUNT=$((STALE_COUNT + 1))
    if [ "${CRON_MODE}" = true ]; then
      echo "STALE|${INSTANCE_ID}|${ROLE}|${MISSED}|${LAST_BEAT}"
    else
      echo "  STALE  ${INSTANCE_ID} (${ROLE}) -- already stale, last beat: ${LAST_BEAT}"
    fi
  fi
done

if [ "${TOTAL_COUNT}" -eq 0 ]; then
  [ "${CRON_MODE}" = false ] && echo "No instances found in ${INSTANCES_DIR}"
  exit 0
fi

if [ "${CRON_MODE}" = false ]; then
  echo ""
  if [ "${STALE_COUNT}" -eq 0 ]; then
    echo "All instances healthy."
  else
    echo "${STALE_COUNT} stale instance(s) detected."
  fi
fi

[ "${STALE_COUNT}" -gt 0 ] && exit 1 || exit 0
