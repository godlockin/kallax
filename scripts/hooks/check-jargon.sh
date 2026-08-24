#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 + EPIC-286 + EPIC-287-C
#
# Usage:
#   check-jargon.sh <path>   # 扫单个文件
#   check-jargon.sh --staged # 扫 staged
#   check-jargon.sh --all    # 扫全仓 (scope cache 加速)
#
# EPIC-286 X/Y PASS exemption:
#   命中 X/Y PASS 数字时, 查 ±10 行窗口是否有命令证据
#   有 → 豁免 (raw output 引用). 无 → fail
#
# EPIC-287-C scope cache:
#   .scope_commits.json 缓存基线后修改过的文件列表
#   --all 模式用 scope cache 快速过滤
#   META_EXEMPT 不受 scope cache 影响
#
# Exit: 0 = PASS, 1 = FAIL
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_ROOT" ] && REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
BLACKLIST="${REPO_ROOT}/jira/tickets/.jargon-blacklist.json"
BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"
SCOPE_JSON="${REPO_ROOT}/jira/tickets/.scope-commits.json"

[ ! -f "$BLACKLIST" ] && { echo "FAIL: blacklist not found: $BLACKLIST" >&2; exit 1; }

BASELINE_COMMIT=""
BASELINE_TIMESTAMP=""
if [ -f "$BASELINE_JSON" ]; then
  BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"
fi
if [ -n "$BASELINE_COMMIT" ]; then
  BASELINE_TIMESTAMP="$(git -C "$REPO_ROOT" show -s --format=%ct "$BASELINE_COMMIT" 2>/dev/null || echo "")"
fi

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
PATTERNS_FILE="${TMPDIR_TEST}/patterns.txt"
HITS_FILE="${TMPDIR_TEST}/hits.txt"
: > "$HITS_FILE"
jq -r '.blacklist | to_entries[] | .value.patterns[] | .regex' "$BLACKLIST" > "$PATTERNS_FILE"

# META_EXEMPT: EPIC-286 精确 basename + EPIC-287-C scope cache
META_EXEMPT_BASENAMES=(
  ".jargon-blacklist.json"
  ".jargon-baseline.json"
  ".scope-commits.json"
  "EPIC-225"
  "EPIC-287"
  "check-jargon"
)
META_EXEMPT_PATH_PATTERNS=(
  "*/tests/integration/check-jargon-exemption.test.sh"
  "*/tests/integration/check-jargon-*"
  "*/tests/integration/epic-225-jargon-*"
  "*/tests/integration/epic-250-jargon-*"
  "*/scripts/hooks/check-jargon.sh"
  "*/confluence/decisions/EPIC-225*"
  "*/jira/tickets/.jargon-*"
  "*/CLAUDE.md"
  "*/.claude/rules/immutable-scripts.md"
)

is_meta_file() {
  local rel="${1:-}"
  [ -z "$rel" ] && return 1
  local base
  base="$(basename "$rel")"
  for name in "${META_EXEMPT_BASENAMES[@]}"; do
    [ "$base" = "$name" ] && return 0
  done
  for pat in "${META_EXEMPT_PATH_PATTERNS[@]}"; do
    if [[ "$rel" == $pat ]]; then
      return 0
    fi
    local stripped="${pat#\*/}"
    if [ "$stripped" != "$pat" ] && [[ "$rel" == $stripped ]]; then
      return 0
    fi
  done
  return 1
}

# 历史文件判断: 用提交时间 (跨主干 merge 后仍正确)
is_historical_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 1
  [ -z "$BASELINE_COMMIT" ] && return 1
  [ -z "$BASELINE_TIMESTAMP" ] && return 1
  local rel="${f#$REPO_ROOT/}"
  local first_commit
  first_commit="$(git -C "$REPO_ROOT" log --format="%H" --reverse --follow -- "$rel" 2>/dev/null | head -1 || echo "")"
  [ -z "$first_commit" ] && return 1
  local first_timestamp
  first_timestamp="$(git -C "$REPO_ROOT" show -s --format=%ct "$first_commit" 2>/dev/null || echo "")"
  [ -n "$first_timestamp" ] && [ "$first_timestamp" -le "$BASELINE_TIMESTAMP" ]
}

