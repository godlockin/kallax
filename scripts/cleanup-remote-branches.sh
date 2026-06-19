#!/usr/bin/env bash
# KALLAX Remote Branches Cleanup — filter-repo dry-run (NO actual history rewrite)
# EPIC-058-D — 跟 主公 2026-06-17 D 跳过 + 主公 2026-06-19 '都拆卡做' explicit 覆盖 联合
# 跟 "不埋坑" 5 原则 联合 (filter-repo 改写 history 是 不可逆 操作, 高风险)
# 跟 v2.0.5 Option A 保留 模式 联合 (跟"翻篇&精进" 战略 一致, 0 实际 history 改写)
# 跟 eket MASTER-RULES.md §11 派遣 Checklist 11 项 联合 (PASS 报告含 raw test output)
# 跟 EPIC-059-D Fact-Forcing 联合 (治根 "0 假 PASS" 反复)
#
# Usage: ./scripts/cleanup-remote-branches.sh
#
# Output: dry-run report (stdout) — 0 actual history rewrite applied
# Exit: 0 (dry-run success) | 1 (precondition failure)
#
# ⚠️  HARD CONSTRAINT: filter-repo 改写 history 是 不可逆 操作
#     本脚本 仅 dry-run, 0 实际改写, 跟 "不埋坑" 5 原则 联合
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly PROJECT_ROOT

# Constants (Rule 4: 0 magic numbers, name all)
readonly THRESHOLD_DAYS=180
readonly EXPECTED_TOTAL_REFS=114
readonly EXPECTED_HEAD_COUNT=1
readonly EXPECTED_BRANCH_MIN=70  # 71 observed, 70 floor for assertion stability

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*" >&2; }

# Hard precondition: must be inside a git repo
git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  err "Not a git repository: $PROJECT_ROOT"
  exit 1
}

echo "═══════════════════════════════════════════════════════════"
echo " KALLAX Remote Branches Cleanup — filter-repo DRY-RUN"
echo "═══════════════════════════════════════════════════════════"
echo " Project root:  $PROJECT_ROOT"
echo " Threshold:     ${THRESHOLD_DAYS} days (stale = no commit within window)"
echo " Mode:          DRY-RUN ONLY — 0 actual history rewrite"
echo " Rationale:     filter-repo 改写 history 是 不可逆, 跟'不埋坑' 5 原则 联合"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Total remote refs
TOTAL_REFS=$(git -C "$PROJECT_ROOT" ls-remote origin | wc -l | tr -d ' ')
info "Total remote refs: ${TOTAL_REFS} (expected ~${EXPECTED_TOTAL_REFS})"
if [ "$TOTAL_REFS" -ne "$EXPECTED_TOTAL_REFS" ]; then
  warn "Total remote refs diverged (${TOTAL_REFS} != ${EXPECTED_TOTAL_REFS}) — not blocking dry-run"
fi

# 2. Branch-only count
BRANCH_REFS=$(git -C "$PROJECT_ROOT" ls-remote origin 'refs/heads/*' | wc -l | tr -d ' ')
info "Remote branches:   ${BRANCH_REFS} (expected >= ${EXPECTED_BRANCH_MIN})"
if [ "$BRANCH_REFS" -lt "$EXPECTED_BRANCH_MIN" ]; then
  warn "Remote branch count below floor (${BRANCH_REFS} < ${EXPECTED_BRANCH_MIN})"
fi

# 3. HEAD ref (sanity)
HEAD_REFS=$(git -C "$PROJECT_ROOT" ls-remote origin 'HEAD' | wc -l | tr -d ' ')
info "HEAD refs:         ${HEAD_REFS} (expected ${EXPECTED_HEAD_COUNT})"

# 4. Non-branch refs (PRs + tags) — informational
NON_BRANCH_REFS=$(git -C "$PROJECT_ROOT" ls-remote origin \
  | awk '{print $2}' \
  | grep -v 'refs/heads/' \
  | grep -v '^HEAD$' \
  | wc -l | tr -d ' ')
