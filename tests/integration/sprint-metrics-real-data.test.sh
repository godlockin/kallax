#!/usr/bin/env bash
# tests/integration/sprint-metrics-real-data.test.sh — EPIC-277-F AC7
#
# 4 case, 每个 case 打中 sprint-metrics.sh 的一个出口码, 并验证对应指标出真数据:
#   Case 1 → exit 3 (DOCS_ONLY_SKIP)
#   Case 2 → exit 2 (ALL_NO_DATA, 数据源全空)
#   Case 3 → exit 1 (至少 1 个 FAIL, 且带真 X/Y 数字而非 NO_DATA)
#   Case 4 → exit 0 (0 FAIL) + ab_hit_rate / expert_activation_rate 真数据
#
# 为什么要这个 test:
#   sprint-metrics.sh 的 exit code 是 Rule 36 的门控信号 (0=通过 / 2=NO_DATA 触发 ASK).
#   之前 4 指标恒 NO_DATA → exit 2 是唯一实际走过的路径, 另外 3 条从没被验证过.
#   本 test 用隔离的 fixture tickets 目录 + 隔离的 invocation 数据源, 4 条路都跑一遍.
#
# 隔离手段: 每个 case 建 tmp git repo (metrics.sh 的 resolve_paths 用 git root),
#   把 fixture ticket.json 放进去, 并用 INVOCATION_DB / INVOCATION_FILE 环境变量
#   指向 tmp 文件 — 不读也不写真实的 ~/.kallax 数据.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
METRICS="$REPO_ROOT/scripts/metrics/sprint-metrics.sh"

if [ ! -f "$METRICS" ]; then
  echo "FAIL: metrics CLI not found: $METRICS" >&2
  exit 1
fi
for c in jq git; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "FAIL: $c not found" >&2
    exit 1
  fi
done

TMP="$(mktemp -d -t sprint-metrics-real.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
TOTAL=4

section() { printf '\n=== %s ===\n' "$1"; }
ok()  { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; }

# 建一个隔离的 fixture repo (metrics.sh resolve_paths 用 git rev-parse --show-toplevel)
make_fixture_repo() {
  local dir="$1"
  mkdir -p "$dir/jira/tickets"
  git -C "$dir" init -q 2>/dev/null
  git -C "$dir" config user.email t@k.io 2>/dev/null
  git -C "$dir" config user.name t 2>/dev/null
  # archive baseline: 让 fixture EPIC 编号都算"新卡" (不触发 ARCHIVED_SKIP)
  cat > "$dir/jira/tickets/.archive-baseline.json" <<'EOF'
{
  "archive_baseline": { "archived_before": 0 },
  "new_ticket_required_fields": ["id", "status", "title", "performer", "file_scope.includes", "review"],
  "review_field_schema": {
    "required_paths": [
      "review.group_a.recommendation",
      "review.group_b.recommendation",
      "review.final_outcome"
    ]
  }
}
EOF
}

# 写一个 fixture ticket
# 参数: repo_dir, ticket_id, status, performer, review_a, review_b, final, file...
write_ticket() {
  local dir="$1" tid="$2" status="$3" performer="$4" a="$5" b="$6" final="$7"
  shift 7
  local files_json
  files_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  mkdir -p "$dir/jira/tickets/$tid"
  local review_json='null'
  if [ -n "$a" ]; then
    review_json="$(jq -n --arg a "$a" --arg b "$b" --arg f "$final" \
      '{group_a:{recommendation:$a}, group_b:{recommendation:$b}, final_outcome:$f}')"
  fi
  jq -n \
    --arg id "$tid" --arg st "$status" --arg p "$performer" \
    --argjson files "$files_json" --argjson review "$review_json" \
    '{id:$id, status:$st, title:("fixture " + $id), performer:$p, type:"chore",
      file_scope:{includes:$files},
      expert_binding:{suggested_expert:"custom:x", actual_expert:"custom:x"},
      review:$review}' \
    > "$dir/jira/tickets/$tid/ticket.json"
}

