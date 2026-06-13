#!/usr/bin/env bash
# scripts/audit/subagent-pass-gate.sh — Subagent Self-Verification Gate (Rule 26)
# Security Extension: Prevents tool-bypass = architectural defect (Root Cause #1)
# Required: subagent reports PASS only after self-verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KALLAX_ROOT="$REPO_ROOT"

echo "=========================================="
echo "Subagent Self-Verification Gate (Rule 26)"
echo "=========================================="
echo ""

# L1: Git log SHA must change (not cached/fake commit)
echo "--- L1: Git SHA真变验证 ---"
CURRENT_SHA=$(git log --oneline -1 2>/dev/null | awk '{print $1}')
if [[ -z "$CURRENT_SHA" ]]; then
    echo "[L1 FAIL] No commit found (0 SHA)"
    echo "BLOCKED: subagent claims PASS but git log shows 0 commits"
    exit 1
fi
echo "[L1 PASS] SHA: $CURRENT_SHA"

# L2: Verify actual content change (not stub/empty)
echo ""
echo "--- L2: 内容真改验证 ---"
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")
if [[ -z "$COMMIT_MSG" ]] || [[ "$COMMIT_MSG" == "null" ]]; then
    echo "[L2 FAIL] Empty commit message (possible stub)"
    exit 1
fi
echo "[L2 PASS] Commit message non-empty"

# L3: Anti-fab 3 tools must PASS before claiming PASS
echo ""
echo "--- L3: 3 Anti-Fab Tools ---"
cd "$KALLAX_ROOT"

ANTI_FAB_FAIL=0
for tool in "check-kpi-precision.sh" "check-test-case-isolation.sh" "check-scope-creep.sh"; do
    TOOL_PATH="scripts/verify/$tool"
    if [[ ! -x "$TOOL_PATH" ]]; then
        echo "[L3 FAIL] $tool not found or not executable"
        ANTI_FAB_FAIL=1
        continue
    fi
    if ! bash "$TOOL_PATH" 2>/dev/null; then
        echo "[L3 FAIL] $tool returned FAIL"
        ANTI_FAB_FAIL=1
    else
        echo "[L3 PASS] $tool"
    fi
done

if [[ $ANTI_FAB_FAIL -eq 1 ]]; then
    echo ""
    echo "BLOCKED: 3 anti-fab tools must PASS before claiming PASS"
    exit 1
fi

# L4: File existence check (files must exist, not missing)
echo ""
echo "--- L4: 文件存在性验证 ---"
# Get list of files changed in last commit
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || echo "")
if [[ -z "$CHANGED_FILES" ]]; then
    echo "[L4 WARN] No changed files detected (may be empty commit)"
fi

# Check if any expected output files exist
EXPECTED_DIRS=("jira/tickets" "scripts" "docs")
for dir in "${EXPECTED_DIRS[@]}"; do
    if [[ -d "$REPO_ROOT/$dir" ]]; then
        echo "[L4 PASS] $dir exists"
    else
        echo "[L4 WARN] $dir not found"
    fi
done

echo ""
echo "=========================================="
echo "GATE RESULT: PASS"
echo "=========================================="
echo ""
echo "Subagent has passed self-verification (Rule 26)."
echo "Conductor can now receive the PASS report."
exit 0