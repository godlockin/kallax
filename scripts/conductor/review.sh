#!/usr/bin/env bash
# scripts/conductor/review.sh — Conductor review flow for merge gate
# Runs 3 anti-fab + preflight + amend-verify before Conductor merge
# EPIC-039-B: Step 4 of Rule 16 5-step flow
#
# EPIC-053-C: BE-10 治根
#   - Self-guard: 静态检查本脚本不复发 [[:space:]] 数组模式 (bash 5.x 兼容要求 \s)
#   - 跟 check-kpi-precision.sh / tool-self-check.sh 同步
#   - 跟 EPIC-053-B 4-Level 证据链 联动, 跟 EPIC-048 tool-bypass-audit 模式 一致

set -euo pipefail

# Self-guard: BE-10 模式治根 — 拒 [[:space:]] 数组模式 (bash 5.x 兼容要求 \s)
# 跟 tool-self-check.sh / check-kpi-precision.sh 中的 guard 一致
_b53_guard_ok=1
_awk_b53=$(awk '
    BEGIN { in_a = 0; d = 0 }
    {
        line = $0
        gsub(/\$\(\(/, "", line)
        gsub(/\$\(/, "", line)
        if (in_a == 0) {
            if (match(line, /[A-Za-z_][A-Za-z0-9_]*[ ]*(\+)?=\(/)) { in_a = 1; d = 1 }
        } else {
            d += gsub(/\(/, "x", line) - gsub(/\)/, "x", line)
            if (match(line, /\[\[:space:\]\]/)) { exit 1 }
            if (d <= 0) in_a = 0
        }
    }
' "$0" 2>/dev/null) || _b53_guard_ok=0
if [ "$_b53_guard_ok" -eq 0 ]; then
    echo "BE-10 模式复发: [[:space:]] 在数组模式 (bash 5.x 不兼容). 用 \\s 替代." >&2
    exit 1
fi
unset _b53_guard_ok _awk_b53

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

echo "=========================================="
echo "Conductor Review Gate (EPIC-039-B)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# --- 1. test-case-isolation check (Rule 9b) ---
echo "--- 1. Anti-Fab: test-case-isolation ---"
if bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1; then
    pass "test-case-isolation PASS"
else
    fail "test-case-isolation FAIL (Rule 9b: verbatim in trigger)"
fi
echo ""

# --- 2. kpi-precision check (Rule 9a) ---
echo "--- 2. Anti-Fab: kpi-precision ---"
if bash "$VERIFY_DIR/check-kpi-precision.sh" >/dev/null 2>&1; then
    pass "kpi-precision PASS"
else
    fail "kpi-precision FAIL (Rule 9a: estimate/PARTIAL pattern)"
fi
echo ""

# --- 3. scope-creep check (Rule 9c) ---
echo "--- 3. Anti-Fab: scope-creep ---"
# scope-creep needs TICKET_ID arg; use HEAD commit to infer ticket
RECENT_TICKET=$(git log -1 --pretty=%B | grep -oE 'EPIC-[0-9]+-[A-Z]' | head -1 || echo "")
if [ -n "$RECENT_TICKET" ]; then
    if bash "$VERIFY_DIR/check-scope-creep.sh" "$RECENT_TICKET" >/dev/null 2>&1; then
        pass "scope-creep PASS (ticket: $RECENT_TICKET)"
    else
        fail "scope-creep FAIL (Rule 9c: files outside scope)"
    fi
else
    # No ticket ID in commit msg — skip scope check
    pass "scope-creep SKIP (no ticket ID in commit)"
fi
echo ""

# --- 4. check-fact-forcing-preflight.sh (Rule 9 L1-L4) ---
echo "--- 4. Fact-Forcing: preflight 5-tool check ---"
# Run against most recent commit's diff to find expert.md
EXPERT_FILE=$(git diff HEAD~1..HEAD --name-only | grep -E 'expert.*\.md$' | head -1 || echo "")
if [ -n "$EXPERT_FILE" ] && [ -f "$EXPERT_FILE" ]; then
    if bash "$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh" "$EXPERT_FILE" >/dev/null 2>&1; then
        pass "preflight PASS (L1/L2/L3/L4/L4_script)"
    else
        fail "preflight FAIL (L1/L2/L3/L4/L4_script exists)"
    fi
else
    # No expert.md changed — run stub check
    if [ -f "$KALLAX_ROOT/scripts/check-fact-forcing-preflight.sh" ]; then
        pass "preflight SKIP (no expert.md in diff)"
    else
        fail "preflight FAIL (check-fact-forcing-preflight.sh missing)"
    fi
fi
echo ""

# --- 5. check-commit-amend-verify.sh (Rule 9d) ---
echo "--- 5. Anti-Fab: commit-amend-verify ---"
if bash "$VERIFY_DIR/check-commit-amend-verify.sh" >/dev/null 2>&1; then
    pass "commit-amend-verify PASS"
else
    fail "commit-amend-verify FAIL (Rule 9d: hidden amend)"
fi
echo ""

# --- 6. EPIC-053-E: l3-l4-consistency.sh wired into Conductor review (治 BE-5 反讽) ---
# Conductor 合并前 review 必须确认 l3-l4-consistency 在生产路径, 否则治 BE-9 工具自己不在生产路径 — BE-5 反讽.
echo "--- 6. L3/L4 Consistency Wiring (EPIC-053-E, 治 BE-5 反讽) ---"
L3L4_SCRIPT="$KALLAX_ROOT/scripts/verify/l3-l4-consistency.sh"
if [ ! -x "$L3L4_SCRIPT" ]; then
    fail "l3-l4-consistency.sh missing or not executable: $L3L4_SCRIPT"
else
    # Self-test 1: PASS/PASS = OK
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=PASS >/dev/null 2>&1
    RC1=$?
    set -e
    if [ "$RC1" -ne 0 ]; then
        fail "l3-l4-consistency PASS/PASS expected OK, got ERROR (exit=$RC1)"
    else
        pass "l3-l4-consistency PASS/PASS = OK (consistent)"
    fi
    # Self-test 2: PASS/FAIL = ERROR (contradiction detection)
    set +e
    bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=FAIL >/dev/null 2>&1
    RC2=$?
    set -e
    if [ "$RC2" -eq 0 ]; then
        fail "l3-l4-consistency PASS/FAIL expected ERROR (contradiction), got OK (exit=$RC2)"
    else
        pass "l3-l4-consistency PASS/FAIL = ERROR (contradiction detected)"
    fi
fi
echo ""

# --- Summary ---
echo "=========================================="
echo "REVIEW RESULT: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "GATE: FAIL — Conductor must NOT merge"
    echo "Fix failures before proceeding with merge."
    exit 1
else
    echo "GATE: PASS — Conductor may proceed with merge"
    exit 0
fi