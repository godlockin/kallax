#!/usr/bin/env bash
# KALLAX Forbidden Pattern Scanner
# CI gate — catches forbidden patterns before they reach production.
# Fail-fast: crash at scan time, not at 2 AM.

set -euo pipefail

EXIT_CODE=0
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error()   { echo -e "${RED}[FORBIDDEN]${NC} $*"; EXIT_CODE=1; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $*"; }

echo "=== KALLAX Forbidden Pattern Scan ==="
echo ""

# ── Rust patterns ──────────────────────────────────────────────────────────

echo "--- Rust ---"

scan_rust() {
  local pattern="$1"
  local label="$2"
  local severity="${3:-error}"

  local matches
  matches=$(find "$PROJECT_ROOT/rust" -name '*.rs' -type f \
    -exec grep -Hn "$pattern" {} + 2>/dev/null || true)

  if [ -n "$matches" ]; then
    if [ "$severity" = "error" ]; then
      log_error "$label found:"
      echo "$matches" | while read -r line; do
        echo "  $line"
      done
    else
      log_warn "$label found:"
      echo "$matches" | while read -r line; do
        echo "  $line"
      done
    fi
  else
    log_ok "No $label detected"
  fi
}

# Note: .unwrap()/.expect() in #[cfg(test)] is acceptable.
# These scan as warning because many matches are in test modules.
scan_rust '\.expect('      '.expect() — use Result propagation instead' 'warning'
scan_rust '\.unwrap()'     '.unwrap() — use ? operator instead' 'warning'
scan_rust 'panic!'         'panic!     — use Result<T,E> instead'

echo ""

# ── TypeScript patterns ────────────────────────────────────────────────────

echo "--- TypeScript ---"

scan_ts() {
  local pattern="$1"
  local label="$2"
  local severity="${3:-error}"

  # Exclude test files, node_modules, and generated code
  local matches
  matches=$(find "$PROJECT_ROOT/node/src" -name '*.ts' -type f \
    ! -name '*.test.ts' \
    -exec grep -Hn "$pattern" {} + 2>/dev/null || true)

  if [ -n "$matches" ]; then
    if [ "$severity" = "error" ]; then
      log_error "$label found:"
      echo "$matches" | while read -r line; do
        echo "  $line"
      done
    else
      log_warn "$label found:"
      echo "$matches" | while read -r line; do
        echo "  $line"
      done
    fi
  else
    log_ok "No $label detected"
  fi
}

scan_ts ': any[^=]'        ': any type annotation — use unknown + type guards'
scan_ts '@ts-ignore'       '@ts-ignore — fix the type error instead'
scan_ts '@ts-expect-error' '@ts-expect-error — use proper types'
scan_ts 'console\.log'     'console.log — use structured logger instead' 'warning'

# Check empty catch blocks
EMPTY_CATCH=$(find "$PROJECT_ROOT/node/src" -name '*.ts' -type f \
  -exec grep -Hn 'catch.*{.*}' {} + 2>/dev/null || true)
if [ -n "$EMPTY_CATCH" ]; then
  log_error "Empty catch blocks found (silent error swallowing):"
  echo "$EMPTY_CATCH" | while read -r line; do
    echo "  $line"
  done
else
  log_ok "No empty catch blocks detected"
fi

echo ""

# ── LLM Marker patterns ────────────────────────────────────────────────────

echo "--- LLM Markers ---"

scan_ts "Let's\|Now let's\|Here we\|Simply put\|Basically\|It's worth noting" 'LLM filler phrase — remove hedging/filler language' 'warning'
scan_ts "^---$" 'Em-dash separator (---) in code — use // comments instead' 'warning'
scan_ts "TODO:\|FIXME:" 'Bare TODO/FIXME without ticket reference — use TODO(TASK-NNN)' 'warning'
scan_ts "Please ensure\|Kindly\|Thank you for" 'Overly polite comment — use direct language' 'warning'

echo ""

# ── Secret patterns ────────────────────────────────────────────────────────

echo "--- Secrets ---"

SECRET_PATTERNS=(
  "ghp_[a-zA-Z0-9]{36}"
  "gho_[a-zA-Z0-9]{36}"
  "ghu_[a-zA-Z0-9]{36}"
  "ghs_[a-zA-Z0-9]{36}"
  "ghr_[a-zA-Z0-9]{36}"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  SECRET_MATCHES=$(find "$PROJECT_ROOT" \
    -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/target/*' \
    ! -name '*.lock' \
    ! -name "$(basename "$0")" \
    -exec grep -Hn "$pattern" {} + 2>/dev/null || true)
  if [ -n "$SECRET_MATCHES" ]; then
    log_error "Possible secret detected (GitHub token pattern):"
    echo "$SECRET_MATCHES" | while read -r line; do
      echo "  $line"
    done
  fi
done

log_ok "Secret scan complete"

echo ""

# ── Summary ────────────────────────────────────────────────────────────────

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}=== All scans passed ===${NC}"
else
  echo -e "${RED}=== Forbidden patterns detected — fix before commit ===${NC}"
fi

exit $EXIT_CODE
