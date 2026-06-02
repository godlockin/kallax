#!/bin/bash
# KALLAX Health Check Script
# Comprehensive system health monitoring
# Usage: ./scripts/health_check.sh [--json] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Flags
OUTPUT_JSON=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) OUTPUT_JSON=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--json] [--verbose]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors (disabled for JSON output)
if [[ "$OUTPUT_JSON" == false ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Health status tracking
declare -A HEALTH_STATUS
OVERALL_STATUS="healthy"

check_status() {
    local name="$1"
    local status="$2"
    local message="${3:-}"

    HEALTH_STATUS["$name"]="$status"

    if [[ "$status" == "error" ]]; then
        OVERALL_STATUS="unhealthy"
    elif [[ "$status" == "warning" && "$OVERALL_STATUS" == "healthy" ]]; then
        OVERALL_STATUS="degraded"
    fi

    if [[ "$OUTPUT_JSON" == false ]]; then
        case "$status" in
            ok) echo -e "${GREEN}[OK]${NC} $name: $message" ;;
            warning) echo -e "${YELLOW}[WARN]${NC} $name: $message" ;;
            error) echo -e "${RED}[ERROR]${NC} $name: $message" ;;
        esac
    fi
}

# ============================================================
# System Checks
# ============================================================
check_nodejs() {
    if ! command -v node &>/dev/null; then
        check_status "nodejs" "error" "not installed"
        return
    fi

    local version
    version=$(node -v | sed 's/v//')
    local major
    major=$(echo "$version" | cut -d. -f1)

    if [[ "$major" -lt 20 ]]; then
        check_status "nodejs" "warning" "v$version (>= 20 recommended)"
    else
        check_status "nodejs" "ok" "v$version"
    fi
}

check_rust() {
    if ! command -v rustc &>/dev/null; then
        check_status "rust" "warning" "not installed (optional)"
        return
    fi

    local version
    version=$(rustc --version | cut -d' ' -f2)
    check_status "rust" "ok" "v$version"
}

check_redis() {
    if ! command -v redis-cli &>/dev/null; then
        check_status "redis" "warning" "not installed (optional)"
        return
    fi

    if redis-cli ping &>/dev/null; then
        local info
        info=$(redis-cli info server 2>/dev/null | grep redis_version | cut -d: -f2 | tr -d '\r')
        check_status "redis" "ok" "v$info running"
    else
        check_status "redis" "warning" "not running"
    fi
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        check_status "docker" "warning" "not installed (optional)"
        return
    fi

    if docker info &>/dev/null; then
        local version
        version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        check_status "docker" "ok" "v$version running"
    else
        check_status "docker" "warning" "daemon not running"
    fi
}

check_git() {
    if ! command -v git &>/dev/null; then
        check_status "git" "error" "not installed"
        return
    fi

    local version
    version=$(git --version | cut -d' ' -f3)
    check_status "git" "ok" "v$version"
}

# ============================================================
# Project Checks
# ============================================================
check_directories() {
    local dirs=(".kallax" ".kallax/config" ".kallax/state" ".kallax/logs" "node" "rust")
    local missing=()

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            missing+=("$dir")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        check_status "directories" "ok" "all present"
    else
        check_status "directories" "warning" "missing: ${missing[*]}"
    fi
}

check_config() {
    local config="$PROJECT_ROOT/.kallax/config.yml"

    if [[ ! -f "$config" ]]; then
        check_status "config" "error" "config.yml not found"
        return
    fi

    # Basic YAML validation
    if command -v yq &>/dev/null; then
        if yq eval '.' "$config" &>/dev/null; then
            check_status "config" "ok" "valid YAML"
        else
            check_status "config" "error" "invalid YAML syntax"
        fi
    else
        check_status "config" "ok" "present (yq not available for validation)"
    fi
}

check_node_modules() {
    if [[ ! -d "$PROJECT_ROOT/node_modules" ]]; then
        check_status "node_modules" "warning" "not installed (run npm install)"
        return
    fi

    local count
    count=$(find "$PROJECT_ROOT/node_modules" -maxdepth 1 -type d | wc -l | tr -d ' ')
    check_status "node_modules" "ok" "$count packages"
}

