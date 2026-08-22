#!/usr/bin/env bash
# check-snapshot-exemption.sh — list snapshot expected.json paths exempted
# from check-claim-evidence.sh numeric pattern check (EPIC-283, DSH Path B)
#
# Why: snapshot harness records real slash command output to expected/*.json.
# Output may contain numbers like "Core Experts (5)" or "Skills (16)" — these
# are NOT "X/Y PASS" decorative claims but the regex is greedy on context.
# Exempting these paths prevents false-positive FAIL in pre-commit hook.
#
# Usage:
#   bash scripts/verify/check-snapshot-exemption.sh
#   Returns 0 if all expected paths exist, 1 if any missing.
#
# Exit codes:
#   0 = all listed snapshot files exist
#   1 = at least one path missing (FAIL — exemption references dangling file)

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
LIST="${ROOT}/scripts/verify/.snapshot-exemption-list.txt"

if [[ ! -f "$LIST" ]]; then
  echo "FAIL: exemption list not found: $LIST"
  exit 1
fi

MISSING=0
COUNT=0

# Use || [[ -n "$line" ]] to handle files without trailing newline (EPIC-283: maintainer edit)
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  COUNT=$((COUNT + 1))
  full="${ROOT}/${line}"
  if [[ ! -f "$full" ]]; then
    echo "FAIL: exempted snapshot missing: $line"
    MISSING=$((MISSING + 1))
  fi
done < "$LIST"

if [[ $MISSING -gt 0 ]]; then
  echo ""
  echo "FAILED: $MISSING/$COUNT exempted snapshot(s) missing"
  exit 1
fi

echo "OK: $COUNT exempted snapshot file(s) all exist"
exit 0