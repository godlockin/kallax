#!/usr/bin/env bash
# scripts/metrics/lib/metrics.sh
# EPIC-023-C 北极星指标 helper library
# Sourceable; provides 4 metric computation functions + JSON / Markdown formatters
#
# 设计原则 (跟 Performer Hard Rules 联合):
#   - No magic numbers: 所有阈值/路径都是命名常量
#   - No console.log: log_info/log_warn/log_error 输出 stderr (结构化 key=value)
#   - No copy-paste: 4 metric 函数共享 load_invocations + safe_jq_query
#   - bash 5.x 兼容: 不用 [[:space:]], 用 portable [ \t\n]
#   - Defensive defaults: 数据缺失 → 返回 status=NO_DATA, 不崩

set -euo pipefail

# ─── 常量 (no magic numbers) ────────────────────────────────────────────────

# 路径
export METRICS_LIB_DIR
METRICS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export METRICS_SCRIPT_DIR
METRICS_SCRIPT_DIR="$(cd "${METRICS_LIB_DIR}/.." && pwd)"
export KALLAX_ROOT_DEFAULT
KALLAX_ROOT_DEFAULT="$(cd "${METRICS_SCRIPT_DIR}/../.." && pwd)"

# expert_invocations 队列 (复用 EPIC-021-F 基础设施, Redis→SQLite→file)
export INVOCATION_FILE_DEFAULT="${HOME}/.kallax/queue/expert_invocations.jsonl"
export INVOCATION_DB_DEFAULT="${HOME}/.kallax/state/expert_invocations.db"

# JIRA ticket 数据源
export JIRA_TICKETS_DIR_DEFAULT="jira/tickets"

# 4 北极星指标 阈值 (目标值)
export EXPERT_ACTIVATION_TARGET_DISTINCT=5      # ≥5 distinct experts / EPIC
export CROSS_EPIC_REUSE_TARGET_PCT=40          # ≥40% 跨 EPIC 复用率 (EPIC-277-H 主公拍板 60→40, 基础设施型 EPIC 复用率天然低)
export CROSS_EPIC_DOCS_REUSE_TARGET_PCT=40     # ≥40% 跨 EPIC docs 复用率 (EPIC-253, docs 天然比 code 分散)
export AB_HIT_RATE_TARGET_MISMATCH_PCT=15      # <15% 错配 (推荐 vs 实际)
export MIS_DISPATCH_TARGET_PCT=10              # <10% 错派率
export ABANDONMENT_THRESHOLD_HOURS=48         # assigned >48h 无 PR = abandoned
export ABANDONMENT_TARGET_PCT=10             # <10% abandonment rate

# 输入校验
export EPIC_ID_PATTERN='^EPIC-[0-9]+$'
export TICKET_ID_PATTERN='^EPIC-[0-9]+-[A-Z]+$'
export EXPERT_ID_PATTERN='^kallax\.[a-z]+\.[0-9]{3}$'

# file_scope specialization 推断 (按 path pattern → expected role)
# 注: 顺序敏感, 先匹配先返回
readonly -a SPECIALIZATION_PATTERNS=(
  "frontend|src/components/|src/styles/|\.tsx$|\.css$|\.scss$|\.jsx$"
  "backend|src/api/|src/db/|\.go$|\.rs$|server\.ts$|\.sql$"
  "infra|docker/|k8s/|\.yml$|\.yaml$|terraform/"
  "test|tests/|test/|__tests__/|\.test\.|\.spec\."
  "docs|docs/|\.md$|README"
)

# ─── Structured logger (替代 console.log, Performer Hard Rule 5) ─────────────

log_info() {
  local event="$1"
  shift
  local ctx="$*"
  printf '[INFO]  event=%s %s\n' "$event" "$ctx" >&2
}

log_warn() {
  local event="$1"
  shift
  local ctx="$*"
  printf '[WARN]  event=%s %s\n' "$event" "$ctx" >&2
}

log_error() {
  local event="$1"
  shift
  local ctx="$*"
  printf '[ERROR] event=%s %s\n' "$event" "$ctx" >&2
}

# ─── 路径解析 ────────────────────────────────────────────────────────────────

resolve_paths() {
  # 优先 git root; 否则 fallback 到脚本默认
  local script_root="${KALLAX_ROOT_DEFAULT}"
  if command -v git >/dev/null 2>&1; then
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ]; then
      script_root="$git_root"
    fi
  fi
  WORKTREE_ROOT="$script_root"
  JIRA_TICKETS_DIR="${script_root}/${JIRA_TICKETS_DIR_DEFAULT}"
  INVOCATION_FILE="${INVOCATION_FILE:-${INVOCATION_FILE_DEFAULT}}"
  INVOCATION_DB="${INVOCATION_DB:-${INVOCATION_DB_DEFAULT}}"
}

# ─── 校验 ────────────────────────────────────────────────────────────────────

validate_epic_id() {
  local epic_id="$1"
  if [ -z "$epic_id" ]; then
    log_error "validate_epic_id" "reason=empty_epic_id"
    return 1
  fi
  if ! [[ "$epic_id" =~ $EPIC_ID_PATTERN ]]; then
    log_error "validate_epic_id" "reason=bad_format epic_id=${epic_id} expected=${EPIC_ID_PATTERN}"
    return 1
  fi
  return 0
}

# ─── Expert invocations 读取 (复用 EPIC-021-F 队列, Redis→SQLite→file) ──────