# 跑 metrics, 隔离 invocation 数据源
# 参数: repo_dir, epic, invocation_db, invocation_jsonl, extra args...
run_metrics() {
  local dir="$1" epic="$2" db="$3" jsonl="$4"
  shift 4
  ( cd "$dir" && INVOCATION_DB="$db" INVOCATION_FILE="$jsonl" \
      bash "$METRICS" --epic "$epic" "$@" 2>>"$TMP/metrics.log" )
}

# ------------------------------------------------------------------
# Case 1: exit 3 — DOCS_ONLY_SKIP
# ------------------------------------------------------------------
section "Case 1: exit 3 (DOCS_ONLY_SKIP)"
C1_OK=1; C1_WHY=""
R1="$TMP/case1"
make_fixture_repo "$R1"
write_ticket "$R1" "EPIC-901-A" "done" "master" "APPROVE" "APPROVE" "MERGED" "docs/a.md"

OUT1="$(run_metrics "$R1" "EPIC-901" "$TMP/none.db" "$TMP/none.jsonl" --docs-only)"
RC1=$?
if [ "$RC1" -ne 3 ]; then
  C1_OK=0; C1_WHY="exit=$RC1 (期望 3)"
fi
if [ "$C1_OK" -eq 1 ]; then
  ST="$(printf '%s' "$OUT1" | jq -r '.status // empty' 2>/dev/null || true)"
  if [ "$ST" != "DOCS_ONLY_SKIP" ]; then
    C1_OK=0; C1_WHY="status=$ST (期望 DOCS_ONLY_SKIP)"
  fi
fi
if [ "$C1_OK" -eq 1 ]; then
  ok "exit 3 DOCS_ONLY_SKIP + status 字段相符"
else
  bad "exit 3: $C1_WHY"
fi

# ------------------------------------------------------------------
# Case 2: exit 2 — 所有 metric NO_DATA
#   做法: EPIC 编号在 fixture 里根本没有对应 ticket, 且 invocation 数据源为空文件.
# ------------------------------------------------------------------
section "Case 2: exit 2 (ALL_NO_DATA)"
C2_OK=1; C2_WHY=""
R2="$TMP/case2"
make_fixture_repo "$R2"
# 只放一个跟目标 EPIC 无关的 ticket, 让目标 EPIC 查无数据
write_ticket "$R2" "EPIC-800-A" "done" "master" "APPROVE" "APPROVE" "MERGED" "scripts/x.sh"
: > "$TMP/empty.jsonl"

OUT2="$(run_metrics "$R2" "EPIC-902" "$TMP/none.db" "$TMP/empty.jsonl")"
RC2=$?
if [ "$RC2" -ne 2 ]; then
  C2_OK=0; C2_WHY="exit=$RC2 (期望 2)"
fi
if [ "$C2_OK" -eq 1 ]; then
  TOT="$(printf '%s' "$OUT2" | jq '.metrics | length')"
  ND="$(printf '%s' "$OUT2" | jq '[.metrics[] | select(.status=="NO_DATA")] | length')"
  if [ "$TOT" -eq 0 ] || [ "$ND" -ne "$TOT" ]; then
    C2_OK=0; C2_WHY="NO_DATA $ND/$TOT (期望全部 NO_DATA)"
  fi
fi
if [ "$C2_OK" -eq 1 ]; then
  ok "exit 2 ALL_NO_DATA (${ND}/${TOT} 指标 NO_DATA)"
else
  bad "exit 2: $C2_WHY"
fi

