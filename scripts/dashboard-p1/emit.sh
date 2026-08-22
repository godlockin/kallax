#!/usr/bin/env bash
# scripts/dashboard-p1/emit.sh
# EPIC-281 Phase 1 — Dashboard 静态站 MVP emit (1 周 effort / 200 LOC)
#
# 扫描 jira/tickets/**/*.json (jq 解析) 生成静态站 dist/dashboard/{data.json,index.html}
# 单页 table, 4-branch swimlane, 零 JS 依赖, 127.0.0.1-only serve (R5 mitigation).
#
# 约束:
#   - 0 schema change (跟 check-ticket-schema.sh 口径一致)
#   - 0 DB (jira/tickets/*.json 是单真相源)
#   - NO_DATA 灰态 vs 真 0 区分 (跟 EPIC-223 exit=2 处理对齐)
#   - Rule 34 gate badge (bugfix ticket 缺 reproduction 字段红牌)
#
# Usage:
#   bash scripts/dashboard-p1/emit.sh
#   bash scripts/dashboard-p1/emit.sh --output /custom/path
#
# Exit codes:
#   0 = success (data.json + index.html 已生成)
#   1 = missing dependency (jq not found)
#   2 = tickets dir not found
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS_DIR="${PROJECT_ROOT}/jira/tickets"
BASELINE="${TICKETS_DIR}/.archive-baseline.json"

OUTPUT_DIR="${PROJECT_ROOT}/dist/dashboard"
DATA_JSON="${OUTPUT_DIR}/data.json"
INDEX_HTML="${OUTPUT_DIR}/index.html"

# arg parse
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT_DIR="$2"; DATA_JSON="${OUTPUT_DIR}/data.json"; INDEX_HTML="${OUTPUT_DIR}/index.html"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# deps
for cmd in jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd required" >&2; exit 1; }
done

[[ -d "$TICKETS_DIR" ]] || { echo "FAIL: tickets dir not found: $TICKETS_DIR" >&2; exit 2; }

mkdir -p "$OUTPUT_DIR"

# archived_before for ARCHIVED_SKIP (跟 EPIC-223 + check-ticket-schema.sh 口径一致)
ARCHIVED_BEFORE="$(jq -r '.archive_baseline.archived_before // 222' "$BASELINE" 2>/dev/null || echo 222)"

# ─── 收集所有 ticket.json (按 EPIC 编号升序) ───────────────────────────────

TICKETS_JSON="[]"
BUGFIX_MISSING_REPRO="[]"  # Rule 34 红牌清单
COUNT_TOTAL=0
COUNT_BUGFIX=0
COUNT_DOCS=0
COUNT_DONE=0
COUNT_IN_PROGRESS=0
COUNT_BLOCKED=0
COUNT_BACKLOG=0
COUNT_NO_DATA=0  # NO_DATA 灰态计数
COUNT_ARCHIVED=0

