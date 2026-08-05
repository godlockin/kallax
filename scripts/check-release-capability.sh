#!/usr/bin/env bash
# scripts/check-release-capability.sh — EPIC-175 Release Capability Usage Gate
#
# 检测 release PR 是否含 capability 4 字段:
#   1. activation  — 如何激活/禁用此 capability
#   2. privacy     — 数据隐私/可见性边界
#   3. rollback    — 回滚机制
#   4. link        — 相关文档/issue 链接
#
# Exit codes (跟 scan-dead-code 1:1):
#   0 = PASS (all 4 fields present)
#   1 = FAIL (missing fields)
#   2 = BLOCKED-env (环境缺失)
#
# Usage:
#   check-release-capability.sh [--staged] [--file <path>]
#   check-release-capability.sh --help
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Exit code constants
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# Required fields
readonly REQUIRED_FIELDS=("activation" "privacy" "rollback" "link")

USAGE="check-release-capability.sh — EPIC-175 Release Capability Usage Gate

Usage:
  check-release-capability.sh [--staged] [--file <path>]
  check-release-capability.sh --help

Checks release PR for capability 4 fields:
  1. activation  — 如何激活/禁用此 capability
  2. privacy     — 数据隐私/可见性边界
  3. rollback    — 回滚机制
  4. link        — 相关文档/issue 链接

Exit codes:
  0 = PASS (all 4 fields present)
  1 = FAIL (missing fields)
  2 = BLOCKED-env (环境缺失)

Examples:
  # Check staged files only (pre-commit context)
  KALLAX_STAGED_ONLY=1 bash scripts/check-release-capability.sh

  # Check specific file
  bash scripts/check-release-capability.sh --file CHANGELOG.md

  # Check all .md files
  bash scripts/check-release-capability.sh
"

# Parse args
MODE="all"
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) MODE="staged" ;;
    --file) TARGET_FILE="$2"; shift ;;
    -h|--help) echo "$USAGE"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit $EXIT_FAIL ;;
  esac
  shift
done

# ── Helpers ──────────────────────────────────────────────────────────────────

check_file() {
  local file="$1"
  local missing=()
  local found=()

  # Check if file contains release entry (look for [VERSION] pattern)
  if ! grep -qE '^\[3\.[0-9]+\.[0-9]+\]' "$file" 2>/dev/null; then
    return 0  # Skip non-release files
  fi

  for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -qiE "(^##?[[:space:]]*$field|${field}[[:space:]]*:)" "$file" 2>/dev/null; then
      found+=("$field")
    else
      missing+=("$field")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    echo "PASS: $file (4/4 fields: ${found[*]})"
    return $EXIT_PASS
  else
    echo "FAIL: $file (missing: ${missing[*]})"
    return $EXIT_FAIL
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local files=()
  local exit_code=0

  if [ -n "$TARGET_FILE" ]; then
    if [ ! -f "$TARGET_FILE" ]; then
      echo "BLOCKED: file not found: $TARGET_FILE" >&2
      exit $EXIT_BLOCKED_ENV
    fi
    files=("$TARGET_FILE")
  elif [ "$MODE" = "staged" ] || [ -n "${KALLAX_STAGED_ONLY:-}" ]; then
    # Get staged .md files
    while IFS= read -r f; do
      [ -f "$f" ] && files+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.md$' || true)

    if [ ${#files[@]} -eq 0 ]; then
      echo "No staged .md files, skip"
      exit $EXIT_PASS
    fi
  else
    # Scan CHANGELOG.md and recent release entries
    if [ -f "CHANGELOG.md" ]; then
      files=("CHANGELOG.md")
    fi
  fi

  if [ ${#files[@]} -eq 0 ]; then
    echo "No files to check"
    exit $EXIT_PASS
  fi

  for f in "${files[@]}"; do
    check_file "$f" || exit_code=1
  done

  exit $exit_code
}

main
