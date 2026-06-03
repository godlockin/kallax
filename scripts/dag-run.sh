#!/usr/bin/env bash
# KALLAX DAG Runner — wrapper for `kallax epic:run` with environment checks
# Usage: ./scripts/dag-run.sh [epic-name] [--dry-run]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KALLAX_DIR="${PROJECT_ROOT}/.kallax"
DRY_RUN=false
EPIC_NAME="${1:-}"
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

echo "=== KALLAX DAG Run: ${EPIC_NAME:-<unspecified>} ==="
echo ""

# ── Pre-flight checks ──────────────────────────────────────────

[ -n "$EPIC_NAME" ] || fail "Usage: $0 <epic-name> [--dry-run]"

info "Checking prerequisites..."

command -v kallax &>/dev/null || fail "kallax CLI not found in PATH"
pass "kallax CLI found"

[ -f "${KALLAX_DIR}/config.yml" ] || fail "Config not found at ${KALLAX_DIR}/config.yml"
pass "Config exists"

ROLE=$(grep "role:" "${KALLAX_DIR}/state/instance_config.yml" 2>/dev/null | awk '{print $2}' || echo "")
[ "$ROLE" = "conductor" ] || warn "Role is '$ROLE' — DAG runs typically performed by Conductor"

GIT_CLEAN=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[ "$GIT_CLEAN" -eq 0 ] || warn "Uncommitted changes: ${GIT_CLEAN} file(s)"

# Check for existing epic in progress to avoid collision
EPIC_MARKER="${KALLAX_DIR}/state/epic_${EPIC_NAME}.lock"
if [ -f "$EPIC_MARKER" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$EPIC_MARKER" 2>/dev/null || echo 0) ))
  fail "Epic '${EPIC_NAME}' already in progress (locked ${LOCK_AGE}s ago)"
fi

# ── Execute ─────────────────────────────────────────────────────

echo ""
info "Starting DAG execution for epic: ${EPIC_NAME}"

if [ "$DRY_RUN" = true ]; then
  info "[DRY RUN] Would execute: kallax epic:run \"${EPIC_NAME}\""
  echo ""
  info "Environment checks passed. Run without --dry-run to execute."
  exit 0
fi

# Create lock
date +%s > "$EPIC_MARKER"
trap 'rm -f "$EPIC_MARKER"' EXIT

kallax epic:run "${EPIC_NAME}"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  pass "DAG execution completed: ${EPIC_NAME}"
else
  fail "DAG execution failed with exit code ${EXIT_CODE}"
fi
