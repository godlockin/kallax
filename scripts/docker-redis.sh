#!/bin/bash
# KALLAX Docker Redis Management Script
# Start/stop/manage Redis container for development
# Usage: ./scripts/docker-redis.sh [start|stop|restart|status|logs|cli]

set -euo pipefail

CONTAINER_NAME="kallax-redis"
REDIS_PORT="${KALLAX_REDIS_PORT:-6379}"
REDIS_PASSWORD="${KALLAX_REDIS_PASSWORD:-}"
REDIS_DATA_DIR="${KALLAX_REDIS_DATA:-$HOME/.kallax/redis-data}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker not installed"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon not running"
        exit 1
    fi
}

container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

start_redis() {
    check_docker

    if container_running; then
        log_warn "Redis container already running"
        return
    fi

    # Create data directory
    mkdir -p "$REDIS_DATA_DIR"

    # Build command
    local cmd="docker run -d --name $CONTAINER_NAME"
    cmd+=" -p $REDIS_PORT:6379"
    cmd+=" -v $REDIS_DATA_DIR:/data"
    cmd+=" --restart unless-stopped"

    # Add password if set
    if [[ -n "$REDIS_PASSWORD" ]]; then
        cmd+=" -e REDIS_PASSWORD=$REDIS_PASSWORD"
        cmd+=" redis:7-alpine redis-server --appendonly yes --requirepass $REDIS_PASSWORD"
    else
        cmd+=" redis:7-alpine redis-server --appendonly yes"
    fi

    if container_exists; then
        log_info "Starting existing container..."
        docker start "$CONTAINER_NAME"
    else
        log_info "Creating new Redis container..."
        eval "$cmd"
    fi

    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if docker exec "$CONTAINER_NAME" redis-cli ping &>/dev/null; then
            log_success "Redis started on port $REDIS_PORT"
            return
        fi
        sleep 0.5
        ((attempt++))
    done

    log_error "Redis failed to start"
    exit 1
}

stop_redis() {
    check_docker

    if ! container_running; then
        log_warn "Redis container not running"
        return
    fi

    log_info "Stopping Redis container..."
    docker stop "$CONTAINER_NAME"
    log_success "Redis stopped"
}

restart_redis() {
    stop_redis
    sleep 1
    start_redis
}

status_redis() {
    check_docker

    echo ""
    echo "=== Redis Container Status ==="
    echo ""

    if ! container_exists; then
        echo "Status: NOT CREATED"
        echo ""
        return
    fi

    if container_running; then
        echo -e "Status: ${GREEN}RUNNING${NC}"
        echo ""

        # Container info
        docker inspect "$CONTAINER_NAME" --format '
Container ID: {{.Id}}
Image: {{.Config.Image}}
Created: {{.Created}}
Port: {{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}
' | head -5

        echo ""

        # Redis info
        if [[ -n "$REDIS_PASSWORD" ]]; then
            docker exec "$CONTAINER_NAME" redis-cli -a "$REDIS_PASSWORD" INFO server 2>/dev/null | grep -E "redis_version|uptime_in_seconds|connected_clients" || true
        else
            docker exec "$CONTAINER_NAME" redis-cli INFO server 2>/dev/null | grep -E "redis_version|uptime_in_seconds|connected_clients" || true
        fi
    else
        echo -e "Status: ${YELLOW}STOPPED${NC}"
    fi

    echo ""
}

logs_redis() {
    check_docker

    if ! container_exists; then
        log_error "Redis container does not exist"
        exit 1
    fi

    docker logs -f "$CONTAINER_NAME"
}

cli_redis() {
    check_docker

    if ! container_running; then
        log_error "Redis container not running"
        exit 1
    fi

    if [[ -n "$REDIS_PASSWORD" ]]; then
        docker exec -it "$CONTAINER_NAME" redis-cli -a "$REDIS_PASSWORD"
    else
        docker exec -it "$CONTAINER_NAME" redis-cli
    fi
}

remove_redis() {
    check_docker

    if container_running; then
        log_info "Stopping container..."
        docker stop "$CONTAINER_NAME"
    fi

    if container_exists; then
        log_info "Removing container..."
        docker rm "$CONTAINER_NAME"
        log_success "Redis container removed"
    else
        log_warn "Container does not exist"
    fi
}

show_help() {
    echo "KALLAX Redis Management"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     Start Redis container"
    echo "  stop      Stop Redis container"
    echo "  restart   Restart Redis container"
    echo "  status    Show container status"
    echo "  logs      Follow container logs"
    echo "  cli       Open Redis CLI"
    echo "  remove    Remove container"
    echo ""
    echo "Environment Variables:"
    echo "  KALLAX_REDIS_PORT     Redis port (default: 6379)"
    echo "  KALLAX_REDIS_PASSWORD Redis password (optional)"
    echo "  KALLAX_REDIS_DATA     Data directory (default: ~/.kallax/redis-data)"
    echo ""
}

# Main
case "${1:-status}" in
    start) start_redis ;;
    stop) stop_redis ;;
    restart) restart_redis ;;
    status) status_redis ;;
    logs) logs_redis ;;
    cli) cli_redis ;;
    remove) remove_redis ;;
    -h|--help|help) show_help ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
