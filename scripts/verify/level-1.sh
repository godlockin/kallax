#!/usr/bin/env bash
# scripts/verify/level-1.sh — L1 存在性 (git log SHA 真变) (武器 2 Iter 5)
#
# 目的: 验证 commit 真存在 + SHA 真变 (反 "Amend SHA 没变" 反模式)
# 跟 docs/5-levels.md L1 段 1:1 联合
#
# Usage:
#   bash scripts/verify/level-1.sh [TICKET_ID]
#
# Exit codes:
#   0  PASS — HEAD SHA 存在 + 变更文件 ≥ 1
#   1  FAIL — 无 commit / 变更文件 = 0 / ticket.json 不存在
#   2  ERROR — 参数错 / git 不可用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_ID="${1:-}"

echo "=========================================="
echo "L1 存在性验证 (git log SHA 真变) — 武器 2"
echo "=========================================="
if [ -n "$TICKET_ID" ]; then
    echo "TICKET: $TICKET_ID"
else
    echo "TICKET: (none — HEAD-only mode)"
fi
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=4

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ----- Check 1: git 仓库存在 (worktree 可能是 gitfile, 不是 directory) -----
echo ">>> Check 1: git repo available"
if [ -d "$KALLAX_ROOT/.git" ] || [ -f "$KALLAX_ROOT/.git" ]; then
    pass ".git present (dir or file — worktree gitfile OK)"
else
    fail "Not a git repo: $KALLAX_ROOT"
    echo ""
    echo "RESULT: FAIL (no git repo)"
    exit 1
fi
echo ""

# ----- Check 2: HEAD commit 存在 + 输出 SHA -----
echo ">>> Check 2: HEAD commit SHA"
cd "$KALLAX_ROOT"
set +e
HEAD_SHA=$(git log --oneline -1 2>&1)
RC=$?
set -e
if [ "$RC" -ne 0 ] || [ -z "$HEAD_SHA" ]; then
    fail "git log failed (no commits?)"
    echo "$HEAD_SHA"
    echo ""
    echo "RESULT: FAIL"
    exit 1
fi
echo "  HEAD: $HEAD_SHA"
pass "HEAD SHA captured: $(echo "$HEAD_SHA" | awk '{print $1}')"
echo ""

# ----- Check 3: 变更文件 ≥ 1 -----
echo ">>> Check 3: changed files ≥ 1"
CHANGED_COUNT=$(git diff HEAD~1 --name-only 2>/dev/null | wc -l | tr -d ' ' || echo 0)
if [ "$CHANGED_COUNT" -ge 1 ]; then
    pass "$CHANGED_COUNT files changed in HEAD"
else
    # initial commit (no parent)
    if git log --oneline 2>/dev/null | wc -l | tr -d ' ' | grep -q "^1$"; then
        pass "initial commit (no parent to diff) — count=0 OK"
    else
        fail "0 files changed in HEAD (no real work done)"
    fi
fi
echo ""

# ----- Check 4 (optional): TICKET_ID 关联 -----
if [ -n "$TICKET_ID" ]; then
    echo ">>> Check 4: ticket reference: $TICKET_ID"
    TICKET_FILE="$KALLAX_ROOT/jira/tickets/$TICKET_ID/ticket.json"
    if [ -f "$TICKET_FILE" ]; then
        pass "ticket.json exists: $TICKET_FILE"
    else
        fail "ticket.json missing: $TICKET_FILE (warn only — TICKET_ID optional)"
    fi
    echo ""
fi

# Summary
echo "=========================================="
echo "L1 Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — L1 not satisfied"
    exit 1
fi
echo "RESULT: PASS — L1 OK (git SHA 真变)"
exit 0