# ------------------------------------------------------------------
# Case 3: exit 1 — 至少 1 个 FAIL, 且 FAIL 是真数字算出来的
#   做法: 造 5 个 ticket, 其中 3 个 review 错配 (A+B APPROVE 但 final REJECTED)
#   → ab_hit_rate mismatch 60% > 15% target → FAIL, total_reviews=5 真数字.
# ------------------------------------------------------------------
section "Case 3: exit 1 (有 FAIL + 真 X/Y 数字)"
C3_OK=1; C3_WHY=""
R3="$TMP/case3"
make_fixture_repo "$R3"
write_ticket "$R3" "EPIC-903-A" "done"     "master" "APPROVE" "APPROVE" "MERGED"   "scripts/a.sh"
write_ticket "$R3" "EPIC-903-B" "done"     "master" "APPROVE" "APPROVE" "MERGED"   "scripts/b.sh"
write_ticket "$R3" "EPIC-903-C" "rejected" "master" "APPROVE" "APPROVE" "REJECTED" "scripts/c.sh"
write_ticket "$R3" "EPIC-903-D" "rejected" "master" "APPROVE" "APPROVE" "REJECTED" "scripts/d.sh"
write_ticket "$R3" "EPIC-903-E" "rejected" "master" "APPROVE" "APPROVE" "REJECTED" "scripts/e.sh"

OUT3="$(run_metrics "$R3" "EPIC-903" "$TMP/none.db" "$TMP/empty.jsonl")"
RC3=$?
if [ "$RC3" -ne 1 ]; then
  C3_OK=0; C3_WHY="exit=$RC3 (期望 1)"
fi
if [ "$C3_OK" -eq 1 ]; then
  AB="$(printf '%s' "$OUT3" | jq -c '.metrics[] | select(.metric=="ab_hit_rate")')"
  AB_ST="$(printf '%s' "$AB" | jq -r '.status')"
  AB_TOT="$(printf '%s' "$AB" | jq -r '.total_reviews')"
  AB_MM="$(printf '%s' "$AB" | jq -r '.mismatches')"
  AB_PCT="$(printf '%s' "$AB" | jq -r '.mismatch_pct')"
  # 5 个 review 里 3 个错配 → 60%
  if [ "$AB_ST" != "FAIL" ] || [ "$AB_TOT" != "5" ] || [ "$AB_MM" != "3" ] || [ "$AB_PCT" != "60" ]; then
    C3_OK=0
    C3_WHY="ab_hit_rate status=$AB_ST total=$AB_TOT mismatches=$AB_MM pct=$AB_PCT (期望 FAIL/5/3/60)"
  fi
fi
if [ "$C3_OK" -eq 1 ]; then
  ok "exit 1 有 FAIL, ab_hit_rate 3/5 错配 = 60% (真数字, 非 NO_DATA)"
else
  bad "exit 1: $C3_WHY"
fi

# ------------------------------------------------------------------
# Case 4: exit 0 — 0 FAIL, 且 expert_activation_rate + ab_hit_rate 都是真数据
#   做法:
#     - invocation JSONL 放 5 个 distinct expert 的记录 → activation 达标 (5 >= target 5)
#     - review 推荐跟 final 相符 → ab_hit_rate 0% mismatch, 达标
#     - file_scope 全部跟别的 EPIC 重叠 → cross_epic_reuse 满额, 达标
#     - performer 全填 + 单一 specialization → mis_dispatch 0%, 达标
# ------------------------------------------------------------------
section "Case 4: exit 0 (4 指标真数据 + 0 FAIL)"
C4_OK=1; C4_WHY=""
R4="$TMP/case4"
make_fixture_repo "$R4"

# 目标 EPIC 的 2 个 ticket, file_scope 只用 scripts/*.sh (单一 specialization)
write_ticket "$R4" "EPIC-904-A" "done" "performer-904-A" "APPROVE" "APPROVE" "MERGED" \
  "scripts/shared1.sh" "scripts/shared2.sh"
write_ticket "$R4" "EPIC-904-B" "done" "performer-904-B" "REJECT" "REJECT" "REJECTED" \
  "scripts/shared1.sh" "scripts/shared2.sh"
# 另一个 EPIC 覆盖同样的文件 → cross_epic_reuse 满额
write_ticket "$R4" "EPIC-905-A" "done" "performer-905-A" "APPROVE" "APPROVE" "MERGED" \
  "scripts/shared1.sh" "scripts/shared2.sh"

