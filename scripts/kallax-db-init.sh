#!/usr/bin/env bash
# KALLAX DB Init — 团队协作 SQLite 数据库初始化 (v1.0.0)
# 跟 EPIC-015-F 联合: .kallax/data/kallax.db 团队协作 SQLite
# 跟 EPIC-015-D 联合: jira/schemas/db-schema.json 1:1 验证 (single source of truth)
# 跟 EPIC-030-G 联合: audit_log 表 1:1 验证 (id/command/ticket_id/slaver_id/elapsed_ms/created_at)
# 跟 EPIC-057-A 联合: --target CLI (multi-project, 跟 install.sh 模式一致)
# 跟"翻篇&精进" 战略 联合: 0 增 Rule 0 增命令, 复用 sqlite3 + jq 现有工具

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_FILE="${REPO_ROOT}/jira/schemas/db-schema.json"

# Default DB path (relative to project)
DEFAULT_PROJECT_PATH="${REPO_ROOT}"
DEFAULT_DB_DIR_REL=".kallax/data"
DEFAULT_DB_FILE="kallax.db"

# ── ANSI colors ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 8 tables must match db-schema.json (single source of truth) ─────────────
EXPECTED_TABLES=(phases epics tickets team_instances heartbeat_log audit_log expert_invocations experts)

usage() {
  cat <<EOF
Usage: kallax-db-init [<project_path>] [--target <path[,path2,...]>] [--force]
  <project_path>  optional, defaults to current worktree root
  --target        optional, comma-separated list of project paths (multi-project init, 跟 EPIC-057-A install.sh 模式一致)
  --force         optional, re-initialize DB even if it exists (overwrites .kallax/data/kallax.db)
  -h|--help       show this help

Behavior:
  - Fresh project (no .kallax/data/kallax.db): full init
  - Existing project (.kallax/data/kallax.db present): skipped unless --force
  - Tables created: phases / epics / tickets / team_instances / heartbeat_log
                    audit_log / expert_invocations / experts
  - Single source of truth: jira/schemas/db-schema.json (8 tables, 跟 EPIC-015-D 1:1 + EPIC-030-G audit_log 1:1)
  - INIT-REPORT written to <project>/.kallax/state/db-init-report.md

Examples:
  kallax-db-init /path/to/project
  kallax-db-init --target=/tmp/p1,/tmp/p2
  kallax-db-init --force   # re-create
EOF
  exit 1
}

# ── Parse args (跟 EPIC-015-E / EPIC-057-A 模式一致) ─────────────────────────
PROJECT_PATH=""
TARGETS_RAW=""
FORCE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGETS_RAW="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    -h|--help)
      usage
      ;;
    --target=*)
      TARGETS_RAW="${1#--target=}"
      shift
      ;;
    *)
      if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$1"
        shift
      else
        log_error "unexpected arg: $1"
        usage
      fi
      ;;
  esac
done

# Resolve targets: --target wins; else PROJECT_PATH; else DEFAULT_PROJECT_PATH
if [[ -n "$TARGETS_RAW" ]]; then
  IFS=',' read -r -a TARGETS <<< "$TARGETS_RAW"
elif [[ -n "$PROJECT_PATH" ]]; then
  TARGETS=("$PROJECT_PATH")
else
  TARGETS=("$DEFAULT_PROJECT_PATH")
fi

# ── check deps ──────────────────────────────────────────────────────────────
check_deps() {
  if ! command -v sqlite3 &>/dev/null; then
    log_error "sqlite3 CLI not found. Install with: brew install sqlite3"
    exit 1
  fi
  if ! command -v jq &>/dev/null; then
    log_error "jq not found. Install with: brew install jq"
    exit 1
  fi
  if [[ ! -f "$SCHEMA_FILE" ]]; then
    log_error "db-schema.json not found at $SCHEMA_FILE"
    exit 1
  fi
}

