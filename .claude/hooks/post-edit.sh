#!/bin/bash
# KALLAX Claude Code Hook - Post Edit
# Triggered after file edits
# Usage: Automatically invoked by Claude Code after Edit/Write operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Get edited file from environment
EDITED_FILE="${1:-}"

# ============================================================
# File Type Detection
# ============================================================

get_file_extension() {
    local file="$1"
    echo "${file##*.}"
}

is_typescript_file() {
    local ext
    ext=$(get_file_extension "$1")
    [[ "$ext" == "ts" || "$ext" == "tsx" ]]
}

is_rust_file() {
    local ext
    ext=$(get_file_extension "$1")
    [[ "$ext" == "rs" ]]
}

# ============================================================
# Anti-Pattern Detection
# ============================================================

check_typescript_patterns() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return
    fi

    local issues=()

    # Check for 'any' type
    if grep -n ": any" "$file" 2>/dev/null | grep -v "// @allow-any"; then
        issues+=("Found 'any' type - use unknown + type guards instead")
    fi

    # Check for @ts-ignore
    if grep -n "@ts-ignore" "$file" 2>/dev/null; then
        issues+=("Found @ts-ignore - fix the underlying type error")
    fi

    # Check for @ts-expect-error
    if grep -n "@ts-expect-error" "$file" 2>/dev/null; then
        issues+=("Found @ts-expect-error - fix the underlying type error")
    fi

    # Check for console.log (non-test files)
    if [[ "$file" != *".test."* && "$file" != *".spec."* ]]; then
        if grep -n "console\.log" "$file" 2>/dev/null; then
            issues+=("Found console.log - use structured logging")
        fi
    fi

    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "[KALLAX] TypeScript issues in $file:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

check_rust_patterns() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return
    fi

    local issues=()

    # Check for unwrap() (non-test code)
    if grep -n "\.unwrap()" "$file" 2>/dev/null | grep -v "#\[cfg(test)\]" | grep -v "// @allow-unwrap"; then
        issues+=("Found .unwrap() - use ? operator or proper error handling")
    fi

    # Check for expect() (non-test code)
    if grep -n "\.expect(" "$file" 2>/dev/null | grep -v "#\[cfg(test)\]" | grep -v "// @allow-expect"; then
        issues+=("Found .expect() - use ? operator with context")
    fi

    # Check for panic! (non-test code)
    if grep -n "panic!" "$file" 2>/dev/null | grep -v "#\[cfg(test)\]" | grep -v "// @allow-panic"; then
        issues+=("Found panic! - use Result<T, E> instead")
    fi

    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "[KALLAX] Rust issues in $file:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

# ============================================================
# Scope Validation
# ============================================================

check_file_scope() {
    local file="$1"
    local current_task_file="$PROJECT_ROOT/.kallax/state/current_task.json"

    if [[ ! -f "$current_task_file" ]]; then
        return
    fi

    # Extract file scope from task
    local includes
    includes=$(grep -o '"includes":\[[^]]*\]' "$current_task_file" 2>/dev/null || echo "")

    if [[ -z "$includes" ]]; then
        return
    fi

    # Get relative path
    local rel_path="${file#$PROJECT_ROOT/}"

    # Simple check - warn if editing outside scope
    # This is a basic implementation - production would use proper JSON parsing
    if ! echo "$includes" | grep -q "$rel_path"; then
        echo "[KALLAX] Warning: Editing file outside declared scope: $rel_path"
        echo "[KALLAX] Please verify this change is necessary for the current task."
    fi
}

# ============================================================
# Auto-format (optional)
# ============================================================

auto_format() {
    local file="$1"

    # Skip if not enabled
    if [[ "${KALLAX_AUTO_FORMAT:-false}" != "true" ]]; then
        return
    fi

    if is_typescript_file "$file"; then
        # Run prettier if available
        if command -v npx &>/dev/null && [[ -f "$PROJECT_ROOT/node_modules/.bin/prettier" ]]; then
            npx prettier --write "$file" 2>/dev/null || true
        fi
    elif is_rust_file "$file"; then
        # Run rustfmt if available
        if command -v rustfmt &>/dev/null; then
            rustfmt "$file" 2>/dev/null || true
        fi
    fi
}

# ============================================================
# Main
# ============================================================
main() {
    # Only run if in KALLAX project
    if [[ ! -d "$PROJECT_ROOT/.kallax" ]]; then
        exit 0
    fi

    # Skip if no file provided
    if [[ -z "$EDITED_FILE" ]]; then
        exit 0
    fi

    # Run checks based on file type
    if is_typescript_file "$EDITED_FILE"; then
        check_typescript_patterns "$EDITED_FILE"
    elif is_rust_file "$EDITED_FILE"; then
        check_rust_patterns "$EDITED_FILE"
    fi

    # Check file scope
    check_file_scope "$EDITED_FILE"

    # Auto-format if enabled
    auto_format "$EDITED_FILE"
}

main "$@"
