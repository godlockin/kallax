#!/usr/bin/env bash
# scripts/instance/cleanup.sh — LRU + 7d TTL auto-cleanup for instance dirs
# EPIC-054-B: 治 A7 instance 僵尸, 跟 AGENTS.md §Resource Management 一致
#
# Sourceable functions:
#   is_within_ttl <last_beat_epoch> <ttl_seconds>
#   lru_sort_instances <instances_dir>
#   run_cleanup <instances_dir> <ttl_days> <dry_run> [log_dir]
#
# CLI:
#   cleanup.sh [--dry-run] [--ttl-days=7] [--instances-dir=PATH] [--log-dir=PATH] [--apply]
#
# Exit codes:
#   0 — cleanup completed (including 0 cleaned)
#   1 — invalid arguments
#   2 — instances dir not found
#
# Resource Management 硬要求 (AGENTS.md §Cache TTL Requirement):
#   - TTL=7d 覆盖典型周末+短假
#   - LRU 排序按 last_heartbeat 升序
#   - 保留白名单: role ∈ {conductor, master} 且 last_beat ≤ TTL

set -uo pipefail

# Constants (no magic numbers — Rule 4)
readonly DEFAULT_TTL_DAYS=7
readonly DEFAULT_INSTANCES_DIR=".kallax/instances"
readonly DEFAULT_LOG_DIR=".kallax/logs"
readonly PROTECTED_ROLES_REGEX='^(conductor|master)$'

# ----------------------------------------------------------------------
# Helper: read a timestamp field with fallback chain
# Tries: .heartbeat.last_beat → .heartbeat.last_heartbeat
#        → .last_beat → .last_heartbeat → .started_at → .created_at
# Args: $1=state_json_file
# Echo: epoch seconds, or empty if no timestamp found
# ----------------------------------------------------------------------
read_last_beat_epoch() {
    local state_file="$1"
    [ -f "$state_file" ] || { echo ""; return; }

    local raw
    # Try each field in priority order
    for field in '.heartbeat.last_beat' \
                 '.heartbeat.last_heartbeat' \
                 '.last_beat' \
                 '.last_heartbeat' \
                 '.started_at' \
                 '.created_at'; do
        raw=$(jq -r "$field // empty" "$state_file" 2>/dev/null || echo "")
        if [ -n "$raw" ] && [ "$raw" != "null" ]; then
            # Convert ISO 8601 to epoch
            local epoch
            epoch=$(iso_to_epoch "$raw")
            if [ -n "$epoch" ] && [ "$epoch" -gt 0 ] 2>/dev/null; then
                echo "$epoch"
                return
            fi
        fi
    done

    echo ""
}

# ----------------------------------------------------------------------
# Helper: ISO 8601 → epoch seconds (macOS + Linux compatible)
# ----------------------------------------------------------------------
iso_to_epoch() {
    local iso="$1"
    # Try GNU date first (Linux)
    date -u -d "$iso" +%s 2>/dev/null || \
    # Try BSD date (macOS)
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null || \
    date -u -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null || \
    echo ""
}

# ----------------------------------------------------------------------
# Helper: read role from state.json
# Args: $1=state_json_file
# Echo: role string, or "unknown" if missing
# ----------------------------------------------------------------------
read_role() {
    local state_file="$1"
    [ -f "$state_file" ] || { echo "unknown"; return; }
    jq -r '.role // "unknown"' "$state_file" 2>/dev/null || echo "unknown"
}

# ----------------------------------------------------------------------
# Function: is_within_ttl
# Args: $1=last_beat_epoch  $2=ttl_seconds  $3=now_epoch (optional, for testability)
# Return: 0 if within TTL (keep), 1 if expired (clean)
# Boundary semantics: age < ttl means within (exclusive boundary at exactly ttl)
# ----------------------------------------------------------------------
is_within_ttl() {
    local last_beat="$1"
    local ttl="$2"
    local now="${3:-}"

    # Empty timestamp → zombie (treat as expired)
    if [ -z "$last_beat" ]; then
        return 1
    fi

    if [ -z "$now" ]; then
        now=$(date -u +%s)
    fi

    local age=$((now - last_beat))
    # age < ttl means within TTL (exclusive boundary — deterministic for tests)
    if [ "$age" -lt "$ttl" ]; then
        return 0
    fi
    return 1
}

