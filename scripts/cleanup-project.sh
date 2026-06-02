#!/bin/bash
# KALLAX Project Cleanup Script
# Clean up build artifacts, caches, and temporary files
# Usage: ./scripts/cleanup-project.sh [--all] [--dry-run] [--keep-logs]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Flags
CLEAN_ALL=false
DRY_RUN=false
KEEP_LOGS=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all) CLEAN_ALL=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --keep-logs) KEEP_LOGS=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--all] [--dry-run] [--keep-logs] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --all        Clean everything including node_modules"
            echo "  --dry-run    Show what would be deleted"
            echo "  --keep-logs  Preserve log files"
            echo "  --verbose    Show detailed output"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_action() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would delete: $1"
    elif [[ "$VERBOSE" == true ]]; then
        echo -e "  ${GREEN}[DELETE]${NC} $1"
    fi
}

# Calculate size of a path
get_size() {
    du -sh "$1" 2>/dev/null | cut -f1 || echo "0"
}

# Delete with tracking
deleted_size=0
deleted_count=0

safe_delete() {
    local path="$1"
    local description="${2:-$path}"

    if [[ ! -e "$path" ]]; then
        return
    fi

    local size
    size=$(get_size "$path")

    log_action "$description ($size)"
    ((deleted_count++))

    if [[ "$DRY_RUN" == false ]]; then
        rm -rf "$path"
    fi
}

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  KALLAX Project Cleanup"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_warn "DRY RUN MODE - No files will be deleted"
    echo ""
fi

# ============================================================
# Build Artifacts
# ============================================================
log_info "Cleaning build artifacts..."

# Node.js dist
safe_delete "$PROJECT_ROOT/node/dist" "Node.js build output"

# Rust target
safe_delete "$PROJECT_ROOT/rust/target" "Rust build output"

# TypeScript incremental
find "$PROJECT_ROOT" -name "*.tsbuildinfo" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "TypeScript build info"
done

# ============================================================
# Caches
# ============================================================
log_info "Cleaning caches..."

# npm cache in project
safe_delete "$PROJECT_ROOT/.npm" "npm cache"

# ESLint cache
find "$PROJECT_ROOT" -name ".eslintcache" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "ESLint cache"
done

# Jest cache
safe_delete "$PROJECT_ROOT/node/.jest-cache" "Jest cache"

# Turborepo cache
safe_delete "$PROJECT_ROOT/.turbo" "Turborepo cache"

# Vite cache
find "$PROJECT_ROOT" -name ".vite" -type d 2>/dev/null | while read -r d; do
    safe_delete "$d" "Vite cache"
done

# ============================================================
# Temporary Files
# ============================================================
log_info "Cleaning temporary files..."

# .DS_Store
find "$PROJECT_ROOT" -name ".DS_Store" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "macOS metadata"
done

# Vim swap files
find "$PROJECT_ROOT" -name "*.swp" -o -name "*.swo" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "Vim swap"
done

# Editor backups
find "$PROJECT_ROOT" -name "*~" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "Editor backup"
done

# Temp directories
safe_delete "$PROJECT_ROOT/tmp" "Temp directory"
safe_delete "$PROJECT_ROOT/.tmp" "Hidden temp directory"

# ============================================================
# Test Artifacts
# ============================================================
log_info "Cleaning test artifacts..."

# Coverage reports
safe_delete "$PROJECT_ROOT/coverage" "Coverage reports"
safe_delete "$PROJECT_ROOT/node/coverage" "Node coverage"

# Test outputs
find "$PROJECT_ROOT" -path "*/test-results/*" -type f 2>/dev/null | while read -r f; do
    safe_delete "$f" "Test result"
done

# ============================================================
# Logs (optional)
# ============================================================
if [[ "$KEEP_LOGS" == false ]]; then
    log_info "Cleaning logs..."

    safe_delete "$PROJECT_ROOT/logs" "Log files"
    safe_delete "$PROJECT_ROOT/.kallax/logs" "KALLAX logs"

    find "$PROJECT_ROOT" -name "*.log" -type f 2>/dev/null | while read -r f; do
        safe_delete "$f" "Log file"
    done
else
    log_info "Keeping logs (--keep-logs)"
fi

# ============================================================
# KALLAX State (optional with --all)
# ============================================================
if [[ "$CLEAN_ALL" == true ]]; then
    log_info "Cleaning KALLAX state..."

    safe_delete "$PROJECT_ROOT/.kallax/queue" "Queue data"
    safe_delete "$PROJECT_ROOT/.kallax/dag-runs" "DAG run history"

    # Keep config and templates
    log_info "Preserving: .kallax/config, .kallax/templates"
fi

# ============================================================
# Dependencies (only with --all)
# ============================================================
if [[ "$CLEAN_ALL" == true ]]; then
    log_info "Cleaning dependencies (--all mode)..."

    safe_delete "$PROJECT_ROOT/node_modules" "Root node_modules"
    safe_delete "$PROJECT_ROOT/node/node_modules" "Node workspace modules"

    # Package lock (optional, regenerates on install)
    # safe_delete "$PROJECT_ROOT/package-lock.json" "Package lock"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════════"

if [[ "$DRY_RUN" == true ]]; then
    echo "  Would delete $deleted_count items"
    echo ""
    echo "  Run without --dry-run to actually delete"
else
    echo -e "  ${GREEN}Cleanup complete!${NC}"
    echo "  Deleted $deleted_count items"

    if [[ "$CLEAN_ALL" == true ]]; then
        echo ""
        echo "  Run 'npm install' to restore dependencies"
    fi
fi

echo "════════════════════════════════════════════════════════════════"
echo ""
