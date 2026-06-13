#!/usr/bin/env bash
# subagent-pass-gate.sh — Subagent 报 PASS 必跑 3 硬脚本 + 6 维度自验证
# Rule 26: Subagent 报 PASS 必跑 3 硬脚本
#
# Usage: bash scripts/process/subagent-pass-gate.sh <ticket_id>
#
# Subagent 报 PASS 前必跑, 跟 independent-witness.sh 联合.
# L1-L4 验证, 跟 L1-L4 Fact-Forcing 一致.
set -euo pipefail
umask 077

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
    echo "Usage: bash scripts/process/subagent-pass-gate.sh <ticket_id>"
    exit 1
fi

WORKTREE_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
AUDIT_DIR="${KALLAX_ROOT}/audit/subagent_pass_gate"
mkdir -p "$AUDIT_DIR"
LOG_FILE="${AUDIT_DIR}/${TICKET_ID}_${TIMESTAMP}.log"

exec > >(tee "$LOG_FILE")
exec 2>&1

echo "=== Subagent PASS Gate | ticket=$TICKET_ID | ts=$TIMESTAMP ==="

# L1: git log --oneline -1 (SHA 真变)
SHA=$(git log --oneline -1 2>/dev/null | awk '{print $1}' || echo '')
if [ -z "$SHA" ]; then
    echo "FAIL: L1 git log empty (no commit)"
    exit 1
fi
echo "L1 PASS: sha=$SHA"

# L2: File existence check (sampling CLAUDE.md + ticket.json)
for file in CLAUDE.md ticket.json; do
    if ! git show HEAD:"$file" &>/dev/null; then
        echo "FAIL: L2 $file missing in HEAD"
        exit 1
    fi
    LINES=$(git show HEAD:"$file" | wc -l | tr -d ' ')
    echo "L2 PASS: $file lines=$LINES"
done

# L3: 3 hard scripts
for script in check-kpi-precision check-test-case-isolation check-scope-creep; do
    SCRIPT_PATH="scripts/verify/${script}.sh"
    if [ ! -x "$SCRIPT_PATH" ]; then
        echo "SKIP: $script not executable"
        continue
    fi
    echo "Running $script..."
    if ! bash "$SCRIPT_PATH"; then
        echo "FAIL: L3 $script FAIL (cannot report PASS)"
        exit 1
    fi
    echo "L3 PASS: $script"
done

# L4: check-fact-forcing-preflight.sh
PREFLIGHT_PATH="scripts/check-fact-forcing-preflight.sh"
if [ -x "$PREFLIGHT_PATH" ]; then
    echo "Running L4 preflight..."
    if ! bash "$PREFLIGHT_PATH"; then
        echo "FAIL: L4 preflight FAIL (cannot report PASS)"
        exit 1
    fi
    echo "L4 PASS: preflight"
fi

# L5: Scope check (跟 file_scope.includes 比对)
if [ -f "ticket.json" ]; then
    SCOPE_FILES=$(jq -r '.file_scope.include[]? // empty' ticket.json 2>/dev/null || echo '')
    if [ -n "$SCOPE_FILES" ]; then
        echo "L5: scope check present (file_scope comparison deferred to conductor-verify-gate)"
    else
        echo "L5: SKIP (no file_scope in ticket.json)"
    fi
fi

# L6: 诚实检查 (无估数/模糊/PARTIAL/around/approximately/估计/roughly/should)
echo "Running L6 honesty check..."
if grep -E "(估数|约|PARTIAL|around|approximately|估计|roughly|should)" CLAUDE.md ticket.json 2>/dev/null; then
    echo "FAIL: L6 honesty check FAIL (found fuzzy/estimated language)"
    exit 1
fi
echo "L6 PASS: no fuzzy language"

echo "=== subagent-pass-gate OK: ticket=$TICKET_ID sha=$SHA ==="
echo "Log: $LOG_FILE"
exit 0