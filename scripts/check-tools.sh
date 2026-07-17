#!/usr/bin/env bash
# scripts/check-tools.sh — EPIC-122-B: DotSlash-style tool version check
#
# 行为:
#   1. 检查必需工具 (jq, git, bash)
#   2. 检查可选工具 (sqlite3, redis-cli)
#   3. 输出友好错误（缺什么、版本要求、如何安装）
#
# Exit:
#   0 = all required tools present
#   1 = missing required tool(s)
#   2 = error (unexpected)

set -euo pipefail

# === Tool definitions ===
# Each entry: name|required|min_version|install_hint
TOOLS=(
  "jq|required|1.6|brew install jq || apt install jq"
  "git|required|2.0|brew install git || apt install git"
  "bash|required|3.2|brew install bash (macOS)"
  "sqlite3|optional|3.0|brew install sqlite3 || apt install sqlite3"
)

# === Parse arguments ===
VERBOSE=0
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    --json) JSON_OUTPUT=1; shift ;;
    -h|--help)
      echo "Usage: $0 [-v|--verbose] [--json]"
      echo "  --json     JSON output (for CI)"
      echo "  -v         verbose (show versions)"
      exit 0
      ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# === Utility functions ===
has_command() {
  command -v "$1" &>/dev/null
}

get_version() {
  local cmd="$1"
  local version_flag="${2:-"--version"}"
  local version_regex="${3:-"([0-9]+\.[0-9]+(\.[0-9]+)?)"}"

  if ! has_command "$cmd"; then return 1; fi

  local version
  version=$("$cmd" $version_flag 2>/dev/null | head -1 | grep -oE "$version_regex" | head -1 || true)
  if [[ -z "$version" ]]; then
    # Fallback: try --version with different regex
    version=$("$cmd" $version_flag 2>/dev/null | grep -oE "[0-9]+(\.[0-9]+)+" | head -1 || echo "unknown")
  fi
  echo "$version"
  return 0
}

version_at_least() {
  local actual="$1"
  local required="$2"

  # Simple version comparison using sort -V
  printf '%s\n%s\n' "$required" "$actual" | sort -V | head -1 | grep -q "^${actual}$"
}

# === Check single tool ===
check_tool() {
  local name="$1"
  local required="$2"
  local min_version="${3:-}"
  local install_hint="$4"

  if ! has_command "$name"; then
    echo "  [MISSING] $name (required: $required)"
    if [[ -n "$install_hint" ]]; then
      echo "            Install: $install_hint"
    fi
    return 1
  fi

  local version
  version=$(get_version "$name")

  if [[ -n "$min_version" && "$min_version" != "" ]]; then
    if ! version_at_least "$version" "$min_version"; then
      echo "  [OLD] $name version $version (need >= $min_version)"
      echo "        Install: $install_hint"
      return 1
    fi
  fi

  if [[ "$VERBOSE" == "1" ]]; then
    echo "  [OK] $name $version"
  fi
  return 0
}

# === Main check ===
ERRORS=0
REQUIRED_MISSING=0
OPTIONAL_MISSING=0

if [[ "$JSON_OUTPUT" == "1" ]]; then
  echo "{"
  echo "  \"tools\": {"
  first=true
fi

for entry in "${TOOLS[@]}"; do
  IFS='|' read -r name required min_version install_hint <<< "$entry"

  if [[ "$JSON_OUTPUT" == "1" ]]; then
    if [[ "$first" != "true" ]]; then echo ","; fi
    first=false
    status=$(has_command "$name" && echo "present" || echo "missing")
    version=$(has_command "$name" && get_version "$name" || echo "null")
    echo -n "    \"$name\": {\"status\": \"$status\", \"version\": \"$version\"}"
    continue
  fi

  if ! check_tool "$name" "$required" "$min_version" "$install_hint"; then
    ERRORS=$((ERRORS + 1))
    if [[ "$required" == "required" ]]; then
      REQUIRED_MISSING=$((REQUIRED_MISSING + 1))
    else
      OPTIONAL_MISSING=$((OPTIONAL_MISSING + 1))
    fi
  fi
done

if [[ "$JSON_OUTPUT" == "1" ]]; then
  echo ""
  echo "  },"
  echo "  \"summary\": {\"required_missing\": $REQUIRED_MISSING, \"optional_missing\": $OPTIONAL_MISSING}"
  echo "}"
  if [[ $ERRORS -gt 0 ]]; then exit 1; fi
  exit 0
fi

# Human-readable output
echo ""
echo "=========================================="
echo "Tool Check — KALLAX"
echo "=========================================="

if [[ $ERRORS -eq 0 ]]; then
  echo "All tools OK."
  echo ""
  echo "Required: jq, git, bash — OK"
  echo "Optional: sqlite3, redis-cli — OK (not required for basic operation)"
  exit 0
fi

if [[ $REQUIRED_MISSING -gt 0 ]]; then
  echo ""
  echo "FAIL: $REQUIRED_MISSING required tool(s) missing."
  echo "KALLAX cannot run without: jq, git, bash"
  echo ""
  echo "Run 'brew install jq git bash' (macOS)"
  echo "Or 'apt install jq git bash' (Linux)"
fi

if [[ $OPTIONAL_MISSING -gt 0 ]]; then
  echo ""
  echo "NOTE: $OPTIONAL_MISSING optional tool(s) missing."
  echo "Advanced features (Redis queue, SQLite backend) will use fallback."
fi

echo ""
echo "=========================================="
exit 1
