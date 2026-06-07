#!/usr/bin/env bash
# KALLAX Conductor Session Init -- EPIC-016-R AC13
# 3-step state-check on startup: performers → inbox → PRs/blockers.
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
INBOX_DIR="${KALLAX_ROOT}/queue/inbox"
OUTBOX_DIR="${KALLAX_ROOT}/queue/outbox"
LOG_DIR="${KALLAX_ROOT}/logs"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ============================================================
# Step 1/3: Scan in-progress performers
# ============================================================
echo ""
echo "─── Step 1/3: Active Performers ───"

PERFORMER_COUNT=0
IN_PROGRESS=""
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  role=$(jq -r '.role // ""' "$sf" 2>/dev/null || echo "")
  [ "$role" = "performer" ] || continue

  instance_id=$(basename "$(dirname "$sf")")
  status=$(jq -r '.status // "unknown"' "$sf" 2>/dev/null || echo "unknown")
  task_id=$(jq -r '.current_task.ticket_id // empty' "$sf" 2>/dev/null || echo "")
  branch=$(jq -r '.branch // "unknown"' "$sf" 2>/dev/null || echo "unknown")

  PERFORMER_COUNT=$((PERFORMER_COUNT + 1))
  if [ "$status" = "ACTIVE" ] || [ "$status" = "HEARTBEATING" ]; then
    IN_PROGRESS="${IN_PROGRESS}  [${instance_id}] task=${task_id:-none} branch=${branch}"
  fi
done

echo "  Total performers: ${PERFORMER_COUNT}"
if [ -n "$IN_PROGRESS" ]; then
  echo "  In progress:${IN_PROGRESS}"
else
  echo "  In progress: (none)"
fi

# ============================================================
# Step 2/3: Scan inbox queue
# ============================================================
echo ""
echo "─── Step 2/3: Inbox Queue ───"

INBOX_COUNT=0
PENDING_ITEMS=""
for inbox_dir in "${INBOX_DIR}"/*; do
  [ -d "$inbox_dir" ] || continue
  count=$(ls -1 "$inbox_dir" 2>/dev/null | wc -l | tr -d ' ')
  instance=$(basename "$inbox_dir")
  if [ "$count" -gt 0 ]; then
    INBOX_COUNT=$((INBOX_COUNT + count))
    PENDING_ITEMS="${PENDING_ITEMS}  ${instance}: ${count} item(s)"
  fi
done

echo "  Total pending items: ${INBOX_COUNT}"
if [ -n "$PENDING_ITEMS" ]; then
  echo "  By performer:${PENDING_ITEMS}"
else
  echo "  (empty)"
fi

# ============================================================
# Step 3/3: PR status + blockers
# ============================================================
echo ""
echo "─── Step 3/3: PRs & Blockers ───"

# Check for recently closed stale instances (ZOMBIE/STALE)
STALE_INSTANCES=""
for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  status=$(jq -r '.status // "unknown"' "$sf" 2>/dev/null || echo "unknown")
  if [ "$status" = "STALE" ] || [ "$status" = "ZOMBIE" ]; then
    instance_id=$(basename "$(dirname "$sf")")
    last_beat=$(jq -r '.heartbeat.last_beat // "unknown"' "$sf" 2>/dev/null || echo "unknown")
    STALE_INSTANCES="${STALE_INSTANCES}  ${instance_id} [${status}] last_beat=${last_beat}"
  fi
done

if [ -n "$STALE_INSTANCES" ]; then
  echo "  Stale/zombie instances:${STALE_INSTANCES}"
else
  echo "  Stale/zombie: (none)"
fi

# Summary card
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  CONDUCTOR SESSION READY                          ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Performers  ▸ ${PERFORMER_COUNT} active                ║"
echo "║  Inbox items▸ ${INBOX_COUNT} pending                   ║"
echo "║  Blockers   ▸ $(echo "${STALE_INSTANCES:-none}" | wc -l | tr -d ' ') stale/zombie            ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  NEXT: review inbox → dispatch tasks → merge PRs  ║"
echo "╚════════════════════════════════════════════════════╝"