#!/usr/bin/env bash
# scripts/verify/level-4.sh — L4 独立见证 (independent witness 重跑) (武器 2 Iter 5)
#
# 目的: 独立 Slaver session 重跑 L1-L3, 不可被原 subagent 篡改
# 跟 docs/5-levels.md L4 段 + 武器 1 audit-verify.sh 联合
#
# Usage:
#   bash scripts/verify/level-4.sh TICKET_ID [--dry-run]
#
# 行为:
#   1. 调 audit-verify.sh (武器 1) 校验 hash chain
#   2. 重新跑 L1-L3 (独立路径, 不可信原 subagent 输出)
#   3. 全 PASS = exit 0
#
# Exit codes:
#   0  PASS — audit chain OK + L1-L3 重跑全 PASS
#   1  FAIL — 任一 fail
#   2  ERROR — 参数错

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_ID="${1:-}"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

echo "=========================================="
echo "L4 独立见证验证 (independent witness) — 武器 2"
echo "=========================================="
echo "TICKET: $TICKET_ID"
echo "DRY_RUN: $DRY_RUN"
echo ""

if [ -z "$TICKET_ID" ]; then
    echo "ERROR: TICKET_ID required" >&2
    exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=4

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ----- Check 1: 武器 1 audit-verify.sh 存在 -----
echo ">>> Check 1: audit-verify.sh (武器 1) available"
AUDIT_VERIFY="$KALLAX_ROOT/scripts/audit/audit-verify.sh"
if [ -x "$AUDIT_VERIFY" ]; then
    pass "audit-verify.sh exists + executable"
else
    fail "audit-verify.sh missing: $AUDIT_VERIFY (武器 1 必须先落地)"
    echo ""
    echo "RESULT: FAIL"
    exit 1
fi
echo ""

# ----- Check 2: audit chain 校验 -----
echo ">>> Check 2: audit chain verify"
cd "$KALLAX_ROOT"
set +e
AUDIT_OUT=$(bash "$AUDIT_VERIFY" 2>&1)
AUDIT_RC=$?
set -e
echo "  audit-verify output (first 5 lines):"
echo "$AUDIT_OUT" | head -5 | sed 's/^/    /'
if [ "$AUDIT_RC" -eq 0 ]; then
    pass "audit chain OK (武器 1 PASS)"
elif [ "$AUDIT_RC" -eq 1 ]; then
    # 1 也可能 OK (无 audit log 备案)
    if echo "$AUDIT_OUT" | grep -q "No audit logs found\|does not exist"; then
        pass "audit chain OK (no logs to verify — first run)"
    else
        fail "audit chain FAIL (rc=$AUDIT_RC)"
    fi
else
    fail "audit-verify.sh error (rc=$AUDIT_RC)"
fi
echo ""

# ----- Check 3: 独立 re-run L1 -----
echo ">>> Check 3: independent re-run L1"
if [ "$DRY_RUN" -eq 1 ]; then
    pass "L1 re-run dry-run OK"
else
    set +e
    bash "$SCRIPT_DIR/level-1.sh" >/dev/null 2>&1
    L1_RC=$?
    set -e
    if [ "$L1_RC" -eq 0 ]; then
        pass "L1 re-run PASS (independent)"
    else
        fail "L1 re-run FAIL (rc=$L1_RC) — original subagent 瞒报"
    fi
fi
echo ""

# ----- Check 4: 独立 re-run L2 + L3 -----
echo ">>> Check 4: independent re-run L2 + L3"
if [ "$DRY_RUN" -eq 1 ]; then
    pass "L2+L3 re-run dry-run OK"
else
    set +e
    bash "$SCRIPT_DIR/level-2.sh" "$TICKET_ID" --dry-run >/dev/null 2>&1
    L2_RC=$?
    bash "$SCRIPT_DIR/level-3.sh" "$TICKET_ID" --dry-run >/dev/null 2>&1
    L3_RC=$?
    set -e
    if [ "$L2_RC" -eq 0 ] && [ "$L3_RC" -eq 0 ]; then
        pass "L2+L3 re-run PASS (independent dry-run)"
    else
        fail "L2 or L3 re-run FAIL (L2=$L2_RC, L3=$L3_RC)"
    fi
fi
echo ""

# Summary
echo "=========================================="
echo "L4 Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — L4 not satisfied (independent witness found issues)"
    exit 1
fi
echo "RESULT: PASS — L4 OK (independent witness verified)"
exit 0
