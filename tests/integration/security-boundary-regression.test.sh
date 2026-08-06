#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_not_found() { rg -n "$1" "$2" >/dev/null && fail "$1 still present in $2" || true; }
assert_not_found 'eval[[:space:]]+"\$cmd"' "$ROOT/scripts/docker-redis.sh"
assert_not_found 'bash[[:space:]]+-c[[:space:]]+"\$SERVER_CMD"' "$ROOT/scripts/supervisor.sh"
assert_not_found 'flock[[:space:]]+.*-c' "$ROOT/scripts/heartbeat/run-history.sh"
assert_not_found 'KALLAX_CURRENT_ROLE' "$ROOT/scripts/permission/readonly-path.sh"
assert_not_found 'KALLAX_CURRENT_ROLE' "$ROOT/scripts/permission/workspace-switch.sh"
# Workspace inputs must be rejected before filesystem access.
source "$ROOT/scripts/lib/workspace.sh"
workspace_init "$ROOT"
! workspace_fs_exists /etc/passwd || fail 'absolute path escaped workspace'
! workspace_fs_exists ../etc/passwd || fail '.. path escaped workspace'
# Existing symlink pointing outside must also be denied.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ln -s /etc "$ROOT/.security-boundary-link"
trap 'rm -f "$ROOT/.security-boundary-link"; rm -rf "$tmp"' EXIT
! workspace_fs_exists .security-boundary-link/passwd || fail 'symlink escaped workspace'
rm -f "$ROOT/.security-boundary-link"
# Nonexistent final components must still resolve symlink parents and dot segments.
mkdir -p "$ROOT/miao" "$ROOT/.kallax"
ln -s "$ROOT/miao" "$ROOT/.kallax/security-miao-link"
state="$ROOT/.kallax/state/state.json"
backup="${state}.security-backup.$$"
mkdir -p "$(dirname "$state")"
cp "$state" "$backup" 2>/dev/null || true
restore() {
  rm -f "$ROOT/.kallax/security-miao-link"
  if [[ -f "$backup" ]]; then mv "$backup" "$state"; fi
}
trap restore EXIT
printf '{"role":"performer"}\n' > "$state"
if bash "$ROOT/scripts/permission/readonly-path.sh" --path .kallax/security-miao-link/new-final --actor security-test >/dev/null 2>&1; then
  fail 'symlink parent with missing final path bypassed readonly protection'
fi
if bash "$ROOT/scripts/permission/readonly-path.sh" --path miao/new-final/../secret --actor security-test >/dev/null 2>&1; then
  fail 'normalized nonexistent protected path bypassed readonly protection'
fi
printf 'PASS security boundary regression\n'
