#!/usr/bin/env bash
# scripts/audit/list-build-rs.sh
#
# EPIC-136-D — supply-chain audit
# 扫 rust/ workspace 内所有 build.rs, 输出 inventory.
# CI check: 每次加/删 build.rs 必须同步更新 docs/reference/build-rs-inventory.md.
#
# Usage:
#   scripts/audit/list-build-rs.sh [--format human|json]
#   scripts/audit/list-build-rs.sh --diff-against docs/reference/build-rs-inventory.md
#
# Exit codes:
#   0 = scan complete (or diff match)
#   1 = diff mismatch (only when --diff-against used)
#   2 = usage error

set -euo pipefail

FORMAT="human"
DIFF_AGAINST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --format)
      shift
      FORMAT="${1:-human}"
      case "$FORMAT" in
        human|json) ;;
        *) echo "error: --format must be human|json (got: $FORMAT)" >&2; exit 2 ;;
      esac
      shift
      ;;
    --diff-against)
      shift
      DIFF_AGAINST="${1:-}"
      if [ -z "$DIFF_AGAINST" ]; then
        echo "error: --diff-against needs a path" >&2
        exit 2
      fi
      shift
      ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Resolve repo root (script lives at scripts/audit/list-build-rs.sh)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -d "$REPO_ROOT/rust" ]; then
  echo "error: no rust/ dir under repo root $REPO_ROOT" >&2
  exit 2
fi

# Scan; -not -path excludes target/ and .git/. Portable find.
BUILD_RS_FILES=$(find "$REPO_ROOT/rust" -name build.rs \
  -not -path '*/target/*' \
  -not -path '*/.git/*' \
  2>/dev/null | sort || true)

COUNT=0
if [ -n "$BUILD_RS_FILES" ]; then
  COUNT=$(printf "%s\n" "$BUILD_RS_FILES" | wc -l | tr -d ' ')
fi

emit_human() {
  echo "# build.rs inventory (rust/ workspace)"
  echo "# scanned: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "# root: $REPO_ROOT/rust"
  echo "# count: $COUNT"
  echo
  if [ "$COUNT" -eq 0 ]; then
    echo "(no build.rs files found)"
    return
  fi
  printf "%-60s %10s  %-40s  %s\n" "PATH" "BYTES" "OWNING_CRATE" "FIRST_NONBLANK_LINE"
  echo "$BUILD_RS_FILES" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#$REPO_ROOT/}"
    bytes=$(wc -c <"$f" | tr -d ' ')
    crate_dir=$(dirname "$(dirname "$f")")
    crate=$(basename "$crate_dir")
    # first non-blank, non-comment line
    first=$(grep -vE '^\s*(//|$)' "$f" | head -n 1 | sed 's/[[:space:]]\+$//' | cut -c1-80)
    [ -z "$first" ] && first="(empty or all comments)"
    printf "%-60s %10s  %-40s  %s\n" "$rel" "$bytes" "$crate" "$first"
  done
}

emit_json() {
  echo "{"
  printf '  "scanned_at": "%s",\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '  "root": "%s",\n' "$REPO_ROOT/rust"
  printf '  "count": %s,\n' "$COUNT"
  echo '  "files": ['
  if [ "$COUNT" -gt 0 ]; then
    first_row=1
    echo "$BUILD_RS_FILES" | while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel="${f#$REPO_ROOT/}"
      bytes=$(wc -c <"$f" | tr -d ' ')
      crate_dir=$(dirname "$(dirname "$f")")
      crate=$(basename "$crate_dir")
      first=$(grep -vE '^\s*(//|$)' "$f" | head -n 1 | sed 's/[[:space:]]\+$//' | cut -c1-200 | sed 's/\\/\\\\/g; s/"/\\"/g')
      if [ "$first_row" -eq 1 ]; then
        first_row=0
      else
        printf ",\n"
      fi
      printf '    {"path": "%s", "bytes": %s, "crate": "%s", "first_line": "%s"}' \
        "$rel" "$bytes" "$crate" "$first"
    done
    echo
  fi
  echo "  ]"
  echo "}"
}

TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

case "$FORMAT" in
  human) emit_human >"$TMP_OUT" ;;
  json)  emit_json  >"$TMP_OUT" ;;
esac

if [ -n "$DIFF_AGAINST" ]; then
  # Compare current scan against inventory doc.
  # Extract inventory lines (path + crate + bytes) from doc if it has a table;
  # for zero-build.rs sentinel case, doc should contain "count: 0".
  if [ ! -f "$DIFF_AGAINST" ]; then
    echo "error: --diff-against target not found: $DIFF_AGAINST" >&2
    exit 2
  fi
  # Minimal check: every path in current scan must appear in doc.
  # And doc should not reference a build.rs that no longer exists (grep for build.rs paths in doc).
  MISMATCH=0
  if [ "$COUNT" -eq 0 ]; then
    # Sentinel: doc must state count: 0 (or "0 build.rs")
    if ! grep -qE '(count[[:space:]]*[:=][[:space:]]*0|\b0 build\.rs\b)' "$DIFF_AGAINST"; then
      echo "diff: current scan finds 0 build.rs but doc does not say so" >&2
      MISMATCH=1
    fi
  else
    echo "$BUILD_RS_FILES" | while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel="${f#$REPO_ROOT/}"
      if ! grep -qF "$rel" "$DIFF_AGAINST"; then
        echo "diff: build.rs present in tree but not in doc: $rel" >&2
        exit 1
      fi
    done || MISMATCH=1
    # And check doc's build.rs paths still exist
    grep -oE '[a-zA-Z0-9_/.-]+/build\.rs' "$DIFF_AGAINST" | sort -u | while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      if [ ! -f "$REPO_ROOT/$rel" ]; then
        echo "diff: doc references non-existent build.rs: $rel" >&2
        exit 1
      fi
    done || MISMATCH=1
  fi
  if [ "$MISMATCH" -ne 0 ]; then
    exit 1
  fi
  cat "$TMP_OUT"
  exit 0
fi

cat "$TMP_OUT"
exit 0
