#!/bin/bash
# expert-list.sh — List experts with filtering
# Usage: scripts/expert-list.sh [--tier default|extended|generated] [--domain <domain>|all] [--count]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_PATH="$REPO_ROOT/.kallax/data/expert_index.db"

TIER="all"
DOMAIN="all"
COUNT_ONLY=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --count)
      COUNT_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Build query
WHERE_CLAUSE="1=1"
if [[ "$TIER" != "all" ]]; then
  WHERE_CLAUSE="tier='$TIER'"
fi
if [[ "$DOMAIN" != "all" ]]; then
  WHERE_CLAUSE="$WHERE_CLAUSE AND domain='$DOMAIN'"
fi

# Check database exists
if [[ ! -f "$DB_PATH" ]]; then
  echo "ERROR: Database not found. Run: scripts/build-expert-index.sh --rebuild" >&2
  exit 1
fi

# Count query
if [[ "$COUNT_ONLY" == true ]]; then
  COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM expert WHERE $WHERE_CLAUSE;")
  echo "$COUNT"
  exit 0
fi

# Full listing
sqlite3 -header -column "$DB_PATH" \
  "SELECT emoji, name_cn, role, domain, tier, description FROM expert WHERE $WHERE_CLAUSE ORDER BY domain, name_cn;"