# 读取指定 EPIC 下的所有 expert invocations
# 输出: 每行一个 invocation JSON object
#   - ticket_id 匹配 EPIC-{N}-* (regex ^EPIC-{N}-[A-Z]+$)
# 来源优先级: SQLite (落盘完整) > JSONL (兜底)
load_invocations_for_epic() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local epic_num="${epic_id#EPIC-}"
  # Pattern: EPIC-NUM 本身, 或 EPIC-NUM-<UPPER> 带后缀 (test data 可能加, e.g. EPIC-021-F-test1)
  #
  # EPIC-268 修 bug: 原 pattern 是 ^EPIC-${epic_num}-[A-Z], 只认带大写后缀的 ID.
  #   实测新卡 (251+) 一律无后缀 (EPIC-259 / EPIC-262 ...), 52 个全部匹配不上 →
  #   expert_activation_rate 恒 NO_DATA. 历史卡带后缀 (EPIC-015-D, 151 个) 才匹配.
  #   加 (-[A-Z]|$) 兼容两种. 仍排除 EPIC-merge 这种 lowercase 后缀.
  local ticket_pattern="^EPIC-${epic_num}(-[A-Z]|$)"
  local total=0
  local matched=0

  # Source 1: SQLite (主, 历史完整)
  if [ -f "$INVOCATION_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    local sqlite_rows
    sqlite_rows="$(sqlite3 "$INVOCATION_DB" "SELECT payload FROM invocations" 2>/dev/null || true)"
    if [ -n "$sqlite_rows" ]; then
      while IFS= read -r row; do
        [ -z "$row" ] && continue
        total=$((total + 1))
        local tid
        tid="$(printf '%s' "$row" | jq -r '.ticket_id // empty' 2>/dev/null || true)"
        if [ -n "$tid" ] && [[ "$tid" =~ $ticket_pattern ]]; then
          printf '%s\n' "$row"
          matched=$((matched + 1))
        fi
      done <<< "$sqlite_rows"
    fi
  fi

  # Source 2: JSONL (兜底, 部分 backend 可能未刷盘)
  if [ -f "$INVOCATION_FILE" ]; then
    while IFS= read -r row; do
      [ -z "$row" ] && continue
      total=$((total + 1))   # EPIC-268: 原先只在 SQLite 分支累加, src_state 判断会误报 source_empty
      # 去重: SQLite 已记录的跳过 (避免重复)
      local tid ts backend
      tid="$(printf '%s' "$row" | jq -r '.ticket_id // empty' 2>/dev/null || true)"
      ts="$(printf '%s' "$row" | jq -r '.ts // empty' 2>/dev/null || true)"
      backend="$(printf '%s' "$row" | jq -r '.backend // "file"' 2>/dev/null || true)"
      [ -z "$tid" ] && continue
      if [[ "$tid" =~ $ticket_pattern ]]; then
        # 仅当 backend=file 时追加 (sqlite/redis 通常已落 sqlite)
        if [ "$backend" = "file" ]; then
          printf '%s\n' "$row"
          matched=$((matched + 1))
        fi
      fi
    done < "$INVOCATION_FILE"
  fi

  # EPIC-268: 区分 3 种 0 结果, 让 NO_DATA 的真实原因可见.
  #   原先只 log matched=0, 看不出是"数据源不存在" / "数据源空" / "有数据但不匹配".
  #   实测本仓 ~/.kallax/state/expert_invocations.db 只有 8 行 test fixture
  #   (ticket_id=EPIC-021-F-test1 之类), 最后写入 2026-06-07 — expert 调用路径
  #   从没埋点. 接数据源在 EPIC-269.
  local src_state="unknown"
  if [ ! -f "$INVOCATION_DB" ] && [ ! -f "$INVOCATION_FILE" ]; then
    src_state="no_source"
  elif [ "$total" -eq 0 ]; then
    src_state="source_empty"
  elif [ "$matched" -eq 0 ]; then
    src_state="no_match_for_epic"
  else
    src_state="ok"
  fi

  log_info "load_invocations_for_epic" \
    "epic=${epic_id} matched=${matched} scanned=${total} src_state=${src_state} db=${INVOCATION_DB} jsonl=${INVOCATION_FILE}"
  return 0
}

# ─── Metric 1: expert_activation_rate ───────────────────────────────────────

# 5 expert 在 EPIC 内的激活频次
# 输出: JSON object {distinct_count, target, status, breakdown: {expert_id: count}}
compute_expert_activation_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local invocations
  invocations="$(load_invocations_for_epic "$epic_id")"

  if [ -z "$invocations" ]; then
    log_warn "expert_activation_rate" "epic=${epic_id} reason=no_invocations"
    jq -n \
      --argjson target "$EXPERT_ACTIVATION_TARGET_DISTINCT" \
      '{metric:"expert_activation_rate", epic:$epic, distinct_count:0, target:$target, status:"NO_DATA", breakdown:{}, note:"no expert invocations found for this EPIC"}' \
      --arg epic "$epic_id"
    return 0
  fi

  # 统计每个 expert_id 的激活频次 + distinct count
  local breakdown_json
  breakdown_json="$(printf '%s\n' "$invocations" \
    | jq -s 'group_by(.expert_id) | map({(.[0].expert_id): length}) | add // {}')"

  local distinct_count
  distinct_count="$(printf '%s' "$breakdown_json" | jq 'length')"

  local status="FAIL"
  if [ "$distinct_count" -ge "$EXPERT_ACTIVATION_TARGET_DISTINCT" ]; then
    status="PASS"
  fi

  jq -n \
    --arg epic "$epic_id" \
    --argjson distinct "$distinct_count" \
    --argjson target "$EXPERT_ACTIVATION_TARGET_DISTINCT" \
    --argjson breakdown "$breakdown_json" \
    --arg status "$status" \
    '{metric:"expert_activation_rate", epic:$epic, distinct_count:$distinct, target:$target, status:$status, breakdown:$breakdown}'

  return 0
}

# ─── Metric 2: cross_epic_reuse_rate ─────────────────────────────────────────

