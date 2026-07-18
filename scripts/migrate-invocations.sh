#!/usr/bin/env bash
# scripts/migrate-invocations.sh
# EPIC-122-E Phase 2: Migrate state.json expert_invocations[] to EPIC jsonl files
#
# Usage: bash scripts/migrate-invocations.sh [--dry-run]
#
# This script:
# 1. Reads state.json expert_invocations[] array
# 2. Extracts EPIC from each ticket_id (e.g., "EPIC-104-TASK-002" → "EPIC-104")
# 3. Appends each invocation to ~/.kallax/queue/EPIC-XXX/invocations.jsonl
# 4. Does NOT delete state.json expert_invocations[] (Phase 3 will do that)
#
set -euo pipefail

INVOCATION_DIR="${HOME}/.kallax/queue"
STATE_FILE="${HOME}/.kallax/state/state.json"
DRY_RUN=false

# Parse args
if [ "$#" -ge 1 ] && [ "$1" = "--dry-run" ]; then
  DRY_RUN=true
  echo "[DRY-RUN] No files will be modified"
fi

# Check jq availability
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found (required for JSON parsing)"
  exit 1
fi

# Check state.json exists and has expert_invocations
if [ ! -f "$STATE_FILE" ]; then
  echo "INFO: $STATE_FILE not found, nothing to migrate"
  exit 0
fi

# Check if expert_invocations array exists and is non-empty
invocations=$(jq '.expert_invocations // []' "$STATE_FILE" 2>/dev/null || echo '[]')
if [ -z "$invocations" ] || [ "$invocations" = "[]" ]; then
  echo "INFO: No expert_invocations[] found in state.json, nothing to migrate"
  exit 0
fi

count=$(echo "$invocations" | jq 'length')
echo "Found $count invocation(s) in state.json to migrate"

# Get array as JSON lines and process each
invocations_list=$(echo "$invocations" | jq -r '.[] | @json' 2>/dev/null || echo "")

if [ -z "$invocations_list" ]; then
  echo "INFO: No invocations to process"
  exit 0
fi

# Process each invocation using for loop (avoids pipe-to-while subshell issue)
for invocation in $invocations_list; do
  # Extract fields from JSON
  ticket_id=$(echo "$invocation" | jq -r '.ticket_id // empty' 2>/dev/null || echo "")
  expert_id=$(echo "$invocation" | jq -r '.expert_id // empty' 2>/dev/null || echo "")
  ts=$(echo "$invocation" | jq -r '.ts // empty' 2>/dev/null || echo "")
  backend=$(echo "$invocation" | jq -r '.backend // "unknown"' 2>/dev/null || echo "unknown")

  if [ -z "$ticket_id" ] || [ -z "$expert_id" ] || [ -z "$ts" ]; then
    echo "WARN: Skipping malformed invocation"
    continue
  fi

  # Extract EPIC from ticket_id (e.g., "EPIC-104-TASK-002" → "EPIC-104")
  if [[ "$ticket_id" =~ ^([A-Z]+-[0-9]+) ]]; then
    epic="${BASH_REMATCH[1]}"
  else
    epic="DEFAULT"
  fi

  epic_dir="${INVOCATION_DIR}/${epic}"
  epic_file="${epic_dir}/invocations.jsonl"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would write to: $epic_file"
    echo "[DRY-RUN]   expert_id=$expert_id, ticket_id=$ticket_id, ts=$ts, backend=$backend"
  else
    # Create EPIC dir if not exists
    mkdir -p "$epic_dir"
    chmod 0700 "$epic_dir" 2>/dev/null || true

    # Build JSON payload for EPIC jsonl
    payload=$(jq -n \
      --arg eid "$expert_id" \
      --arg tid "$ticket_id" \
      --argjson t "$ts" \
      --arg b "$backend" \
      '{expert_id: $eid, ticket_id: $tid, ts: $t, backend: $b}')

    # Append to EPIC jsonl
    echo "$payload" >> "$epic_file"
    echo "Migrated: $ticket_id -> $epic/invocations.jsonl"
  fi
done

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] Run without --dry-run to actually migrate"
else
  echo "Migration complete. EPIC jsonl files created in: $INVOCATION_DIR"
  echo "NOTE: state.json expert_invocations[] not modified (Phase 3 cleanup pending)"
fi
