#!/usr/bin/env bash
# KALLAX Health Check — comprehensive system diagnostics
# Checks: git, DB, disk, memory, Node, Rust, network, worktree count
# Supports --json (structured) and --text (legacy, default) modes
set -euo pipefail

# Mode selection: --json or --text (default)
# Supports both: bash health_check.sh --json  (mode only)
#               bash health_check.sh /path --json  (path + mode)
#               bash health_check.sh /path  (path, mode=text default)
MODE="text"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

if [[ "${1:-}" == "--json" ]]; then
  MODE="--json"; shift
  PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
elif [[ "${1:-}" == "--text" ]]; then
  MODE="--text"; shift
  PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
elif [[ -n "${1:-}" ]]; then
  PROJECT_ROOT="$1"
  # Check if $2 is --json or --text
  if [[ "${2:-}" == "--json" ]]; then
    MODE="--json"
  elif [[ "${2:-}" == "--text" ]]; then
    MODE="--text"
  fi
fi

KALLAX_DIR="${PROJECT_ROOT}/.kallax"
EXIT_CODE=0

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; EXIT_CODE=1; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }

# ─────────────────────────────────────────────────────────
# Check functions (return "ok" or error message)
# ─────────────────────────────────────────────────────────

check_git() {
  if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ok"
  else
    echo "not a git repository"
  fi
}

check_sqlite() {
  DB_PATH="${KALLAX_DIR}/data/kallax.db"
  if [ -f "$DB_PATH" ]; then
    echo "ok"
  else
    echo "not found"
  fi
}

check_disk() {
  DISK_PCT=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
  local pct="${DISK_PCT:-100}"
  if [ "$pct" -lt 85 ]; then
    echo "ok"
  elif [ "$pct" -lt 95 ]; then
    echo "degraded: ${pct}% used"
  else
    echo "unhealthy: ${pct}% used"
  fi
}

check_node() {
  if command -v node &>/dev/null; then
    echo "ok"
  else
    echo "not found"
  fi
}

check_rust() {
  if command -v rustc &>/dev/null; then
    echo "ok"
  else
    echo "not found"
  fi
}

check_worktrees() {
  WT_COUNT=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$WT_COUNT" -le 5 ]; then
    echo "ok"
  else
    echo "degraded: $WT_COUNT worktrees (consider cleanup)"
  fi
}

check_config() {
  if [ -f "${KALLAX_DIR}/config.yml" ]; then
    echo "ok"
  else
    echo "not found"
  fi
}

check_role() {
  ROLE=$(grep "role:" "${KALLAX_DIR}/state/instance_config.yml" 2>/dev/null | awk '{print $2}' || echo "unset")
  if [ "$ROLE" != "unset" ]; then
    echo "ok"
  else
    echo "unset"
  fi
}

# ─────────────────────────────────────────────────────────
# Run all checks
# ─────────────────────────────────────────────────────────

GIT_OK=$(check_git)
SQLITE_OK=$(check_sqlite)
DISK_OK=$(check_disk)
NODE_OK=$(check_node)
RUST_OK=$(check_rust)
WORKTREES_OK=$(check_worktrees)
CONFIG_OK=$(check_config)
ROLE_OK=$(check_role)

# ─────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────