while IFS= read -r -d '' tfile; do
  COUNT_TOTAL=$((COUNT_TOTAL + 1))
  # 只读有效的 ticket.json (jq 解析成功 + id 字段存在)
  if ! jq -e '.id' "$tfile" >/dev/null 2>&1; then
    continue
  fi

  tid=$(jq -r '.id' "$tfile")
  tstatus=$(jq -r '.status // "unknown"' "$tfile")
  ttype=$(jq -r '.type // "unknown"' "$tfile")
  ttitle=$(jq -r '.title // ""' "$tfile")
  tperformer=$(jq -r '.performer // ""' "$tfile")
  has_repro=$(jq -e '.verification.reproduction_command // .verification.reproduction_exit_code // .verification.reproduction_raw_output' "$tfile" >/dev/null 2>&1 && echo "yes" || echo "no")

  # Rule 34: bugfix ticket 缺 reproduction 任一字段 → 红牌
  if [[ "$ttype" == "bugfix" && "$has_repro" == "no" ]]; then
    BUGFIX_MISSING_REPRO=$(echo "$BUGFIX_MISSING_REPRO" | jq --arg id "$tid" '. + [$id]')
  fi

  # status 计数
  case "$tstatus" in
    done|merged|closed|passed) COUNT_DONE=$((COUNT_DONE + 1)) ;;
    in_progress|in-progress) COUNT_IN_PROGRESS=$((COUNT_IN_PROGRESS + 1)) ;;
    blocked) COUNT_BLOCKED=$((COUNT_BLOCKED + 1)) ;;
    backlog|todo) COUNT_BACKLOG=$((COUNT_BACKLOG + 1)) ;;
    *) COUNT_NO_DATA=$((COUNT_NO_DATA + 1)) ;;  # unknown / 空 = 灰态
  esac

  case "$ttype" in
    bugfix) COUNT_BUGFIX=$((COUNT_BUGFIX + 1)) ;;
    docs) COUNT_DOCS=$((COUNT_DOCS + 1)) ;;
  esac

  # 解析 EPIC 编号 (EPIC-223 → 223); 非 EPIC- 编号 (e.g. PHASE-008-B) 视为 archived
  epic_num_raw=$(echo "$tid" | sed -E 's/^EPIC-0*([0-9]+).*/\1/' 2>/dev/null)
  if [[ -z "$epic_num_raw" || ! "$epic_num_raw" =~ ^[0-9]+$ ]]; then
    tarchived="true"
    COUNT_ARCHIVED=$((COUNT_ARCHIVED + 1))
  elif [ "$epic_num_raw" -le "$ARCHIVED_BEFORE" ]; then
    COUNT_ARCHIVED=$((COUNT_ARCHIVED + 1))
    tarchived="true"
  else
    tarchived="false"
  fi

  # review final_outcome 提取 (Rule 36 #3 数据源)
  treview=$(jq -r '.review.final_outcome // "NO_DATA"' "$tfile" 2>/dev/null)

  TICKETS_JSON=$(echo "$TICKETS_JSON" | jq \
    --arg id "$tid" \
    --arg status "$tstatus" \
    --arg type "$ttype" \
    --arg title "$ttitle" \
    --arg performer "$tperformer" \
    --arg archived "$tarchived" \
    --arg review "$treview" \
    '. + [{
      "id": $id,
      "status": $status,
      "type": $type,
      "title": $title,
      "performer": $performer,
      "archived": ($archived == "true"),
      "review": $review
    }]')
done < <(find "$TICKETS_DIR" -mindepth 2 -maxdepth 2 -name "ticket.json" 2>/dev/null | head -n 500 | while IFS= read -r f; do printf '%s\0' "$f"; done)

# ─── Sprint 4 北极星 metric (Rule 36, 跟 sprint-metrics.sh 对齐) ─────────────
# 调用 sprint-metrics.sh 拿真实数据, exit=2/3 时显式标 NO_DATA / DOCS_ONLY_SKIP
# 根因 (EPIC-281 verify): emit.sh 调用 --epic EPIC-277-F 触发 validate_epic_id
#   bad_format (expected ^EPIC-[0-9]+$) → exit 1 (FAIL 红牌). 修复:
#   改用 --epic EPIC-281 (本卡 id, 合法). EPIC-281 是新 EPIC 无 metrics 数据源
#   → 预期 exit=2 (ALL_NO_DATA) → metrics_status=NO_DATA 灰态 ⚠️ (跟 AC6)
METRICS_FILE="$OUTPUT_DIR/.metrics-raw.json"
METRICS_EXIT=0
if bash "${PROJECT_ROOT}/scripts/metrics/sprint-metrics.sh" --epic EPIC-281 --format json > "$METRICS_FILE" 2>/dev/null; then
  METRICS_EXIT=0
else
  METRICS_EXIT=$?
fi

# Exit-code 映射 (跟 sprint-metrics.sh §Exit codes):
#   0 = all 4 metrics PASS → metrics_status="PASS"
#   1 = at least 1 FAIL    → metrics_status="FAIL" (红牌)
#   2 = ALL_NO_DATA        → metrics_status="NO_DATA" (灰态 ⚠️, 跟 EPIC-223 exit=2)
#   3 = DOCS_ONLY_SKIP     → metrics_status="DOCS_ONLY_SKIP"
# AC6: NO_DATA / DOCS_ONLY_SKIP 灰态 (灰牌 ⚠️), 不混 PASS; FAIL 真红牌
case "$METRICS_EXIT" in
  0) METRICS_STATUS="PASS" ;;
  2) METRICS_STATUS="NO_DATA" ;;
  3) METRICS_STATUS="DOCS_ONLY_SKIP" ;;
  *) METRICS_STATUS="FAIL" ;;