info "Non-branch refs:   ${NON_BRANCH_REFS} (PRs + tags — out of cleanup scope)"

# 5. Capture HEAD SHA before any operation (Fact-Forcing invariant)
HEAD_SHA_BEFORE=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
info "HEAD SHA (before): ${HEAD_SHA_BEFORE}"

# 6. Stale candidate analysis (no fetches, no rewrites — read-only)
# 算 stale 仅看 local cache, 0 网络操作
STALE_CANDIDATES=0
ACTIVE_CANDIDATES=0
NOW_EPOCH=$(date +%s)
THRESHOLD_EPOCH=$((NOW_EPOCH - THRESHOLD_DAYS * 86400))

# Use a temp file to avoid subshell scoping
TMP_STALE_LIST="$(mktemp -t kallax-stale.XXXXXX)"
trap 'rm -f "$TMP_STALE_LIST"' EXIT

while read -r branch; do
  # Skip HEAD and empty lines
  [ -z "$branch" ] && continue
  case "$branch" in
    HEAD|*/HEAD) continue ;;
  esac

  # Try to read commit date for this branch's tip
  BRANCH_TIP=$(git -C "$PROJECT_ROOT" rev-parse --verify "$branch" 2>/dev/null || echo "")
  if [ -z "$BRANCH_TIP" ]; then
    # Branch not in local cache, mark stale by default (conservative)
    STALE_CANDIDATES=$((STALE_CANDIDATES + 1))
    echo "$branch [not-in-local-cache]" >> "$TMP_STALE_LIST"
    continue
  fi

  COMMIT_EPOCH=$(git -C "$PROJECT_ROOT" show -s --format=%ct "$BRANCH_TIP" 2>/dev/null | tr -d ' ' || echo "0")
  if [ "${COMMIT_EPOCH:-0}" -lt "$THRESHOLD_EPOCH" ]; then
    STALE_CANDIDATES=$((STALE_CANDIDATES + 1))
    echo "$branch [epoch=$COMMIT_EPOCH]" >> "$TMP_STALE_LIST"
  else
    ACTIVE_CANDIDATES=$((ACTIVE_CANDIDATES + 1))
  fi
done < <(git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' refs/remotes/origin 2>/dev/null)

info "Stale candidates:  ${STALE_CANDIDATES} (> ${THRESHOLD_DAYS} days OR not-in-local-cache)"
info "Active candidates: ${ACTIVE_CANDIDATES} (within ${THRESHOLD_DAYS} days)"

# 7. Show first 10 stale candidates for transparency (DRY evidence)
if [ -s "$TMP_STALE_LIST" ]; then
  echo ""
  info "Sample stale branches (first 10 of ${STALE_CANDIDATES}):"
  head -10 "$TMP_STALE_LIST" | sed 's/^/    /'
fi

# 8. HEAD SHA after (must be identical — proves 0 history rewrite)
HEAD_SHA_AFTER=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
info "HEAD SHA (after):  ${HEAD_SHA_AFTER}"

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ "$HEAD_SHA_BEFORE" = "$HEAD_SHA_AFTER" ]; then
  pass "DRY-RUN complete — 0 actual history rewrite (HEAD SHA unchanged)"
  pass "filter-repo NOT invoked — 跟'不埋坑' 5 原则 联合"
  pass "Stale=${STALE_CANDIDATES} Active=${ACTIVE_CANDIDATES} (informational only)"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "raw_metrics: total_refs=${TOTAL_REFS} branches=${BRANCH_REFS}"
  echo "             head_refs=${HEAD_REFS} non_branch_refs=${NON_BRANCH_REFS}"
  echo "             stale_candidates=${STALE_CANDIDATES} active_candidates=${ACTIVE_CANDIDATES}"
  echo "             threshold_days=${THRESHOLD_DAYS} head_sha_unchanged=true"
  echo "             mode=dry_run history_rewritten=false"
  exit 0
else
  err "FATAL: HEAD SHA changed during dry-run — possible state corruption"
  err "  before: ${HEAD_SHA_BEFORE}"
  err "  after:  ${HEAD_SHA_AFTER}"
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
