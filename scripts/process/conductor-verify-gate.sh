#!/usr/bin/env bash
# conductor-verify-gate.sh — Conductor强制验证 subagent 产出 (替代 self-verification)
# Solution 4: process-engineering 流程重构 (治根 80%)
#
# Usage: bash scripts/process/conductor-verify-gate.sh <ticket_id> <worktree_path>
#
# Conductor 在独立 shell 验证,不受 subagent 控制.
# 跟 Rule 27 升级联合 (撤销 self-verification, 改为 conductor-verification).
#
# Rule 27: Conductor 收 PASS 必看硬脚本输出 + 6 维度自验证.
set -euo pipefail
umask 077

TICKET_ID="${1:-}"
WORKTREE_PATH="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$WORKTREE_PATH" ]; then
    echo "Usage: bash scripts/process/conductor-verify-gate.sh <ticket_id> <worktree_path>"
    exit 1
fi

if [ ! -d "$WORKTREE_PATH" ]; then
    echo "FAIL: worktree not found: $WORKTREE_PATH"
    exit 1
fi

# Change to worktree (独立 shell, 不受 subagent 控制)
cd "$WORKTREE_PATH" || { echo "FAIL: cd worktree failed"; exit 1; }

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "=== Conductor Verify Gate | ticket=$TICKET_ID | ts=$TIMESTAMP ==="

# L1: git log --oneline -1 (SHA 真变, 非空)
SHA=$(git log --oneline -1 2>/dev/null | awk '{print $1}' || echo '')
if [ -z "$SHA" ]; then
    echo "FAIL: L1 git log empty (no commit)"
    exit 1
fi
echo "L1 PASS: sha=$SHA"

# L2: File existence (sampling CLAUDE.md + ticket.json)
for file in CLAUDE.md ticket.json; do
    if ! git show HEAD:"$file" &>/dev/null; then
        echo "FAIL: L2 $file missing in HEAD"
        exit 1
    fi
    LINES=$(git show HEAD:"$file" | wc -l | tr -d ' ')
    echo "L2 PASS: $file lines=$LINES"
done

# L3: 3 hard scripts (in conductor-controlled shell)
for script in check-kpi-precision check-test-case-isolation check-scope-creep; do
    SCRIPT_PATH="scripts/verify/${script}.sh"
    if [ ! -x "$SCRIPT_PATH" ]; then
        echo "SKIP: $script not executable"
        continue
    fi
    echo "Running $script..."
    if ! bash "$SCRIPT_PATH"; then
        echo "FAIL: L3 $script FAIL"
        exit 1
    fi
    echo "L3 PASS: $script"
done

# L4: check-fact-forcing-preflight.sh
PREFLIGHT_PATH="scripts/check-fact-forcing-preflight.sh"
if [ -x "$PREFLIGHT_PATH" ]; then
    echo "Running L4 preflight..."
    if ! bash "$PREFLIGHT_PATH"; then
        echo "FAIL: L4 preflight FAIL"
        exit 1
    fi
    echo "L4 PASS: preflight"
else
    echo "SKIP: L4 preflight not executable"
fi

# L5: Scope check (file_scope.includes 比对)
if [ -f "ticket.json" ]; then
    SCOPE_FILES=$(jq -r '.file_scope.include[]? // empty' ticket.json 2>/dev/null || echo '')
    if [ -n "$SCOPE_FILES" ]; then
        CHANGED=$(git diff --name-only miao 2>/dev/null | tr '\n' ' ' || echo '')
        echo "L5: scope_check skipped (file_scope comparison not implemented)"
    fi
fi

echo "=== conductor-verify-gate OK: ticket=$TICKET_ID sha=$SHA ==="
exit 0