#!/usr/bin/env bash
# scripts/context/checkpoint.sh — Performer session auto-checkpoint (LangGraph Checkpoint pattern)
# PHASE-008-D: Auto-checkpoint for Performer sessions
#
# Checkpoint includes:
#   1. state.json — instance state
#   2. handoff.json — task context for handoff
#   3. knowledge base增量 — ~/.claude/knowledge/ changes since last checkpoint
#
# Integrates with:
#   - Performer session_start.sh (entry)
#   - Performer claim (task-claim)
#   - Performer complete (task-complete)
#   - ticket-status-sync.sh (EPIC-039-A Rule 16 Step 1)
#   - strong-verify-6d.sh (EPIC-039-D)
#
# Usage:
#   bash scripts/context/checkpoint.sh save [--label <label>]  # Save checkpoint
#   bash scripts/context/checkpoint.sh restore [--id <checkpoint_id>]  # Restore checkpoint
#   bash scripts/context/checkpoint.sh list  # List checkpoints
#   bash scripts/context/checkpoint.sh clean [--older-than <hours>]  # Clean old checkpoints
#
# LangGraph Checkpoint pattern:
#   - Checkpoint BEFORE long operations (prevent context loss)
#   - Checkpoint AFTER completion (state sync)
#   - Checkpoint ON Handoff (session transfer)
set -uo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
KNOWLEDGE_DIR="${HOME}/.claude/knowledge"
CHECKPOINT_DIR="${KALLAX_ROOT}/checkpoints"
LOG_DIR="${KALLAX_ROOT}/logs"

HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
PID="$$"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NOW_SHORT="$(date '+%Y%m%d_%H%M%S')"

# ============================================================
# BE-7 Fix Pattern: umask + install -d -m 700 + ownership check
# ============================================================
umask 077

# Safe directory creation (BE-7 Issue 1 fix)
_safe_mkdir() {
    local dir="$1"
    if [ -e "$dir" ]; then
        if [ ! -d "$dir" ]; then
            echo "[checkpoint] ERROR: $dir exists but is not a directory" >&2
            return 1
        fi
        # Check for symlink attacks
        if [ -L "$dir" ]; then
            echo "[checkpoint] ERROR: $dir is a symlink (potential symlink attack)" >&2
            return 1
        fi
        return 0
    fi
    # create with proper permissions
    install -d -m 700 "$dir" || {
        echo "[checkpoint] ERROR: failed to create directory $dir" >&2
        return 1
    }
    return 0
}

# ============================================================
# Logging
# ============================================================
log() {
    local level="$1"
    local msg="$2"
    echo "[checkpoint] [$level] $msg" >&2
}