# 跨 EPIC 复用率: 目标 EPIC 的 file_scope 中, 已被其他 EPIC 覆盖的文件占比
# 输出: JSON object {reuse_pct, target, status, overlap_count, total_files, ...}
compute_cross_epic_reuse_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  if [ ! -d "$JIRA_TICKETS_DIR" ]; then
    log_warn "cross_epic_reuse_rate" "epic=${epic_id} reason=tickets_dir_missing path=${JIRA_TICKETS_DIR}"
    jq -n \
      --argjson target "$CROSS_EPIC_REUSE_TARGET_PCT" \
      '{metric:"cross_epic_reuse_rate", epic:$epic, reuse_pct:0, target:$target, status:"NO_DATA", overlap_count:0, total_files:0, note:"jira/tickets directory not found"}' \
      --arg epic "$epic_id"
    return 0
  fi

  local epic_num="${epic_id#EPIC-}"

  # 收集目标 EPIC 的所有 file_scope 路径 (unique)
  local target_files_json
  target_files_json="$(collect_filescope_for_epic "$epic_num")"

  local total_files
  total_files="$(printf '%s' "$target_files_json" | jq 'length')"

  if [ "$total_files" -eq 0 ]; then
    log_warn "cross_epic_reuse_rate" "epic=${epic_id} reason=no_files_in_scope"
    jq -n \
      --argjson target "$CROSS_EPIC_REUSE_TARGET_PCT" \
      '{metric:"cross_epic_reuse_rate", epic:$epic, reuse_pct:0, target:$target, status:"NO_DATA", overlap_count:0, total_files:0}' \
      --arg epic "$epic_id"
    return 0
  fi

  # 收集所有其他 EPIC 的 file_scope 路径 (除目标 EPIC 外)
  local other_files_json
  other_files_json="$(collect_filescope_all_except "$epic_num")"

  # 计算 overlap (strict equality: target path 出现在 other_paths 中)
  # 注: 用 strict equality 而非 startswith — file_scope 是 glob pattern, 复用判定以字面匹配为准
  local overlap_count
  overlap_count="$(jq -n \
    --argjson target "$target_files_json" \
    --argjson other "$other_files_json" \
    '($other | unique) as $u | $target | map(select(. as $t | any($u[]; . == $t))) | length')"

  local reuse_pct=0
  if [ "$total_files" -gt 0 ]; then
    reuse_pct=$(( (overlap_count * 100) / total_files ))
  fi

  local status="FAIL"
  if [ "$reuse_pct" -ge "$CROSS_EPIC_REUSE_TARGET_PCT" ]; then
    status="PASS"
  fi

  jq -n \
    --arg epic "$epic_id" \
    --argjson reuse "$reuse_pct" \
    --argjson target "$CROSS_EPIC_REUSE_TARGET_PCT" \
    --argjson overlap "$overlap_count" \
    --argjson total "$total_files" \
    --arg status "$status" \
    '{metric:"cross_epic_reuse_rate", epic:$epic, reuse_pct:$reuse, target:$target, status:$status, overlap_count:$overlap, total_files:$total}'

  return 0
}

# ─── Metric 2b: cross_epic_docs_reuse_rate (EPIC-253) ───────────────────────

# docs 文件模式 (CLAUDE.md / .claude/rules / confluence / docs / *.md / tests/integration/*.sh)
# 顺序敏感: 先匹配先归类
export DOCS_PATH_PATTERN='^(CLAUDE\.md|README|CHANGELOG\.md|\.claude/rules/|confluence/|docs/|jira/tickets/|tests/integration/.*\.sh$)|\.md$'

# 跨 EPIC docs 复用率 (EPIC-253): 只看 docs 类文件.
# 起因: metric 2 (cross_epic_reuse_rate) 对 docs-only EPIC 常年 0% / NO_DATA,
#       因 docs-only EPIC 的 file_scope 多为一次性路径 (jira/tickets/EPIC-XXX/).
#       本 metric 单独统计 docs 路径, 目标放宽到 40% (docs 天然比 code 分散).
# 数据源: jira/tickets/EPIC-*/ticket.json file_scope.includes, 过滤 DOCS_PATH_PATTERN.
# 输出: JSON object {docs_reuse_pct, target, status, overlap_count, total_docs_files}
compute_cross_epic_docs_reuse_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  if [ ! -d "$JIRA_TICKETS_DIR" ]; then
    log_warn "cross_epic_docs_reuse_rate" "epic=${epic_id} reason=tickets_dir_missing"
    jq -n \
      --arg epic "$epic_id" \
      --argjson target "$CROSS_EPIC_DOCS_REUSE_TARGET_PCT" \
      '{metric:"cross_epic_docs_reuse_rate", epic:$epic, docs_reuse_pct:0, target:$target, status:"NO_DATA", overlap_count:0, total_docs_files:0, note:"jira/tickets directory not found"}'
    return 0
  fi

  local epic_num="${epic_id#EPIC-}"

  # 目标 EPIC 的 docs 文件 (过滤 DOCS_PATH_PATTERN)
  local target_docs_json
  target_docs_json="$(collect_filescope_for_epic "$epic_num" \
    | jq --arg pat "$DOCS_PATH_PATTERN" '[.[] | select(test($pat))]')"

  local total_docs
  total_docs="$(printf '%s' "$target_docs_json" | jq 'length')"

  if [ "$total_docs" -eq 0 ]; then
    log_warn "cross_epic_docs_reuse_rate" "epic=${epic_id} reason=no_docs_in_scope"
    jq -n \
      --arg epic "$epic_id" \
      --argjson target "$CROSS_EPIC_DOCS_REUSE_TARGET_PCT" \
      '{metric:"cross_epic_docs_reuse_rate", epic:$epic, docs_reuse_pct:0, target:$target, status:"NO_DATA", overlap_count:0, total_docs_files:0}'
    return 0
  fi

  # 其他 EPIC 的 docs 文件
  local other_docs_json
  other_docs_json="$(collect_filescope_all_except "$epic_num" \
    | jq --arg pat "$DOCS_PATH_PATTERN" '[.[] | select(test($pat))]')"

  # overlap: strict equality (同 metric 2 判定口径)
  local overlap_count
  overlap_count="$(jq -n \
    --argjson target "$target_docs_json" \
    --argjson other "$other_docs_json" \
    '($other | unique) as $u | $target | map(select(. as $t | any($u[]; . == $t))) | length')"

  local docs_reuse_pct=0
  if [ "$total_docs" -gt 0 ]; then
    docs_reuse_pct=$(( (overlap_count * 100) / total_docs ))
  fi

  local status="FAIL"
  if [ "$docs_reuse_pct" -ge "$CROSS_EPIC_DOCS_REUSE_TARGET_PCT" ]; then
    status="PASS"
  fi

  jq -n \
    --arg epic "$epic_id" \
    --argjson reuse "$docs_reuse_pct" \
    --argjson target "$CROSS_EPIC_DOCS_REUSE_TARGET_PCT" \
    --argjson overlap "$overlap_count" \
    --argjson total "$total_docs" \
    --arg status "$status" \
    '{metric:"cross_epic_docs_reuse_rate", epic:$epic, docs_reuse_pct:$reuse, target:$target, status:$status, overlap_count:$overlap, total_docs_files:$total}'

  return 0
}

