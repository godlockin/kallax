#!/usr/bin/env bash
# EPIC-287-C — isolated real scope-cache behavior.
# Scope cache is optimization; missing, malformed, or stale cache must fall back
# to git ls-files and never turn a real scan into silent empty PASS.
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "$REPO_ROOT"

SCRIPT="scripts/hooks/check-jargon.sh"
SCOPE_JSON="jira/tickets/.scope-commits.json"
PASS=0
FAIL=0
TMPDIR_TEST="$(mktemp -d)"
SCOPE_BACKUP="$TMPDIR_TEST/scope-commits.json"

if [ -f "$SCOPE_JSON" ]; then
  cp "$SCOPE_JSON" "$SCOPE_BACKUP"
else
  printf '%s\n' 'scope cache must exist after builder step' >&2
  rm -rf "$TMPDIR_TEST"
  exit 1
fi
restore() {
  mv "$SCOPE_BACKUP" "$SCOPE_JSON"
  rm -rf "$TMPDIR_TEST"
}
trap restore EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_scan() {
  local output="$1"
  local rc
  if bash "$SCRIPT" --all > "$output" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
    SCAN_RC="$rc"
  else
    ko "--all unexpected exit=$rc"
    SCAN_RC="$rc"
  fi
}

assert_fallback_scan() {
  local label="$1" output="$2"
  if grep -q 'scope cache: fallback git ls-files' "$output"; then
    ok "$label reports git ls-files fallback"
  else
    ko "$label missing git ls-files fallback report"
  fi
  if grep -q '^FAIL:' "$output"; then
    ok "$label performed non-empty fail-closed scan (exit=$SCAN_RC)"
  else
    ko "$label produced no scan findings (possible empty PASS)"
  fi
}

echo '=== EPIC-287-C: isolated scope cache ==='
echo ''

echo '--- Group 1: Python scanner and valid cache ---'
if grep -q 'python3 -' "$SCRIPT"; then
  ok 'Python single-process scanner present'
else
  ko 'Python single-process scanner missing'
fi
if bash scripts/hooks/build-scope-commits.sh >"$TMPDIR_TEST/build.log" 2>&1; then
  ok 'build-scope-commits.sh exit 0'
else
  rc=$?
  ko "build-scope-commits.sh exit $rc"
  cat "$TMPDIR_TEST/build.log"
fi
if [ -f "$SCOPE_JSON" ]; then
  ok 'real scope cache exists'
else
  ko 'real scope cache missing'
fi
START=$(date +%s)
run_scan "$TMPDIR_TEST/valid.log"
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -lt 15 ]; then
  ok "valid --all completed in ${ELAPSED}s (exit=$SCAN_RC)"
else
  ko "valid --all took ${ELAPSED}s"
fi
if grep -q 'scope cache: loaded' "$TMPDIR_TEST/valid.log"; then
  ok 'valid cache reported loaded'
else
  ko 'valid cache did not report loaded'
fi

echo ''
echo '--- Group 2: missing cache fallback ---'
mv "$SCOPE_JSON" "$TMPDIR_TEST/missing-scope.json"
run_scan "$TMPDIR_TEST/missing.log"
assert_fallback_scan 'missing cache' "$TMPDIR_TEST/missing.log"
mv "$TMPDIR_TEST/missing-scope.json" "$SCOPE_JSON"

echo ''
echo '--- Group 3: malformed cache fallback ---'
printf '%s\n' '{"commits": []}' > "$SCOPE_JSON"
run_scan "$TMPDIR_TEST/malformed.log"
assert_fallback_scan 'malformed cache' "$TMPDIR_TEST/malformed.log"
mv "$SCOPE_BACKUP" "$SCOPE_JSON"
cp "$SCOPE_JSON" "$SCOPE_BACKUP"

echo ''
echo '--- Group 4: metadata-matching empty commits fallback ---'
CURRENT_HEAD="$(git rev-parse HEAD)"
BASELINE_COMMIT="$(jq -r '.baseline_commit' jira/tickets/.jargon-baseline.json)"
printf '{"commits": {}, "generated_head": "%s", "baseline_commit": "%s"}\n' "$CURRENT_HEAD" "$BASELINE_COMMIT" > "$SCOPE_JSON"
run_scan "$TMPDIR_TEST/empty.log"
assert_fallback_scan 'empty commits cache' "$TMPDIR_TEST/empty.log"

# Restore known-good cache before stale metadata case.
mv "$SCOPE_BACKUP" "$SCOPE_JSON"
cp "$SCOPE_JSON" "$SCOPE_BACKUP"

echo ''
echo '--- Group 5: stale metadata fallback ---'
printf '%s\n' '{"commits": {"stale": ["CLAUDE.md"]}, "generated_head": "stale-head", "baseline_commit": "stale-baseline"}' > "$SCOPE_JSON"
run_scan "$TMPDIR_TEST/stale.log"
assert_fallback_scan 'stale cache' "$TMPDIR_TEST/stale.log"

printf '%s\n' "=== Result: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ]
