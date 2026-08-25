#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

baseline=$(mktemp)
fixture="node/src/__epic296_unmeasured__.ts"
cleanup() {
  rm -f "$baseline" "$fixture" "$fixture.tsbuildinfo"
}
trap cleanup EXIT

if ! bash scripts/scan-dead-code.sh >"$baseline" 2>&1; then
  printf '%s\n' 'baseline dead-code scan failed' >&2
  exit 1
fi

if grep -qE 'core/event-log/(event-store|emit|types)' "$baseline"; then
  printf '%s\n' 'barrel-mediated event-log coverage reported as uncovered' >&2
  exit 1
fi

printf '%s\n' 'export const epic296Unmeasured = true;' >"$fixture"
fixture_output=$(mktemp)
trap 'rm -f "$baseline" "$fixture" "$fixture_output" "$fixture.tsbuildinfo"' EXIT

if bash scripts/scan-dead-code.sh >"$fixture_output" 2>&1; then
  printf '%s\n' 'unmeasured fixture unexpectedly passed scanner' >&2
  exit 1
fi

if ! grep -q '__epic296_unmeasured__' "$fixture_output"; then
  printf '%s\n' 'scanner did not report unmeasured fixture' >&2
  exit 1
fi