# collect_filescope_for_epic <epic_num>: 输出 JSON array of file paths
# EPIC-253 修 bug: 原实现只扫 EPIC-XXX-*/ (sub-ticket), 漏 root ticket EPIC-XXX/.
# 同 compute_mis_dispatch_binding_rate 的 root+sub 双路径模式.
collect_filescope_for_epic() {
  local epic_num="$1"
  local tmp
  tmp="$(mktemp -t filescope.XXXXXX)"
  trap "rm -f '$tmp'" RETURN

  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}" "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
    [ -d "$ticket_dir" ] || continue
    local tj="${ticket_dir%/}/ticket.json"
    [ -f "$tj" ] || continue
    jq -r '.file_scope.includes[]? // empty' "$tj" 2>/dev/null >> "$tmp" || true
  done

  # 去重 + 输出 JSON array
  if [ -s "$tmp" ]; then
    sort -u "$tmp" | jq -R . | jq -s 'map(select(. != ""))'
  else
    echo '[]'
  fi
}

# collect_filescope_all_except <epic_num>: 所有其他 EPIC 的 file_scope paths
# EPIC-253 修 bug: 排除判断加 root ticket 形态 (EPIC-XXX 精确匹配).
collect_filescope_all_except() {
  local epic_num="$1"
  local tmp
  tmp="$(mktemp -t filescope_all.XXXXXX)"
  trap "rm -f '$tmp'" RETURN

  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-"*/; do
    [ -d "$ticket_dir" ] || continue
    # 提取 basename 用于 EPIC 排除判断 (root: EPIC-XXX, sub: EPIC-XXX-A)
    local base
    base="$(basename "$ticket_dir")"
    case "$base" in
      "EPIC-${epic_num}"|"EPIC-${epic_num}-"*) continue ;;
    esac
    local tj="${ticket_dir}ticket.json"
    [ -f "$tj" ] || continue
    jq -r '.file_scope.includes[]? // empty' "$tj" 2>/dev/null >> "$tmp" || true
  done

  if [ -s "$tmp" ]; then
    sort -u "$tmp" | jq -R . | jq -s 'map(select(. != ""))'
  else
    echo '[]'
  fi
}

# ─── Metric 3: ab_hit_rate ──────────────────────────────────────────────────

# 2-Group review 推荐 vs 实际命中率
# 数据源: jira/tickets/EPIC-XXX-*/ticket.json `review` 字段 (A+B 推荐 + final_outcome)
# 输出: JSON object {mismatch_pct, target, status, total_reviews, mismatches}
compute_ab_hit_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local epic_num="${epic_id#EPIC-}"
  local total=0
  local mismatches=0
  local hit=0
  local no_data=0

  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
    [ -d "$ticket_dir" ] || continue
    local tj="${ticket_dir}ticket.json"
    [ -f "$tj" ] || continue

    # 提取 review 字段 (A+B 推荐 + final)
    local a_rec b_rec final
    a_rec="$(jq -r '.review.group_a.recommendation // empty' "$tj" 2>/dev/null || true)"
    b_rec="$(jq -r '.review.group_b.recommendation // empty' "$tj" 2>/dev/null || true)"
    final="$(jq -r '.review.final_outcome // empty' "$tj" 2>/dev/null || true)"

    if [ -z "$a_rec" ] || [ -z "$b_rec" ] || [ -z "$final" ]; then
      no_data=$((no_data + 1))
      continue
    fi

    total=$((total + 1))

    # 一致判定: A + B 都 APPROVE, final=MERGED → hit
    # 错配: A=APPROVE 但 final=REJECTED → mismatch (反之亦然)
    # NEEDS_FIX 视为部分 hit (后续 fix 后 merged 算 hit, fix 后 rejected 算 mismatch)
    local expected_match=1
    case "$final" in
      MERGED|APPROVED)
        [ "$a_rec" = "APPROVE" ] && [ "$b_rec" = "APPROVE" ] && expected_match=1 || expected_match=0
        ;;
      REJECTED|REVERTED)
        [ "$a_rec" = "REJECT" ] && [ "$b_rec" = "REJECT" ] && expected_match=1 || expected_match=0
        ;;
      *)
        # 其他 final (NEEDS_FIX, IN_PROGRESS) → 不计入错配
        total=$((total - 1))
        continue
        ;;
    esac

    if [ "$expected_match" -eq 1 ]; then
      hit=$((hit + 1))
    else
      mismatches=$((mismatches + 1))
    fi
  done

  if [ "$total" -eq 0 ]; then
    log_warn "ab_hit_rate" "epic=${epic_id} reason=no_review_data no_data_tickets=${no_data}"
    jq -n \
      --argjson target "$AB_HIT_RATE_TARGET_MISMATCH_PCT" \
      '{metric:"ab_hit_rate", epic:$epic, mismatch_pct:0, target:$target, status:"NO_DATA", total_reviews:0, mismatches:0, hits:0, no_data_tickets:$no_data}' \
      --arg epic "$epic_id" \
      --argjson no_data "$no_data"
    return 0
  fi

  local mismatch_pct=$(( (mismatches * 100) / total ))
  local status="FAIL"
  if [ "$mismatch_pct" -lt "$AB_HIT_RATE_TARGET_MISMATCH_PCT" ]; then
    status="PASS"
  fi

  jq -n \
    --arg epic "$epic_id" \
    --argjson mismatch "$mismatch_pct" \
    --argjson target "$AB_HIT_RATE_TARGET_MISMATCH_PCT" \
    --argjson total "$total" \
    --argjson hits "$hit" \
    --argjson mm "$mismatches" \
    --arg status "$status" \
    '{metric:"ab_hit_rate", epic:$epic, mismatch_pct:$mismatch, target:$target, status:$status, total_reviews:$total, hits:$hits, mismatches:$mm}'

  return 0
}