# ============================================================
# Get instance ID from env or detect
# ============================================================
_get_instance_id() {
    local instance_id="${KALLAX_INSTANCE_ID:-}"
    if [ -z "$instance_id" ]; then
        # Detect from current state.json
        local state_file
        for state_file in "${INSTANCES_DIR}"/*/state.json; do
            if [ -f "$state_file" ]; then
                instance_id=$(grep '"instance_id"' "$state_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
                break
            fi
        done
    fi
    echo "${instance_id:-performer_${HOSTNAME}_${PID}}"
}

# ============================================================
# Get ticket ID from instance state
# ============================================================
_get_ticket_id() {
    local instance_id="$(_get_instance_id)"
    local state_file="${INSTANCES_DIR}/${instance_id}/state.json"
    if [ -f "$state_file" ]; then
        grep '"ticket_id"' "$state_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,'
    fi
}

# ============================================================
# Knowledge base incremental backup
# ============================================================
_backup_knowledge() {
    local checkpoint_id="$1"
    local backup_dir="${CHECKPOINT_DIR}/${checkpoint_id}/knowledge增量"
    local timestamp_file="${backup_dir}/.timestamp"

    _safe_mkdir "$backup_dir" || return 1

    if [ ! -d "$KNOWLEDGE_DIR" ]; then
        log "INFO" "Knowledge dir not found, skipping KB backup: $KNOWLEDGE_DIR"
        return 0
    fi

    # Get last checkpoint timestamp
    local last_timestamp=""
    local prev_checkpoint="${CHECKPOINT_DIR}/.last_kb_checkpoint"
    if [ -f "$prev_checkpoint" ]; then
        last_timestamp="$(cat "$prev_checkpoint" 2>/dev/null | tr -d ' \n')"
    fi

    # Find files modified since last checkpoint
    local kb_files=()
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        kb_files+=("$file")
    done < <(find "$KNOWLEDGE_DIR" -type f \( -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) -newer "$timestamp_file" 2>/dev/null || true)

    # If no timestamp file, copy all (first backup)
    if [ ! -f "$timestamp_file" ]; then
        log "INFO" "First KB backup, copying all knowledge files"
        kb_files=()
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            kb_files+=("$file")
        done < <(find "$KNOWLEDGE_DIR" -type f \( -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null || true)
    fi

    # Copy changed files
    local copied=0
    for src_file in "${kb_files[@]}"; do
        local rel_path="${src_file#${KNOWLEDGE_DIR}/}"
        local dest_file="${backup_dir}/${rel_path}"
        local dest_dir="$(dirname "$dest_file")"

        _safe_mkdir "$dest_dir" || continue
        if ! cp -p "$src_file" "$dest_file" 2>/dev/null; then
            log "WARN" "Failed to copy KB file: $src_file"
            continue
        fi
        copied=$((copied + 1))
    done

    # Update timestamp
    echo "$NOW" > "$timestamp_file"
    echo "$NOW" > "${CHECKPOINT_DIR}/.last_kb_checkpoint"

    log "INFO" "KB backup: $copied files copied to $backup_dir"
    return 0
}

# ============================================================
# Save checkpoint
# ============================================================
cmd_save() {
    local label=""
    local instance_id
    instance_id="$(_get_instance_id)"

    while [ $# -gt 0 ]; do
        case "$1" in
            --label)
                label="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local ticket_id
    ticket_id="$(_get_ticket_id)"
    local checkpoint_id="${instance_id}_${NOW_SHORT}"
    local checkpoint_path="${CHECKPOINT_DIR}/${checkpoint_id}"

    # Create checkpoint directory
    _safe_mkdir "$checkpoint_path" || {
        log "ERROR" "Failed to create checkpoint directory: $checkpoint_path"
        return 1
    }

    log "INFO" "Saving checkpoint: $checkpoint_id"

    # 1. Copy state.json
    local state_src="${INSTANCES_DIR}/${instance_id}/state.json"
    if [ -f "$state_src" ]; then
        if ! cp -p "$state_src" "${checkpoint_path}/state.json" 2>/dev/null; then
            log "WARN" "Failed to copy state.json"
        fi
    fi

    # 2. Copy handoff.json
    local handoff_src="${INSTANCES_DIR}/${instance_id}/handoff.json"
    if [ -f "$handoff_src" ]; then
        if ! cp -p "$handoff_src" "${checkpoint_path}/handoff.json" 2>/dev/null; then
            log "WARN" "Failed to copy handoff.json"
        fi
    fi

    # 3. Backup knowledge base incremental
    _backup_knowledge "$checkpoint_id" || log "WARN" "KB backup failed"

    # 4. Write metadata
    cat > "${checkpoint_path}/metadata.json" << METADATA
{
  "checkpoint_id": "${checkpoint_id}",
  "instance_id": "${instance_id}",
  "ticket_id": "${ticket_id}",
  "label": "${label:-auto}",
  "created_at": "${NOW}",
  "hostname": "${HOSTNAME}",
  "pid": ${PID}
}
METADATA

    # 5. Update symlink to latest
    local latest_link="${CHECKPOINT_DIR}/latest"
    if [ -e "$latest_link" ]; then
        if [ -L "$latest_link" ]; then
            rm -f "$latest_link"
        else
            log "WARN" "Latest link exists but is not a symlink"
            rm -rf "$latest_link"
        fi
    fi
    ln -s "$checkpoint_path" "$latest_link"

    log "INFO" "Checkpoint saved: $checkpoint_id"
    echo "$checkpoint_id"
    return 0
}

# ============================================================
# Restore checkpoint
# ============================================================
cmd_restore() {
    local checkpoint_id=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --id)
                checkpoint_id="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [ -z "$checkpoint_id" ]; then
        # Use latest
        if [ -L "${CHECKPOINT_DIR}/latest" ]; then
            checkpoint_id="$(basename "$(readlink "${CHECKPOINT_DIR}/latest")")"
        else
            log "ERROR" "No checkpoint_id provided and no latest checkpoint found"
            return 1
        fi
    fi

    local checkpoint_path="${CHECKPOINT_DIR}/${checkpoint_id}"
    if [ ! -d "$checkpoint_path" ]; then
        log "ERROR" "Checkpoint not found: $checkpoint_id"
        return 1
    fi

    log "INFO" "Restoring checkpoint: $checkpoint_id"

    # 1. Get instance_id from metadata
    local metadata_file="${checkpoint_path}/metadata.json"
    if [ ! -f "$metadata_file" ]; then
        log "ERROR" "Checkpoint metadata not found"
        return 1
    fi

    local instance_id
    instance_id="$(grep '"instance_id"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"

    # 2. Restore state.json
    if [ -f "${checkpoint_path}/state.json" ]; then
        _safe_mkdir "${INSTANCES_DIR}/${instance_id}" || return 1
        if ! cp -p "${checkpoint_path}/state.json" "${INSTANCES_DIR}/${instance_id}/state.json" 2>/dev/null; then
            log "ERROR" "Failed to restore state.json"
            return 1
        fi
    fi

    # 3. Restore handoff.json
    if [ -f "${checkpoint_path}/handoff.json" ]; then
        if ! cp -p "${checkpoint_path}/handoff.json" "${INSTANCES_DIR}/${instance_id}/handoff.json" 2>/dev/null; then
            log "WARN" "Failed to restore handoff.json"
        fi
    fi

    # 4. Restore knowledge base (merge)
    local kb_dir="${checkpoint_path}/knowledge增量"
    if [ -d "$kb_dir" ]; then
        log "INFO" "Restoring knowledge base from $kb_dir"
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            local rel_path="${file#${kb_dir}/}"
            local dest_file="${KNOWLEDGE_DIR}/${rel_path}"
            local dest_dir="$(dirname "$dest_file")"

            _safe_mkdir "$dest_dir" || continue
            cp -p "$file" "$dest_file" 2>/dev/null || log "WARN" "Failed to restore KB file: $rel_path"
        done < <(find "$kb_dir" -type f 2>/dev/null || true)
    fi

    log "INFO" "Checkpoint restored: $checkpoint_id"
    return 0
}

# ============================================================
# List checkpoints
# ============================================================
cmd_list() {
    if [ ! -d "$CHECKPOINT_DIR" ]; then
        echo "No checkpoints found"
        return 0
    fi

    echo "=========================================="
    echo "Checkpoints"
    echo "=========================================="

    local count=0
    while IFS= read -r checkpoint_path; do
        [ -z "$checkpoint_path" ] && continue
        [ "$checkpoint_path" = "${CHECKPOINT_DIR}/.last_kb_checkpoint" ] && continue
        [ "$checkpoint_path" = "${CHECKPOINT_DIR}/latest" ] && continue

        local checkpoint_id="${checkpoint_path##*/}"
        local metadata_file="${checkpoint_path}/metadata.json"

        if [ -f "$metadata_file" ]; then
            local ticket_id instance_id label created_at
            ticket_id="$(grep '"ticket_id"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"
            instance_id="$(grep '"instance_id"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"
            label="$(grep '"label"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"
            created_at="$(grep '"created_at"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"

            echo "  $checkpoint_id"
            echo "    Ticket: $ticket_id"
            echo "    Instance: $instance_id"
            echo "    Label: $label"
            echo "    Created: $created_at"
            echo ""
        else
            echo "  $checkpoint_id (no metadata)"
        fi
        count=$((count + 1))
    done < <(find "$CHECKPOINT_DIR" -maxdepth 1 -type d -not -name ".*" -not -name "checkpoints" 2>/dev/null | sort -r || true)

    echo "Total: $count checkpoint(s)"
    return 0
}

