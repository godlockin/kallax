#!/usr/bin/env bash
# KALLAX Common Functions
# Shared library for all /kallax-* slash commands

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
KALLAX_DIR="${KALLAX_ROOT}/.kallax"
KALLAX_CONFIG="${KALLAX_DIR}/config.yml"
KALLAX_STATE="${KALLAX_DIR}/state"
KALLAX_DATA="${KALLAX_DIR}/data"
KALLAX_LOG="${KALLAX_DIR}/logs/kallax.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Logging ────────────────────────────────────────────────────────────────

log_info()  { echo -e "${GREEN}[KALLAX]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[KALLAX]${NC} $*" >&2; }
log_error() { echo -e "${RED}[KALLAX]${NC} $*" >&2; }
log_title() { echo -e "\n${BOLD}${BLUE}═══ $* ═══${NC}\n"; }

# ── Config ─────────────────────────────────────────────────────────────────

get_config() {
  local key="$1"
  local default="${2:-}"
  if [ -f "$KALLAX_CONFIG" ]; then
    grep "$key:" "$KALLAX_CONFIG" 2>/dev/null | head -1 | sed 's/.*: *//' || echo "$default"
  else
    echo "$default"
  fi
}

get_role() {
  if [ -f "${KALLAX_STATE}/instance_config.yml" ]; then
    grep "role:" "${KALLAX_STATE}/instance_config.yml" 2>/dev/null | awk '{print $2}' || echo "unset"
  else
    echo "unset"
  fi
}

# ── Git helpers ────────────────────────────────────────────────────────────

current_branch() { git branch --show-current 2>/dev/null || echo "unknown"; }
has_uncommitted() { [ -n "$(git status --porcelain 2>/dev/null)" ] && echo "true" || echo "false"; }
get_repo_name() { basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown"; }

# ── Checks ─────────────────────────────────────────────────────────────────

require_kallax_init() {
  if [ ! -f "$KALLAX_CONFIG" ]; then
    log_error "KALLAX not initialized. Run /kallax-start first."
    exit 1
  fi
}

require_role() {
  local role="$1"
  local current
  current=$(get_role)
  if [ "$current" != "$role" ]; then
    log_error "This command requires role: $role (current: $current)"
    exit 1
  fi
}

require_git_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a git repository."
    exit 1
  fi
}

# ── CLI Detection (Node > Rust fallback) ──────────────────────────────────

KALLAX_CLI="${KALLAX_ROOT}/node/bin/kallax"

kallax_cli() {
  if [ -x "$KALLAX_CLI" ]; then
    "$KALLAX_CLI" "$@"
  elif command -v npx &>/dev/null; then
    npx tsx "${KALLAX_ROOT}/node/src/index.ts" "$@"
  else
    log_warn "No Node CLI found. Install: npm install && npm run build"
  fi
}

# ── API Server Auto-Start ──────────────────────────────────────────────────

KALLAX_API="${KALLAX_API:-http://127.0.0.1:9877}"
KALLAX_SERVER_PID_FILE="${KALLAX_STATE}/server.pid"

ensure_server_running() {
  # ⚠️ S-001 治根: API key 必须 env 注入, 0 default 兜底
  local api_key
  api_key="${KALLAX_API_KEY:-}"
  if [[ -z "$api_key" ]]; then
    log_fatal "KALLAX_API_KEY required (fail-closed, S-001)"
    return 1
  fi
  export KALLAX_API_KEY="$api_key"

  # Check if server already running via /live (no auth, simple liveness)
  if command -v curl &>/dev/null; then
    if curl -sf "${KALLAX_API}/live" >/dev/null 2>&1; then
      log_info "Server already running on ${KALLAX_API}"
      return 0
    fi
  fi

  # Start server in background using tsx
  log_info "Starting API server on ${KALLAX_API}..."
  mkdir -p "${KALLAX_DIR}/logs"
  nohup npx tsx "${KALLAX_ROOT}/node/src/api/server.ts" >> "${KALLAX_DIR}/logs/server.log" 2>&1 &
  local server_pid=$!
  echo "$server_pid" > "$KALLAX_SERVER_PID_FILE"
  log_info "Server PID: ${server_pid}"

  # Wait for server to be ready (up to 10s, polling /live every 0.5s)
  for i in $(seq 1 20); do
    if curl -sf "${KALLAX_API}/live" >/dev/null 2>&1; then
      log_info "Server ready after $((i * 500))ms (PID: ${server_pid})"
      return 0
    fi
    sleep 0.5
  done

  log_warn "Server may not be ready after 10s — continuing anyway (PID: ${server_pid})"
  return 1
}

# Initialize database if needed
ensure_db_initialized() {
  mkdir -p "$KALLAX_DATA"
  if [ ! -f "${KALLAX_DATA}/kallax.db" ]; then
    log_info "Initializing database..."
    kallax_cli system doctor > /dev/null 2>&1 || true
  fi
}

api_call() {
  local method="$1" path="$2" data="${3:-}"
  local url="${KALLAX_API}${path}"
  local api_key="${KALLAX_API_KEY:-}"

  if [ -n "$api_key" ]; then
    if [ -n "$data" ]; then
      curl -s -X "$method" "$url" -H "Content-Type: application/json" -H "X-KALLAX-API-Key: $api_key" -d "$data"
    else
      curl -s -X "$method" "$url" -H "X-KALLAX-API-Key: $api_key"
    fi
  else
    if [ -n "$data" ]; then
      curl -s -X "$method" "$url" -H "Content-Type: application/json" -d "$data"
    else
      curl -s -X "$method" "$url"
    fi
  fi
}

# ── Display ────────────────────────────────────────────────────────────────

print_table_header() { printf "${BOLD}%-40s %-10s %-10s %s${NC}\n" "$@"; }
print_table_row() { printf "%-40s %-10s %-10s %s\n" "$@"; }
print_separator() { printf '=%.0s' $(seq 1 80); echo; }
print_divider() { printf -- '-%.0s' $(seq 1 80); echo; }

# ── Help system ──────────────────────────────────────────────────────────

# show_help — read help text from stdin and print with consistent formatting.
# Usage in a command (place AFTER `source` and BEFORE main logic):
#
#   if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
#     show_help <<'EOF'
#     <command> — <one-line description>
#
#     USAGE:
#       /<command> [args]
#
#     ARGS:
#       <arg>              <description>
#
#     DESCRIPTION:
#       <2-3 line description>
#
#     EXAMPLES:
#       /<command> <example>
#
#     RELATED:
#       /<related-cmd>
#     EOF
#     exit 0
#   fi
#
# Section headers (USAGE:, ARGS:, DESCRIPTION:, EXAMPLES:, RELATED:) are
# printed in bold blue. Body lines are indented by 2 spaces. Blank lines
# stay blank.
show_help() {
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      echo ""
    elif [[ "$line" =~ ^(USAGE|ARGS|DESCRIPTION|EXAMPLES|RELATED): ]]; then
      echo -e "${BOLD}${BLUE}${line}${NC}"
    else
      echo "  $line"
    fi
  done
}