check_rust_build() {
    local target="$PROJECT_ROOT/rust/target/release"

    if [[ ! -d "$PROJECT_ROOT/rust" ]]; then
        check_status "rust_build" "warning" "rust/ not found"
        return
    fi

    if [[ -d "$target" ]]; then
        check_status "rust_build" "ok" "release build exists"
    else
        check_status "rust_build" "warning" "not built (run cargo build --release)"
    fi
}

# ============================================================
# Resource Checks
# ============================================================
check_disk_space() {
    local available
    available=$(df -h "$PROJECT_ROOT" | tail -1 | awk '{print $4}')
    local percent_used
    percent_used=$(df -h "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | tr -d '%')

    if [[ "$percent_used" -gt 90 ]]; then
        check_status "disk_space" "error" "$available available ($percent_used% used)"
    elif [[ "$percent_used" -gt 75 ]]; then
        check_status "disk_space" "warning" "$available available ($percent_used% used)"
    else
        check_status "disk_space" "ok" "$available available"
    fi
}

check_memory() {
    local mem_info
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        local total
        total=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        local used
        used=$(vm_stat | grep "Pages active" | awk '{print int($3*4096/1024/1024/1024)}')
        mem_info="${used}G / ${total}G"
        local percent=$((used * 100 / total))
    else
        # Linux
        mem_info=$(free -h | grep Mem | awk '{print $3 " / " $2}')
        local percent
        percent=$(free | grep Mem | awk '{print int($3/$2*100)}')
    fi

    if [[ "${percent:-0}" -gt 90 ]]; then
        check_status "memory" "error" "$mem_info"
    elif [[ "${percent:-0}" -gt 75 ]]; then
        check_status "memory" "warning" "$mem_info"
    else
        check_status "memory" "ok" "$mem_info"
    fi
}

# ============================================================
# Service Checks
# ============================================================
check_kallax_server() {
    local port=9877

    if lsof -i ":$port" &>/dev/null; then
        check_status "kallax_server" "ok" "running on port $port"
    else
        check_status "kallax_server" "warning" "not running"
    fi
}

check_web_dashboard() {
    local port=3000

    if lsof -i ":$port" &>/dev/null; then
        check_status "web_dashboard" "ok" "running on port $port"
    else
        check_status "web_dashboard" "warning" "not running"
    fi
}

# ============================================================
# Output
# ============================================================
output_json() {
    echo "{"
    echo "  \"status\": \"$OVERALL_STATUS\","
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"checks\": {"

    local first=true
    for key in "${!HEALTH_STATUS[@]}"; do
        if [[ "$first" == false ]]; then
            echo ","
        fi
        first=false
        echo -n "    \"$key\": \"${HEALTH_STATUS[$key]}\""
    done

    echo ""
    echo "  }"
    echo "}"
}

# ============================================================
# Main
# ============================================================
main() {
    if [[ "$OUTPUT_JSON" == false ]]; then
        echo ""
        echo "========================================"
        echo "  KALLAX Health Check"
        echo "========================================"
        echo ""
        echo "=== System Dependencies ==="
    fi

    check_nodejs
    check_rust
    check_redis
    check_docker
    check_git

    if [[ "$OUTPUT_JSON" == false ]]; then
        echo ""
        echo "=== Project Structure ==="
    fi

    check_directories
    check_config
    check_node_modules
    check_rust_build

    if [[ "$OUTPUT_JSON" == false ]]; then
        echo ""
        echo "=== System Resources ==="
    fi

    check_disk_space
    check_memory

    if [[ "$OUTPUT_JSON" == false ]]; then
        echo ""
        echo "=== Services ==="
    fi

    check_kallax_server
    check_web_dashboard

    if [[ "$OUTPUT_JSON" == true ]]; then
        output_json
    else
        echo ""
        echo "========================================"
        case "$OVERALL_STATUS" in
            healthy) echo -e "  Status: ${GREEN}HEALTHY${NC}" ;;
            degraded) echo -e "  Status: ${YELLOW}DEGRADED${NC}" ;;
            unhealthy) echo -e "  Status: ${RED}UNHEALTHY${NC}" ;;
        esac
        echo "========================================"
        echo ""
    fi

    # Exit code based on status
    case "$OVERALL_STATUS" in
        healthy) exit 0 ;;
        degraded) exit 0 ;;
        unhealthy) exit 1 ;;
    esac
}

main "$@"
