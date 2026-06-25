#!/usr/bin/env bash
# scripts/sync/status-sync.sh — 3 仓 sync 状态报告 (machine-parseable 1-line)
# EPIC-060-A Phase 3: 3 仓 NFS/S3 sync
#
# 跟 confluence-sync.sh + jira-sync.sh + s3-sync.sh 联合 (status 监控)
# 跟 eket 4 级降级 模式 联合 (3 仓 health check)
# 跟"反讽" 联合 治根 vendor lock-in (状态 报告 0 S3 强制)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
#
# Usage: bash scripts/sync/status-sync.sh [--format=text|json] [--tier=confluence|jira|all]
#
# Returns 0 if status retrievable, 1 otherwise.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly STATUS_FORMAT_DEFAULT="text"
readonly STATUS_TIER_DEFAULT="all"

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SYNC_STATE_DIR="${KALLAX_ROOT}/.claude/sync-state"

# ── Flags ──────────────────────────────────────────────────────────────
FORMAT="$STATUS_FORMAT_DEFAULT"
TIER="$STATUS_TIER_DEFAULT"
while [[ $# -gt 0 ]]; do
    case $1 in
        --format=*) FORMAT="${1#--format=}"; shift ;;
        --tier=*)   TIER="${1#--tier=}";   shift ;;
        -h|--help)
            echo "Usage: $0 [--format=text|json] [--tier=confluence|jira|all]"
            echo ""
            echo "Reports 3 仓 sync status (machine-parseable)"
            echo "  text:  human-readable"
            echo "  json:  machine-parseable (跟 Phase 2 status-litestream.sh 模式 一致)"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }

# ── Per-tier status check ─────────────────────────────────────────────
check_tier_status() {
    local tier="$1"
    local src_path=""
    local sync_log=""
    local count=0

    case "$tier" in
        confluence)
            src_path="${KALLAX_ROOT}/confluence"
            sync_log="${SYNC_STATE_DIR}/confluence-sync.log"
            ;;
        jira)
            src_path="${KALLAX_ROOT}/jira"
            sync_log="${SYNC_STATE_DIR}/jira-sync.log"
            ;;
    esac

    if [ ! -d "$src_path" ]; then
        echo "tier=$tier status=missing path=$src_path"
        return 1
    fi

    count="$(find "$src_path" -type f 2>/dev/null | wc -l | tr -d ' ')"

    local log_status="none"
    if [ -f "$sync_log" ]; then
        log_status="present"
    fi

    echo "tier=$tier src=$src_path files=$count log=$log_status status=ready"
    return 0
}

# ── Execute per tier ──────────────────────────────────────────────────
RESULTS=()
case "$TIER" in
    confluence)
        check_tier_status "confluence" >> /dev/null || true
        RESULTS=("$(check_tier_status 'confluence')")
        ;;
    jira)
        RESULTS=("$(check_tier_status 'jira')")
        ;;
    all)
        RESULTS=("$(check_tier_status 'confluence')")
        RESULTS+=("$(check_tier_status 'jira')")
        ;;
esac

# ── Format output ──────────────────────────────────────────────────────
case "$FORMAT" in
    text)
        echo ""
        echo "════════════════════════════════════════════"
        echo " EPIC-060-A Phase 3 — 3 仓 sync status"
        echo "════════════════════════════════════════════"
        echo "  KALLAX_ROOT: $KALLAX_ROOT"
        echo "  Tier:        $TIER"
        echo "  Format:      $FORMAT"
        echo ""
        for r in "${RESULTS[@]}"; do
            echo "  $r"
        done
        echo ""
        ok "Status check complete (跟 eket 4 级降级 模式 联合)"
        ;;
    json)
        # Build JSON manually (no jq dependency assumed)
        echo -n "{"
        echo -n "\"tier\":\"$TIER\","
        echo -n "\"kallax_root\":\"$KALLAX_ROOT\","
        echo -n "\"tiers\":["
        first=true
        for r in "${RESULTS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo -n ","
            fi
            echo -n "{"
            # Parse key=value into JSON
            tier_name=""
            src_path=""
            file_count=""
            log_state=""
            status_state=""
            IFS=' ' read -ra PARTS <<< "$r"
            for p in "${PARTS[@]}"; do
                key="${p%%=*}"
                val="${p#*=}"
                case "$key" in
                    tier)   tier_name="$val" ;;
                    src)    src_path="$val" ;;
                    files)  file_count="$val" ;;
                    log)    log_state="$val" ;;
                    status) status_state="$val" ;;
                esac
            done
            echo -n "\"tier\":\"$tier_name\",\"src\":\"$src_path\",\"files\":$file_count,\"log\":\"$log_state\",\"status\":\"$status_state\""
            echo -n "}"
        done
        echo -n "]"
        echo "}"
        ;;
    *)
        err "Unknown format: $FORMAT (expected: text|json)"
        exit 1
        ;;
esac

exit 0
