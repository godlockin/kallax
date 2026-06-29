#!/usr/bin/env bash
# scripts/build/version-check.sh — Q1 决策: build-time version consistency check
# Iter 3 / EPIC-GAP6: stop package.json (2.7.6) vs rust/Cargo.toml (1.0.0) drift.
#
# 用法:
#   bash scripts/build/version-check.sh            # 严格: drift = exit 1
#   bash scripts/build/version-check.sh --warn     # 警告: drift = exit 0 + stderr
#
# 退出码:
#   0  - 版本一致 (或 --warn 模式下漂移)
#   1  - 版本漂移 (严格模式)
#   2  - 解析失败 (package.json / Cargo.toml 缺失或无 version)

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT" || exit 2

WARN_MODE=0
for arg in "$@"; do
  case "$arg" in
    --warn) WARN_MODE=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

node_version() {
  if [[ ! -f package.json ]]; then
    echo "MISSING"
    return 1
  fi
  grep -E '"version"' package.json | head -1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

rust_version() {
  if [[ ! -f rust/Cargo.toml ]]; then
    echo "MISSING"
    return 1
  fi
  # [workspace.package] version OR first [package] version
  local v
  v=$(awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' rust/Cargo.toml)
  if [[ -z "$v" ]]; then
    echo "MISSING"
    return 1
  fi
  echo "$v"
}

main() {
  local nv rv
  nv=$(node_version) || exit 2
  rv=$(rust_version) || exit 2

  if [[ "$nv" == "MISSING" || "$rv" == "MISSING" ]]; then
    echo "ERROR: package.json or rust/Cargo.toml missing version field" >&2
    echo "  node: ${nv}" >&2
    echo "  rust: ${rv}" >&2
    exit 2
  fi

  if [[ "$nv" != "$rv" ]]; then
    if [[ "$WARN_MODE" == "1" ]]; then
      echo "WARN: version drift detected (Q1 决策 — bumping needed)" >&2
      echo "  package.json:        ${nv}" >&2
      echo "  rust/Cargo.toml:     ${rv}" >&2
      exit 0
    else
      echo "FAIL: version drift detected" >&2
      echo "  package.json:        ${nv}" >&2
      echo "  rust/Cargo.toml:     ${rv}" >&2
      echo "  Run: bump one to match the other (Q1 决策 — canonical = package.json)" >&2
      exit 1
    fi
  fi

  echo "PASS: versions match (${nv})"
  exit 0
}

main