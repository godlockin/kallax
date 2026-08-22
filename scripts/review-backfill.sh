#!/usr/bin/env bash
# scripts/review-backfill.sh — EPIC-277-F AC3
#
# 目的: 回填历史 ticket.json 的 review.group_a / review.group_b / review.final_outcome,
#   让 Rule 36 指标 #3 (ab_hit_rate) 有数据源.
#
# 为什么需要回填 (背景):
#   scripts/metrics/lib/metrics.sh compute_ab_hit_rate 读的是
#   .review.group_a.recommendation / .review.group_b.recommendation / .review.final_outcome.
#   实测 212 个 ticket.json 里只有 12 个有 review 字段, 且那 12 个是旧 schema
#   ({reviewer, decision, merged_to}) — 没有 group_a/group_b/final_outcome.
#   结果 ab_hit_rate 在所有 EPIC 上恒 NO_DATA.
#
# 回填启发式 (数据来源 = git 历史 + ticket.status, 不编造):
#   1. final_outcome (优先级从上到下):
#        - git log 有 "revert <ticket_id>" commit          → REVERTED
#        - ticket.status ∈ {done, merged, closed, passed}  → MERGED
#        - ticket.status ∈ {rejected, abandoned}           → REJECTED
#        - ticket.status ∈ {blocked}                       → NEEDS_FIX
#        - git log 有该 ticket 的 commit 且在 miao 祖先中   → MERGED
#        - 其余 (backlog / in_progress / 无 commit)         → IN_PROGRESS
#   2. group_a / group_b recommendation (1-PR-1-final-outcome 启发式):
#        历史 4-branch flow 里 A+B 2-Group review 的结论没有独立存档,
#        只有跟 final 不相符时才在 git 留痕 (revert commit).
#        - final=MERGED   → A=APPROVE, B=APPROVE  (放行且合了 = hit)
#        - final=REVERTED → A=APPROVE, B=APPROVE  (放行但回滚 = 错配信号)
#        - final=REJECTED → A=REJECT,  B=REJECT   (拒且没合 = hit)
#        - final ∈ {NEEDS_FIX, IN_PROGRESS} → 不回填 (留 NO_DATA 比编造好)
#
#   注: 回填值是 git 历史的机械推断, 不是真实 review 记录. review.backfill.inferred=true
#   标记这一点, 让读数据的人知道口径. 新 ticket 应由 review 流程直接写真值.
#
# Usage:
#   bash scripts/review-backfill.sh --dry-run          # 只打印计划, 0 写入
#   bash scripts/review-backfill.sh                    # 实跑 (写 ticket.json + jsonl 备份)
#   bash scripts/review-backfill.sh --epic EPIC-277    # 只处理单个 EPIC
#   bash scripts/review-backfill.sh --force            # 覆盖已有 review 字段
#   bash scripts/review-backfill.sh --backup-file P    # 指定备份 jsonl 路径
#
# Exit codes:
#   0 = OK (dry-run 或 实跑成功)
#   1 = FAIL (依赖缺失 / 写入失败 / 覆盖率不足阈值)
#   2 = NO_DATA (0 个 ticket.json 可处理)
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
TICKETS_DIR="${REPO_ROOT}/jira/tickets"
DEFAULT_BACKUP="${TICKETS_DIR}/review-backfill-$(date -u +%Y-%m-%d).jsonl"

DRY_RUN=0
FORCE=0
ONLY_EPIC=""
BACKUP_FILE="$DEFAULT_BACKUP"
MIN_COVERAGE_PCT=95

usage() {
  cat <<'EOF'
review-backfill.sh — 回填历史 ticket review 字段 (EPIC-277-F AC3)

USAGE:
  bash scripts/review-backfill.sh [--dry-run] [--epic EPIC-XXX] [--force]
                                  [--backup-file PATH] [--min-coverage PCT]

OPTIONS:
  --dry-run              只打印计划, 0 写入
  --epic EPIC-XXX        只处理指定 EPIC
  --force                覆盖已有 review.group_a / group_b / final_outcome
  --backup-file PATH     备份 jsonl 路径 (默认 jira/tickets/review-backfill-<date>.jsonl)
  --min-coverage PCT     实跑后要求的最低写入覆盖率 (默认 95), 不达标 exit 1
  -h, --help             本帮助

EXIT CODES:
  0  OK
  1  FAIL (依赖缺失 / 写入失败 / 覆盖率 < min-coverage)
  2  NO_DATA (0 个 ticket.json)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --epic) ONLY_EPIC="${2:-}"; shift 2 ;;
    --epic=*) ONLY_EPIC="${1#*=}"; shift ;;
    --backup-file) BACKUP_FILE="${2:-}"; shift 2 ;;
    --backup-file=*) BACKUP_FILE="${1#*=}"; shift ;;
    --min-coverage) MIN_COVERAGE_PCT="${2:-}"; shift 2 ;;
    --min-coverage=*) MIN_COVERAGE_PCT="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for cmd in jq git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: required command not found: $cmd" >&2
    exit 1
  fi