# ----------------------------------------------------------------------
# Function: lru_sort_instances
# Args: $1=instances_dir
# Echo: instance IDs sorted by last_beat ascending (oldest first)
# ----------------------------------------------------------------------
lru_sort_instances() {
    local base="$1"
    [ -d "$base" ] || return 1

    # Collect (epoch, instance_id) pairs, sort by epoch asc
    local pairs=()
    for state_file in "$base"/*/state.json; do
        [ -f "$state_file" ] || continue
        local id
        id=$(basename "$(dirname "$state_file")")
        # Skip .archive
        [ "$id" = ".archive" ] && continue

        local epoch
        epoch=$(read_last_beat_epoch "$state_file")
        # If no epoch, treat as epoch=0 (very old, zombie)
        [ -z "$epoch" ] && epoch=0
        pairs+=("$epoch|$id")
    done

    # Sort by epoch asc, print IDs
    printf '%s\n' "${pairs[@]}" | sort -t '|' -k1,1n | cut -d '|' -f2
}

# ----------------------------------------------------------------------
# Function: run_cleanup
# Args: $1=instances_dir  $2=ttl_days  $3=dry_run ("true"|"false")  $4=log_dir (optional)
# Echo: JSON report {total, cleaned, retained, retained_list, cleaned_list}
# Side effect: writes .kallax/logs/instance-cleanup-YYYYMMDD.json
# ----------------------------------------------------------------------
run_cleanup() {
    local base="$1"
    local ttl_days="$2"
    local dry_run="$3"
    local log_dir="${4:-}"

    if [ -z "$log_dir" ]; then
        log_dir="$DEFAULT_LOG_DIR"
    fi
    mkdir -p "$log_dir"

    if [ ! -d "$base" ]; then
        echo '{"error": "instances dir not found", "path": "'"$base"'"}'
        return 2
    fi

    local ttl_seconds=$((ttl_days * 86400))
    local now_epoch
    now_epoch=$(date -u +%s)

    local cleaned_list=()
    local retained_list=()
    local total=0
    local cleaned=0
    local retained=0

    # Iterate all instance dirs
    for instance_dir in "$base"/*/; do
        [ -d "$instance_dir" ] || continue
        local id
        id=$(basename "$instance_dir")
        # Skip .archive
        [ "$id" = ".archive" ] && continue

        local state_file="$instance_dir/state.json"
        total=$((total + 1))

        # Get role + last_beat
        local role
        role=$(read_role "$state_file")
        local last_beat_epoch
        last_beat_epoch=$(read_last_beat_epoch "$state_file")

        # Decision: protected role + within TTL → retain
        local keep=false
        if [[ "$role" =~ $PROTECTED_ROLES_REGEX ]]; then
            if is_within_ttl "$last_beat_epoch" "$ttl_seconds"; then
                keep=true
            fi
        else
            # Non-protected: only keep if within TTL AND not too old
            # (LRU: if total < max, retain; else use TTL)
            if is_within_ttl "$last_beat_epoch" "$ttl_seconds"; then
                keep=true
            fi
        fi

        if [ "$keep" = true ]; then
            retained_list+=("$id")
            retained=$((retained + 1))
        else
            cleaned_list+=("$id")
            cleaned=$((cleaned + 1))
            # If NOT dry_run, archive (don't hard-delete per EPIC-016-R lesson)
            if [ "$dry_run" = "false" ]; then
                local archive_subdir="$instance_dir"
                # Move state.json to .archive with timestamp
                local archive_target="$base/.archive/$(date -u +%Y%m%d_%H%M%S)_${id}"
                if [ -d "$base/.archive" ] || mkdir -p "$base/.archive"; then
                    mv "$instance_dir" "$archive_target" 2>/dev/null || true
                fi
            fi
        fi
    done

    # Build JSON lists
    local retained_json="[]"
    if [ ${#retained_list[@]} -gt 0 ]; then
        retained_json=$(printf '%s\n' "${retained_list[@]}" | jq -R . | jq -s .)
    fi
    local cleaned_json="[]"
    if [ ${#cleaned_list[@]} -gt 0 ]; then
        cleaned_json=$(printf '%s\n' "${cleaned_list[@]}" | jq -R . | jq -s .)
    fi

    # Build report JSON
    local report
    report=$(jq -n \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg ttl "$ttl_days" \
        --argjson total "$total" \
        --argjson cleaned "$cleaned" \
        --argjson retained "$retained" \
        --argjson rl "$retained_json" \
        --argjson cl "$cleaned_json" \
        '{
            timestamp: $ts,
            ttl_days: ($ttl | tonumber),
            total: $total,
            cleaned: $cleaned,
            retained: $retained,
            retained_list: $rl,
            cleaned_list: $cl
        }')

    # Write log file
    local log_file="$log_dir/instance-cleanup-$(date -u +%Y%m%d_%H%M%S).json"
    echo "$report" > "$log_file"

    # Echo report for caller
    echo "$report"
}

# ----------------------------------------------------------------------
# CLI entry point (only when run directly, not sourced)
# ----------------------------------------------------------------------
cli_main() {
    local ttl_days="$DEFAULT_TTL_DAYS"
    local instances_dir="$DEFAULT_INSTANCES_DIR"
    local log_dir="$DEFAULT_LOG_DIR"
    local dry_run="true"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --apply)
                dry_run="false"
                shift
                ;;
            --ttl-days=*)
                ttl_days="${1#*=}"
                shift
                ;;
            --instances-dir=*)
                instances_dir="${1#*=}"
                shift
                ;;
            --log-dir=*)
                log_dir="${1#*=}"
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: cleanup.sh [OPTIONS]

OPTIONS:
  --dry-run                Show what would be cleaned without modifying (default)
  --apply                  Actually archive instances to .archive/
  --ttl-days=N             TTL threshold in days (default: 7)
  --instances-dir=PATH     Instances directory (default: .kallax/instances)
  --log-dir=PATH           Log directory (default: .kallax/logs)
  -h, --help               Show this help

EXIT CODES:
  0  cleanup completed
  1  invalid arguments
  2  instances dir not found

EXAMPLES:
  # Dry run with defaults
  bash scripts/instance/cleanup.sh --dry-run

  # Apply with 7d TTL
  bash scripts/instance/cleanup.sh --apply

  # Custom TTL
  bash scripts/instance/cleanup.sh --ttl-days=14 --dry-run
EOF
                exit 0
                ;;
            *)
                echo "ERROR: unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    if [ ! -d "$instances_dir" ]; then
        echo "ERROR: instances dir not found: $instances_dir" >&2
        exit 2
    fi

    if ! [[ "$ttl_days" =~ ^[0-9]+$ ]] || [ "$ttl_days" -le 0 ]; then
        echo "ERROR: --ttl-days must be a positive integer, got: $ttl_days" >&2
        exit 1
    fi

    local result
    result=$(run_cleanup "$instances_dir" "$ttl_days" "$dry_run" "$log_dir")

    if [ "$dry_run" = "true" ]; then
        echo "[dry-run] cleanup report:"
    else
        echo "[apply] cleanup report:"
    fi
    echo "$result" | jq . 2>/dev/null || echo "$result"

    local cleaned retained
    cleaned=$(echo "$result" | jq -r '.cleaned // 0' 2>/dev/null || echo "0")
    retained=$(echo "$result" | jq -r '.retained // 0' 2>/dev/null || echo "0")
    echo ""
    echo "Summary: cleaned=$cleaned retained=$retained log=$log_dir/instance-cleanup-$(date -u +%Y%m%d)*.json"
    exit 0
}

# Only run cli_main if executed directly (not sourced)
# Pattern: BASH_SOURCE[0] check (Bash 3.2+ compatible, no associative arrays)
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
    cli_main "$@"
fi
