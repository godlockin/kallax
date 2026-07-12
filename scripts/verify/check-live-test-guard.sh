#!/usr/bin/env bash
# check-live-test-guard.sh — EPIC-114 L5: *-live.test.ts must gate with describe.skipIf
# Prevents CI from unconditionally running tests that need live external servers.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -qE 'describe\.skipIf\(' "$f"; then
    echo "FAIL: $f — *-live.test.ts must use describe.skipIf(!process.env.X_LIVE)" >&2
    fail=1
  fi
done < <(find node/tests -name '*-live.test.ts' 2>/dev/null)

exit "$fail"
