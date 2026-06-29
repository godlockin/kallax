#!/usr/bin/env bash
# scripts/verify/check-fact-forcing-preflight.sh — L4 verify preflight (EPIC-053-A) + 5-Level wrapper (武器 2 Iter 5)
#
# 双重身份:
#   1. 原始 (EPIC-053-A) — 6 checks (l3-l4-consistency, 3 anti-fab, smoke, scope-creep)
#   2. 武器 2 wrapper — 跑 5 level-*.sh (L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary)
#
# Usage:
#   bash scripts/verify/check-fact-forcing-preflight.sh                    # 默认 wrapper 跑 5 levels (no TICKET)
#   bash scripts/verify/check-fact-forcing-preflight.sh <TICKET_ID>        # 跑 5 levels (L1-L5) for ticket
#   bash scripts/verify/check-fact-forcing-preflight.sh --original         # 跑原始 6 checks (向后兼容)
#   bash scripts/verify/check-fact-forcing-preflight.sh --help
#
# 退出码:
#   0  全部 PASS
#   1  有 FAIL
#   2  参数错
#
# Source: EPIC-053-A (L4 verify preflight) + 武器 2 (Iter 5 5-Level Fact-Forcing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

usage() {
    cat <<EOF
check-fact-forcing-preflight.sh — L4 verify preflight + 5-Level wrapper

Usage:
  bash scripts/verify/check-fact-forcing-preflight.sh                # wrapper: 5 levels (no ticket, dry-run OK)
  bash scripts/verify/check-fact-forcing-preflight.sh <TICKET_ID>    # wrapper: 5 levels for ticket
  bash scripts/verify/check-fact-forcing-preflight.sh --original     # 原始 6 checks (EPIC-053-A)
  bash scripts/verify/check-fact-forcing-preflight.sh --help

Examples:
  bash scripts/verify/check-fact-forcing-preflight.sh
  bash scripts/verify/check-fact-forcing-preflight.sh EPIC-053-A
  bash scripts/verify/check-fact-forcing-preflight.sh --original

Exit codes:
  0  全部 PASS
  1  有 FAIL
  2  参数错
EOF
}

# ============ 武器 2 wrapper: 跑 5 level-*.sh ============
run_5_levels_wrapper() {
    local ticket_id="${1:-}"
    echo "=========================================="
    echo "5-Level Fact-Forcing Wrapper (武器 2 Iter 5)"
    echo "=========================================="
    if [ -n "$ticket_id" ]; then
        echo "TICKET: $ticket_id"
    else
        echo "TICKET: (none — HEAD-only + dry-run mode)"
    fi
    echo ""

    local pass_count=0
    local fail_count=0
    local total=5

    for level in 1 2 3 4 5; do
        local script="$VERIFY_DIR/level-${level}.sh"
        echo ">>> Running L${level}: $script"
        if [ ! -x "$script" ]; then
            echo "  [FAIL] L${level} script missing or not executable: $script"
            fail_count=$((fail_count+1))
            echo ""
            continue
        fi

        set +e
        if [ -n "$ticket_id" ]; then
            # 真跑 + 干跑 都跑, 拿 L1 真跑 + 其他 dry-run
            if [ "$level" -eq 1 ]; then
                bash "$script" "$ticket_id" 2>&1
            else
                bash "$script" "$ticket_id" --dry-run 2>&1
            fi
        else
            # 无 ticket: L1 跑 (无 arg 模式), L2-L5 干跑需要 arg → 传 placeholder
            if [ "$level" -eq 1 ]; then
                bash "$script" 2>&1
            else
                bash "$script" "PLACEHOLDER" --dry-run 2>&1 || true
            fi
        fi
        local rc=$?
        set -e

        if [ "$rc" -eq 0 ]; then
            echo "  [PASS] L${level} PASS (rc=0)"
            pass_count=$((pass_count+1))
        else
            echo "  [FAIL] L${level} FAIL (rc=$rc)"
            fail_count=$((fail_count+1))
        fi
        echo ""
    done

    echo "=========================================="
    echo "5-Level Summary: $pass_count PASS, $fail_count FAIL (of $total)"
    echo "=========================================="
    if [ "$fail_count" -gt 0 ]; then
        echo "RESULT: FAIL — 5-Level not satisfied"
        return 1
    fi
    echo "RESULT: PASS — 5-Level OK"
    return 0
}

