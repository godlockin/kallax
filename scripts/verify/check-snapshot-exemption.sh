#!/usr/bin/env bash
# check-snapshot-exemption.sh — list snapshot expected.json paths exempted
# from check-claim-evidence.sh numeric pattern check (EPIC-283, DSH Path B)
#
# Why: snapshot harness records real slash command output to expected/*.json.
# Output may contain numbers like "Core Experts (5)" or "Skills (16)" — these
# are NOT "X/Y PASS" decorative claims but the regex is greedy on context.
# Exempting these paths prevents false-positive FAIL in pre-commit hook.
#
# EPIC-283-scope (L5 boundary defense, 2026-08-22):
# Exemption scope is STRICTLY LIMITED to paths matching:
#   ^node/tests/integration/snapshot/expected/.*\.json$
# Any other path (README / CHANGELOG / confluence/decisions/* etc.) is
# REJECTED with exit 1 — extending the list to bypass L5 boundary would
# recreate v3.8.0 fake-PASS regression (EPIC-069-D).
# See confluence/decisions/epic-283-snapshot-exemption-scope-2026-08-22.md
# for the locked rationale.
#
# Usage:
#   bash scripts/verify/check-snapshot-exemption.sh [optional-test-path]
#     Without arg: validate the configured exemption list itself.
#     With arg:    validate ONE path against the strict scope (for follow-up tests).
#   Returns 0 if all expected paths exist + within scope, 1 otherwise.
#
# Exit codes:
#   0 = all listed snapshot files exist + within strict scope
#   1 = at least one path missing OR out of scope (exemption list violation)

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
LIST="${ROOT}/scripts/verify/.snapshot-exemption-list.txt"

# Strict scope regex: snapshot expected JSON paths only.
# Anchored: full path from repo root must match.
STRICT_PATTERN='^node/tests/integration/snapshot/expected/[^[:space:]]+\.json$'

# Mode 1 (single-arg validation): caller passes one path to validate.
# Used by follow-up tests that probe scope enforcement without writing to
# the exemption list. We NEVER touch the list here.
if [[ $# -ge 1 ]]; then
  probe="$1"
  if [[ "$probe" =~ $STRICT_PATTERN ]]; then
    echo "OK: path in scope: $probe"
    exit 0
  else
    echo "REJECT: path 不在 snapshot/expected/* 范围, L5 boundary 防线自毁防御"
    echo "  path: $probe"
    echo "  required pattern: $STRICT_PATTERN"
    exit 1
  fi
fi

# Mode 0 (default): validate the configured exemption list.
if [[ ! -f "$LIST" ]]; then
  echo "FAIL: exemption list not found: $LIST"
  exit 1
fi

MISSING=0
OUT_OF_SCOPE=0
COUNT=0

# Use || [[ -n "$line" ]] to handle files without trailing newline (EPIC-283: maintainer edit)
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  COUNT=$((COUNT + 1))

  # EPIC-283-scope: enforce strict scope before doing file existence check.
  # Out-of-scope paths fail-fast — even if the file exists, we don't
  # allow exemption for non-snapshot paths.
  if ! [[ "$line" =~ $STRICT_PATTERN ]]; then
    echo "REJECT: exemption path out of scope (L5 boundary defense): $line"
    OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
    continue
  fi

  full="${ROOT}/${line}"
  if [[ ! -f "$full" ]]; then
    echo "FAIL: exempted snapshot missing: $line"
    MISSING=$((MISSING + 1))
  fi
done < "$LIST"

if [[ $OUT_OF_SCOPE -gt 0 ]]; then
  echo ""
  echo "REJECTED: $OUT_OF_SCOPE/$COUNT path(s) out of strict scope"
  echo "  scope regex: $STRICT_PATTERN"
  echo "  L5 boundary defense engaged — extending exemption to README/CHANGELOG"
  echo "  would recreate v3.8.0 fake-PASS regression."
  exit 1
fi

if [[ $MISSING -gt 0 ]]; then
  echo ""
  echo "FAILED: $MISSING/$COUNT exempted snapshot(s) missing"
  exit 1
fi

echo "OK: $COUNT exempted snapshot file(s) all exist + within strict scope"
exit 0
