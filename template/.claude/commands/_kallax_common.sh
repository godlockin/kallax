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

# ── API helpers ────────────────────────────────────────────────────────────

KALLAX_API="${KALLAX_API:-http://127.0.0.1:9877}"

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
