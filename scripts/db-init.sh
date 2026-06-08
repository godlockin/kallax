#!/usr/bin/env bash
# KALLAX DB Init / Migrate Script
# Usage:
#   kallax db:init              Create .kallax/kallax.db + initialize tables
#   kallax db:migrate           Run schema migrations (version upgrade)
#   kallax db:migrate --dry-run Show pending migrations without applying

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DB_DIR="${KALLAX_ROOT}/.kallax"
DB_PATH="${DB_DIR}/kallax.db"
MIGRATIONS_DIR="${DB_DIR}/migrations"
SCHEMA_VERSION_FILE="${DB_DIR}/schema_version"

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Utility: get current schema version from DB ──────────────────────────────
get_db_version() {
  if [ ! -f "${DB_PATH}" ]; then
    echo 0
    return
  fi
  sqlite3 "${DB_PATH}" "SELECT MAX(version) FROM _schema_version;" 2>/dev/null || echo 0
}

# ── Utility: check if sqlite3 CLI is available ────────────────────────────────
check_deps() {
  if ! command -v sqlite3 &>/dev/null; then
    log_error "sqlite3 CLI not found. Install with: brew install sqlite3"
    exit 1
  fi
}

# ── db:init — Create DB + tables ──────────────────────────────────────────────
cmd_init() {
  check_deps
  log_info "Initializing database at ${DB_PATH}"

  mkdir -p "${DB_DIR}"
  mkdir -p "${MIGRATIONS_DIR}"

  if [ -f "${DB_PATH}" ]; then
    log_warn "Database already exists at ${DB_PATH}"
    log_info "Use 'kallax db:migrate' to run pending migrations"
    exit 0
  fi

  # Create database and initialize with base schema
  sqlite3 "${DB_PATH}" <<'SQL'
-- Schema version tracking
CREATE TABLE IF NOT EXISTS _schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now')),
  description TEXT
);

-- Base schema version 1
INSERT INTO _schema_version (version, description) VALUES (1, 'team collaboration schema');

-- Phases
CREATE TABLE IF NOT EXISTS phases (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  scope TEXT NOT NULL,
  status TEXT NOT NULL,
  start_time TEXT,
  delivery_time TEXT
);

-- Epics
CREATE TABLE IF NOT EXISTS epics (
  id TEXT PRIMARY KEY,
  phase_id TEXT NOT NULL,
  title TEXT NOT NULL,
  scope TEXT NOT NULL,
  status TEXT NOT NULL,
  start_time TEXT,
  delivery_time TEXT,
  FOREIGN KEY (phase_id) REFERENCES phases(id)
);

-- Project tickets
CREATE TABLE IF NOT EXISTS project_tickets (
  id TEXT PRIMARY KEY,
  epic_id TEXT NOT NULL,
  title TEXT NOT NULL,
  type TEXT NOT NULL,
  priority TEXT NOT NULL,
  status TEXT NOT NULL,
  assignee TEXT,
  file_scope TEXT,
  acceptance_criteria TEXT NOT NULL,
  FOREIGN KEY (epic_id) REFERENCES epics(id)
);

-- Team instances (heartbeat tracking)
CREATE TABLE IF NOT EXISTS team_instances (
  instance_id TEXT PRIMARY KEY,
  role TEXT NOT NULL,
  status TEXT NOT NULL,
  branch TEXT,
  pid INTEGER NOT NULL,
  heartbeat_at INTEGER,
  missed_count INTEGER NOT NULL DEFAULT 0
);

-- Heartbeat log
CREATE TABLE IF NOT EXISTS heartbeat_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  instance_id TEXT NOT NULL,
  tick_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  FOREIGN KEY (instance_id) REFERENCES team_instances(instance_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_phases_status ON phases(status);
CREATE INDEX IF NOT EXISTS idx_epics_phase ON epics(phase_id);
CREATE INDEX IF NOT EXISTS idx_epics_status ON epics(status);
CREATE INDEX IF NOT EXISTS idx_project_tickets_epic ON project_tickets(epic_id);
CREATE INDEX IF NOT EXISTS idx_project_tickets_status ON project_tickets(status);
CREATE INDEX IF NOT EXISTS idx_project_tickets_assignee ON project_tickets(assignee);
CREATE INDEX IF NOT EXISTS idx_team_instances_role ON team_instances(role);
CREATE INDEX IF NOT EXISTS idx_team_instances_status ON team_instances(status);
CREATE INDEX IF NOT EXISTS idx_team_instances_heartbeat ON team_instances(heartbeat_at);
CREATE INDEX IF NOT EXISTS idx_heartbeat_log_instance ON heartbeat_log(instance_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_log_tick ON heartbeat_log(tick_at);
SQL

  echo ""
  log_info "Database initialized at: ${DB_PATH}"
  log_info "Schema version: 1"
  log_info "Tables created: phases, epics, project_tickets, team_instances, heartbeat_log"
  echo ""
}

# ── db:migrate — Run pending schema migrations ────────────────────────────────
cmd_migrate() {
  local dry_run=false
  if [ "${1:-}" = "--dry-run" ]; then
    dry_run=true
    log_info "DRY RUN MODE — no changes will be applied"
  fi

  check_deps

  if [ ! -f "${DB_PATH}" ]; then
    log_error "Database not found at ${DB_PATH}"
    log_info "Run 'kallax db:init' first"
    exit 1
  fi

  # Ensure schema_version table exists
  sqlite3 "${DB_PATH}" "CREATE TABLE IF NOT EXISTS _schema_version (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (datetime('now')), description TEXT);" 2>/dev/null || true

  local current_version
  current_version=$(get_db_version)
  log_info "Current schema version: ${current_version}"

  local latest_version=1
  if [ "${current_version}" -ge "${latest_version}" ]; then
    log_info "Schema is up to date (version ${current_version})"
    exit 0
  fi

  if [ "${dry_run}" = true ]; then
    log_info "Pending migrations: version $((current_version + 1)) to ${latest_version}"
    exit 0
  fi

  # Apply pending migrations
  for v in $(seq $((current_version + 1)) "${latest_version}"); do
    local migration_file="${MIGRATIONS_DIR}/V${v}__*.sql"
    # shellcheck disable=SC2086
    local matched
    matched=$(ls -1 ${migration_file} 2>/dev/null | head -1 || true)

    if [ -n "${matched}" ] && [ -f "${matched}" ]; then
      log_info "Applying migration V${v}: ${matched}"
      sqlite3 "${DB_PATH}" < "${matched}"
    else
      log_info "No migration file for V${v}, recording version bump"
    fi

    sqlite3 "${DB_PATH}" "INSERT INTO _schema_version (version, description) VALUES (${v}, 'migration V${v}');"
    log_info "Schema upgraded to version ${v}"
  done

  log_info "Migration complete. Schema at version $(get_db_version)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  init)
    cmd_init
    ;;
  migrate)
    cmd_migrate "${2:-}"
    ;;
  *)
    echo "KALLAX DB Management"
    echo ""
    echo "Usage:"
    echo "  kallax db:init              Create .kallax/kallax.db + initialize tables"
    echo "  kallax db:migrate           Run pending schema migrations"
    echo "  kallax db:migrate --dry-run Show pending migrations without applying"
    echo ""
    ;;
esac
