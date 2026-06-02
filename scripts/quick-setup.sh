#!/bin/bash
# KALLAX Quick Setup Script
# Automatically detects and installs Rust/Node.js dependencies
# Usage: ./scripts/quick-setup.sh [--skip-rust] [--skip-node] [--skip-init]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Flags
SKIP_RUST=false
SKIP_NODE=false
SKIP_INIT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-rust) SKIP_RUST=true; shift ;;
        --skip-node) SKIP_NODE=true; shift ;;
        --skip-init) SKIP_INIT=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--skip-rust] [--skip-node] [--skip-init]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_command() {
    command -v "$1" &> /dev/null
}

# ============================================================
# Node.js Check
# ============================================================
check_nodejs() {
    log_info "Checking Node.js..."

    if ! check_command node; then
        log_error "Node.js not found"
        log_info "Install via: brew install node@20 OR nvm install 20"
        return 1
    fi

    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d. -f1)

    if [[ "$node_version" -lt 20 ]]; then
        log_error "Node.js >= 20 required (found: v$node_version)"
        log_info "Upgrade via: nvm install 20 && nvm use 20"
        return 1
    fi

    log_success "Node.js $(node -v) detected"
    return 0
}

# ============================================================
# Rust Check
# ============================================================
check_rust() {
    log_info "Checking Rust toolchain..."

    if ! check_command rustc; then
        log_warn "Rust not found"
        log_info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    if ! check_command cargo; then
        log_error "Cargo not found after Rust installation"
        return 1
    fi

    log_success "Rust $(rustc --version | cut -d' ' -f2) detected"
    return 0
}

# ============================================================
# Install npm dependencies
# ============================================================
install_npm_deps() {
    log_info "Installing npm dependencies..."

    cd "$PROJECT_ROOT"

    if [[ -f "package-lock.json" ]]; then
        npm ci
    else
        npm install
    fi

    log_success "npm dependencies installed"
}

# ============================================================
# Build Rust
# ============================================================
build_rust() {
    log_info "Building Rust components..."

    if [[ ! -d "$PROJECT_ROOT/rust" ]]; then
        log_warn "rust/ directory not found, skipping Rust build"
        return 0
    fi

    cd "$PROJECT_ROOT/rust"
    cargo build --release

    log_success "Rust build completed"
}

# ============================================================
# Initialize .kallax directory
# ============================================================
init_kallax() {
    log_info "Initializing .kallax directory..."

    local kallax_dir="$PROJECT_ROOT/.kallax"

    # Create directories
    mkdir -p "$kallax_dir"/{config,data,instances,logs,memory,queue,state,templates,inbox,dag-runs}

    # Create IDENTITY.md if not exists
    if [[ ! -f "$kallax_dir/IDENTITY.md" ]]; then
        cat > "$kallax_dir/IDENTITY.md" << 'EOF'
# KALLAX Instance Identity

## System Information
- **Framework**: KALLAX (Knowledge-Augmented Leveraged Learning Agent eXecutor)
- **Version**: 1.0.0
- **Mode**: claude_code

## Instance Configuration
- **Profile**: standard
- **Max Parallel Performers**: 5
- **Worktree Isolation**: enabled

## Capabilities
- Multi-agent orchestration (Conductor-Performer pattern)
- Automatic degradation (Rust → Node.js → Shell)
- Worktree-based parallel execution
- 4-Level Fact-Forcing verification
EOF
        log_success "Created IDENTITY.md"
    fi

    # Create default config.yml if not exists
    if [[ ! -f "$kallax_dir/config.yml" ]]; then
        cp "$PROJECT_ROOT/template/config.yml" "$kallax_dir/config.yml" 2>/dev/null || \
        log_warn "No template config found, using existing config"
    fi

    log_success ".kallax directory initialized"
}

# ============================================================
# Run system doctor
# ============================================================
run_doctor() {
    log_info "Running system:doctor..."

    cd "$PROJECT_ROOT"

    # Check if npm script exists
    if npm run --silent 2>&1 | grep -q "system:doctor"; then
        npm run system:doctor
    else
        # Manual health checks
        log_info "Running manual health checks..."

        echo ""
        echo "=== System Health Check ==="
        echo ""

        # Node.js
        echo -n "Node.js: "
        node -v

        # npm
        echo -n "npm: "
        npm -v

        # Rust
        if check_command rustc; then
            echo -n "Rust: "
            rustc --version | cut -d' ' -f2
        else
            echo "Rust: not installed"
        fi

        # Redis
        if check_command redis-cli; then
            echo -n "Redis: "
            if redis-cli ping &>/dev/null; then
                echo "running"
            else
                echo "not running"
            fi
        else
            echo "Redis: not installed (optional)"
        fi

        # Docker
        if check_command docker; then
            echo -n "Docker: "
            if docker info &>/dev/null; then
                echo "running"
            else
                echo "not running"
            fi
        else
            echo "Docker: not installed (optional)"
        fi

        echo ""
        echo "=== Directory Structure ==="
        echo ""

        [[ -d "$PROJECT_ROOT/.kallax" ]] && echo "[OK] .kallax/" || echo "[MISSING] .kallax/"
        [[ -d "$PROJECT_ROOT/node" ]] && echo "[OK] node/" || echo "[MISSING] node/"
        [[ -d "$PROJECT_ROOT/rust" ]] && echo "[OK] rust/" || echo "[MISSING] rust/"
        [[ -f "$PROJECT_ROOT/.kallax/config.yml" ]] && echo "[OK] .kallax/config.yml" || echo "[MISSING] .kallax/config.yml"

        echo ""
    fi

    log_success "System check completed"
}

# ============================================================
# Main
# ============================================================
main() {
    echo ""
    echo "========================================"
    echo "  KALLAX Quick Setup"
    echo "  Knowledge-Augmented Leveraged Learning"
    echo "  Agent eXecutor"
    echo "========================================"
    echo ""

    cd "$PROJECT_ROOT"

    # Node.js check (required)
    if [[ "$SKIP_NODE" == false ]]; then
        if ! check_nodejs; then
            log_error "Node.js check failed"
            exit 1
        fi
    fi

    # Rust check (optional but recommended)
    if [[ "$SKIP_RUST" == false ]]; then
        check_rust || log_warn "Rust unavailable, will use Node.js fallback"
    fi

    echo ""

    # Install npm dependencies
    if [[ "$SKIP_NODE" == false ]]; then
        install_npm_deps
    fi

    # Build Rust
    if [[ "$SKIP_RUST" == false ]]; then
        build_rust || log_warn "Rust build failed, continuing with Node.js only"
    fi

    echo ""

    # Initialize .kallax
    if [[ "$SKIP_INIT" == false ]]; then
        init_kallax
    fi

    echo ""

    # Run doctor
    run_doctor

    echo ""
    echo "========================================"
    echo "  Setup Complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. Review .kallax/config.yml"
    echo "  2. Start server: npm start"
    echo "  3. Open dashboard: npm run web"
    echo ""
}

main "$@"