done

if ! [[ "$MIN_COVERAGE_PCT" =~ ^[0-9]+$ ]] || [ "$MIN_COVERAGE_PCT" -gt 100 ]; then
  echo "FAIL: --min-coverage must be an integer 0..100 (got: $MIN_COVERAGE_PCT)" >&2
  exit 1
fi

if [ ! -d "$TICKETS_DIR" ]; then
  echo "FAIL: tickets dir not found: $TICKETS_DIR" >&2
  exit 1
fi

log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }

# ─── final_outcome 推断 ─────────────────────────────────────────────────────
# 输入: ticket_id, ticket.json path
# 输出: "<OUTCOME> <SOURCE>" (SOURCE 说明推断依据, 进 review.backfill.source)
infer_final_outcome() {
  local ticket_id="$1" tj="$2"

  # revert 痕迹优先: A+B 曾放行但事后被 revert → final=REVERTED.
  # 这正是 ab_hit_rate 要抓的错配信号 (review 放行 vs 实际回滚).
  local reverted
  reverted="$(git -C "$REPO_ROOT" log --format='%H' --grep="[Rr]evert.*${ticket_id}" 2>/dev/null | head -1 || true)"
  if [ -n "$reverted" ]; then
    echo "REVERTED git_revert:${reverted:0:8}"
    return 0
  fi

  local status
  status="$(jq -r '.status // empty' "$tj" 2>/dev/null || true)"

  case "$status" in
    done|merged|closed|passed)
      echo "MERGED ticket_status:${status}"
      return 0
      ;;
    rejected|abandoned)
      echo "REJECTED ticket_status:${status}"
      return 0
      ;;
    blocked)
      echo "NEEDS_FIX ticket_status:${status}"
      return 0
      ;;
  esac

  # status 不确定 → 看 git 历史里该 ticket 是否有已合并 commit
  local commit
  commit="$(git -C "$REPO_ROOT" log --format='%H' -1 --grep="${ticket_id}" 2>/dev/null || true)"
  if [ -n "$commit" ]; then
    # commit 在 miao (或当前 HEAD) 祖先中 → 已合并
    local base="miao"
    git -C "$REPO_ROOT" rev-parse --verify --quiet "$base" >/dev/null 2>&1 || base="HEAD"
    if git -C "$REPO_ROOT" merge-base --is-ancestor "$commit" "$base" 2>/dev/null; then
      echo "MERGED git_ancestor:${commit:0:8}"
      return 0
    fi
    echo "IN_PROGRESS git_commit_unmerged:${commit:0:8}"
    return 0
  fi

  echo "IN_PROGRESS no_commit_status:${status:-unset}"
  return 0
}

# ─── group_a / group_b 推断 (1-PR-1-final-outcome 启发式) ───────────────────
# 输出: "<A_REC> <B_REC>" 或 "SKIP SKIP" (无从推断)
#
# 口径 (跟 metrics.sh compute_ab_hit_rate 判定表对齐):
#   MERGED   → A=APPROVE B=APPROVE  → hit   (review 放行, 确实合了)
#   REVERTED → A=APPROVE B=APPROVE  → 错配  (review 放行, 事后回滚 — 真错配信号)
#   REJECTED → A=REJECT  B=REJECT   → hit   (review 拒, 确实没合)
#   其余     → SKIP (NEEDS_FIX / IN_PROGRESS 无从推断, 留 NO_DATA 不编造)
infer_group_recs() {
  local final="$1"

  case "$final" in
    MERGED|REVERTED) echo "APPROVE APPROVE" ;;
    REJECTED)        echo "REJECT REJECT" ;;
    *)               echo "SKIP SKIP" ;;
  esac
}

# ─── 主循环 ─────────────────────────────────────────────────────────────────
PLANNED=0
WRITTEN=0
SKIPPED_EXISTING=0
SKIPPED_UNINFERABLE=0
SKIPPED_INVALID_JSON=0

TMP_BACKUP=""
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$(dirname "$BACKUP_FILE")"
  TMP_BACKUP="$(mktemp -t review-backfill.XXXXXX)"
  trap 'rm -f "$TMP_BACKUP"' EXIT
fi

echo "review-backfill — mode=$([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo apply) force=${FORCE} epic=${ONLY_EPIC:-ALL}"
echo "tickets_dir=${TICKETS_DIR}"
echo ""