# ─── Metric 4: mis_dispatch_rate ─────────────────────────────────────────────

# EPIC-223 归档基线 helper (DRY: compute_mis_dispatch_rate + _binding_rate 共用)
# 返回 0 = 该 EPIC 已归档 (编号 <= archived_before), 1 = 非归档
is_archived_epic() {
  local epic_num="$1"
  local baseline="${JIRA_TICKETS_DIR}/.archive-baseline.json"
  [ -f "$baseline" ] || return 1

  local archived_before num_only
  archived_before="$(jq -r '.archive_baseline.archived_before // 0' "$baseline" 2>/dev/null || echo 0)"
  num_only="$(echo "$epic_num" | sed -E 's/^0*([0-9]+).*/\1/')"

  [ -n "$num_only" ] || return 1
  [ "$num_only" -le "$archived_before" ] 2>/dev/null || return 1
  return 0
}

# 输出 ARCHIVED_SKIP JSON (跟 EPIC-204 exit 3 DOCS_ONLY_SKIP 同型)
emit_archived_skip() {
  local metric="$1" epic_id="$2" target="$3"
  local baseline="${JIRA_TICKETS_DIR}/.archive-baseline.json"
  local archived_before
  archived_before="$(jq -r '.archive_baseline.archived_before // 0' "$baseline" 2>/dev/null || echo 0)"

  log_warn "$metric" "epic=${epic_id} reason=archived_skip archived_before=${archived_before}"
  jq -n \
    --arg metric "$metric" \
    --arg epic "$epic_id" \
    --argjson target "$target" \
    --argjson ab "$archived_before" \
    '{metric:$metric, epic:$epic, mis_pct:0, target:$target, status:"ARCHIVED_SKIP", total:0, mis_dispatched:0, archived_before:$ab, breakdown:{}}'
}

# Performer 错派率: ticket 实际被分配的 Performer 与 file_scope 推断的 specialization 不一致
# (或 ticket 未被派单 / file_scope 跨 specialization 冲突)
#
# 错派判定 (二选一即错派):
#   1. ticket.json `performer` 字段为空 (未派单)
#   2. file_scope.includes 路径同时命中 ≥2 个 specialization (scope 冲突 → 必然错派)
#
# 数据源: ticket.json `performer` (performer-<EPIC>-<TICKET> 格式) + file_scope.includes
# 归档语义 (EPIC-223): EPIC 编号 <= .archive-baseline.json archived_before → ARCHIVED_SKIP,
#   历史 EPIC 不回溯 (工作已完成合并, 仅缺 ticket 元数据), 跟 EPIC-204 exit 3 同型
# 输出: JSON object {mis_pct, target, status, total, mis_dispatched, breakdown: {reason: count}}
compute_mis_dispatch_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local epic_num="${epic_id#EPIC-}"
  local total=0
  local mis=0
  local reason_unassigned=0
  local reason_scope_conflict=0
  local multi_spec_intentional_skip_count=0

  # EPIC-223: 归档基线检查 — 历史 EPIC 跳过, 不回溯
  if is_archived_epic "$epic_num"; then
    emit_archived_skip "mis_dispatch_rate" "$epic_id" "$MIS_DISPATCH_TARGET_PCT"
    return 0
  fi

  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
    [ -d "$ticket_dir" ] || continue
    local tj="${ticket_dir}ticket.json"
    [ -f "$tj" ] || continue

    total=$((total + 1))

    # 1) 检查 performer 是否分配
    local performer
    performer="$(jq -r '.performer // empty' "$tj" 2>/dev/null || true)"
    local unassigned=0
    if [ -z "$performer" ]; then
      unassigned=1
    fi

    # 2) 检查 file_scope 是否跨 specialization
    local includes_json
    includes_json="$(jq -c '[.file_scope.includes[]? // empty]' "$tj" 2>/dev/null || echo '[]')"
    [ -z "$includes_json" ] || [ "$includes_json" = "null" ] && includes_json='[]'

    local expected
    expected="$(infer_specialization "$includes_json")"
    local scope_conflict=0
    if [ "$expected" = "mixed" ]; then
      scope_conflict=1
    fi

    # EPIC-277-H 主公拍板: ticket.json 标 `multi_spec_intentional: true` 豁免 scope_conflict
    # (基础设施型 EPIC 跨多 specialization 是设计, 非错派)
    local multi_spec_intentional
    multi_spec_intentional="$(jq -r '.multi_spec_intentional // false' "$tj" 2>/dev/null || echo 'false')"
    if [ "$multi_spec_intentional" = "true" ]; then
      scope_conflict=0
      multi_spec_intentional_skip_count=$((multi_spec_intentional_skip_count + 1))
      log_info "mis_dispatch" "epic=${epic_id} reason=multi_spec_intentional_skip"
    fi

    if [ "$unassigned" -eq 1 ] || [ "$scope_conflict" -eq 1 ]; then
      mis=$((mis + 1))
      [ "$unassigned" -eq 1 ] && reason_unassigned=$((reason_unassigned + 1))
      [ "$scope_conflict" -eq 1 ] && reason_scope_conflict=$((reason_scope_conflict + 1))
    fi
  done

  if [ "$total" -eq 0 ]; then
    log_warn "mis_dispatch_rate" "epic=${epic_id} reason=no_tickets"
    jq -n \
      --argjson target "$MIS_DISPATCH_TARGET_PCT" \
      '{metric:"mis_dispatch_rate", epic:$epic, mis_pct:0, target:$target, status:"NO_DATA", total:0, mis_dispatched:0, breakdown:{}}' \
      --arg epic "$epic_id"
    return 0
  fi

  local mis_pct=$(( (mis * 100) / total ))
  local status="FAIL"
  if [ "$mis_pct" -lt "$MIS_DISPATCH_TARGET_PCT" ]; then
    status="PASS"
  fi

  local breakdown_json
  breakdown_json="$(# breakdown 字段 (EPIC-277-H 加 multi_spec_intentional_skip)
    jq -n \
    --argjson u "$reason_unassigned" \
    --argjson c "$reason_scope_conflict" \
    --argjson msi "$multi_spec_intentional_skip_count" \
    '{unassigned:$u, scope_conflict:$c, multi_spec_intentional_skip:$msi}')"

  jq -n \
    --arg epic "$epic_id" \
    --argjson mis "$mis_pct" \
    --argjson target "$MIS_DISPATCH_TARGET_PCT" \
    --argjson total "$total" \
    --argjson mm "$mis" \
    --argjson bd "$breakdown_json" \
    --arg status "$status" \
    '{metric:"mis_dispatch_rate", epic:$epic, mis_pct:$mis, target:$target, status:$status, total:$total, mis_dispatched:$mm, breakdown:$bd}'

  return 0
}

