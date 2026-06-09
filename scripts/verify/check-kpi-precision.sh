#!/usr/bin/env bash
# scripts/verify/check-kpi-precision.sh — KPI falsification detection
# Detects estimate patterns like "~70%", "around 80", "大约 90", "PARTIAL"
# Previous issue: 51125b9 reported "PARTIAL" as PASS = second KPI falsification

set -euo pipefail

TARGET="${1:-last-commit}"
MSG=$(git log -1 --pretty=%B "$TARGET")

echo "=========================================="
echo "KPI Precision Check (Anti-Falsification)"
echo "=========================================="
echo "Checking commit: $TARGET"
echo ""

# Detection patterns for estimate/falsification anti-patterns
LEAKED_PATTERNS=(
    '~[0-9]+%'           # ~70%
    'around [0-9]+'       # around 80
    '大约 [0-9]+'         # 大约 90
    'approximately [0-9]+' # approximately 80
    'PARTIAL'             # PARTIAL reported as PASS
    '估计'                # 估计
    '约[0-9]+'            # 约70%
    '大概 [0-9]+'         # 大概 80
)

FOUND=()
for pat in "${LEAKED_PATTERNS[@]}"; do
    if echo "$MSG" | grep -qE "$pat"; then
        MATCH=$(echo "$MSG" | grep -oE "$pat" | head -1)
        FOUND+=("$pat (matched: $MATCH)")
    fi
done

if [ ${#FOUND[@]} -gt 0 ]; then
    echo "FAIL: KPI estimate / PARTIAL patterns detected in commit msg:"
    printf '  %s\n' "${FOUND[@]}"
    echo ""
    echo "REQUIREMENT: Exact X/Y numbers with one decimal (e.g. 'M1: 24/30 = 80.0%')."
    echo "Estimates ~= KPI falsification = ticket REJECT."
    exit 1
fi

echo "PASS: 0 estimate patterns in commit message"
echo "All KPI reports use precise numbers."

# Additional check: verify KPI format if present
if echo "$MSG" | grep -qE 'M[1678]:|[0-9]+/[0-9]+.*='; then
    echo ""
    echo "KPI format check: PASS (found numeric X/Y format)"
fi