for ticket_dir in "${TICKETS_DIR}"/EPIC-*/; do
  [ -d "$ticket_dir" ] || continue
  ticket_id="$(basename "$ticket_dir")"
  tj="${ticket_dir}ticket.json"
  [ -f "$tj" ] || continue

  if [ -n "$ONLY_EPIC" ]; then
    case "$ticket_id" in
      "$ONLY_EPIC"|"${ONLY_EPIC}-"*) ;;
      *) continue ;;
    esac
  fi

  PLANNED=$((PLANNED + 1))

  # 语法坏掉的 ticket.json 跳过 — 不在回填脚本里顺手"修" JSON.
  # 实测 jira/tickets/EPIC-150-D/ticket.json 在 HEAD 里就是坏的 (第 31 行
  # 多一层 `}` 提前闭合, 后面字段悬空). 那是独立的数据缺陷, 归它自己的卡,
  # 混进本卡会让 diff 语义不清 + 无法审计回填口径.
  if ! jq -e . "$tj" >/dev/null 2>&1; then
    SKIPPED_INVALID_JSON=$((SKIPPED_INVALID_JSON + 1))
    echo "BADJSON  ${ticket_id} (ticket.json 语法错, 跳过 — 需独立修)"
    continue
  fi

  # 已有完整 review 三字段 → 跳过 (除 --force)
  has_full="$(jq -r '
    if (.review.group_a.recommendation? // "") != ""
       and (.review.group_b.recommendation? // "") != ""
       and (.review.final_outcome? // "") != ""
    then "yes" else "no" end' "$tj" 2>/dev/null || echo no)"
  if [ "$has_full" = "yes" ] && [ "$FORCE" -eq 0 ]; then
    SKIPPED_EXISTING=$((SKIPPED_EXISTING + 1))
    echo "SKIP     ${ticket_id} (review 已完整)"
    continue
  fi

  read -r final final_source <<<"$(infer_final_outcome "$ticket_id" "$tj")"
  read -r a_rec b_rec <<<"$(infer_group_recs "$final")"

  if [ "$a_rec" = "SKIP" ]; then
    SKIPPED_UNINFERABLE=$((SKIPPED_UNINFERABLE + 1))
    echo "NOINFER  ${ticket_id} final=${final} (group_a/b 无从推断, 不编造)"
    continue
  fi

  echo "PLAN     ${ticket_id} final=${final} a=${a_rec} b=${b_rec} src=${final_source}"

  [ "$DRY_RUN" -eq 1 ] && continue

  # 备份原 review 字段 (含 null) 到 jsonl, 供回滚
  jq -c --arg tid "$ticket_id" --arg path "${tj#"$REPO_ROOT"/}" \
    '{ticket_id:$tid, path:$path, previous_review:(.review // null)}' "$tj" >> "$TMP_BACKUP"

  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp_tj="${tj}.tmp.$$"
  if ! jq \
      --arg a "$a_rec" --arg b "$b_rec" --arg f "$final" \
      --arg src "$final_source" --arg ts "$now_iso" \
      '.review = ((.review // {}) + {
         group_a: ((.review.group_a // {}) + {recommendation: $a}),
         group_b: ((.review.group_b // {}) + {recommendation: $b}),
         final_outcome: $f,
         backfill: {
           inferred: true,
           source: $src,
           heuristic: "1-PR-1-final-outcome (EPIC-277-F AC3)",
           backfilled_at: $ts
         }
       })' "$tj" > "$tmp_tj"; then
    echo "FAIL: jq update failed for $tj" >&2
    rm -f "$tmp_tj"
    exit 1
  fi
  if ! mv "$tmp_tj" "$tj"; then
    echo "FAIL: atomic move failed for $tj" >&2
    rm -f "$tmp_tj"
    exit 1
  fi
  WRITTEN=$((WRITTEN + 1))
done

echo ""
ELIGIBLE=$(( PLANNED - SKIPPED_EXISTING - SKIPPED_UNINFERABLE - SKIPPED_INVALID_JSON ))
echo "planned=${PLANNED} eligible=${ELIGIBLE} written=${WRITTEN} skipped_existing=${SKIPPED_EXISTING} skipped_uninferable=${SKIPPED_UNINFERABLE} skipped_invalid_json=${SKIPPED_INVALID_JSON}"

if [ "$PLANNED" -eq 0 ]; then
  log_warn "0 ticket.json matched — nothing to backfill"
  exit 2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run: 0 写入. 实跑去掉 --dry-run."
  exit 0
fi

# 备份文件落盘 (append 模式, 多次实跑不互相覆盖)
if [ -s "$TMP_BACKUP" ]; then
  cat "$TMP_BACKUP" >> "$BACKUP_FILE"
  log_info "backup appended: ${BACKUP_FILE} (+$(wc -l < "$TMP_BACKUP" | tr -d ' ') lines)"
else
  log_info "backup skipped (0 writes)"
fi

# 覆盖率门控: 可推断的 ticket 里实际写入比例
if [ "$ELIGIBLE" -gt 0 ]; then
  COVERAGE=$(( (WRITTEN * 100) / ELIGIBLE ))
else
  COVERAGE=100
fi
echo "coverage=${WRITTEN}/${ELIGIBLE} (${COVERAGE}%) min_required=${MIN_COVERAGE_PCT}%"

if [ "$COVERAGE" -lt "$MIN_COVERAGE_PCT" ]; then
  echo "FAIL: coverage ${COVERAGE}% < min ${MIN_COVERAGE_PCT}%" >&2
  exit 1
fi

echo "OK: review backfill done"
exit 0