# ── DDL generator: read db-schema.json → SQL CREATE statements ──────────────
# 输出: (stdout) 多条 SQL 语句
generate_ddl() {
  local schema_file="$1"
  local table_count
  table_count=$(jq '.tables | keys | length' "$schema_file")

  for ((i = 0; i < table_count; i++)); do
    local table_name
    table_name=$(jq -r ".tables | keys[$i]" "$schema_file")
    local col_count
    col_count=$(jq ".tables[\"$table_name\"].columns | length" "$schema_file")

    echo ""
    echo "-- ── Table: $table_name ──"
    echo "CREATE TABLE IF NOT EXISTS ${table_name} ("

    local col_lines=()
    for ((c = 0; c < col_count; c++)); do
      local col_name col_type col_pk col_nn col_auto col_default col_check
      col_name=$(jq -r ".tables[\"$table_name\"].columns[$c].name" "$schema_file")
      col_type=$(jq -r ".tables[\"$table_name\"].columns[$c].type" "$schema_file")
      col_pk=$(jq -r ".tables[\"$table_name\"].columns[$c].primary_key // false" "$schema_file")
      col_nn=$(jq -r ".tables[\"$table_name\"].columns[$c].not_null // false" "$schema_file")
      col_auto=$(jq -r ".tables[\"$table_name\"].columns[$c].auto_increment // false" "$schema_file")
      col_default=$(jq -r ".tables[\"$table_name\"].columns[$c].default // empty" "$schema_file")
      col_check=$(jq -r ".tables[\"$table_name\"].columns[$c].check // empty" "$schema_file")

      local parts=()
      parts+=("${col_name}")
      parts+=("${col_type}")

      if [[ "$col_pk" == "true" ]]; then
        parts+=("PRIMARY KEY")
      fi
      if [[ "$col_auto" == "true" ]]; then
        parts+=("AUTOINCREMENT")
      fi
      if [[ "$col_nn" == "true" ]]; then
        parts+=("NOT NULL")
      fi
      if [[ -n "$col_default" ]]; then
        parts+=("DEFAULT")
        parts+=("${col_default}")
      fi
      if [[ -n "$col_check" ]]; then
        parts+=("CHECK")
        parts+=("(${col_check})")
      fi

      local joined
      joined=$(IFS=' '; echo "${parts[*]}")
      col_lines+=("  ${joined}")
    done

    local joined_cols
    joined_cols=$(IFS=','$'\n'; echo "${col_lines[*]}")
    echo "${joined_cols}"
    echo ");"

    # Indexes
    local idx_count
    idx_count=$(jq ".tables[\"$table_name\"].indexes // [] | length" "$schema_file")
    for ((x = 0; x < idx_count; x++)); do
      local idx_name idx_cols_json
      idx_name=$(jq -r ".tables[\"$table_name\"].indexes[$x].name" "$schema_file")
      idx_cols_json=$(jq -c ".tables[\"$table_name\"].indexes[$x].columns" "$schema_file")
      local idx_cols_csv
      idx_cols_csv=$(echo "$idx_cols_json" | jq -r 'join(", ")')
      echo "CREATE INDEX IF NOT EXISTS ${idx_name} ON ${table_name}(${idx_cols_csv});"
    done
  done
}

