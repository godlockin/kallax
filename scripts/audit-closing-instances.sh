#!/usr/bin/env bash
# KALLAX audit-closing-instances — 扫描 .kallax/instances/ 找 CLOSING + ZOMBIE instances
# Usage: bash scripts/audit-closing-instances.sh
# Output: CLOSING/ZOMBIE instance列表 + 距 last_beat 时间
set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"

if [ ! -d "$INSTANCES_DIR" ]; then
  echo "ERROR: instances dir not found: $INSTANCES_DIR"
  exit 1
fi

# etime_to_seconds "01:23:45" -> 5025 (or "1-02:03:04" -> 93784)
etime_to_seconds() {
  local e="$1" days=0 rest="" h=0 m=0 s=0
  case "$e" in
    *-*) days="${e%%-*}"; rest="${e#*-}" ;;
    *)   days=0; rest="$e" ;;
  esac
  local IFS=':'
  local parts=($rest)
  case "${#parts[@]}" in
    3) h="${parts[0]}"; m="${parts[1]}"; s="${parts[2]}" ;;
    2) m="${parts[0]}"; s="${parts[1]}" ;;
    *) echo 0; return ;;
  esac
  local dh=${days#0}; dh=${dh:-0}; local hh=${h#0}; hh=${hh:-0}; local mm=${m#0}; mm=${mm:-0}; local ss=${s#0}; ss=${ss:-0}; echo $(( dh * 86400 + hh * 3600 + mm * 60 + ss ))
}

now_sec=$(date +%s)
total_closing=0
total_zombie=0

echo "── KALLAX instance audit $(date -u +%Y-%m-%dT%H:%M:%SZ) ──"
echo ""

for sf in "${INSTANCES_DIR}"/*/state.json; do
  [ -f "$sf" ] || continue
  INSTANCE_ID=$(jq -r '.instance_id // empty' "$sf" 2>/dev/null || true)
  [ -z "$INSTANCE_ID" ] && continue

  STATUS=$(jq -r '.status // empty' "$sf" 2>/dev/null || true)
  LAST_BEAT=$(jq -r '.heartbeat.last_beat // empty' "$sf" 2>/dev/null || true)

  if [ "$STATUS" != "CLOSING" ] && [ "$STATUS" != "ZOMBIE" ]; then
    continue
  fi

  # Calculate age from last_beat
  age_sec=0
  if [ -n "$LAST_BEAT" ]; then
    # Portable timestamp parser (Linux + macOS)
# Try GNU date first (Linux), then BSD date (macOS)
last_beat_sec=$(date -u -d "$LAST_BEAT" +%s 2>/dev/null) || \
last_beat_sec=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_BEAT" +%s 2>/dev/null) || \
last_beat_sec=0
    age_sec=$((now_sec - last_beat_sec))
  fi

  age_str=""
  if [ "$age_sec" -gt 0 ]; then
    days=$((age_sec / 86400))
    hours=$(((age_sec % 86400) / 3600))
    mins=$(((age_sec % 3600) / 60))
    if [ "$days" -gt 0 ]; then
      age_str="${days}d ${hours}h ${mins}m ago"
    elif [ "$hours" -gt 0 ]; then
      age_str="${hours}h ${mins}m ago"
    else
      age_str="${mins}m ago"
    fi
  fi

  if [ "$STATUS" = "CLOSING" ]; then
    total_closing=$((total_closing + 1))
    flag=""
    # Flag if CLOSING > 24h (86400 seconds)
    if [ "$age_sec" -gt 86400 ]; then
      flag=" [>24h OLD]"
    fi
    echo "  CLOSING  ${INSTANCE_ID}${flag} last_beat: ${age_str:-(unknown)}"
  else
    total_zombie=$((total_zombie + 1))
    echo "  ZOMBIE   ${INSTANCE_ID} last_beat: ${age_str:-(unknown)}"
  fi
done

echo ""
echo "── summary: ${total_closing} CLOSING, ${total_zombie} ZOMBIE ──"

if [ "$total_closing" -gt 30 ]; then
  echo "  WARNING: CLOSING count ${total_closing} > 30 threshold"
fi