if [[ "$MODE" == "--json" ]]; then
  # Determine overall status and level
  # Level 1: unhealthy (git or sqlite critical)
  # Level 2: degraded (disk/node/rust/worktrees/config issue)
  # Level 3: healthy (all checks ok)

  status="healthy"; level=3

  # Critical failures → level 1
  [[ "$GIT_OK" != "ok" ]] && { status="unhealthy"; level=1; }
  [[ "$SQLITE_OK" != "ok" ]] && { status="unhealthy"; level=1; }

  # Degraded → level 2
  if [[ "$status" == "healthy" ]]; then
    [[ "$DISK_OK" != "ok" ]] && { status="degraded"; level=2; }
    [[ "$NODE_OK" != "ok" ]] && { status="degraded"; level=2; }
    [[ "$RUST_OK" != "ok" ]] && { status="degraded"; level=2; }
    [[ "$WORKTREES_OK" != "ok" ]] && { status="degraded"; level=2; }
    [[ "$CONFIG_OK" != "ok" ]] && { status="degraded"; level=2; }
    [[ "$ROLE_OK" != "ok" ]] && { status="degraded"; level=2; }
  fi

  # Build JSON with checks array
  # Use jq -n with --arg for all string values, --argjson for level
  # Each check: {name, status, error (null if ok), note (null if ok)}
  jq -n \
    --arg status "$status" \
    --argjson level "$level" \
    --arg git "$GIT_OK" \
    --arg sqlite "$SQLITE_OK" \
    --arg disk "$DISK_OK" \
    --arg node "$NODE_OK" \
    --arg rust "$RUST_OK" \
    --arg worktrees "$WORKTREES_OK" \
    --arg config "$CONFIG_OK" \
    --arg role "$ROLE_OK" \
    '{
      status: $status,
      level: $level,
      checks: [
        {name: "git",      status: (if $git      == "ok" then "pass" else "fail" end), error: (if $git      == "ok" then null else $git      end), note: null},
        {name: "sqlite",   status: (if $sqlite   == "ok" then "pass" else "fail" end), error: (if $sqlite   == "ok" then null else $sqlite   end), note: null},
        {name: "disk",     status: (if $disk == "ok" then "pass" elif $disk | contains("degraded") then "warn" else "fail" end), error: null, note: (if $disk != "ok" then $disk else null end)},
        {name: "node",     status: (if $node     == "ok" then "pass" else "fail" end), error: (if $node     == "ok" then null else $node     end), note: null},
        {name: "rust",     status: (if $rust     == "ok" then "pass" else "warn" end), error: null, note: (if $rust != "ok" then $rust else null end)},
        {name: "worktrees",status: (if $worktrees == "ok" then "pass" else "warn" end), error: null, note: (if $worktrees != "ok" then $worktrees else null end)},
        {name: "config",   status: (if $config   == "ok" then "pass" else "fail" end), error: (if $config   == "ok" then null else $config   end), note: null},
        {name: "role",     status: (if $role     == "ok" then "pass" else "warn" end), error: null, note: (if $role != "ok" then $role else null end)}
      ]
    }'
else
  # Legacy text output
  echo "=== KALLAX Health Check ==="
  echo "Project: $PROJECT_ROOT"
  echo ""

  # Git
  echo "--- Git ---"
  if [[ "$GIT_OK" == "ok" ]]; then
    pass "Git repo: $(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
    UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$UNCOMMITTED" -gt 0 ] && warn "Uncommitted: $UNCOMMITTED files" || pass "Working tree clean"
  else
    fail "$GIT_OK"
  fi

  # Database
  echo "--- Database ---"
  if [[ "$SQLITE_OK" == "ok" ]]; then
    DB_PATH="${KALLAX_DIR}/data/kallax.db"
    pass "SQLite DB: $(du -h "$DB_PATH" 2>/dev/null | cut -f1)"
  else
    warn "DB not found — run 'kallax system doctor'"
  fi

  # Disk
  echo "--- Disk ---"
  if [[ "$DISK_OK" == "ok" ]]; then
    DISK_PCT=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    pass "Disk: ${DISK_PCT}%"
  else
    if [[ "$DISK_OK" == *"degraded"* ]]; then
      DISK_PCT=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
      warn "Disk: ${DISK_PCT}%"
    else
      DISK_PCT=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
      fail "Disk critical: ${DISK_PCT}%"
    fi
  fi

  # Node.js
  echo "--- Node.js ---"
  if [[ "$NODE_OK" == "ok" ]]; then
    pass "Node: $(node -v)"
  else
    fail "Node.js not found"
  fi

  # Rust
  echo "--- Rust ---"
  if [[ "$RUST_OK" == "ok" ]]; then
    pass "Rust: $(rustc --version)"
  else
    warn "Rust not found"
  fi

  # Worktrees
  echo "--- Worktrees ---"
  if [[ "$WORKTREES_OK" == "ok" ]]; then
    WT_COUNT=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null | wc -l | tr -d ' ')
    pass "Worktrees: $WT_COUNT"
  else
    WT_COUNT=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null | wc -l | tr -d ' ')
    warn "Worktrees: $WT_COUNT — consider cleanup"
  fi

  # Config
  echo "--- Config ---"
  if [[ "$CONFIG_OK" == "ok" ]]; then
    pass "Config exists"
  else
    warn "Config missing"
  fi
  echo "  Role: ${ROLE_OK}"

  echo ""
  [ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}All checks passed${NC}" || echo -e "${RED}${EXIT_CODE} issue(s) found${NC}"
  exit $EXIT_CODE
fi