# 历史文件逐行豁免 (B5 修)
historical_line_exempt() {
  local f="$1" lineno="$2"
  [ -z "$BASELINE_COMMIT" ] && return 1
  [ -z "$BASELINE_TIMESTAMP" ] && return 1
  local rel="${f#$REPO_ROOT/}"
  local lc
  lc="$(git -C "$REPO_ROOT" blame --porcelain -L "${lineno},${lineno}" -- "$rel" 2>/dev/null | head -1 | cut -d ' ' -f1 || echo "")"
  [ -z "$lc" ] && return 1
  local line_timestamp
  line_timestamp="$(git -C "$REPO_ROOT" show -s --format=%ct "$lc" 2>/dev/null || echo "")"
  [ -n "$line_timestamp" ] && [ "$line_timestamp" -le "$BASELINE_TIMESTAMP" ]
}

# EPIC-287-C: scope cache
SCOPE_CACHE_FILE=""
SCOPE_CACHE_LOADED=0

load_scope_cache() {
  [ ! -f "$SCOPE_JSON" ] && return 1
  SCOPE_CACHE_FILE="${TMPDIR_TEST}/scope_files.txt"
  jq -r '.commits | to_entries[].value[]' "$SCOPE_JSON" 2>/dev/null \
    | sort -u > "$SCOPE_CACHE_FILE"
  SCOPE_CACHE_LOADED=1
}

COMBINED_PATTERN="$(tr '\n' '|' < "$PATTERNS_FILE" | sed 's/|$//')"

# EPIC-286: X/Y PASS 命令证据豁免
XY_PASS_PATTERN='[0-9]+/[0-9]+\s+(PASS|passed)'
XY_EVIDENCE_WINDOW=10

has_command_evidence() {
  local file="$1" lineno="$2"
  local from=$(( lineno > XY_EVIDENCE_WINDOW ? lineno - XY_EVIDENCE_WINDOW : 1 ))
  local to=$(( lineno + XY_EVIDENCE_WINDOW ))
  sed -n "${from},${to}p" "$file" 2>/dev/null \
    | grep -qE '(`(bash|npx|cargo|npm|git|python3) |^\s*\$ |exit=[0-9]|RC=[0-9]|rc=[0-9])'
}

