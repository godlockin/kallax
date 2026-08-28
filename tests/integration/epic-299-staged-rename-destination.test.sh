#!/usr/bin/env bash
# EPIC-299: staged rename scans destination path using isolated alternate index.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

TMPDIR_TEST="$(mktemp -d)"
INDEX_FILE="$TMPDIR_TEST/index"
SOURCE="confluence/decisions/kallax-lessons-best-practices-2026-08-07.md"
DEST="confluence/decisions/.epic299-staged-rename-destination.md"
cp "$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --git-path index)" "$INDEX_FILE"
cleanup() {
  rm -f "$DEST"
  rm -rf "$TMPDIR_TEST"
}
trap cleanup EXIT
export GIT_INDEX_FILE="$INDEX_FILE"

cp "$SOURCE" "$DEST"
printf '\n这是%s staged rename regression fixture.\n' "$(printf '\347\224\237\344\272\247\347\272\247')" >> "$DEST"
git add "$DEST"
git rm --cached --ignore-unmatch "$SOURCE" >/dev/null

if ! git diff --cached --name-status -M | grep -Eq $'^[R][0-9]+\t.*\t'"$DEST"'$'; then
  printf 'FAIL: staged diff did not identify rename destination: %s\n' "$DEST" >&2
  exit 1
fi

set +e
OUTPUT="$(env GIT_INDEX_FILE="$INDEX_FILE" bash scripts/hooks/check-jargon.sh --staged 2>&1)"
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -ne 1 ]; then
  printf 'FAIL: scanner exit=%s, expected 1\n%s\n' "$EXIT_CODE" "$OUTPUT" >&2
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | grep -q "$DEST:"; then
  printf 'FAIL: scanner did not report staged rename destination\n%s\n' "$OUTPUT" >&2
  exit 1
fi
printf 'PASS: staged rename destination scanned (%s)\n' "$DEST"
