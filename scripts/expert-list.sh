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

# TIER allowlist validation (strict — only known values)
VALID_TIERS="default extended generated all"
if [[ ! " $VALID_TIERS " =~ " $TIER " ]]; then
  echo "ERROR: Invalid tier '$TIER'. Must be one of: $VALID_TIERS" >&2
  exit 1
fi

# DOMAIN validation: alphanumeric + dash/underscore only (rejects SQL meta-chars)
if [[ "$DOMAIN" != "all" ]] && [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: Invalid domain '$DOMAIN'. Must be alphanumeric, dash, or underscore." >&2
  exit 1
fi

# Build query — values escaped via single-quote wrap + double-single-quote for embedded '
# (sqlite3 CLI does NOT support :param or ? placeholders, so shell-escape is the only option)
# Since TIER is allowlisted and DOMAIN is regex-validated above, escape is a defense-in-depth.
TIER_ESC="${TIER//\'/\'\'}"
DOMAIN_ESC="${DOMAIN//\'/\'\'}"

WHERE_CLAUSE="1=1"
if [[ "$TIER" != "all" ]]; then
  WHERE_CLAUSE="tier='$TIER_ESC'"
fi
if [[ "$DOMAIN" != "all" ]]; then
  WHERE_CLAUSE="$WHERE_CLAUSE AND domain='$DOMAIN_ESC'"
fi

# Check database exists
if [[ ! -f "$DB_PATH" ]]; then
  echo "ERROR: Database not found. Run: scripts/build-expert-index.sh --rebuild" >&2
  exit 1
fi

# Count query
if [[ "$COUNT_ONLY" == true ]]; then
  sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM expert WHERE $WHERE_CLAUSE;"
  exit 0
fi

# Full listing
sqlite3 -header -column "$DB_PATH" \
  "SELECT emoji, name_cn, role, domain, tier, description FROM expert WHERE $WHERE_CLAUSE ORDER BY domain, name_cn;"
