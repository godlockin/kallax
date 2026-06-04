#!/usr/bin/env bash
# KALLAX Environment Validator — verify .env file completeness and format
# Usage: ./scripts/env-validator.sh [.env path]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-${PROJECT_ROOT}/.env}"
TEMPLATE="${PROJECT_ROOT}/.env.example"
EXIT_CODE=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=== KALLAX Environment Validator ==="
echo ""

# Check file exists
[ -f "$ENV_FILE" ] || { fail ".env file not found at ${ENV_FILE}"; exit 1; }
pass "Found: ${ENV_FILE}"

# Check permissions — should not be world-readable
PERMS=$(stat -f "%Lp" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null || echo "000")
[ "${PERMS: -2}" -le "40" ] 2>/dev/null && pass "Permissions: ${PERMS}" || warn "Permissions: ${PERMS} (should be 600 or 640)"

# Compare against template
if [ -f "$TEMPLATE" ]; then
  echo ""
  echo "--- Checking against template: ${TEMPLATE} ---"
  while IFS='=' read -r key _; do
    key="$(echo "$key" | xargs)"
    [ -z "$key" ] && continue
    [[ "$key" == \#* ]] && continue
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
      VALUE=$(grep "^${key}=" "$ENV_FILE" | cut -d'=' -f2-)
      [ -z "$VALUE" ] && warn "${key}= is empty" || pass "${key} is set"
    else
      fail "Missing key: ${key}"
    fi
  done < <(grep -v '^#' "$TEMPLATE" | grep '=' || true)
fi

# Basic format checks
echo ""
echo "--- Format Checks ---"
while IFS='=' read -r key value; do
  key="$(echo "$key" | xargs)"
  [ -z "$key" ] && continue
  [[ "$key" == \#* ]] && continue
  [ -z "$value" ] && continue

  # Check for trailing whitespace in values
  [[ "$value" =~ [[:space:]]$ ]] && warn "Key '${key}' has trailing whitespace"

  # Check for unquoted values with special chars
  grep -qE "^${key}=[a-zA-Z0-9_./:@-]+$" "$ENV_FILE" 2>/dev/null || true

  # Warn on potential secrets in plaintext
  if [[ "$key" == *"SECRET"* ]] || [[ "$key" == *"PASSWORD"* ]] || [[ "$key" == *"KEY"* ]]; then
    [[ "$value" =~ ^sk- || "$value" =~ ^[A-Za-z0-9]{16,} ]] && \
      warn "Key '${key}' contains a credential — verify this is intentional"
  fi
done < <(grep -v '^#' "$ENV_FILE" | grep '=' || true)

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}All checks passed${NC}" || echo -e "${RED}${EXIT_CODE} issue(s) found${NC}"
exit $EXIT_CODE
