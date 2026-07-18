#!/usr/bin/env bash
# scripts/kallax-tools.sh — EPIC-122-G/K: KALLAX Tool Registry (Dynamic Scan)
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

TOOL_CMD=""
TOOL_JSON=0
TOOL_QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) TOOL_JSON=1; shift ;;
    -h|--help) echo "Usage: kallax tools {list|search <query>|info <name>} [--json]"; exit 0 ;;
    *) [[ -z "$TOOL_CMD" ]] && TOOL_CMD="$1" || { TOOL_QUERY="$1"; }; shift ;;
  esac
done

# === Tool scanner ===
do_scan() {
  local sd="${REPO_ROOT}/scripts"
  local d
  for d in $sd verify metrics audit permission; do
    [[ -d "$d" ]] || continue
    find "$d" -maxdepth 2 -name "*.sh" -type f 2>/dev/null | sort | while IFS= read -r file; do
      local rel="${file#$sd/}"
      [[ "$rel" == lib/* ]] && continue
      [[ "$rel" == hooks/* ]] && continue
      local desc
      desc=$(awk '
        NR > 10 { exit }
        /^#!/ { next }
        /^#  *[A-Za-z]/ && !/\// { sub(/^#  */, ""); print; exit }
      ' "$file" 2>/dev/null)
      [[ -z "$desc" ]] && desc="No description"
      local cat="${rel%%/*}"
      [[ "$cat" == "$rel" ]] && cat="root"
      local nm="${file##*/}"
      nm="${nm%.sh}"
      local tags
      tags=$(echo "$desc" | grep -oE '[a-z][a-z0-9-]*' 2>/dev/null | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')
      # Output format: name|DESC|cat|FILE|tags
      printf '%s|DESC|%s|FILE|%s|TAGS|%s\n' "$nm" "$desc" "$cat" "$rel" "$tags"
    done
  done
}

# Formatters: read pre-parsed fields from | delimited input
fmt_list() {
  local nm desc cat rel tags
  IFS='|' read -r nm _ desc _ cat _ rel _ tags <<< "$1"
  echo "  $nm"
  echo "    $desc"
  echo "    category=$cat | file=$rel | tags=[$tags]"
  echo ""
}

fmt_json() {
  local nm desc cat rel tags
  IFS='|' read -r nm _ desc _ cat _ rel _ tags <<< "$1"
  local tt
  tt=$(echo "$tags" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')
  echo "    {"
  echo "      \"name\": \"$nm\","
  echo "      \"description\": \"$desc\","
  echo "      \"category\": \"$cat\","
  echo "      \"file_path\": \"$rel\","
  echo "      \"tags\": [$tt]"
  echo "    }"
}

do_search() {
  local query="$1"
  local lcq
  lcq=$(echo "$query" | tr '[:upper:]' '[:lower:]')
  local tmpf="/tmp/kallax-results-$$.tmp"
  local tmpcnt="/tmp/kallax-cnt-$$.tmp"
  do_scan > "$tmpf" 2>/dev/null || true
  echo "0" > "$tmpcnt"
  while IFS= read -r line; do
    local nm desc cat rel tags
    IFS='|' read -r nm _ desc _ cat _ rel _ tags <<< "$line"
    local hay
    hay=$(echo "$nm $desc $cat $tags" | tr '[:upper:]' '[:lower:]')
    if echo "$hay" | grep -qi "$lcq" 2>/dev/null; then
      echo "MATCH:$line"
    fi
    local current
    current=$(cat "$tmpcnt")
    echo $((current + 1)) > "$tmpcnt"
  done < "$tmpf"
  local cnt
  cnt=$(cat "$tmpcnt")
  rm -f "$tmpf" "$tmpcnt"
  echo "COUNT:$cnt"
}

case "$TOOL_CMD" in
  list|"")
    if [[ "$TOOL_JSON" == "1" ]]; then
      echo "{"
      echo "  \"tools\": ["
      first=true
      do_scan | while IFS= read -r line; do
        $first || echo "      ,"
        first=false
        fmt_json "$line"
      done
      echo ""
      echo "  ],"
      echo "  \"total\": $(do_scan | grep -c .)"
      echo "}"
    else
      total=$(do_scan | grep -c .)
      echo "=========================================="
      echo "KALLAX Tool Registry ($total tools)"
      echo "=========================================="
      do_scan | while IFS= read -r line; do
        fmt_list "$line"
      done
    fi
    ;;

  search)
    if [[ -z "$TOOL_QUERY" ]]; then echo "ERROR: search requires <query>" >&2; exit 1; fi
    sr=$(do_search "$TOOL_QUERY")
    cnt=$(echo "$sr" | tail -1 | cut -d: -f2)
    matches=$(echo "$sr" | grep "^MATCH:")
    if [[ "$TOOL_JSON" == "1" ]]; then
      echo "{"
      echo "  \"query\": \"$TOOL_QUERY\","
      echo "  \"results\": ["
      first=true
      echo "$matches" | while IFS= read -r line; do
        local entry="${line#MATCH:}"
        $first || echo "      ,"
        first=false
        fmt_json "$entry"
      done
      echo ""
      echo "  ],"
      echo "  \"count\": $cnt"
      echo "}"
    else
      echo "=========================================="
      echo "Search: \"$TOOL_QUERY\" — $cnt results"
      echo "=========================================="
      echo "$matches" | while IFS= read -r line; do
        fmt_list "${line#MATCH:}"
      done
    fi
    ;;

  info)
    if [[ -z "$TOOL_QUERY" ]]; then echo "ERROR: info requires <name>" >&2; exit 1; fi
    found=$(do_scan | while IFS= read -r line; do
      nm=$(echo "$line" | cut -d'|' -f1)
      if [[ "$nm" == "$TOOL_QUERY" ]]; then echo "$line"; break; fi
    done)
    if [[ -z "$found" ]]; then echo "ERROR: tool not found: $TOOL_QUERY" >&2; exit 1; fi
    fmt_list "$found"
    ;;
esac
