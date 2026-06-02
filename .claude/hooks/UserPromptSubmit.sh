#!/bin/bash
# KALLAX Claude Code Hook - UserPromptSubmit
# Triggered before each user prompt is submitted
# Usage: Automatically invoked by Claude Code

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Get current context from environment
CONVERSATION_ID="${CLAUDE_CONVERSATION_ID:-}"
PROMPT_TEXT="${1:-}"

# ============================================================
# Context Checks
# ============================================================

# Check token usage and suggest compression
check_context_size() {
    local state_file="$PROJECT_ROOT/.kallax/state/session.json"

    if [[ -f "$state_file" ]]; then
        local token_count
        token_count=$(grep -o '"token_count":[0-9]*' "$state_file" 2>/dev/null | cut -d: -f2 || echo "0")

        if [[ "$token_count" -gt 75000 ]]; then
            echo "[KALLAX] Warning: High context usage ($token_count tokens). Consider compacting."
        fi
    fi
}

# ============================================================
# Safety Checks
# ============================================================

# Check for dangerous operations in prompt
check_dangerous_ops() {
    local prompt="$1"

    # Check for force push to main
    if echo "$prompt" | grep -qiE "(force push|push --force|push -f).*(main|master)"; then
        echo "[KALLAX] Warning: Force push to protected branch detected in prompt."
    fi

    # Check for hard reset
    if echo "$prompt" | grep -qiE "git reset --hard"; then
        echo "[KALLAX] Warning: Hard reset detected. This may lose uncommitted changes."
    fi

    # Check for production operations
    if echo "$prompt" | grep -qiE "(deploy|publish|release).*(production|prod)"; then
        echo "[KALLAX] Notice: Production operation detected. Please verify carefully."
    fi
}

# ============================================================
# Task Context
# ============================================================

# Remind about current task
remind_task_context() {
    local current_task_file="$PROJECT_ROOT/.kallax/state/current_task.json"

    if [[ -f "$current_task_file" ]]; then
        local task_id
        task_id=$(grep -o '"ticket_id":"[^"]*"' "$current_task_file" 2>/dev/null | cut -d'"' -f4 || echo "")

        if [[ -n "$task_id" ]]; then
            echo "[KALLAX] Current task: $task_id"
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

    # Run checks
    check_context_size
    check_dangerous_ops "$PROMPT_TEXT"
    remind_task_context
}

main "$@"
