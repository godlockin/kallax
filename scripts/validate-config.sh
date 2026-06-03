#!/usr/bin/env bash
# KALLAX Config Validator — validate .kallax/config.yml structure and values
# Usage: ./scripts/validate-config.sh [--strict]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/.kallax/config.yml"
STRICT=false
[ "${1:-}" = "--strict" ] && STRICT=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

EXIT_CODE=0

echo "=== KALLAX Config Validation ==="
echo "  File: ${CONFIG_FILE}"
echo ""

[ -f "$CONFIG_FILE" ] || { fail "Config file not found at ${CONFIG_FILE}"; exit 1; }

# ── Parse and validate key fields ──────────────────────────────

info "Checking required top-level keys..."

# Use grep-based validation (no yq dependency needed)
REQUIRED_KEYS="version mode profile degradation isolation resources error_handling verification logging monitoring server dashboard"
for key in $REQUIRED_KEYS; do
  if grep -q "^${key}:" "$CONFIG_FILE" 2>/dev/null; then
    pass "Key '${key}' present"
  else
    if [ "$STRICT" = true ]; then
      fail "Missing required key: ${key}"
    else
      warn "Missing key: ${key} (non-strict mode)"
    fi
  fi
done

# ── Validate version ───────────────────────────────────────────

VERSION=$(grep '^version:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'"'" 2>/dev/null || echo "")
if [ -n "$VERSION" ]; then
  if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "Version format valid: ${VERSION}"
  else
    fail "Version format invalid: ${VERSION} (expected semver)"
  fi
fi

# ── Validate isolation settings ────────────────────────────────

MAX_PARALLEL=$(grep 'max_parallel_performers:' "$CONFIG_FILE" | awk '{print $2}' 2>/dev/null || echo "")
if [ -n "$MAX_PARALLEL" ]; then
  [ "$MAX_PARALLEL" -le 10 ] 2>/dev/null || warn "max_parallel_performers=${MAX_PARALLEL} is high (>10)"
fi

# ── Validate server port ───────────────────────────────────────

SERVER_PORT=$(grep 'port:' "$CONFIG_FILE" | head -1 | awk '{print $2}' 2>/dev/null || echo "")
if [ -n "$SERVER_PORT" ]; then
  [ "$SERVER_PORT" -ge 1024 ] 2>/dev/null || fail "Server port ${SERVER_PORT} is privileged (<1024)"
  [ "$SERVER_PORT" -le 65535 ] 2>/dev/null || fail "Server port ${SERVER_PORT} out of range"
fi

# ── Validate logging config ────────────────────────────────────

LOG_LEVEL=$(grep 'level:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo "")
case "$LOG_LEVEL" in
  debug|info|warn|error) pass "Log level: ${LOG_LEVEL}" ;;
  "") warn "Log level not specified" ;;
  *)  fail "Invalid log level: ${LOG_LEVEL} (expected debug|info|warn|error)" ;;
esac

# ── Validate resources ─────────────────────────────────────────

LRU_MAX=$(grep 'max_entries:' "$CONFIG_FILE" | awk '{print $2}' 2>/dev/null || echo "")
if [ -n "$LRU_MAX" ]; then
  [ "$LRU_MAX" -ge 1 ] 2>/dev/null || fail "max_entries must be >= 1"
  [ "$LRU_MAX" -le 100000 ] 2>/dev/null || warn "max_entries=${LRU_MAX} is very high"
fi

# ── YAML syntax check (if python3 available) ──────────────────

if command -v python3 &>/dev/null; then
  info "Performing YAML syntax check..."
  if python3 -c "
import yaml, sys
try:
  with open('${CONFIG_FILE}') as f:
    yaml.safe_load(f)
  print('OK')
except Exception as e:
  print(f'ERROR: {e}')
  sys.exit(1)
" 2>/dev/null; then
    pass "YAML syntax is valid"
  else
    fail "YAML syntax is invalid"
    python3 -c "
import yaml, sys
try:
  with open('${CONFIG_FILE}') as f:
    yaml.safe_load(f)
except Exception as e:
  print(f'  ${RED}Details: {e}${NC}')
" 2>/dev/null || true
  fi
else
  warn "python3 not found — skipping YAML syntax validation"
fi

# ── Summary ─────────────────────────────────────────────────────

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}=== Configuration is valid ===${NC}"
else
  echo -e "${RED}=== Configuration has ${EXIT_CODE} issue(s) ===${NC}"
fi
exit $EXIT_CODE
