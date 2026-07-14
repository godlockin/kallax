#!/usr/bin/env bash
# check-live-test-guard.sh — EPIC-114 L5: *-live.test.ts must gate with describe.skipIf
# Prevents CI from unconditionally running tests that need live external servers.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# KALLAX_STAGED_ONLY=1 → only check staged *-live.test.ts files
if [ -n "${KALLAX_STAGED_ONLY:-}" ] && [ "$KALLAX_STAGED_ONLY" = "1" ]; then
  STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E 'node/tests/.*-live\.test\.ts$' || true)
  if [ -z "$STAGED" ]; then
    echo "KALLAX_STAGED_ONLY=1: no staged *-live.test.ts files, skip"
    exit 0
  fi
  FILES=$STAGED
else
  FILES=$(find node/tests -name '*-live.test.ts' 2>/dev/null)
fi

fail=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ -f "$f" ]] || continue
  if ! grep -qE 'describe\.skipIf\(' "$f"; then
    echo "FAIL: $f — *-live.test.ts must use describe.skipIf(!process.env.X_LIVE)" >&2
    fail=1
  fi
done <<< "$FILES"

exit "$fail"
