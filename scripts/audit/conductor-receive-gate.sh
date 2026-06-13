#!/usr/bin/env bash
# scripts/audit/conductor-receive-gate.sh — Conductor Receive Verification Gate (Rule 27)
# Security Extension: Conductor must verify subagent PASS is real (Root Cause #1)
# Required: Conductor checks 3 hard script outputs before accepting PASS report
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KALLAX_ROOT="$REPO_ROOT"

echo "=========================================="
echo "Conductor Receive Verification Gate (Rule 27)"
echo "=========================================="
echo ""

# L1: Verify subagent-pass-gate.sh was run and PASSed
echo "--- L1: Subagent Gate Output ---"
GATE_SCRIPT="$KALLAX_ROOT/scripts/audit/subagent-pass-gate.sh"
if [[ ! -f "$GATE_SCRIPT" ]]; then
    echo "[L1 FAIL] subagent-pass-gate.sh does not exist"
    echo "BLOCKED: Cannot verify subagent PASS without gate script"
    exit 1
fi

if ! bash "$GATE_SCRIPT" 2>/dev/null; then
    echo "[L1 FAIL] subagent-pass-gate.sh returned FAIL"
    echo "BLOCKED: Subagent self-verification failed"
    exit 1
fi
echo "[L1 PASS] subagent-pass-gate.sh PASS"

# L2: Check ticket status sync (Rule 16 Step 1)
echo ""
echo "--- L2: Ticket Status Sync ---"
TICKET_JSON=$(find "$REPO_ROOT/jira/tickets" -name "ticket.json" -newer "$GATE_SCRIPT" 2>/dev/null | head -1)
if [[ -z "$TICKET_JSON" ]]; then
    echo "[L2 WARN] No recent ticket.json update found"
else
    echo "[L2 PASS] ticket.json exists: $TICKET_JSON"
    # Verify status field
    STATUS=$(jq -r '.status' "$TICKET_JSON" 2>/dev/null || echo "unknown")
    if [[ "$STATUS" == "in_progress" ]]; then
        echo "[L2 PASS] Status: in_progress (expected)"
    else
        echo "[L2 WARN] Status: $STATUS (expected in_progress)"
    fi
fi

# L3: Verify 3 anti-fab outputs (Rule 16 Step 2)
echo ""
echo "--- L3: 3 Anti-Fab Tools Output ---"
ANTI_FAB_FAIL=0
for tool in "check-kpi-precision.sh" "check-test-case-isolation.sh" "check-scope-creep.sh"; do
    TOOL_PATH="$KALLAX_ROOT/scripts/verify/$tool"
    if [[ ! -x "$TOOL_PATH" ]]; then
        echo "[L3 FAIL] $tool not found"
        ANTI_FAB_FAIL=1
        continue
    fi
    if ! bash "$TOOL_PATH" 2>/dev/null; then
        echo "[L3 FAIL] $tool FAIL"
        ANTI_FAB_FAIL=1
    else
        echo "[L3 PASS] $tool"
    fi
done

if [[ $ANTI_FAB_FAIL -eq 1 ]]; then
    echo ""
    echo "BLOCKED: 3 anti-fab tools must all PASS"
    exit 1
fi

# L4: Verify preflight (Rule 16 Step 3)
echo ""
echo "--- L4: Preflight Check ---"
PREFLIGHT_SCRIPT="$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh"
if [[ ! -x "$PREFLIGHT_SCRIPT" ]]; then
    echo "[L4 FAIL] check-fact-forcing-preflight.sh not found"
    exit 1
fi

# Find most recent expert.md to check
EXPERT_FILE=$(find "$REPO_ROOT/.kallax/experts" -name "*.md" -newer "$GATE_SCRIPT" 2>/dev/null | head -1)
if [[ -z "$EXPERT_FILE" ]]; then
    echo "[L4 WARN] No recent expert.md found, skipping preflight check"
else
    if ! bash "$PREFLIGHT_SCRIPT" "$EXPERT_FILE" 2>/dev/null; then
        echo "[L4 FAIL] preflight returned FAIL"
        exit 1
    fi
    echo "[L4 PASS] preflight PASS"
fi

echo ""
echo "=========================================="
echo "GATE RESULT: PASS"
echo "=========================================="
echo ""
echo "Conductor has verified subagent PASS is authentic (Rule 27)."
echo "Master strong-verify-6d.sh can proceed."
exit 0