#!/usr/bin/env bash
# KALLAX Dependency Check — audit npm and cargo dependencies
# Usage: ./scripts/dependency-check.sh [--fix]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX_MODE=false
[ "${1:-}" = "--fix" ] && FIX_MODE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

EXIT_CODE=0

echo "=== KALLAX Dependency Check ==="
echo "  Fix mode: ${FIX_MODE}"
echo ""

# ── npm outdated ──────────────────────────────────────────────

NODE_DIR="${PROJECT_ROOT}/node"
echo "--- npm @ ${NODE_DIR} ---"

if [ -f "${NODE_DIR}/package.json" ]; then
  OUTDATED_NPM=$(npm --prefix "$NODE_DIR" outdated 2>/dev/null || true)
  if [ -z "$OUTDATED_NPM" ]; then
    pass "All npm packages up to date"
  else
    OUTDATED_COUNT=$(echo "$OUTDATED_NPM" | tail -n +2 | wc -l | tr -d ' ')
    warn "${OUTDATED_COUNT} npm package(s) outdated:"
    echo "$OUTDATED_NPM" | tail -n +2 | head -20 | while read -r line; do
      PACKAGE=$(echo "$line" | awk '{print $1}')
      CURRENT=$(echo "$line" | awk '{print $3}')
      WANTED=$(echo "$line" | awk '{print $4}')
      LATEST=$(echo "$line" | awk '{print $5}')
      echo "    ${PACKAGE}: ${CURRENT} -> ${WANTED} (latest: ${LATEST})"
    done

    if [ "$FIX_MODE" = true ]; then
      info "Running npm update..."
      npm --prefix "$NODE_DIR" update 2>&1 || warn "npm update had issues"
      pass "npm update completed"
    fi
  fi

  # npm audit
  AUDIT_RESULT=$(npm --prefix "$NODE_DIR" audit --audit-level=high 2>&1 || true)
  if echo "$AUDIT_RESULT" | grep -qi "found 0"; then
    pass "npm audit: no high-severity vulnerabilities"
  else
    VULN_COUNT=$(echo "$AUDIT_RESULT" | grep -i "found" | head -1 || echo "unknown")
    fail "npm audit: ${VULN_COUNT}"
  fi
else
  warn "No node/package.json found — skipping npm check"
fi

echo ""

# ── cargo outdated ────────────────────────────────────────────

RUST_DIR="${PROJECT_ROOT}/rust"
echo "--- Cargo @ ${RUST_DIR} ---"

if [ -f "${RUST_DIR}/Cargo.toml" ]; then
  if command -v cargo &>/dev/null; then
    OUTDATED_CARGO=$(cargo outdated --manifest-path "${RUST_DIR}/Cargo.toml" 2>/dev/null || true)
    if [ -z "$OUTDATED_CARGO" ] || echo "$OUTDATED_CARGO" | grep -q "No updates"; then
      pass "All cargo dependencies up to date"
    else
      # EPIC-254: `|| echo 0` 污染 → "0\n0" 显示成 2 行. 用 `|| true`.
      OUTDATED_RUST_COUNT=$(echo "$OUTDATED_CARGO" | grep -c "^ " 2>/dev/null || true)
      OUTDATED_RUST_COUNT=${OUTDATED_RUST_COUNT:-0}
      warn "${OUTDATED_RUST_COUNT} cargo crate(s) outdated:"
      echo "$OUTDATED_CARGO" | head -30 | while read -r line; do
        echo "    ${line}"
      done

      if [ "$FIX_MODE" = true ]; then
        info "Running cargo update..."
        cargo update --manifest-path "${RUST_DIR}/Cargo.toml" 2>&1 || warn "cargo update had issues"
        pass "cargo update completed"
      fi
    fi

    # cargo audit (if cargo-audit is installed)
    if cargo audit --version &>/dev/null; then
      AUDIT_RUST=$(cargo audit --manifest-path "${RUST_DIR}/Cargo.toml" 2>&1 || true)
      if echo "$AUDIT_RUST" | grep -q "No vulnerabilities found"; then
        pass "cargo audit: no vulnerabilities"
      else
        warn "cargo audit found issues:"
        echo "$AUDIT_RUST" | grep -E "(Vulnerability|CVE|RUSTSEC)" | head -10
      fi
    else
      warn "cargo-audit not installed — skipping advisory check"
    fi
  else
    warn "cargo not found — skipping Rust dependency check"
  fi
else
  warn "No rust/Cargo.toml found — skipping cargo check"
fi

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}=== All dependencies healthy ===${NC}" \
                      || echo -e "${RED}=== Dependency issues found (exit: ${EXIT_CODE}) ===${NC}"
exit $EXIT_CODE