# EPIC-157 — mis_dispatch_rate (binding) variant
# 用 ticket.json expert_binding 字段: actual_expert 跟 suggested_expert 不一致
# 且 prefix 不同 (cross-specialization) 视为 mis_dispatch.
# 数据源: jira/tickets/EPIC-*/ticket.json expert_binding 字段.
# 历史 ticket (无 expert_binding) 跳过不计入分母.
# 调用方: --include-binding 标志启用; 默认仍用原 compute_mis_dispatch_rate.
compute_mis_dispatch_binding_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local epic_num="${epic_id#EPIC-}"
  local total=0
  local mis=0
  local reason_binding_divergent=0
  local reason_binding_unset=0

  # EPIC-223: 归档基线检查 — 历史 EPIC 跳过, 不回溯
  if is_archived_epic "$epic_num"; then
    emit_archived_skip "mis_dispatch_binding_rate" "$epic_id" "$MIS_DISPATCH_TARGET_PCT"
    return 0
  fi

  # 同时支持 EPIC-XXX/ticket.json (root) 跟 EPIC-XXX-A/ticket.json (sub-ticket)
  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}" "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
    [ -d "$ticket_dir" ] || continue
    local tj="${ticket_dir%/}/ticket.json"
    [ -f "$tj" ] || continue

    # 历史 ticket (无 expert_binding) 跳过不计入分母 (per EPIC-157 design)
    local has_binding
    has_binding="$(jq 'has("expert_binding")' "$tj" 2>/dev/null || echo "false")"
    if [ "$has_binding" = "false" ]; then
      continue
    fi

    total=$((total + 1))

    local suggested actual
    suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$tj" 2>/dev/null || echo "")"
    actual="$(jq -r '.expert_binding.actual_expert // empty' "$tj" 2>/dev/null || echo "")"

    # actual 未填视为未派单 (binding 未完成)
    if [ -z "$actual" ]; then
      mis=$((mis + 1))
      reason_binding_unset=$((reason_binding_unset + 1))
      continue
    fi

    # actual 偏离 suggested 且 prefix 不同 → cross-specialization mis_dispatch
    if [ -n "$suggested" ] && [ "$actual" != "$suggested" ]; then
      local s_prefix="${suggested%%-*}"
      local a_prefix="${actual%%-*}"
      if [ "$s_prefix" != "$a_prefix" ] \
         && [ "$s_prefix" != "custom" ] \
         && [ "$a_prefix" != "custom" ]; then
        mis=$((mis + 1))
        reason_binding_divergent=$((reason_binding_divergent + 1))
      fi
    fi
  done

  if [ "$total" -eq 0 ]; then
    log_warn "mis_dispatch_binding_rate" "epic=${epic_id} reason=no_tickets_with_binding"
    jq -n \
      --argjson target "$MIS_DISPATCH_TARGET_PCT" \
      --arg epic "$epic_id" \
      '{metric:"mis_dispatch_binding_rate", epic:$epic, mis_pct:0, target:$target, status:"NO_DATA", total:0, mis_dispatched:0, breakdown:{}}'
    return 0
  fi

  local mis_pct=$(( (mis * 100) / total ))
  local status="FAIL"
  if [ "$mis_pct" -lt "$MIS_DISPATCH_TARGET_PCT" ]; then
    status="PASS"
  fi

  local breakdown_json
  breakdown_json="$(jq -n \
    --argjson d "$reason_binding_divergent" \
    --argjson u "$reason_binding_unset" \
    '{binding_divergent:$d, binding_unset:$u}')"

  jq -n \
    --arg epic "$epic_id" \
    --argjson mis "$mis_pct" \
    --argjson target "$MIS_DISPATCH_TARGET_PCT" \
    --argjson total "$total" \
    --argjson mm "$mis" \
    --argjson bd "$breakdown_json" \
    --arg status "$status" \
    '{metric:"mis_dispatch_binding_rate", epic:$epic, mis_pct:$mis, target:$target, status:$status, total:$total, mis_dispatched:$mm, breakdown:$bd}'

  return 0
}

# ─── Metric 5: abandonment_rate ────────────────────────────────────────────────