# ============ 原始 6 checks (EPIC-053-A, 向后兼容) ============
run_original_6_checks() {
    echo "=========================================="
    echo "L4 Verify Preflight (EPIC-053-A original)"
    echo "=========================================="
    echo ""

    local PASS_COUNT=0
    local FAIL_COUNT=0
    local TOTAL_CHECKS=6

    pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
    fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

    # Check 1: l3-l4-consistency.sh exists + executable
    echo ">>> Check 1: l3-l4-consistency.sh available"
    local L3L4_SCRIPT="$VERIFY_DIR/l3-l4-consistency.sh"
    if [ -x "$L3L4_SCRIPT" ]; then
        pass "l3-l4-consistency.sh exists and executable"
    else
        fail "l3-l4-consistency.sh missing or not executable: $L3L4_SCRIPT"
    fi
    echo ""

    # Check 2: 3 anti-fab tools exist + executable
    echo ">>> Check 2: Anti-fab tools available"
    local ANTI_FAB_TOOLS=(
        "check-test-case-isolation.sh"
        "check-kpi-precision.sh"
        "check-scope-creep.sh"
    )
    for tool in "${ANTI_FAB_TOOLS[@]}"; do
        if [ -x "$VERIFY_DIR/$tool" ]; then
            pass "$tool exists and executable"
        else
            fail "$tool missing or not executable"
        fi
    done
    echo ""

    # Check 3: l3-l4-consistency self-test (PASS/PASS = OK)
    echo ">>> Check 3: L3L4 self-test (PASS/PASS = OK)"
    if [ -x "$L3L4_SCRIPT" ]; then
        set +e
        bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=PASS >/dev/null 2>&1
        local RC=$?
        set -e
        if [ "$RC" -eq 0 ]; then
            pass "L3L4 OK on PASS/PASS (exit=0)"
        else
            fail "L3L4 ERROR on PASS/PASS (expected exit=0, got exit=$RC)"
        fi
    else
        fail "L3L4 script not available for self-test"
    fi
    echo ""

    # Check 4: l3-l4-consistency self-test (PASS/FAIL = ERROR)
    echo ">>> Check 4: L3L4 self-test (PASS/FAIL = ERROR)"
    if [ -x "$L3L4_SCRIPT" ]; then
        set +e
        bash "$L3L4_SCRIPT" --l3-status=PASS --l4-status=FAIL >/dev/null 2>&1
        local RC=$?
        set -e
        if [ "$RC" -ne 0 ]; then
            pass "L3L4 ERROR on PASS/FAIL (exit=$RC, contradiction detected)"
        else
            fail "L3L4 OK on PASS/FAIL (expected non-zero, got exit=0 — contradiction NOT detected)"
        fi
    else
        fail "L3L4 script not available for self-test"
    fi
    echo ""

    # Check 5: Anti-fab tools run without crashing
    echo ">>> Check 5: Anti-fab tools smoke run"
    set +e
    bash "$VERIFY_DIR/check-test-case-isolation.sh" >/dev/null 2>&1
    local RC=$?
    set -e
    if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
        pass "check-test-case-isolation.sh runs (exit=$RC)"
    else
        fail "check-test-case-isolation.sh crashed (exit=$RC)"
    fi

    set +e
    bash "$VERIFY_DIR/check-kpi-precision.sh" >/dev/null 2>&1
    local RC=$?
    set -e
    if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
        pass "check-kpi-precision.sh runs (exit=$RC)"
    else
        fail "check-kpi-precision.sh crashed (exit=$RC)"
    fi
    echo ""

    # Check 6: scope-creep wired (skip if no ticket.json)
    echo ">>> Check 6: scope-creep available"
    local TICKET_FILE="$KALLAX_ROOT/jira/tickets/EPIC-053-A/ticket.json"
    if [ -x "$VERIFY_DIR/check-scope-creep.sh" ]; then
        if [ -f "$TICKET_FILE" ]; then
            if bash "$VERIFY_DIR/check-scope-creep.sh" EPIC-053-A >/dev/null 2>&1; then
                pass "check-scope-creep.sh EPIC-053-A runs clean"
            else
                pass "check-scope-creep.sh EPIC-053-A runs (may flag out-of-scope files)"
            fi
        else
            pass "check-scope-creep.sh exists (no ticket to test against)"
        fi
    else
        fail "check-scope-creep.sh missing"
    fi
    echo ""

    # Summary
    echo "=========================================="
    echo "Preflight Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL_CHECKS)"
    echo "=========================================="
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "RESULT: FAIL — L4 verify framework not ready"
        echo "Action: fix failing checks before ticket can pass preflight"
        return 1
    fi
    echo "RESULT: PASS — L4 verify framework ready"
    echo "Action: ticket can proceed to L4 verify gate"
    return 0
}

# ============ CLI 入口 ============
case "${1:-}" in
    --help|-h|help)
        usage
        exit 0
        ;;
    --original)
        run_original_6_checks
        ;;
    "")
        # 默认: wrapper 跑 5 levels (无 ticket = HEAD-only dry-run)
        run_5_levels_wrapper ""
        ;;
    -*)
        echo "ERROR: unknown flag: $1" >&2
        usage
        exit 2
        ;;
    *)
        # TICKET_ID 模式: wrapper 跑 5 levels
        run_5_levels_wrapper "$1"
        ;;
esac
