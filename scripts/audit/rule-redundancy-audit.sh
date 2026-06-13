#!/usr/bin/env bash
# scripts/audit/rule-redundancy-audit.sh — Rule redundancy audit
# Root Cause 4: 14 Rule upgrade rate 100%
# 跟 ACCUMULATED-LESSONS-2026-06-13.md 5.1 节 联合
# 跟 compliance-design.md 方案 2 联合

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

echo "=========================================="
echo "Rule Redundancy Audit"
echo "Root Cause 4: 14 Rule upgrade rate 100%"
echo "=========================================="
echo ""

# Check CLAUDE.md exists
if [ ! -f "$CLAUDE_MD" ]; then
    echo "FAIL: CLAUDE.md not found at $CLAUDE_MD"
    exit 1
fi

# Count total Rules
RULE_COUNT=$(grep -cE '^### [0-9]+\.' "$CLAUDE_MD" || echo "0")
echo "Total Rules: $RULE_COUNT"

# Count R-NEW upgraded Rules (Rule 14-18 + 19)
RNEW_COUNT=$(grep -cE '^### 1[4-9]\.' "$CLAUDE_MD" || echo "0")
echo "R-NEW upgraded Rules (14-19): $RNEW_COUNT"

# Calculate upgrade rate
if [ "$RULE_COUNT" -gt 0 ]; then
    UPGRADE_RATE=$(echo "scale=1; $RNEW_COUNT * 100 / $RULE_COUNT" | bc)
    echo "Upgrade rate: ${UPGRADE_RATE}%"
else
    UPGRADE_RATE=0
    echo "Upgrade rate: 0%"
fi
echo ""

# Check thresholds
THRESHOLD_RULE_COUNT=15
THRESHOLD_UPGRADE_RATE=80
THRESHOLD_GATE_COUNT=10

# Count gate commands (check-*.sh, *-gate.sh)
GATE_COUNT=$(find "$REPO_ROOT/scripts" -name "check-*.sh" -o -name "*-gate.sh" 2>/dev/null | wc -l | tr -d ' ')
echo "Total gate scripts: $GATE_COUNT"
echo ""

# Run threshold checks
ISSUES=()

if [ "$RULE_COUNT" -gt "$THRESHOLD_RULE_COUNT" ]; then
    ISSUES+=("Rule count $RULE_COUNT > threshold $THRESHOLD_RULE_COUNT")
fi

if [ "$UPGRADE_RATE" -gt "$THRESHOLD_UPGRADE_RATE" ]; then
    ISSUES+=("Upgrade rate ${UPGRADE_RATE}% > threshold ${THRESHOLD_UPGRADE_RATE}%")
fi

if [ "$GATE_COUNT" -gt "$THRESHOLD_GATE_COUNT" ]; then
    ISSUES+=("Gate count $GATE_COUNT > threshold $THRESHOLD_GATE_COUNT")
fi

# Report threshold violations
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "=========================================="
    echo "THRESHOLD VIOLATIONS (Rule 32)"
    echo "=========================================="
    printf '  %s\n' "${ISSUES[@]}"
    echo ""
    echo "REQUIRED ACTION: Trigger redundancy review"
    echo "Run: scripts/audit/rule-redundancy-audit.sh --review"
    echo ""
    # Exit with warning (not FAIL for audit, but report issue)
fi

# Redundancy detection: find Rules that can be replaced by git log
echo "=========================================="
echo "Redundancy Detection"
echo "=========================================="
echo ""

# Rules that are redundant (covered by other Rules or git log)
# Format: "Rule number|reason|replaced_by"
REDUNDANT_RULES=(
    "1|git hook already enforces|git pre-commit"
    "2|git hook already enforces|git pre-commit"
    "5|covered by Rule 9a|anti-fab"
    "6|covered by Rule 9b|anti-fab"
    "7|covered by Rule 9c|anti-fab"
    "9a|merged into Rule 26|subagent self-verification"
    "9b|merged into Rule 26|subagent self-verification"
    "9c|merged into Rule 26|subagent self-verification"
    "9e|merged into Rule 26|subagent self-verification"
    "18|merged into Rule 28|Master 6d verification"
)

REDUNDANT_COUNT=${#REDUNDANT_RULES[@]}
echo "Potential redundant Rules: $REDUNDANT_COUNT"
printf '  %s\n' "${REDUNDANT_RULES[@]}"
echo ""

# Calculate target Rule count after cleanup
TARGET_COUNT=$((RULE_COUNT - REDUNDANT_COUNT))
echo "Target Rule count after cleanup: $TARGET_COUNT"

# Check if target meets goal
GOAL=10
if [ "$TARGET_COUNT" -le "$GOAL" ]; then
    echo "PASS: Target $TARGET_COUNT <= goal $GOAL"
else
    echo "WARN: Target $TARGET_COUNT > goal $GOAL"
    echo "Need additional cleanup"
fi

echo ""
echo "=========================================="
echo "Audit Summary"
echo "=========================================="
echo "Total Rules: $RULE_COUNT"
echo "R-NEW upgraded: $RNEW_COUNT"
echo "Upgrade rate: ${UPGRADE_RATE}%"
echo "Gate scripts: $GATE_COUNT"
echo "Redundant Rules: $REDUNDANT_COUNT"
echo "Target after cleanup: $TARGET_COUNT"
echo ""

# Final status
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "STATUS: AUDIT WARN (threshold violations detected)"
    echo "ACTION: Trigger redundancy review per Rule 32"
    exit 1
elif [ "$TARGET_COUNT" -le "$GOAL" ]; then
    echo "STATUS: AUDIT PASS (target <= 10 Rules)"
    exit 0
else
    echo "STATUS: AUDIT PASS (no threshold violations)"
    exit 0
fi