scan_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 0
  [ -f "$f" ] || return 0
  [ -s "$f" ] || return 0
  local rel="${f#$REPO_ROOT/}"
  is_meta_file "$rel" && return 0

  local is_historical=0
  is_historical_file "$f" && is_historical=1

  while IFS= read -r hit_line; do
    [ -z "$hit_line" ] && continue
    local lineno="${hit_line%%:*}"
    local content="${hit_line#*:}"
    local first_pat=""
    set +e
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      if echo "$content" | grep -qE "$pat"; then
        first_pat="$pat"
        break
      fi
    done < "$PATTERNS_FILE"
    set -e

    # X/Y PASS 附命令证据 → 豁免
    if [ "$first_pat" = "$XY_PASS_PATTERN" ] && has_command_evidence "$f" "$lineno"; then
      continue
    fi

    # 历史文件逐行豁免
    if [ "$is_historical" -eq 1 ] && historical_line_exempt "$f" "$lineno"; then
      continue
    fi

    printf "  %s:%s — %s\n  > %s\n" "$rel" "$lineno" "$first_pat" "$content" >> "$HITS_FILE"
  done < <(grep -nE "$COMBINED_PATTERN" "$f" 2>/dev/null || true)
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  --staged)
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [[ "$f" =~ \.(md|sh|ts|rs)$ ]] || continue
      scan_file "$REPO_ROOT/$f"
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(md|sh|ts|rs)$' || true)
    ;;
  --all)
    load_scope_cache

    # 预过滤 scope 内可扫文件
    files_filtered="${TMPDIR_TEST}/files_filtered.txt"
    : > "$files_filtered"
    if [ -f "$SCOPE_CACHE_FILE" ]; then
      grep -E '\.(md|sh|ts|rs)$' "$SCOPE_CACHE_FILE" 2>/dev/null \
        | grep -vE '^(_archived|node_modules|rust/target)/' \
        > "$files_filtered"
    fi

    # 单次 grep -r
    grep_output="${TMPDIR_TEST}/grep_output.txt"
    : > "$grep_output"

    grep -rEn --include='*.md' --include='*.sh' --include='*.ts' --include='*.rs' \
      -e "$COMBINED_PATTERN" "$REPO_ROOT" 2>/dev/null \
      | grep -vE '^(node_modules/|rust/target/|_archived/)' \
      | awk -v repo="$REPO_ROOT" '
        BEGIN {
          while ((getline line < "'"$files_filtered"'") > 0) {
            scope[repo "/" line] = 1
          }
          close("'"$files_filtered"'")
          split(".jargon-blacklist.json .jargon-baseline.json .scope-commits.json EPIC-225 EPIC-287 check-jargon", meta_pats, " ")
        }
        {
          f = $0
          sub(/:[0-9]+:.*$/, "", f)
          sub("^" repo "/", "", f)
          is_meta = 0
          for (i in meta_pats) {
            if (index(f, meta_pats[i]) > 0) { is_meta = 1; break }
          }
          if (is_meta) next
          if (scope[f]) print $0
        }
      ' > "$grep_output"

    # 处理 grep 结果
    while IFS= read -r hit_line; do
      [ -z "$hit_line" ] && continue
      local_file="${hit_line%%:*}"
      rest="${hit_line#*:}"
      lineno="${rest%%:*}"
      content="${rest#*:}"
      rel="${local_file#$REPO_ROOT/}"
      first_pat=""
      set +e
      while IFS= read -r pat; do
        [ -z "$pat" ] && continue
        if echo "$content" | grep -qE "$pat"; then
          first_pat="$pat"
          break
        fi
      done < "$PATTERNS_FILE"
      set -e
      [ -n "$first_pat" ] && printf "  %s:%s — %s\n  > %s\n" "$rel" "$lineno" "$first_pat" "$content" >> "$HITS_FILE"
    done < "$grep_output"
    ;;
  "")
    echo "Usage: $0 <path>|--staged|--all" >&2
    exit 1
    ;;
  *)
    [ ! -f "$cmd" ] && { echo "FAIL: not a file: $cmd" >&2; exit 1; }
    scan_file "$cmd"
    ;;
esac

violations=$(wc -l < "$HITS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
real_hits=0
[ -s "$HITS_FILE" ] && {
  real_hits=$(grep -cE '^  [^ ].*:.*—' "$HITS_FILE" 2>/dev/null | head -1 | tr -d ' \n' || true)
  real_hits="${real_hits:-0}"
}
violations=$((real_hits + 0))

[ "$violations" -gt 0 ] && {
  head -20 "$HITS_FILE"
  [ "$violations" -gt 7 ] && echo "  ... (还有 $((violations - 7)) 个)"
}

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "FAIL: $violations jargon violation(s) (EPIC-225 fail-closed)"
  echo "Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段"
fi
[ "$cmd" = "--all" ] && {
  echo "baseline = $BASELINE_COMMIT"
  echo "EPIC-287-C scope cache: $([ "$SCOPE_CACHE_LOADED" -eq 1 ] && echo "loaded ($(wc -l < "$SCOPE_CACHE_FILE") files)" || echo "not loaded (using fallback)")"
}
[ "$violations" -gt 0 ] && exit 1

echo "OK: 0 jargon violations"
exit 0