# Performer abandonment rate: assigned 但超 48h 无 PR 的 ticket 占比
# Anthropic research: novice abandonment 19%, expert 5-7%, target <10%
#
# Abandonment 判定:
#   1. ticket.json 有 performer (已派单)
#   2. ticket.json 无 pr_url (未提交 PR)
#   3. status 不在 done/merged/closed/passed/failed
#   4. assigned_at 超过 ABANDONMENT_THRESHOLD_HOURS
#
# 数据源: jira/tickets/EPIC-NNN-*/ticket.json
# 输出: JSON {metric, epic, abandonment_pct, target, status, total, abandoned, breakdown}
compute_abandonment_rate() {
  local epic_id="$1"
  validate_epic_id "$epic_id" || return 1

  local epic_num="${epic_id#EPIC-}"
  local total=0
  local abandoned=0
  local threshold_hours="${ABANDONMENT_THRESHOLD_HOURS:-48}"

  # 当前时间戳
  local now_ts
  now_ts="$(date +%s)" || now_ts="$(python3 -c 'import time; print(int(time.time()))')"

  for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
    [ -d "$ticket_dir" ] || continue
    local tj="${ticket_dir}ticket.json"
    [ -f "$tj" ] || continue

    # 必须有 performer 才算 assigned
    local performer pr_url status assigned_at
    performer="$(jq -r '.performer // empty' "$tj" 2>/dev/null || true)"
    [ -z "$performer" ] && continue

    pr_url="$(jq -r '.pr_url // .pr_number // empty' "$tj" 2>/dev/null || true)"
    status="$(jq -r '.status // empty' "$tj" 2>/dev/null || true)"
    assigned_at="$(jq -r '.assigned_at // empty' "$tj" 2>/dev/null || true)"

    total=$((total + 1))

    # 已合并/完成/关闭 → 非 abandoned
    case "$status" in
      done|merged|closed|passed|failed) continue ;;
    esac

    # 有 PR → 非 abandoned
    [ -n "$pr_url" ] && continue

    # 无 assigned_at → 无法判断 → 不计入
    [ -z "$assigned_at" ] && continue

    # 计算 assigned_at 距今小时数
    local assigned_ts
    assigned_ts="$(python3 -c "import time; print(int(time.mktime(time.strptime('${assigned_at}', '%Y-%m-%dT%H:%M:%SZ'))))" 2>/dev/null || true)"
    [ -z "$assigned_ts" ] && continue

    local elapsed_hours=$(( (now_ts - assigned_ts) / 3600 ))
    if [ "$elapsed_hours" -gt "$threshold_hours" ]; then
      abandoned=$((abandoned + 1))
    fi
  done

  if [ "$total" -eq 0 ]; then
    log_warn "abandonment_rate" "epic=${epic_id} reason=no_assigned_tickets"
    jq -n \
      --arg epic "$epic_id" \
      --argjson target "$ABANDONMENT_TARGET_PCT" \
      '{metric:"abandonment_rate", epic:$epic, abandonment_pct:0, target:$target, status:"NO_DATA", total:0, abandoned:0, breakdown:{}}'
    return 0
  fi

  local abandonment_pct=$(( (abandoned * 100) / total ))
  local status_val="FAIL"
  if [ "$abandonment_pct" -lt "$ABANDONMENT_TARGET_PCT" ]; then
    status_val="PASS"
  fi

  jq -n \
    --arg epic "$epic_id" \
    --argjson abandonment_pct "$abandonment_pct" \
    --argjson target "$ABANDONMENT_TARGET_PCT" \
    --argjson total "$total" \
    --argjson abandoned "$abandoned" \
    --arg status "$status_val" \
    --argjson threshold "$threshold_hours" \
    '{metric:"abandonment_rate", epic:$epic, abandonment_pct:$abandonment_pct, target:$target, status:$status, total:$total, abandoned:$abandoned, threshold_hours:$threshold}'

  return 0
}

# infer_specialization <json_array_of_paths>
# 按 SPECIALIZATION_PATTERNS 顺序匹配, 返回首个匹配; 多 specialization → "mixed"
infer_specialization() {
  local paths_json="$1"
  [ -z "$paths_json" ] || [ "$paths_json" = "[]" ] && { echo "empty"; return; }

  local matched_specs=""
  local pattern spec

  for entry in "${SPECIALIZATION_PATTERNS[@]}"; do
    spec="${entry%%|*}"
    pattern="${entry#*|}"

    # 检查 paths_json 中是否有任何 path 匹配此 pattern
    # pattern 是 extended regex, 用 grep -E
    local hit
    hit="$(printf '%s' "$paths_json" | jq -r '.[]' 2>/dev/null \
      | grep -E "$pattern" 2>/dev/null | head -1)"

    if [ -n "$hit" ]; then
      matched_specs="${matched_specs:+${matched_specs},}${spec}"
    fi
  done

  if [ -z "$matched_specs" ]; then
    echo "unknown"
  elif [[ "$matched_specs" == *","* ]]; then
    echo "mixed"
  else
    echo "$matched_specs"
  fi
}

# ─── Output formatters ──────────────────────────────────────────────────────

# 合并 4 个 metric 为单一 JSON (machine-readable)
format_json_metrics() {
  local epic_id="$1"
  local m1 m2 m2b m3 m4 m5 m4b
  m1="$(compute_expert_activation_rate "$epic_id")"
  m2="$(compute_cross_epic_reuse_rate "$epic_id")"
  m3="$(compute_ab_hit_rate "$epic_id")"
  m4="$(compute_mis_dispatch_rate "$epic_id")"
  m5="$(compute_abandonment_rate "$epic_id")"
  # EPIC-157 — 新增 mis_dispatch_binding_rate 副指标 (binding tracking 数据源)
  m4b="$(compute_mis_dispatch_binding_rate "$epic_id")"
  # EPIC-253 — 新增 cross_epic_docs_reuse_rate 副指标 (docs-only EPIC 复用率)
  m2b="$(compute_cross_epic_docs_reuse_rate "$epic_id")"

  jq -n \
    --arg epic "$epic_id" \
    --argjson generated_at "$(date +%s)" \
    --argjson m1 "$m1" \
    --argjson m2 "$m2" \
    --argjson m2b "$m2b" \
    --argjson m3 "$m3" \
    --argjson m4 "$m4" \
    --argjson m5 "$m5" \
    --argjson m4b "$m4b" \
    '{
      epic: $epic,
      generated_at: $generated_at,
      metrics: [
        $m1,
        $m2,
        $m2b,
        $m3,
        $m4,
        $m4b,
        $m5
      ]
    }'
}