esac

# ─── data.json (静态) ──────────────────────────────────────────────────────

jq -n \
  --argjson tickets "$TICKETS_JSON" \
  --argjson bugfix_missing "$BUGFIX_MISSING_REPRO" \
  --argjson total "$COUNT_TOTAL" \
  --argjson done "$COUNT_DONE" \
  --argjson in_progress "$COUNT_IN_PROGRESS" \
  --argjson blocked "$COUNT_BLOCKED" \
  --argjson backlog "$COUNT_BACKLOG" \
  --argjson no_data "$COUNT_NO_DATA" \
  --argjson bugfix "$COUNT_BUGFIX" \
  --argjson docs "$COUNT_DOCS" \
  --argjson archived "$COUNT_ARCHIVED" \
  --slurpfile metrics "$METRICS_FILE" \
  --arg metrics_status "$METRICS_STATUS" \
  --arg archived_before "$ARCHIVED_BEFORE" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    generated_at: $generated_at,
    metrics_status: $metrics_status,
    archived_before: ($archived_before | tonumber),
    metrics: ($metrics[0].metrics // []),
    counts: {
      total: $total,
      done: $done,
      in_progress: $in_progress,
      blocked: $blocked,
      backlog: $backlog,
      no_data: $no_data,
      bugfix: $bugfix,
      docs: $docs,
      archived: $archived
    },
    rule34_violations: $bugfix_missing,
    tickets: $tickets
  }' > "$DATA_JSON"

# ─── index.html (零 JS 依赖, 单页 table, 4-branch swimlane) ──────────────────

# 复用 KALLAX 调色板 (GRAY/BLUE/YELLOW/MAGENTA/GREEN/RED)
# 4-branch swimlane: feature / testing / main / miao
# 状态色映射:
#   done     -> GREEN
#   in_progress -> YELLOW
#   review   -> MAGENTA
#   blocked  -> RED
#   backlog/todo -> BLUE
#   archived -> GRAY
#   NO_DATA (unknown) -> GRAY + ⚠️

