#!/usr/bin/env bash
# scripts/verify/tool-bypass-audit.sh — Security Extension: Tool Bypass Vector Audit
# Root Cause #1: Tools can be bypassed = 100% failure path
# Rule 26/27/28: Subagent必跑 3 硬脚本 + Master 强验证 0 维度
# BE-7 fix pattern: umask 077 + install -d -m 700
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/.kallax/audit"
REPORT_FILE="$AUDIT_DIR/tool-bypass-report.md"

# 6 硬脚本列表 (Rule 26/27 reference)
SIX_HARD_SCRIPTS=(
    "scripts/verify/check-kpi-precision.sh"
    "scripts/verify/check-test-case-isolation.sh"
    "scripts/verify/check-scope-creep.sh"
    "scripts/check-fact-forcing-preflight.sh"
    "scripts/audit/subagent-pass-gate.sh"
    "scripts/audit/conductor-receive-gate.sh"
)

# Bypass vector patterns to detect
BYPASS_PATTERNS=(
    'KALLAX_BYPASS'
    'BYPASS.*=.*1'
    '\.bypass'
    '--force-merge'
    'force_merge'
    'KALLAX_FORCE'
    '# bypass'
    'exit 0.*# bypass'
)

echo "=========================================="
echo "Tool Bypass Audit (Security Extension)"
echo "Root Cause #1: Tools Can Be Bypassed"
echo "=========================================="
echo ""

mkdir -p "$AUDIT_DIR"
umask 077

AUDIT_RESULT=()
TOTAL_BYPASS_VECTORS=0
NONEXISTENT_SCRIPTS=()
UNPROTECTED_SCRIPTS=()

for script in "${SIX_HARD_SCRIPTS[@]}"; do
    FULL_PATH="$REPO_ROOT/$script"
    SCRIPT_NAME=$(basename "$script" .sh)

    echo "--- Checking: $script ---"

    # L1: Existence check
    if [[ ! -f "$FULL_PATH" ]]; then
        echo "  [L1 FAIL] Script does not exist: $script"
        AUDIT_RESULT+=("[L1] $script: NOT FOUND (100% bypassable)")
        NONEXISTENT_SCRIPTS+=("$script")
        continue
    fi

    echo "  [L1 PASS] Script exists"

    # L2: Permissions check (BE-7 fix pattern: must be non-world-writable)
    PERMS=$(stat -f "%OLp" "$FULL_PATH" 2>/dev/null || stat -c "%a" "$FULL_PATH" 2>/dev/null || echo "???")
    if [[ "$PERMS" == "*"??" ]] || [[ "$PERMS" == "777" ]] || [[ "$PERMS" == "666" ]]; then
        echo "  [L2 FAIL] World-writable permissions: $PERMS (bypassable)"
        AUDIT_RESULT+=("[L2] $script: World-writable $PERMS")
        UNPROTECTED_SCRIPTS+=("$script")
    else
        echo "  [L2 PASS] Permissions OK: $PERMS"
    fi

    # L3: Bypass vector detection (grep for patterns)
    BYPASS_FOUND=()
    for pat in "${BYPASS_PATTERNS[@]}"; do
        if grep -qE "$pat" "$FULL_PATH" 2>/dev/null; then
            MATCHES=$(grep -nE "$pat" "$FULL_PATH" 2>/dev/null | head -3 | tr '\n' '|')
            BYPASS_FOUND+=("$pat (matches: $MATCHES)")
        fi
    done

    if [[ ${#BYPASS_FOUND[@]} -gt 0 ]]; then
        echo "  [L3 FAIL] Bypass vectors detected:"
        for bf in "${BYPASS_FOUND[@]}"; do
            echo "    - $bf"
        done
        AUDIT_RESULT+=("[L3] $script: BYPASS ${#BYPASS_FOUND[@]} vectors")
        TOTAL_BYPASS_VECTORS=$((TOTAL_BYPASS_VECTORS + ${#BYPASS_FOUND[@]}))
    else
        echo "  [L3 PASS] No bypass vectors detected"
    fi

    # L4: Self-validation check (does script verify itself before running?)
    if grep -qE 'SCRIPT_DIR=.*BASH_SOURCE\[0\]|script_dir=|SELF_DIR=' "$FULL_PATH" 2>/dev/null; then
        echo "  [L4 PASS] Self-path resolution found"
    else
        echo "  [L4 WARN] No self-path resolution (could be symlink attack)"
        AUDIT_RESULT+=("[L4] $script: No self-path resolution")
    fi

    echo ""
done

# Generate report
echo "=========================================="
echo "Audit Summary"
echo "=========================================="
echo ""

echo "| Check | Result |" > "$REPORT_FILE"
echo "|--------|--------|" >> "$REPORT_FILE"

for result in "${AUDIT_RESULT[@]}"; do
    echo "| $result |" >> "$REPORT_FILE"
    echo "  $result"
done

echo "" >> "$REPORT_FILE"
echo "## Statistics" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Metric | Value |" >> "$REPORT_FILE"
echo "|--------|-------|" >> "$REPORT_FILE"
echo "| Total scripts audited | ${#SIX_HARD_SCRIPTS[@]} |" >> "$REPORT_FILE"
echo "| Non-existent scripts | ${#NONEXISTENT_SCRIPTS[@]} |" >> "$REPORT_FILE"
echo "| Unprotected scripts | ${#UNPROTECTED_SCRIPTS[@]} |" >> "$REPORT_FILE"
echo "| Total bypass vectors | $TOTAL_BYPASS_VECTORS |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## Non-existent scripts (100% bypassable)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
if [[ ${#NONEXISTENT_SCRIPTS[@]} -eq 0 ]]; then
    echo "None — all 6 hard scripts exist." >> "$REPORT_FILE"
else
    for ns in "${NONEXISTENT_SCRIPTS[@]}"; do
        echo "- $ns" >> "$REPORT_FILE"
        echo "  **100% BYPASSABLE** (script does not exist)"
    done
fi

echo ""
echo "Statistics:"
echo "  Total scripts audited: ${#SIX_HARD_SCRIPTS[@]}"
echo "  Non-existent scripts: ${#NONEXISTENT_SCRIPTS[@]} (100% bypassable)"
echo "  Unprotected scripts: ${#UNPROTECTED_SCRIPTS[@]}"
echo "  Total bypass vectors: $TOTAL_BYPASS_VECTORS"
echo ""
echo "Report saved to: $REPORT_FILE"

# Final verdict
if [[ ${#NONEXISTENT_SCRIPTS[@]} -gt 0 ]] || [[ $TOTAL_BYPASS_VECTORS -gt 0 ]]; then
    echo ""
    echo "AUDIT RESULT: FAIL"
    echo "  ${#NONEXISTENT_SCRIPTS[@]} scripts do not exist (100% bypassable)"
    echo "  $TOTAL_BYPASS_VECTORS bypass vectors found"
    echo ""
    echo "REQUIRED FIXES:"
    echo "  1. Create missing scripts (subagent-pass-gate.sh, conductor-receive-gate.sh)"
    echo "  2. Remove KALLAX_BYPASS_* env var bypasses"
    echo "  3. Harden --force-merge token check to happen BEFORE preflight"
    echo "  4. Set script permissions: chmod 755 (not world-writable)"
    exit 1
fi

echo ""
echo "AUDIT RESULT: PASS"
echo "  All 6 hard scripts exist with no bypass vectors detected"
exit 0