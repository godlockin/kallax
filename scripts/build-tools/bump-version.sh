#!/usr/bin/env bash
# scripts/build-tools/bump-version.sh — sync 3 canonical version sources
# EPIC-147: prevent root/node/rust version drift observed 5+ releases in a row.
#
# Usage:
#   bash scripts/build-tools/bump-version.sh <target-version>
#   bash scripts/build-tools/bump-version.sh --dry-run <target-version>
#
# Updates:
#   - package.json           (root)         "version": "..."
#   - node/package.json                     "version": "..."
#   - rust/Cargo.toml        [workspace.package] version = "..."
#
# rust/crates/*/Cargo.toml already use `version.workspace = true` (no per-crate bump).
#
# Refuses to run if any target file has uncommitted changes (unless --force).
#
# Exit codes:
#   0 - success (or dry-run showing diff)
#   1 - validation / dirty tree
#   2 - I/O error
set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT" || exit 2

DRY_RUN=0
FORCE=0
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$arg"
      else
        echo "ERROR: unexpected arg: $arg" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "ERROR: missing <target-version>" >&2
  echo "Usage: bash scripts/build-tools/bump-version.sh [--dry-run] <target-version>" >&2
  exit 1
fi

if ! [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: invalid version format: '$TARGET' (expected X.Y.Z)" >&2
  exit 1
fi

FILES=(package.json node/package.json rust/Cargo.toml)

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    exit 2
  fi
done

# dirty check
if [[ "$FORCE" == "0" && "$DRY_RUN" == "0" ]]; then
  if git status --porcelain "${FILES[@]}" 2>/dev/null | grep -q .; then
    echo "ERROR: uncommitted changes detected in target files:" >&2
    git status --porcelain "${FILES[@]}" >&2
    echo "  commit / stash first, or pass --force to override" >&2
    exit 1
  fi
fi

current_node_root() {
  grep -E '^[[:space:]]*"version"' package.json | head -1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}
current_node_workspace() {
  grep -E '^[[:space:]]*"version"' node/package.json | head -1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}
current_rust() {
  awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' rust/Cargo.toml
}

CUR_ROOT="$(current_node_root)"
CUR_NODE="$(current_node_workspace)"
CUR_RUST="$(current_rust)"

echo "Current versions:"
echo "  package.json:        ${CUR_ROOT}"
echo "  node/package.json:   ${CUR_NODE}"
echo "  rust/Cargo.toml:     ${CUR_RUST}"
echo "Target:                ${TARGET}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo ""
  echo "--- diff preview (--dry-run) ---"
  for f in "${FILES[@]}"; do
    case "$f" in
      *.toml)
        echo "@@ $f @@"
        echo "-version = \"$(awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' "$f")\""
        echo "+version = \"${TARGET}\""
        ;;
      *)
        echo "@@ $f @@"
        cur=$(grep -E '^[[:space:]]*"version"' "$f" | head -1 \
              | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        echo "-  \"version\": \"${cur}\","
        echo "+  \"version\": \"${TARGET}\","
        ;;
    esac
  done
  echo "--- end preview ---"
  exit 0
fi

# in-place update using sed (portable). Only touches first `"version"` line
# in JSON (package.json root key) or the first `version = "..."` line in TOML
# (which is workspace.package.version, verified by structure).

update_json() {
  local f="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v new="$TARGET" '
    BEGIN{done=0}
    !done && /^[[:space:]]*"version"[[:space:]]*:/ {
      sub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" new "\"")
      done=1
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

update_toml() {
  local f="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v new="$TARGET" '
    BEGIN{done=0}
    !done && /^version[[:space:]]*=/ {
      sub(/"[^"]+"/, "\"" new "\"")
      done=1
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

update_json package.json      || { echo "ERROR: failed to update package.json" >&2; exit 2; }
update_json node/package.json || { echo "ERROR: failed to update node/package.json" >&2; exit 2; }
update_toml rust/Cargo.toml   || { echo "ERROR: failed to update rust/Cargo.toml" >&2; exit 2; }

NEW_ROOT="$(current_node_root)"
NEW_NODE="$(current_node_workspace)"
NEW_RUST="$(current_rust)"

if [[ "$NEW_ROOT" != "$TARGET" || "$NEW_NODE" != "$TARGET" || "$NEW_RUST" != "$TARGET" ]]; then
  echo "ERROR: post-update verification failed" >&2
  echo "  root: $NEW_ROOT  node: $NEW_NODE  rust: $NEW_RUST" >&2
  exit 2
fi

echo ""
echo "OK: all 3 sources bumped to ${TARGET}"
echo "Next steps:"
echo "  1. cd rust && cargo check --workspace   # regen Cargo.lock"
echo "  2. bash scripts/build-tools/version-check.sh   # must exit 0"
echo "  3. git add package.json node/package.json rust/Cargo.toml rust/Cargo.lock"
echo "  4. git commit -m 'chore: bump version to ${TARGET}'"