# 合并 5 个 metric 为 Markdown table (human-readable, master + conductor 可读)
format_markdown_metrics() {
  local epic_id="$1"
  local m1 m2 m2b m3 m4 m5
  m1="$(compute_expert_activation_rate "$epic_id")"
  m2="$(compute_cross_epic_reuse_rate "$epic_id")"
  m2b="$(compute_cross_epic_docs_reuse_rate "$epic_id")"
  m3="$(compute_ab_hit_rate "$epic_id")"
  m4="$(compute_mis_dispatch_rate "$epic_id")"
  m5="$(compute_abandonment_rate "$epic_id")"

  # 提取每个 metric 的 status / 主要数字
  local m1_distinct m1_target m1_status m1_breakdown
  m1_distinct="$(printf '%s' "$m1" | jq -r '.distinct_count')"
  m1_target="$(printf '%s' "$m1" | jq -r '.target')"
  m1_status="$(printf '%s' "$m1" | jq -r '.status')"
  m1_breakdown="$(printf '%s' "$m1" | jq -r '.breakdown | to_entries | map("  - \(.key): \(.value)") | join("\n")')"

  local m2_pct m2_target m2_status m2_overlap m2_total
  m2_pct="$(printf '%s' "$m2" | jq -r '.reuse_pct')"
  m2_target="$(printf '%s' "$m2" | jq -r '.target')"
  m2_status="$(printf '%s' "$m2" | jq -r '.status')"
  m2_overlap="$(printf '%s' "$m2" | jq -r '.overlap_count')"
  m2_total="$(printf '%s' "$m2" | jq -r '.total_files')"

  # EPIC-253 — docs 复用率副指标
  local m2b_pct m2b_target m2b_status m2b_overlap m2b_total
  m2b_pct="$(printf '%s' "$m2b" | jq -r '.docs_reuse_pct')"
  m2b_target="$(printf '%s' "$m2b" | jq -r '.target')"
  m2b_status="$(printf '%s' "$m2b" | jq -r '.status')"
  m2b_overlap="$(printf '%s' "$m2b" | jq -r '.overlap_count')"
  m2b_total="$(printf '%s' "$m2b" | jq -r '.total_docs_files')"

  local m3_pct m3_target m3_status m3_total m3_mm
  m3_pct="$(printf '%s' "$m3" | jq -r '.mismatch_pct')"
  m3_target="$(printf '%s' "$m3" | jq -r '.target')"
  m3_status="$(printf '%s' "$m3" | jq -r '.status')"
  m3_total="$(printf '%s' "$m3" | jq -r '.total_reviews')"
  m3_mm="$(printf '%s' "$m3" | jq -r '.mismatches')"

  local m4_pct m4_target m4_status m4_total m4_mm
  m4_pct="$(printf '%s' "$m4" | jq -r '.mis_pct')"
  m4_target="$(printf '%s' "$m4" | jq -r '.target')"
  m4_status="$(printf '%s' "$m4" | jq -r '.status')"
  m4_total="$(printf '%s' "$m4" | jq -r '.total')"
  m4_mm="$(printf '%s' "$m4" | jq -r '.mis_dispatched')"

  local m5_pct m5_target m5_status m5_total m5_abandoned
  m5_pct="$(printf '%s' "$m5" | jq -r '.abandonment_pct')"
  m5_target="$(printf '%s' "$m5" | jq -r '.target')"
  m5_status="$(printf '%s' "$m5" | jq -r '.status')"
  m5_total="$(printf '%s' "$m5" | jq -r '.total')"
  m5_abandoned="$(printf '%s' "$m5" | jq -r '.abandoned')"

  local generated_at
  generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat <<EOF
# 北极星指标 — ${epic_id}

> Generated: ${generated_at}
> 数据源: expert_invocations queue (Redis→SQLite→file, EPIC-021-F) + jira/tickets/

## Summary

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| expert_activation_rate | ${m1_distinct} distinct experts | ≥ ${m1_target} | **${m1_status}** |
| cross_epic_reuse_rate | ${m2_pct}% (${m2_overlap}/${m2_total} files) | ≥ ${m2_target}% | **${m2_status}** |
| cross_epic_docs_reuse_rate | ${m2b_pct}% (${m2b_overlap}/${m2b_total} docs) | ≥ ${m2b_target}% | **${m2b_status}** |
| ab_hit_rate (mismatch) | ${m3_pct}% (${m3_mm}/${m3_total} reviews) | < ${m3_target}% | **${m3_status}** |
| mis_dispatch_rate | ${m4_pct}% (${m4_mm}/${m4_total} tickets) | < ${m4_target}% | **${m4_status}** |
| abandonment_rate | ${m5_pct}% (${m5_abandoned}/${m5_total} tickets) | < ${m5_target}% | **${m5_status}** |

## 详细

### 1. expert_activation_rate — ${m1_distinct}/${m1_target} distinct experts

${m1_breakdown:-  (no breakdown)}

### 2. cross_epic_reuse_rate — ${m2_pct}% reuse

- Overlap files: ${m2_overlap}
- Total files in EPIC: ${m2_total}

### 3. ab_hit_rate — ${m3_pct}% mismatch (${m3_mm} / ${m3_total})

### 4. mis_dispatch_rate — ${m4_pct}% misdispatch (${m4_mm} / ${m4_total})

### 5. abandonment_rate — ${m5_pct}% abandoned (${m5_abandoned} / ${m5_total})

---

**Legend**: ✅ PASS = meets target | ❌ FAIL = below target | ⚠️ NO_DATA = data unavailable

EOF
}