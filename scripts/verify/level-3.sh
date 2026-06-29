#!/usr/bin/env bash
# scripts/verify/level-3.sh — L3 接线正确 (4-expert 评审) (武器 2 Iter 5 / v3.1.0 dry-run)
#
# 目的: 4 个 expert 真实审 PR (architect/backend/frontend/security), 反 "自审" 反模式
# 跟 docs/5-levels.md L3 段 1:1 联合
# v3.1.0 实做: 缺备案 → exit 2 (跟 W4 check-epic-4-piece.sh schema 一致)
#
# Usage:
#   bash scripts/verify/level-3.sh TICKET_ID [--dry-run]
#
# 行为:
#   1. 4 expert 各自触发 (architect/backend/frontend/security)
#   2. 读 .kallax/reviews/<TICKET_ID>/<expert>.json 输出 PASS/FAIL + rationale
#   3. 全部 PASS = exit 0, 任何 FAIL = exit 1, 备案缺失/parse error = exit 2
#
# Exit codes:
#   0  PASS — 4 expert 全 PASS (或 --dry-run)
#   1  FAIL — 任一 expert 显式 FAIL (status=PASS 之外)
#   2  ERROR — review 备案缺失 / JSON parse error / 参数错 (跟 W4 schema 一致)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_ID="${1:-}"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

EXPERT_LIST=("architect" "backend" "frontend" "security")

echo "=========================================="
echo "L3 接线正确验证 (4-expert 评审) — 武器 2"
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
ERROR_COUNT=0
TOTAL=4

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }
err()  { echo "  [ERROR] $1"; ERROR_COUNT=$((ERROR_COUNT+1)); }

REVIEW_DIR="$KALLAX_ROOT/.kallax/reviews/$TICKET_ID"
mkdir -p "$REVIEW_DIR" 2>/dev/null || true

# ----- 4 expert 评审 -----
for expert in "${EXPERT_LIST[@]}"; do
    echo ">>> Expert: $expert"
    REVIEW_FILE="$REVIEW_DIR/${expert}.json"

    if [ "$DRY_RUN" -eq 1 ]; then
        pass "expert=$expert dry-run OK (review file path: $REVIEW_FILE)"
        echo ""
        continue
    fi

    if [ ! -f "$REVIEW_FILE" ]; then
        err "expert=$expert review missing: $REVIEW_FILE (跟 W4 schema 一致, exit 2)"
        echo ""
        continue
    fi

    # Parse review JSON: 必须有 status + rationale 字段
    set +e
    EXPERT_STATUS=$(python3 -c "
import json, sys
try:
    d = json.load(open('$REVIEW_FILE'))
    print(d.get('status', 'unknown'))
except Exception as e:
    print('parse_error')
" 2>&1)
    RC=$?
    set -e

    if [ "$RC" -ne 0 ] || [ "$EXPERT_STATUS" = "parse_error" ]; then
        err "expert=$expert review JSON parse error: $REVIEW_FILE"
        echo ""
        continue
    fi

    if [ "$EXPERT_STATUS" = "PASS" ]; then
        pass "expert=$expert review=PASS"
    else
        fail "expert=$expert review=$EXPERT_STATUS (expected PASS)"
    fi
    echo ""
done

# Summary
echo "=========================================="
echo "L3 Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL, $ERROR_COUNT ERROR (of $TOTAL)"
echo "=========================================="
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "RESULT: ERROR — L3 review 备案不完整 (exit 2, 跟 W4 schema 一致)"
    exit 2
fi
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — L3 not satisfied (4-expert review incomplete)"
    exit 1
fi
echo "RESULT: PASS — L3 OK (4 expert PASS)"
exit 0
