#!/usr/bin/env bash
# KALLAX check-doc-budgets.sh — EPIC-279 (DSH Path C 借鉴)
#
# 借鉴 DeepSeek-Harness verify-doc-budgets + AGENTS.md ≤1600 词硬顶.
# 比对 budgets.manifest.json 设的 ceiling, 超词必拒 (fail-closed exit 1).
#
# Usage:
#   check-doc-budgets.sh                       # 扫全仓 (per-tier glob)
#   check-doc-budgets.sh --staged             # 扫 git diff --cached (staged only)
#   check-doc-budgets.sh <file>               # 扫单个文件 (跟 check-jargon 同型)
#
# Exit: 0 = PASS, 1 = FAIL (fail-closed), 2 = CONFIG_ERROR
#
# 跟 9-immutable 区别: 这是新非 immutable 脚本 (跟 check-smoke-retention.sh 同级).
# 改动只需 PR review, 不需主公亲自.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MANIFEST="${REPO_ROOT}/budgets.manifest.json"

# ── CONFIG_ERROR ────────────────────────────────────────────────────────
if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: budgets.manifest.json not found: $MANIFEST" >&2
  echo "Fix: 跑 /kallax-research --init-doc-budgets 或 git pull 拿 EPIC-279 落地" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq 未安装 (check-doc-budgets 依赖 jq 读 manifest)" >&2
  exit 2
fi

# ── 抽取 staged file list ───────────────────────────────────────────────
cmd="${1:-}"
staged_mode=0
case "$cmd" in
  --staged)
    staged_mode=1
    _files="$(git diff --cached --name-only --diff-filter=ACM -- '*.md' 2>/dev/null || true)"
    ;;
  "")
    # 全仓模式: 按 tier glob 展开 (排除 worktrees 副产物)
    _files="$(find . -name '*.md' \
      -not -path './node_modules/*' \
      -not -path '*/_archived/*' \
      -not -path '*/rust/target/*' \
      -not -path './.claude/worktrees/*' \
      2>/dev/null | sed 's|^\./||' | sort)"
    ;;
  *)
    # 单文件模式
    if [ ! -f "$cmd" ]; then
      echo "FAIL: not a file: $cmd" >&2
      exit 2
    fi
    _files="$cmd"
    ;;
esac

if [ -z "$_files" ]; then
  echo "OK: 0 .md files to check (early-exit)"
  exit 0
fi

# ── 检查 exemptions ─────────────────────────────────────────────────────
is_exempt() {
  local f="${1:-}"
  local n_exempt
  n_exempt="$(jq -r '.exemptions | length' "$MANIFEST" 2>/dev/null || echo 0)"
  [ "$n_exempt" -eq 0 ] && return 1
  local i=0
  while [ "$i" -lt "$n_exempt" ]; do
    local p
    p="$(jq -r ".exemptions[$i].path" "$MANIFEST" 2>/dev/null || echo "")"
    [ -z "$p" ] && { i=$((i + 1)); continue; }
    if [[ "$f" == "$p" ]]; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# ── 检查 tier match ─────────────────────────────────────────────────────
# Returns tier name on stdout. Empty + exit 0 = no tier match (skip).
find_tier_ceiling() {
  local f="${1:-}"
  case "$f" in
    CLAUDE.md) echo "root"; return 0 ;;
    .claude/rules/*.md) echo "rules"; return 0 ;;
    confluence/decisions/*.md) echo "decisions"; return 0 ;;
    docs/reference/*.md) echo "reference"; return 0 ;;
    confluence/manifesto/*.md) echo "manifesto"; return 0 ;;
  esac
  return 0  # not an error to have no tier
}

# ── 主循环 ──────────────────────────────────────────────────────────────
violations=0
hits_file="$(mktemp)"
trap 'rm -f "$hits_file"' EXIT

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [[ "$f" == *.md ]] || continue
  [ -f "$REPO_ROOT/$f" ] || continue
  if is_exempt "$f"; then continue; fi
  tier="$(find_tier_ceiling "$f")"
  [ -z "$tier" ] && continue  # 不在 budget 范围内的 .md 跳过
  ceiling="$(jq -r ".tiers.${tier}.ceiling_words // 0" "$MANIFEST" 2>/dev/null || echo 0)"
  [ "$ceiling" -le 0 ] && continue
  actual="$(wc -w < "$REPO_ROOT/$f" 2>/dev/null | tr -d ' ' || echo 0)"
  if [ "$actual" -gt "$ceiling" ]; then
    over=$((actual - ceiling))
    pct=$((actual * 100 / ceiling))
    printf "  %s: %d words (ceiling %d, +%d over, %d%%)\n" "$f" "$actual" "$ceiling" "$over" "$pct" >> "$hits_file"
    violations=$((violations + 1))
  fi
done <<< "$_files"

# ── 输出 + exit ─────────────────────────────────────────────────────────
if [ "$violations" -gt 0 ]; then
  echo "FAIL: $violations file(s) exceed word budget (EPIC-279 fail-closed):"
  cat "$hits_file"
  echo ""
  echo "Fix: 拆分文档到子文件 (跟 EPIC-159 path-scoped lazy load 同型) 或"
  echo "      提升 ceiling (改 budgets.manifest.json, 需 PR review)."
  exit 1
fi

echo "OK: doc word budgets PASS ($([ "$staged_mode" -eq 1 ] && echo "staged" || echo "all"))"
exit 0
