#!/usr/bin/env bash
# scripts/check-fact-forcing-preflight.sh
# EPIC-025-B UP-2: 4-Level Fact-Forcing preflight checker
# Usage: check-fact-forcing-preflight.sh <expert.md> [--check-lessons <epic-id>] [--force-merge]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$SCRIPT_DIR/lib/fact-forcing-preflight.sh"

# Check if lib exists
if [[ ! -f "$LIB_PATH" ]]; then
  echo "ERROR: lib not found: $LIB_PATH" >&2
  exit 1
fi

# Source the library
source "$LIB_PATH"

# Default: no force merge
FORCE_MERGE=0

# Parse arguments
EXPERT_FILE=""
CHECK_LESSONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-lessons)
      CHECK_LESSONS="$2"
      shift 2
      ;;
    --force-merge)
      FORCE_MERGE=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 <expert.md> [--check-lessons <epic-id>] [--force-merge]"
      echo ""
      echo "Options:"
      echo "  --check-lessons <epic-id>  Check LESSONS-LEARNED.md exists before running preflight"
      echo "  --force-merge              Override lessons check (for emergency merges)"
      echo "  -h, --help                 Show this help"
      exit 0
      ;;
    *)
      if [[ -z "$EXPERT_FILE" ]]; then
        EXPERT_FILE="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$EXPERT_FILE" ]]; then
  echo "ERROR: missing expert.md file" >&2
  echo "Usage: $0 <expert.md> [--check-lessons <epic-id>] [--force-merge]" >&2
  exit 1
fi

if [[ ! -f "$EXPERT_FILE" ]]; then
  echo "ERROR: file not found: $EXPERT_FILE" >&2
  exit 1
fi

# Run preflight
echo "Running 4-Level Fact-Forcing preflight..."
echo ""

if [[ -n "$CHECK_LESSONS" ]]; then
  if extract_and_execute "$EXPERT_FILE" --check-lessons "$CHECK_LESSONS"; then
    preflight_pass=1
  else
    preflight_pass=0
  fi
else
  if extract_and_execute "$EXPERT_FILE"; then
    preflight_pass=1
  else
    preflight_pass=0
  fi
fi

if [[ $preflight_pass -eq 1 ]]; then
  echo ""
  echo "=========================================="
  echo "PREFLIGHT RESULT: PASS"
  echo "=========================================="
  exit 0
else
  echo ""
  echo "=========================================="
  echo "PREFLIGHT RESULT: FAIL"
  echo "=========================================="
  echo ""
  echo "Ticket cannot be closed. Fix failures before proceeding."
  echo ""
  if [[ $FORCE_MERGE -eq 1 ]]; then
    echo "[OVERRIDE] --force-merge was set, proceeding anyway..."
    exit 0
  fi
  exit 1
fi