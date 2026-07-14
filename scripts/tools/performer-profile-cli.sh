#!/usr/bin/env bash
# scripts/tools/performer-profile-cli.sh — Performer profile tiered memory CLI (EPIC-121-B)
#
# Usage:
#   performer-profile-cli.sh get <performer_id>
#   performer-profile-cli.sh set <performer_id> --mastery L2 --abandonment-rate 8.5
#   performer-profile-cli.sh search --embedding "0.1,0.2" --top 3

set -euo pipefail

STORE="${KALLAX_PROFILE_STORE:-$HOME/.kallax/profiles}"
mkdir -p "$STORE"

cmd="${1:-}"; pid="${2:-}"; shift 2>/dev/null || true

get_profile() {
  if [[ -f "$STORE/$pid.json" ]]; then
    cat "$STORE/$pid.json"
  else
    printf '{"performerId":"%s","masteryLevel":"L2","abandonmentRate":0,"taskHistory":[],"skillEmbedding":null,"updatedAt":0}\n' "$pid"
  fi
}

set_profile() {
  mastery="L2" rate="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in --mastery) mastery="$2"; shift 2 ;; --abandonment-rate) rate="$2"; shift 2 ;; *) shift ;; esac
  done
  python3 - <<EOF
import json, time, sys
p = {
    "performerId": "$pid",
    "masteryLevel": "$mastery",
    "abandonmentRate": $rate,
    "taskHistory": [],
    "skillEmbedding": None,
    "updatedAt": int(time.time() * 1000)
}
print(json.dumps(p))
EOF
}

case "$cmd" in
  get)    [[ -z "$pid" ]] && { echo "ERROR: id required" >&2; exit 2; } ;;
  set)    [[ -z "$pid" ]] && { echo "ERROR: id required" >&2; exit 2; } ;;
  search) ;;
  *) echo "Usage: $0 {get|set|search} [id] [--opts]" >&2; exit 2 ;;
esac

case "$cmd" in
  get)    get_profile ;;
  set)    set_profile "$@" > "$STORE/$pid.json" && echo "Saved: $pid mastery=$mastery rate=$rate" ;;
  search) echo '{"ids":[],"note":"vector search pending EPIC-121-B extension"}' ;;
esac
