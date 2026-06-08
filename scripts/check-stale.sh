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

    # AC5: ZOMBIE detection -- daemon dead but state still ACTIVE
    DAEMON_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' "${state_file}" 2>/dev/null || true)
    if [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
      jq '.status = "ZOMBIE"' "${state_file}" > "${state_file}.tmp" 2>/dev/null && \
        mv "${state_file}.tmp" "${state_file}" 2>/dev/null || true
      if [ "${CRON_MODE}" = true ]; then
        echo "ZOMBIE|${INSTANCE_ID}|${ROLE}|${NEW_MISSED}|${LAST_BEAT}"
      else
        echo "  ZOMBIE ${INSTANCE_ID} (daemon pid ${DAEMON_PID} dead, state was ACTIVE)"
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
  # Master-specific: if master_main is STALE, alert for takeover
  MASTER_STATE="${INSTANCES_DIR}/master_main/state.json"
  MASTER_HANDOFF="${INSTANCES_DIR}/master_main/handoff.json"
  if [ -f "${MASTER_STATE}" ]; then
    MASTER_STATUS=$(jq -r '.status // "unknown"' "${MASTER_STATE}" 2>/dev/null || echo "unknown")
    if [ "${MASTER_STATUS}" = "STALE" ] || [ "${MASTER_STATUS}" = "CLOSING" ]; then
      echo ""
      echo "  ╔════════════════════════════════════════════════════╗"
      echo "  ║  MASTER TAKEOVER REQUIRED                          ║"
      echo "  ╠════════════════════════════════════════════════════╣"
      echo "  ║  master_main is ${MASTER_STATUS}                        ║"
      echo "  ║  Handoff: $([ -f "${MASTER_HANDOFF}" ] && echo 'AVAILABLE' || echo 'NOT FOUND')                              ║"
      echo "  ║  Action: KALLAX_ROLE=master bash session_start.sh  ║"
      echo "  ╚════════════════════════════════════════════════════╝"
      
      # Write alert to conductor inbox
      ALERT_FILE=".kallax/queue/inbox/conductor_main/master_takeover_$(date +%s).json"
      mkdir -p "$(dirname "${ALERT_FILE}")"
      cat > "${ALERT_FILE}" << ALERT
{"type":"master_takeover","master_status":"${MASTER_STATUS}","handoff_available":$([ -f "${MASTER_HANDOFF}" ] && echo 'true' || echo 'false'),"detected_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","action":"KALLAX_ROLE=master bash .kallax/hooks/session_start.sh --role master"}
ALERT
    fi
  fi
  else
    echo "${STALE_COUNT} stale instance(s) detected."
  fi
fi

[ "${STALE_COUNT}" -gt 0 ] && exit 1 || exit 0