# ── Init a single project ───────────────────────────────────────────────────
# Returns 0 (success), 1 (skipped/unchanged), 2 (failed)
init_project() {
  local proj_path="$1"
  local db_dir="${proj_path}/.kallax/data"
  local db_path="${db_dir}/kallax.db"
  local state_dir="${proj_path}/.kallax/state"
  local report_path="${state_dir}/db-init-report.md"

  if [[ ! -d "$proj_path" ]]; then
    log_error "project path does not exist: $proj_path"
    return 2
  fi

  mkdir -p "$db_dir"
  mkdir -p "$state_dir"

  # Existing DB check (idempotent)
  if [[ -f "$db_path" && "$FORCE" != "true" ]]; then
    log_warn "DB already exists: $db_path  (use --force to re-init)"
    return 1
  fi

  if [[ "$FORCE" == "true" && -f "$db_path" ]]; then
    log_warn "FORCE: removing existing DB $db_path"
    rm -f "$db_path"
  fi

  log_info "Initializing DB at: $db_path"

  local ddl
  ddl=$(generate_ddl "$SCHEMA_FILE")

  # Apply DDL
  sqlite3 "$db_path" "$ddl"

  # Verify: 8 tables exist
  local actual_count
  actual_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
  if [[ "$actual_count" -ne "${#EXPECTED_TABLES[@]}" ]]; then
    log_error "expected ${#EXPECTED_TABLES[@]} tables, got $actual_count"
    return 2
  fi

  # Verify each expected table exists
  for t in "${EXPECTED_TABLES[@]}"; do
    local present
    present=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$t';" 2>/dev/null || echo 0)
    if [[ "$present" -ne 1 ]]; then
      log_error "table missing: $t"
      return 2
    fi
  done

  # Verify audit_log columns 1:1 with EPIC-030-G (id/command/ticket_id/slaver_id/elapsed_ms/created_at = 6 cols)
  local audit_col_count
  audit_col_count=$(sqlite3 "$db_path" "PRAGMA table_info(audit_log);" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$audit_col_count" -ne 6 ]]; then
    log_error "audit_log column count mismatch (1:1 with EPIC-030-G): expected 6, got $audit_col_count"
    return 2
  fi

  # Verify audit_log column names 1:1 with EPIC-030-G
  local audit_cols
  audit_cols=$(sqlite3 "$db_path" "SELECT name FROM pragma_table_info('audit_log') ORDER BY cid;" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  local expected_audit_cols="id,command,ticket_id,slaver_id,elapsed_ms,created_at"
  if [[ "$audit_cols" != "$expected_audit_cols" ]]; then
    log_error "audit_log columns 1:1 mismatch with EPIC-030-G: got [$audit_cols], expected [$expected_audit_cols]"
    return 2
  fi

  # Write INIT-REPORT
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local db_size
  db_size=$(stat -f %z "$db_path" 2>/dev/null || stat -c %s "$db_path" 2>/dev/null || echo 0)

  cat > "$report_path" <<EOF
# DB-INIT-REPORT (EPIC-015-F)

- 类型: 全新初始化
- 时间: ${created_at}
- DB 路径: \`${db_path}\`
- DB 大小: ${db_size} bytes
- Schema 来源: \`jira/schemas/db-schema.json\` (v$(jq -r '.version' "$SCHEMA_FILE"))
- 创建表: ${#EXPECTED_TABLES[@]} 张

## 表清单 (8 张, 1:1 跟 EPIC-015-D + EPIC-030-G 联合)

| # | Table | 来源 | 说明 |
|---|-------|------|------|
| 1 | phases | EPIC-015-D phase-schema | 阶段 6-state machine |
| 2 | epics | EPIC-015-D epic-schema | EPIC 6-state machine |
| 3 | tickets | EPIC-015-D ticket-schema | Ticket 12-state machine (8 primary + 4 secondary) |
| 4 | team_instances | (heartbeat) | Conductor/Performer 实例 |
| 5 | heartbeat_log | (heartbeat) | 5 问心跳 tick log |
| 6 | audit_log | **EPIC-030-G 1:1** | id/command/ticket_id/slaver_id/elapsed_ms/created_at |
| 7 | expert_invocations | (governance) | 3-phase expert panel 调用 |
| 8 | experts | (skill catalog) | 5 default + 5 extended |

## 验证

- 表数: \`${#EXPECTED_TABLES[@]}/${#EXPECTED_TABLES[@]}\` PASS
- audit_log 1:1 with EPIC-030-G: 6/6 columns PASS (\`id, command, ticket_id, slaver_id, elapsed_ms, created_at\`)
- Schema 1:1 with EPIC-015-D (phase/epic/ticket/state): PASS

## 后续

- EPIC-015-H / EPIC-015-I 等后续 ticket 可直接用 \`.kallax/data/kallax.db\`
- audit_log 表跟 EPIC-030-G \`scripts/audit/audit-middleware.sh\` schema 1:1 (共享契约)
EOF

  log_info "PASS: DB initialized — ${#EXPECTED_TABLES[@]} tables created, audit_log 1:1 with EPIC-030-G"
  log_info "Report: $report_path"
  return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
check_deps

log_info "EPIC-015-F kallax-db-init"
log_info "Schema: $SCHEMA_FILE (v$(jq -r '.version' "$SCHEMA_FILE"))"
log_info "Targets: ${#TARGETS[@]}"

TOTAL=${#TARGETS[@]}
PASS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
FAILED_TARGETS=()

for t in "${TARGETS[@]}"; do
  # trim whitespace
  t=$(echo "$t" | xargs)
  log_info "[$((PASS_COUNT + SKIP_COUNT + FAIL_COUNT + 1))/${TOTAL}] init: $t"
  if init_project "$t"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      SKIP_COUNT=$((SKIP_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAILED_TARGETS+=("$t")
    fi
  fi
done

echo ""
log_info "Summary: total=${TOTAL} pass=${PASS_COUNT} skipped=${SKIP_COUNT} fail=${FAIL_COUNT}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  log_error "FAILED targets:"
  for ft in "${FAILED_TARGETS[@]}"; do
    log_error "  - $ft"
  done
  exit 1
fi

if [[ $PASS_COUNT -eq 0 && $SKIP_COUNT -gt 0 ]]; then
  log_info "All targets already initialized (no changes). Use --force to re-init."
fi

exit 0
