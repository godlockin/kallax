#!/usr/bin/env bash
# tests/integration/docs-reuse-metric.test.sh — EPIC-253
#
# 覆盖 2 件事:
#   A. 修 bug: collect_filescope_for_epic 漏 root ticket (EPIC-XXX/ vs EPIC-XXX-A/)
#   B. 新 metric: compute_cross_epic_docs_reuse_rate
#
# Rule 34 复现 (bug A): EPIC-251 (root ticket, 有 file_scope) 在修复前返回 NO_DATA / total_files=0.
#
# Exit: 0 = all PASS, 1 = FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="${KALLAX_ROOT}/scripts/metrics/lib/metrics.sh"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (got '$actual')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_ge() {
  local name="$1" min="$2" actual="$3"
  if [ "$actual" -ge "$min" ] 2>/dev/null; then
    echo "  PASS: $name (got $actual, >= $min)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (got $actual, < $min)"
    FAIL=$((FAIL + 1))
  fi
}

assert_grep() {
  local name="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (pattern '$pattern' absent)"
    FAIL=$((FAIL + 1))
  fi
}

# ── 隔离 fixture: 临时 jira/tickets 目录 ────────────────────────────────────
TMPROOT="$(mktemp -d -t epic253.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

seed_ticket() {
  local id="$1"; shift
  local dir="${TMPROOT}/jira/tickets/${id}"
  mkdir -p "$dir"
  local includes_json
  includes_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  jq -n --arg id "$id" --argjson inc "$includes_json" \
    '{id:$id, ticket_id:$id, file_scope:{includes:$inc}}' > "${dir}/ticket.json"
}

# root ticket, docs-heavy, 跟 EPIC-902 共享 2 个 docs
seed_ticket "EPIC-901" "CLAUDE.md" ".claude/rules/testing.md" "node/src/core/foo.ts"
# sub-ticket 形态
seed_ticket "EPIC-902-A" "CLAUDE.md" ".claude/rules/testing.md" "docs/reference/bar.md"
# 无 overlap 的 EPIC
seed_ticket "EPIC-903" "node/src/unique/baz.ts"

# shellcheck source=/dev/null
JIRA_TICKETS_DIR="${TMPROOT}/jira/tickets"
export JIRA_TICKETS_DIR
source "$LIB" 2>/dev/null || true
JIRA_TICKETS_DIR="${TMPROOT}/jira/tickets"

# ── Case 1: lib 语法 + 函数导出 ─────────────────────────────────────────────
echo "Case 1: lib syntax + function present"
if bash -n "$LIB" 2>/dev/null; then
  echo "  PASS: metrics.sh syntax OK"
  PASS=$((PASS + 1))
else
  echo "  FAIL: metrics.sh syntax error"
  FAIL=$((FAIL + 1))
fi
assert_grep "compute_cross_epic_docs_reuse_rate defined" 'compute_cross_epic_docs_reuse_rate\(\)' "$LIB"
assert_grep "DOCS_PATH_PATTERN defined" 'DOCS_PATH_PATTERN=' "$LIB"
assert_grep "CROSS_EPIC_DOCS_REUSE_TARGET_PCT defined" 'CROSS_EPIC_DOCS_REUSE_TARGET_PCT=' "$LIB"

# ── Case 2: bug A 修复 — root ticket 被扫到 ─────────────────────────────────
echo ""
echo "Case 2: collect_filescope_for_epic includes root ticket (bug A fix)"
ROOT_FILES="$(collect_filescope_for_epic "901" | jq 'length')"
assert_eq "root ticket EPIC-901 file_scope collected" "3" "$ROOT_FILES"

# ── Case 3: sub-ticket 仍被扫到 (无 regression) ─────────────────────────────
echo ""
echo "Case 3: sub-ticket form still collected (no regression)"
SUB_FILES="$(collect_filescope_for_epic "902" | jq 'length')"
assert_eq "sub-ticket EPIC-902-A file_scope collected" "3" "$SUB_FILES"

# ── Case 4: collect_filescope_all_except 排除 root + sub ────────────────────
echo ""
echo "Case 4: collect_filescope_all_except excludes both root and sub forms"
OTHER_901="$(collect_filescope_all_except "901" | jq -r '.[]' | sort | tr '\n' ',')"
case "$OTHER_901" in
  *"node/src/core/foo.ts"*)
    echo "  FAIL: EPIC-901 own file leaked into others"
    FAIL=$((FAIL + 1)) ;;
  *)
    echo "  PASS: EPIC-901 own file excluded"
    PASS=$((PASS + 1)) ;;
esac

# ── Case 5: docs metric — 有 overlap ───────────────────────────────────────
echo ""
echo "Case 5: docs reuse rate computed for docs-heavy EPIC"
M2B="$(compute_cross_epic_docs_reuse_rate "EPIC-901")"
DOCS_TOTAL="$(printf '%s' "$M2B" | jq -r '.total_docs_files')"
DOCS_OVERLAP="$(printf '%s' "$M2B" | jq -r '.overlap_count')"
DOCS_PCT="$(printf '%s' "$M2B" | jq -r '.docs_reuse_pct')"
# EPIC-901 docs = CLAUDE.md + .claude/rules/testing.md (foo.ts 非 docs) = 2
assert_eq "docs file count excludes .ts" "2" "$DOCS_TOTAL"
assert_eq "docs overlap with EPIC-902-A" "2" "$DOCS_OVERLAP"
assert_eq "docs reuse pct" "100" "$DOCS_PCT"

# ── Case 6: docs metric — PASS/FAIL 判定 ───────────────────────────────────
echo ""
echo "Case 6: docs metric status reflects target threshold"
DOCS_STATUS="$(printf '%s' "$M2B" | jq -r '.status')"
assert_eq "full overlap >= 40 target → PASS" "PASS" "$DOCS_STATUS"

# ── Case 7: 无 docs 的 EPIC → NO_DATA ──────────────────────────────────────
echo ""
echo "Case 7: EPIC with zero docs files → NO_DATA"
M2B_903="$(compute_cross_epic_docs_reuse_rate "EPIC-903")"
STATUS_903="$(printf '%s' "$M2B_903" | jq -r '.status')"
TOTAL_903="$(printf '%s' "$M2B_903" | jq -r '.total_docs_files')"
assert_eq "no docs → NO_DATA" "NO_DATA" "$STATUS_903"
assert_eq "no docs → total 0" "0" "$TOTAL_903"

# ── Case 8: metric 集成到 JSON / Markdown formatter ─────────────────────────
echo ""
echo "Case 8: metric wired into both formatters"
assert_grep "JSON formatter includes m2b" 'argjson m2b' "$LIB"
assert_grep "Markdown formatter includes docs row" 'cross_epic_docs_reuse_rate \|' "$LIB"

echo ""
echo "================================================"
echo "EPIC-253 Docs Reuse Metric Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