# 5 个 distinct expert 的 invocation (backend=file 才会被 JSONL 分支采纳)
INV4="$TMP/case4-invocations.jsonl"
: > "$INV4"
for i in 1 2 3 4 5; do
  jq -nc --arg e "kallax.role.00${i}" --arg t "EPIC-904-A" \
    '{expert_id:$e, ticket_id:$t, ts:1755000000, backend:"file"}' >> "$INV4"
done

OUT4="$(run_metrics "$R4" "EPIC-904" "$TMP/none.db" "$INV4")"
RC4=$?
if [ "$RC4" -ne 0 ]; then
  C4_OK=0
  C4_WHY="exit=$RC4 (期望 0); 非 PASS 指标: $(printf '%s' "$OUT4" | jq -c '[.metrics[]|select(.status!="PASS")|{metric,status}]')"
fi

if [ "$C4_OK" -eq 1 ]; then
  EA="$(printf '%s' "$OUT4" | jq -c '.metrics[] | select(.metric=="expert_activation_rate")')"
  EA_ST="$(printf '%s' "$EA" | jq -r '.status')"
  EA_N="$(printf '%s' "$EA" | jq -r '.distinct_count')"
  if [ "$EA_ST" != "PASS" ] || [ "$EA_N" != "5" ]; then
    C4_OK=0; C4_WHY="expert_activation status=$EA_ST distinct=$EA_N (期望 PASS/5)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  AB="$(printf '%s' "$OUT4" | jq -c '.metrics[] | select(.metric=="ab_hit_rate")')"
  AB_ST="$(printf '%s' "$AB" | jq -r '.status')"
  AB_TOT="$(printf '%s' "$AB" | jq -r '.total_reviews')"
  AB_HITS="$(printf '%s' "$AB" | jq -r '.hits')"
  if [ "$AB_ST" != "PASS" ] || [ "$AB_TOT" != "2" ] || [ "$AB_HITS" != "2" ]; then
    C4_OK=0; C4_WHY="ab_hit_rate status=$AB_ST total=$AB_TOT hits=$AB_HITS (期望 PASS/2/2)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  CR="$(printf '%s' "$OUT4" | jq -c '.metrics[] | select(.metric=="cross_epic_reuse_rate")')"
  CR_ST="$(printf '%s' "$CR" | jq -r '.status')"
  CR_PCT="$(printf '%s' "$CR" | jq -r '.reuse_pct')"
  if [ "$CR_ST" != "PASS" ] || [ "$CR_PCT" != "100" ]; then
    C4_OK=0; C4_WHY="cross_epic_reuse status=$CR_ST pct=$CR_PCT (期望 PASS/100)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  MD="$(printf '%s' "$OUT4" | jq -c '.metrics[] | select(.metric=="mis_dispatch_rate")')"
  MD_ST="$(printf '%s' "$MD" | jq -r '.status')"
  MD_TOT="$(printf '%s' "$MD" | jq -r '.total')"
  MD_PCT="$(printf '%s' "$MD" | jq -r '.mis_pct')"
  if [ "$MD_ST" != "PASS" ] || [ "$MD_TOT" != "2" ] || [ "$MD_PCT" != "0" ]; then
    C4_OK=0; C4_WHY="mis_dispatch status=$MD_ST total=$MD_TOT pct=$MD_PCT (期望 PASS/2/0)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  ok "exit 0: activation 5 distinct, ab_hit 2 hits / 2 reviews, reuse 满额, mis_dispatch 0 / 2 — 全真数据"
else
  bad "exit 0: $C4_WHY"
fi

# ------------------------------------------------------------------
printf '\n=== Summary ===\n'
printf 'sprint-metrics-real-data.test.sh: %d/%d PASS\n' "$PASS" "$TOTAL"
printf 'exit codes hit: 3=%s 2=%s 1=%s 0=%s\n' "$RC1" "$RC2" "$RC3" "$RC4"

if [ "$PASS" -ne "$TOTAL" ]; then
  printf '\n--- metrics stderr (last 30 lines) ---\n'
  tail -30 "$TMP/metrics.log" 2>/dev/null || true
  exit 1
fi
exit 0
