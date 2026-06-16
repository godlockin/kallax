#!/usr/bin/env bash
# scripts/verify/l3-l4-consistency.sh — L3 集成测试 vs L4 verify 一致性强制 (BE-9 治根)
#
# EPIC-053-A — Rule 8 (4-Level Fact-Forcing) 强约束: L3 + L4 不许矛盾
# 防防御体系自检漏洞 (BE-9): 当 L3 跑 PASS, L4 报 FAIL (或反之) 时,
# 意味着 verify 系统在自检自己的失败 — 必须硬约束为 ERROR.
#
# Usage:
#   l3-l4-consistency.sh --l3-status=PASS|FAIL --l4-status=PASS|FAIL
#
# Exit codes:
#   0 = L3 L4 一致 (OK)
#   1 = L3 L4 矛盾 (ERROR — BE-9 自检漏洞)
#   2 = 参数错误
#
# Truth table:
#        L3 PASS   L3 FAIL
# L4 PASS  OK      ERROR  ← 矛盾
# L4 FAIL  ERROR   OK
#
# 跟 check-fact-forcing-preflight.sh 联动, 跟 Rule 8 4-Level 联合.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

L3_STATUS=""
L4_STATUS=""

usage() {
    cat <<'USAGE'
Usage: l3-l4-consistency.sh --l3-status=PASS|FAIL --l4-status=PASS|FAIL

Verifies that L3 (integration tests) and L4 (verify scripts) signals agree.
Contradiction = ERROR (exit 1) = defense system self-check failure (BE-9).

Truth table:
       L3 PASS   L3 FAIL
L4 PASS  OK      ERROR
L4 FAIL  ERROR   OK

Exit codes:
  0 = consistent (OK)
  1 = contradiction (ERROR)
  2 = invalid arguments
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --l3-status=*)
            L3_STATUS="${1#*=}"
            shift
            ;;
        --l4-status=*)
            L4_STATUS="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown arg: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# Validate inputs
if [ -z "$L3_STATUS" ] || [ -z "$L4_STATUS" ]; then
    echo "ERROR: both --l3-status and --l4-status required" >&2
    usage >&2
    exit 2
fi

case "$L3_STATUS" in
    PASS|FAIL) ;;
    *)
        echo "ERROR: --l3-status must be PASS or FAIL (got: $L3_STATUS)" >&2
        exit 2
        ;;
esac

case "$L4_STATUS" in
    PASS|FAIL) ;;
    *)
        echo "ERROR: --l4-status must be PASS or FAIL (got: $L4_STATUS)" >&2
        exit 2
        ;;
esac

# Core consistency check
if [ "$L3_STATUS" = "$L4_STATUS" ]; then
    echo "=========================================="
    echo "L3/L4 Consistency Check (BE-9 anti-self-check-failure)"
    echo "=========================================="
    echo "L3 status: $L3_STATUS"
    echo "L4 status: $L4_STATUS"
    echo ""
    echo "OK: L3 and L4 agree ($L3_STATUS/$L4_STATUS)"
    if [ "$L3_STATUS" = "PASS" ]; then
        echo "Action: both passed, ticket ready for L4 verify gate"
    else
        echo "Action: both failed (honest), ticket stays in_progress"
    fi
    exit 0
fi

# Contradiction detected — BE-9
echo "=========================================="
echo "L3/L4 Consistency Check (BE-9 anti-self-check-failure)"
echo "=========================================="
echo "L3 status: $L3_STATUS"
echo "L4 status: $L4_STATUS"
echo ""
echo "ERROR: L3 and L4 CONTRADICT (defense system self-check failure)"
echo ""
echo "Anti-pattern: BE-9 — defense system lying about its own checks."
echo "When L3 and L4 disagree, at least one is fabricating signal."
echo ""
echo "Required action:"
echo "  1. Re-run L3 integration tests from clean state (no cache)"
echo "  2. Re-run L4 verify scripts with --no-cache flag"
echo "  3. If still contradictory: ticket REJECT (Rule 18 blacklist)"
echo ""
exit 1
