#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 (主公 2026-08-08 拍板 "以后都要禁止使用黑话")
# 扫 staged / 全仓文件, 命中黑话词表 fail-closed exit 1.
#
# Usage:
#   check-jargon.sh <path>           # 扫单个文件
#   check-jargon.sh --staged         # 扫 git diff --cached (staged only, 默认遵守 baseline)
#   check-jargon.sh --all           # 扫全仓 (含历史违规)
#
# Baseline 机制 (跟 EPIC-223 ticket 归档 1:1):
#   baseline_commit (jira/tickets/.jargon-baseline.json): 14eb7c4f (EPIC-224 合并)
#   --staged 模式: 只对 baseline 之上的新内容 fail-closed
#   --all 模式: 报全部 4056 备案 (供人工 review), 但仍 exit 1 if any
#
# Exit: 0 = PASS, 1 = FAIL (fail-closed)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BLACKLIST="${REPO_ROOT}/jira/tickets/.jargon-blacklist.json"
BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"

if [ ! -f "$BLACKLIST" ]; then
  echo "FAIL: blacklist not found: $BLACKLIST" >&2
  exit 1
fi

# 读取 baseline commit (可能缺失 — 历史模式 graceful)
BASELINE_COMMIT=""
if [ -f "$BASELINE_JSON" ]; then
  BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"
fi

# 提取所有 regex 模式到临时文件 (兼容 bash 3.2)
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
PATTERNS_FILE="${TMPDIR_TEST}/patterns.txt"
HITS_FILE="${TMPDIR_TEST}/hits.txt"
: > "$HITS_FILE"
jq -r '.blacklist | to_entries[] | .value.patterns[] | .regex' "$BLACKLIST" > "$PATTERNS_FILE"

# 元字段豁免
META_EXEMPT_PATTERNS=(
  ".jargon-blacklist.json"
  ".jargon-baseline.json"
  "EPIC-225"
  "check-jargon"
)

is_meta_file() {
  local rel="${1:-}"
  for pat in "${META_EXEMPT_PATTERNS[@]}"; do
    [[ "$rel" == *"$pat"* ]] && return 0
  done
  return 1
}

# 文件是否属于历史 commit? (用 git blame 看最早 commit)
is_historical_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 1
  [ -z "$BASELINE_COMMIT" ] && return 1

  # 相对路径
  local rel="${f#$REPO_ROOT/}"

  # 文件首次引入的 commit (用 log -1 --reverse)
  local first_commit
  first_commit="$(git -C "$REPO_ROOT" log --format="%H" --reverse --follow -- "$rel" 2>/dev/null | head -1 || echo "")"
  [ -z "$first_commit" ] && return 1

  # 若 first_commit 在 baseline 之前/等于, 算历史文件
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$first_commit" "$BASELINE_COMMIT" 2>/dev/null; then
    return 0  # 历史
  fi
  return 1  # 新增
}

# 把所有 regex 用 | 串成 egrep pattern
COMBINED_PATTERN="$(tr '\n' '|' < "$PATTERNS_FILE" | sed 's/|$//')"

scan_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 0
  [ -f "$f" ] || return 0
  [ -s "$f" ] || return 0
  local rel="${f#$REPO_ROOT/}"
  is_meta_file "$rel" && return 0

  # 全仓模式跳过 baseline 豁免; staged 模式也严格 (新内容 0 黑话)
  # 注: baseline 豁免是给审计/报告用的, 不是给 hook 的 (hook 强制 0 黑话)

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
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$REPO_ROOT/$f" ] || continue
      scan_file "$REPO_ROOT/$f"
    done < <(git -C "$REPO_ROOT" ls-files -z 2>/dev/null \
      | tr '\0' '\n' \
      | grep -E '\.(md|sh|ts|rs)$' \
      | grep -vE '^(node_modules/|rust/target/|_archived/)' || true)
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
# 每个 finding 占 3 行 (file:line — pat /  > content + 空行)
# EPIC-229 修 2 bug: grep -c 多行输出 + grep 无匹配时 exit 1 触发 set -e
real_hits=0
if [ -s "$HITS_FILE" ]; then
  real_hits=$(grep -cE '^  [^ ].*:.*—' "$HITS_FILE" 2>/dev/null | head -1 | tr -d ' \n' || true)
  real_hits="${real_hits:-0}"
fi
violations=$((real_hits + 0))

# 输出命中 (限 20 行, 否则太长)
if [ "$violations" -gt 0 ]; then
  head -20 "$HITS_FILE"
  [ "$violations" -gt 7 ] && echo "  ... (还有 $((violations - 7)) 个)"
fi

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "FAIL: $violations jargon violation(s) (EPIC-225 fail-closed)"
  echo "Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段"
  if [ "$cmd" = "--all" ]; then
    echo ""
    echo "注: 全仓模式扫描到 4056 备案历史违规 (跟 EPIC-223 1:1)."
    echo "    baseline = $BASELINE_COMMIT (历史划线, 新增强制)"
    echo "    主公 2026-08-08 拍板 C 方案: 历史不追溯, 代码 (19 self-heal) 真修."
  fi
  exit 1
fi

echo "OK: 0 jargon violations"
exit 0