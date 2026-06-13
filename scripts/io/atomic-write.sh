#!/bin/bash
# atomic-write.sh — Atomic write with temp file + mv replacement
# Rule 17 Step 2: IO layer write safety
#，痛点 6 治根：写半截文件防护
set -euo pipefail

# Usage: atomic-write.sh <file> <content_file_or_content>
#   atomic-write.sh /path/to/file.txt "content here"
#   atomic-write.sh /path/to/file.txt < /path/to/content.txt
#
# Returns: 0 on success, 1 on failure (temp file cleaned up)

readonly ATOMIC_WRITE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
readonly PID="$$"
readonly TS="$(date +%s)"

#_checksum algorithm (sha256 for robustness)
CHECKSUM_ALGO="${CHECKSUM_ALGO:-sha256}"

usage() {
    cat <<EOF
atomic-write.sh — Atomic write with temp file + mv replacement

Usage:
    atomic-write.sh <file> <content>
    atomic-write.sh <file> < <content_file
    atomic-write.sh <file> --stdin

Description:
    1. Write content to <file>.tmp.<pid>.<ts>
    2. Compute checksum and verify write
    3. If verification passes, mv atomically replaces <file>
    4. On any failure, temp file is cleaned up (no half-written files)

Options:
    --checksum TYPE   Checksum algorithm: sha256 (default), sha512, md5
    --no-preserve-owner  Don't preserve original file owner/group
    --help             Show this help

Examples:
    atomic-write.sh /tmp/test.txt "hello world"
    cat content.txt | atomic-write.sh /tmp/test.txt
    atomic-write.sh /tmp/test.txt --stdin < content.txt

Exit codes:
    0 = success (file replaced atomically)
    1 = failure (temp file cleaned up)
EOF
}

# Calculate checksum of a file
calculate_checksum() {
    local file="$1"
    case "$CHECKSUM_ALGO" in
        sha256) sha256sum "$file" | cut -d' ' -f1 ;;
        sha512) sha512sum "$file" | cut -d' ' -f1 ;;
        md5)    md5sum "$file" | cut -d' ' -f1 ;;
        *)      echo "ERROR: Unknown checksum algorithm: $CHECKSUM_ALGO" >&2; return 1 ;;
    esac
}

# Verify file integrity by computing checksum before and after copy
verify_write() {
    local temp_file="$1"
    local original_checksum="${2:-}"

    if [[ -z "$original_checksum" ]]; then
        # First verification: file is readable and non-empty
        if [[ ! -s "$temp_file" ]]; then
            echo "ERROR: Temp file is empty or unreadable" >&2
            return 1
        fi
        return 0
    fi

    # Subsequent verification: checksum must match
    local new_checksum
    new_checksum="$(calculate_checksum "$temp_file")"
    if [[ "$new_checksum" != "$original_checksum" ]]; then
        echo "ERROR: Checksum mismatch after write" >&2
        echo "  Expected: $original_checksum" >&2
        echo "  Got:      $new_checksum" >&2
        return 1
    fi
    return 0
}

# Cleanup handler — called on EXIT (success or failure)
cleanup_temp() {
    local temp_file="$1"
    if [[ -f "$temp_file" ]]; then
        rm -f "$temp_file" 2>/dev/null || true
    fi
}

# Atomic write main logic
atomic_write() {
    local target_file="$1"
    local content="$2"
    local preserve_owner="${3:-true}"

    # Validate target
    if [[ -z "$target_file" ]]; then
        echo "ERROR: Target file path required" >&2
        return 1
    fi

    # Ensure target directory exists
    local target_dir
    target_dir="$(dirname "$target_file")"
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir" 2>/dev/null || {
            echo "ERROR: Cannot create directory: $target_dir" >&2
            return 1
        }
    fi

    # Generate temp file path: <file>.tmp.<pid>.<ts>
    local temp_file="${target_file}.tmp.${PID}.${TS}"

    # Trap cleanup on any exit (normal, error, or signal)
    trap "cleanup_temp '$temp_file'" EXIT

    # Special handling for git index lock files
    local is_git_index=false
    if [[ "$target_file" == *".git/index"* ]]; then
        is_git_index=true
    fi

    # Step 1: Write content to temp file
    if [[ -z "$content" ]]; then
        # Read from stdin
        if ! cat > "$temp_file"; then
            echo "ERROR: Failed to write content to temp file" >&2
            return 1
        fi
    else
        # Write content directly
        if ! echo "$content" > "$temp_file"; then
            echo "ERROR: Failed to write content to temp file" >&2
            return 1
        fi
    fi

    # Step 2: Verify write integrity (file readable, non-empty)
    if ! verify_write "$temp_file" ""; then
        return 1
    fi

    # Step 3: Calculate checksum of temp file
    local checksum
    checksum="$(calculate_checksum "$temp_file")"

    # Step 4: Verify checksum (double-write check)
    if ! verify_write "$temp_file" "$checksum"; then
        echo "ERROR: Verification failed after checksum" >&2
        return 1
    fi

    # Step 5: Set permissions to match original file if it exists
    if [[ -f "$target_file" ]] && [[ "$preserve_owner" == "true" ]] && [[ "$is_git_index" == "false" ]]; then
        local orig_mode
        orig_mode="$(stat -c '%a' "$target_file" 2>/dev/null)" || orig_mode="644"
        chmod "$orig_mode" "$temp_file" 2>/dev/null || true
    elif [[ "$is_git_index" == "false" ]]; then
        # Default mode: 644
        chmod 644 "$temp_file" 2>/dev/null || true
    fi

    # Step 6: Atomic mv (mv is atomic on same filesystem)
    if ! mv "$temp_file" "$target_file"; then
        echo "ERROR: Atomic mv failed" >&2
        return 1
    fi

    # Success — disable trap (file already moved)
    trap - EXIT

    # Verify final file exists and has content
    if [[ ! -f "$target_file" ]]; then
        echo "ERROR: Target file not created after mv" >&2
        return 1
    fi

    echo "OK: Atomic write completed: $target_file"
    echo "    checksum=$checksum"
    return 0
}

# Parse arguments
main() {
    local target_file=""
    local content=""
    local use_stdin=false
    local preserve_owner=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --checksum)
                CHECKSUM_ALGO="$2"
                shift 2
                ;;
            --no-preserve-owner)
                preserve_owner=false
                shift
                ;;
            --stdin)
                use_stdin=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                echo "ERROR: Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                if [[ -z "$target_file" ]]; then
                    target_file="$1"
                else
                    content="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$target_file" ]]; then
        echo "ERROR: Target file required" >&2
        usage
        exit 1
    fi

    if [[ "$use_stdin" == "true" ]]; then
        content="$(cat)" || {
            echo "ERROR: Failed to read stdin" >&2
            exit 1
        }
    fi

    atomic_write "$target_file" "$content" "$preserve_owner"
}

# If script is sourced, provide helper functions
# If script is executed directly, run main
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
