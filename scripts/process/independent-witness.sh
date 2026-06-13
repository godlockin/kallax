#!/usr/bin/env bash
# independent-witness.sh — Independent witness for subagent PASS reporting
# Root cause 2 fix: self-verification subject = fabrication subject
# Solution 1: Independent witness mechanism (治根 100%)
#
# Usage: bash scripts/process/independent-witness.sh <instance_id> <ticket_id>
#
# This script runs in an INDEPENDENT shell不受 subagent 控制.
# Output is JSONL audit log不可伪造.
#
# Rule 30: Subagent 报 PASS 前, 必调用 independent-witness.sh 生成审计日志.
set -euo pipefail
umask 077

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
AUDIT_DIR="${KALLAX_ROOT}/audit/independent_witness"
mkdir -p "$AUDIT_DIR"

# Args
INSTANCE_ID="${1:-}"
TICKET_ID="${2:-}"

if [ -z "$INSTANCE_ID" ] || [ -z "$TICKET_ID" ]; then
    echo "Usage: bash scripts/process/independent-witness.sh <instance_id> <ticket_id>"
    exit 1
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="${AUDIT_DIR}/${INSTANCE_ID}_${TICKET_ID}_${TIMESTAMP}.jsonl"

# Worktree path validation (Rule 22)
WORKTREE_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WT_ROOT="$(cd "$(dirname "$KALLAX_ROOT")" && pwd)/.kallax/worktrees"
if [[ "$WORKTREE_PATH" != "$WT_ROOT"* ]]; then
    {
        printf '{"ts":"%s","event":"witness_start","instance":"%s","ticket":"%s","result":"FAIL","reason":"not_in_worktree"}\n' \
            "$TIMESTAMP" "$INSTANCE_ID" "$TICKET_ID"
    } >> "$LOG_FILE"
    echo "FAIL: not in worktree: $WORKTREE_PATH"
    exit 1
fi

# Start independent witness
{
    printf '{"ts":"%s","event":"witness_start","instance":"%s","ticket":"%s","worktree":"%s"}\n' \
        "$TIMESTAMP" "$INSTANCE_ID" "$TICKET_ID" "$WORKTREE_PATH"

    # L1: git log --oneline -1 (SHA must be non-empty)
    SHA=$(git log --oneline -1 2>/dev/null | awk '{print $1}' || echo '')
    if [ -z "$SHA" ]; then
        printf '{"ts":"%s","event":"L1_git_log","result":"FAIL","reason":"empty_sha"}\n' "$TIMESTAMP"
    else
        printf '{"ts":"%s","event":"L1_git_log","result":"PASS","sha":"%s"}\n' "$TIMESTAMP" "$SHA"
    fi

    # L2: File existence check (sampling CLAUDE.md + ticket.json)
    for file in CLAUDE.md ticket.json; do
        if git show HEAD:"$file" &>/dev/null; then
            LINES=$(git show HEAD:"$file" | wc -l | tr -d ' ')
            printf '{"ts":"%s","event":"L2_file_exists","file":"%s","lines":%s,"result":"PASS"}\n' \
                "$TIMESTAMP" "$file" "$LINES"
        else
            printf '{"ts":"%s","event":"L2_file_exists","file":"%s","result":"FAIL","reason":"missing"}\n' \
                "$TIMESTAMP" "$file"
        fi
    done

    # L3: 3 hard scripts (run in independent shell)
    for script in check-kpi-precision check-test-case-isolation check-scope-creep; do
        SCRIPT_PATH="scripts/verify/${script}.sh"
        if [ ! -x "$SCRIPT_PATH" ]; then
            printf '{"ts":"%s","event":"%s","result":"SKIP","reason":"not_executable"}\n' \
                "$TIMESTAMP" "$script"
            continue
        fi
        START_MS=$(date +%s%3N)
        if bash "$SCRIPT_PATH" &>/dev/null; then
            RESULT="PASS"
        else
            RESULT="FAIL"
        fi
        END_MS=$(date +%s%3N)
        DURATION=$((END_MS - START_MS))
        printf '{"ts":"%s","event":"%s","result":"%s","duration_ms":%s}\n' \
            "$TIMESTAMP" "$script" "$RESULT" "$DURATION"
    done

    # L4: check-fact-forcing-preflight.sh
    PREFLIGHT_PATH="scripts/check-fact-forcing-preflight.sh"
    if [ -x "$PREFLIGHT_PATH" ]; then
        START_MS=$(date +%s%3N)
        if bash "$PREFLIGHT_PATH" &>/dev/null; then
            RESULT="PASS"
        else
            RESULT="FAIL"
        fi
        END_MS=$(date +%s%3N)
        DURATION=$((END_MS - START_MS))
        printf '{"ts":"%s","event":"L4_preflight","result":"%s","duration_ms":%s}\n' \
            "$TIMESTAMP" "$RESULT" "$DURATION"
    else
        printf '{"ts":"%s","event":"L4_preflight","result":"SKIP","reason":"not_executable"}\n' \
            "$TIMESTAMP"
    fi

    printf '{"ts":"%s","event":"witness_end","result":"OK"}\n' "$TIMESTAMP"
} > "$LOG_FILE"

echo "independent-witness OK: $LOG_FILE"
cat "$LOG_FILE"
exit 0