# ============================================================
# Clean old checkpoints
# ============================================================
cmd_clean() {
    local older_than="${1:-24}"

    if [ ! -d "$CHECKPOINT_DIR" ]; then
        echo "No checkpoints to clean"
        return 0
    fi

    log "INFO" "Cleaning checkpoints older than ${older_than} hours"

    local cutoff_date
    cutoff_date="$(date -u -d "${older_than} hours ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-${older_than}H '+%Y-%m-%dT%H:%M:%SZ')"

    local deleted=0
    while IFS= read -r checkpoint_path; do
        [ -z "$checkpoint_path" ] && continue
        [ "$checkpoint_path" = "${CHECKPOINT_DIR}/.last_kb_checkpoint" ] && continue
        [ "$checkpoint_path" = "${CHECKPOINT_DIR}/latest" ] && continue

        local checkpoint_id="${checkpoint_path##*/}"
        local metadata_file="${checkpoint_path}/metadata.json"

        if [ -f "$metadata_file" ]; then
            local created_at
            created_at="$(grep '"created_at"' "$metadata_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')"

            if [ -n "$created_at" ] && [ "$created_at" < "$cutoff_date" ]; then
                log "INFO" "Deleting old checkpoint: $checkpoint_id"
                rm -rf "$checkpoint_path" 2>/dev/null || log "WARN" "Failed to delete: $checkpoint_id"
                deleted=$((deleted + 1))
            fi
        fi
    done < <(find "$CHECKPOINT_DIR" -maxdepth 1 -type d -not -name ".*" -not -name "checkpoints" 2>/dev/null || true)

    log "INFO" "Cleaned $deleted checkpoint(s)"
    echo "Deleted: $deleted checkpoint(s)"
    return 0
}

# ============================================================
# Main
# ============================================================
main() {
    local command="${1:-help}"
    shift 2>/dev/null || true

    # Ensure checkpoint directory exists
    _safe_mkdir "$CHECKPOINT_DIR" || {
        log "ERROR" "Failed to create checkpoint directory"
        return 1
    }

    case "$command" in
        save)
            cmd_save "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        list)
            cmd_list
            ;;
        clean)
            cmd_clean "${1:-24}"
            ;;
        help|--help|-h)
            echo "Usage: checkpoint.sh <command> [options]"
            echo ""
            echo "Commands:"
            echo "  save [--label <label>]    Save checkpoint"
            echo "  restore [--id <id>]       Restore checkpoint"
            echo "  list                      List checkpoints"
            echo "  clean [--older-than <hrs>] Clean old checkpoints (default: 24h)"
            echo ""
            echo "Examples:"
            echo "  bash scripts/context/checkpoint.sh save --label 'before-long-op'"
            echo "  bash scripts/context/checkpoint.sh restore --id performer_xxx_20260613"
            echo "  bash scripts/context/checkpoint.sh list"
            echo "  bash scripts/context/checkpoint.sh clean 48"
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            main help
            return 1
            ;;
    esac
}

main "$@"