#!/usr/bin/env bash
# scripts/lib/expert-invocation-queue.sh
# KALLAX expert_invocations 降级链 (FIXED — EPIC-021-F A+B review fixes)
# 降级: Redis Stream → SQLite → JSONL
# 写盘 by default, 队列是升级路径
#
# 修复 (A+B review):
# - CRITICAL: SQL injection in sqlite_emit → input validation + JSON escape
# - CRITICAL: race drain+emit → portable mkdir-based atomic lock
# - HIGH: Redis XADD silent fallthrough → explicit error check
# - HIGH: get_backend race → lock on STATE_FILE
# - MEDIUM: chmod 0700 on INVOCATION_DIR
# - MEDIUM: explicit length check (MAX_*_LEN)
# - LOW: gtimeout fallback (uses background+kill+wait portable pattern)
#
# 不依赖 flock/timeout (macOS 默认无, 用 mkdir/sleep 替代)

set -euo pipefail

# State file
STATE_FILE="${HOME}/.kallax/state/queue_backend"
INVOCATION_DIR="${HOME}/.kallax/queue"
INVOCATION_FILE="${INVOCATION_DIR}/expert_invocations.jsonl"
ARCHIVE_FILE="${HOME}/.kallax/state/expert_invocations.archive.jsonl"
SQLITE_DB="${HOME}/.kallax/state/expert_invocations.db"
REDIS_KEY="expert_invocations"
REDIS_PING_TIMEOUT=1
SQLITE_WRITE_TIMEOUT=0.5
LRU_MAX=1000
LAST_ERROR=""

# Input validation
MAX_EXPERT_ID_LEN=128
MAX_TICKET_ID_LEN=64
VALID_ID_PATTERN='^[a-zA-Z0-9._-]+$'

# SQLite WAL mode + busy_timeout
SQLITE_BUSY_TIMEOUT_MS=5000

mkdir -p "$INVOCATION_DIR" "$(dirname "$SQLITE_DB")" "$(dirname "$STATE_FILE")"
chmod 0700 "$INVOCATION_DIR" 2>/dev/null || true
chmod 0700 "$(dirname "$SQLITE_DB")" 2>/dev/null || true

# Source modular libraries
# shellcheck source=backend-probe.sh
source "$(dirname "${BASH_SOURCE[0]}")/backend-probe.sh"
# shellcheck source=json-util.sh
source "$(dirname "${BASH_SOURCE[0]}")/json-util.sh"
# shellcheck source=invocation-core.sh
source "$(dirname "${BASH_SOURCE[0]}")/invocation-core.sh"

init_sqlite
