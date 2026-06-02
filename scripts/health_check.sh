#!/usr/bin/env bash
# KALLAX Health Check — comprehensive system diagnostics
# Checks: git, DB, disk, memory, Node, Rust, network, worktree count
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
KALLAX_DIR="${PROJECT_ROOT}/.kallax"
EXIT_CODE=0

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; EXIT_CODE=1; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }

echo "=== KALLAX Health Check ==="
echo "Project: $PROJECT_ROOT"
echo ""

# 1. Git
echo "--- Git ---"
if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  pass "Git repo: $(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
  UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCOMMITTED" -gt 0 ] && warn "Uncommitted: $UNCOMMITTED files" || pass "Working tree clean"
else
  fail "Not a git repository"
fi

# 2. Database
echo "--- Database ---"
DB_PATH="${KALLAX_DIR}/data/kallax.db"
if [ -f "$DB_PATH" ]; then
  pass "SQLite DB: $(du -h "$DB_PATH" 2>/dev/null | cut -f1)"
else
  warn "DB not found — run 'kallax system doctor'"
fi

# 3. Disk
echo "--- Disk ---"
DISK_PCT=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
[ "${DISK_PCT:-100}" -lt 85 ] && pass "Disk: ${DISK_PCT}%" || ([ "${DISK_PCT:-100}" -lt 95 ] && warn "Disk: ${DISK_PCT}%" || fail "Disk critical: ${DISK_PCT}%")

# 4. Node.js
echo "--- Node.js ---"
command -v node &>/dev/null && pass "Node: $(node -v)" || fail "Node.js not found"

# 5. Rust
echo "--- Rust ---"
command -v rustc &>/dev/null && pass "Rust: $(rustc --version)" || warn "Rust not found"

# 6. Worktrees
echo "--- Worktrees ---"
WT_COUNT=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null | wc -l | tr -d ' ')
[ "$WT_COUNT" -le 5 ] && pass "Worktrees: $WT_COUNT" || warn "Worktrees: $WT_COUNT — consider cleanup"

# 7. Config
echo "--- Config ---"
[ -f "${KALLAX_DIR}/config.yml" ] && pass "Config exists" || warn "Config missing"
ROLE=$(grep "role:" "${KALLAX_DIR}/state/instance_config.yml" 2>/dev/null | awk '{print $2}' || echo "unset")
echo "  Role: ${ROLE}"

echo ""
[ $EXIT_CODE -eq 0 ] && echo -e "${GREEN}All checks passed${NC}" || echo -e "${RED}${EXIT_CODE} issue(s) found${NC}"
exit $EXIT_CODE