# 用 jq 生成 ticket rows
TICKET_ROWS=$(echo "$TICKETS_JSON" | jq -r '
  sort_by(.id) | .[] |
  def status_color:
    if .status == "done" or .status == "merged" or .status == "closed" or .status == "passed" then "GREEN"
    elif .status == "in_progress" or .status == "in-progress" then "YELLOW"
    elif .status == "review" then "MAGENTA"
    elif .status == "blocked" then "RED"
    elif .status == "backlog" or .status == "todo" then "BLUE"
    else "GRAY"
    end;
  def branch:
    if .archived then "archived"
    elif .status == "done" or .status == "merged" or .status == "closed" or .status == "passed" then "miao"
    elif .status == "in_progress" or .status == "in-progress" then "feature"
    elif .status == "review" then "testing"
    elif .status == "blocked" then "main"
    else "backlog"
    end;
  "<tr class=\"branch-\(branch) status-\(status_color)\">" +
    "<td>\(.id)</td>" +
    "<td><span class=\"badge badge-\(status_color)\">\(.status)</span></td>" +
    "<td>\(.type)</td>" +
    "<td>\(.title // "")</td>" +
    "<td>\(.performer // "—")</td>" +
    "</tr>"
')

cat > "$INDEX_HTML" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>KALLAX Dashboard — EPIC-281 Phase 1</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, monospace; margin: 24px; background: #fafafa; color: #222; }
  h1 { font-size: 18px; margin: 0 0 12px; }
  h2 { font-size: 14px; margin: 16px 0 8px; }
  .meta { color: #666; font-size: 12px; margin-bottom: 16px; }
  .stats { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }
  .stat { padding: 8px 12px; border-radius: 4px; background: #fff; border: 1px solid #ddd; font-size: 12px; }
  .stat strong { font-size: 18px; display: block; }
  .no-data { background: #f5f5f5; color: #888; border-color: #ccc; }
  .no-data strong { color: #555; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; background: #fff; }
  /* 100% width 表让多列换行; border-collapse 合并 cell; #fff 卡片色 */
  th, td { padding: 6px 8px; text-align: left; border-bottom: 1px solid #eee; }
  th { background: #f0f0f0; font-weight: 600; }
  .badge { padding: 2px 6px; border-radius: 3px; font-size: 11px; color: #fff; }
  .badge-GREEN { background: #28a745; }
  .badge-BLUE { background: #007bff; }
  .badge-YELLOW { background: #ffc107; color: #222; }
  .badge-MAGENTA { background: #d63384; }
  .badge-RED { background: #dc3545; }
  .badge-GRAY { background: #6c757d; }
  .swimlane-feature td:first-child { border-left: 3px solid #007bff; }
  .swimlane-testing td:first-child { border-left: 3px solid #d63384; }
  .swimlane-main td:first-child { border-left: 3px solid #dc3545; }
  .swimlane-miao td:first-child { border-left: 3px solid #28a745; }
  .swimlane-archived td:first-child { border-left: 3px solid #6c757d; opacity: 0.6; }
</style>
</head>
<body>
<h1>KALLAX Dashboard — EPIC-281 Phase 1 (static MVP)</h1>
<div class="meta">
  Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) | Archived before: EPIC-${ARCHIVED_BEFORE} |
  Metrics: <strong>${METRICS_STATUS}</strong> (sprint-metrics.sh EPIC-281)
</div>

<h2>Counts</h2>
<div class="stats">
  <div class="stat"><strong>${COUNT_TOTAL}</strong>Total</div>
  <div class="stat"><strong>${COUNT_DONE}</strong>Done (miao)</div>
  <div class="stat"><strong>${COUNT_IN_PROGRESS}</strong>In Progress (feature)</div>
  <div class="stat"><strong>${COUNT_BLOCKED}</strong>Blocked (main)</div>
  <div class="stat"><strong>${COUNT_BACKLOG}</strong>Backlog/Review</div>
  <div class="stat no-data"><strong>${COUNT_NO_DATA}</strong>⚠ NO_DATA (gray-state)</div>
  <div class="stat"><strong>${COUNT_BUGFIX}</strong>Bugfix</div>
  <div class="stat"><strong>${COUNT_DOCS}</strong>Docs</div>
  <div class="stat no-data"><strong>${COUNT_ARCHIVED}</strong>Archived (skip check)</div>
</div>

<h2>Rule 34 Violations (bugfix missing reproduction field)</h2>
<div class="stats">
HTMLEOF

if [[ "$(echo "$BUGFIX_MISSING_REPRO" | jq 'length')" == "0" ]]; then
  echo '  <div class="stat"><strong>0</strong>PASS — all bugfix tickets have reproduction</div>' >> "$INDEX_HTML"
else
  echo "  <div class=\"stat\"><strong>$(echo "$BUGFIX_MISSING_REPRO" | jq 'length')</strong>RED — bugfix tickets missing reproduction:</div>" >> "$INDEX_HTML"
  echo "$BUGFIX_MISSING_REPRO" | jq -r '.[] | "  <div class=\"stat\">⚠ \(.)</div>"' >> "$INDEX_HTML"
fi

cat >> "$INDEX_HTML" <<'HTMLEOF'
</div>

<h2>Tickets (4-branch swimlane)</h2>
<table>
<thead><tr><th>ID</th><th>Status</th><th>Type</th><th>Title</th><th>Performer</th></tr></thead>
<tbody>
HTMLEOF

echo "$TICKET_ROWS" >> "$INDEX_HTML"

cat >> "$INDEX_HTML" <<HTMLEOF
</tbody>
</table>

<footer style="margin-top:24px;font-size:11px;color:#888">
  EPIC-281 Phase 1 | 0 schema change | 0 DB | jq-parsed jira/tickets/*.json | NO_DATA 灰态 vs 真 0 区分
</footer>
</body>
</html>
HTMLEOF

echo "OK: data.json + index.html generated"
echo "  data: $DATA_JSON"
echo "  html: $INDEX_HTML"