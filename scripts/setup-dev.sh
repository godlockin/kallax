#!/usr/bin/env bash
# KALLAX Dev Setup — one-command initialization for new development environments
# Usage: ./scripts/setup-dev.sh [--force]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FORCE="${1:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "  ${GREEN}[OK]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

cd "$PROJECT_ROOT"

echo "=== KALLAX Development Setup ==="
echo ""

# 1. Check prerequisites
info "Checking prerequisites..."
for cmd in node git bash; do
  command -v "$cmd" &>/dev/null && ok "Found ${cmd}: $($cmd --version 2>&1 | head -1)" \
    || { echo "ERROR: ${cmd} not found"; exit 1; }
done

# 2. Node.js dependencies
info "Installing Node.js dependencies..."
if [ -f package.json ]; then
  npm install 2>&1 | tail -1 && ok "npm install complete" || warn "npm install had warnings"
else
  warn "No package.json found"
fi

# 3. Rust toolchain (optional)
if command -v rustup &>/dev/null && [ -f rust/Cargo.toml ]; then
  info "Setting up Rust toolchain..."
  (cd rust && rustup show && cargo fetch 2>&1 | tail -1) && ok "Rust ready"
fi

# 4. Git hooks
info "Configuring git hooks..."
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"
for hook in pre-commit pre-push; do
  HOOK_PATH="${GIT_HOOKS_DIR}/${hook}"
  if [ ! -f "$HOOK_PATH" ] || [ "$FORCE" = "--force" ]; then
    cat > "$HOOK_PATH" <<-HOOK
#!/bin/bash
exec "${PROJECT_ROOT}/scripts/pre-commit-check.sh"
HOOK
    chmod +x "$HOOK_PATH"
    ok "Installed hook: ${hook}"
  else
    ok "Hook already exists: ${hook}"
  fi
done

# 5. KALLAX config
info "Initializing KALLAX config..."
"${PROJECT_ROOT}/scripts/quick-setup.sh" 2>/dev/null && ok "KALLAX config initialized" \
  || warn "quick-setup.sh failed — run manually: ./scripts/quick-setup.sh"

# 6. Environment file
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  ok "Created .env from .env.example"
elif [ ! -f .env ]; then
  warn "No .env or .env.example found"
else
  ok ".env already exists"
fi

echo ""
info "Setup complete. Run './scripts/pre-commit-check.sh' to verify."
