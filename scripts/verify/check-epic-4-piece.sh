#!/usr/bin/env bash
# scripts/verify/check-epic-4-piece.sh — EPIC 4-Piece Enforcer (武器 4, EPIC iter7-w4)
#
# 治根 PROD-001 "0 实际变化 假动作" — Rule 6/7 强制 EPIC 4 件套 但 无 enforcement.
# 历史 33 EPIC 中 0 个有 LESSONS-LEARNED.md (实测, 治根前状态).
#
# 4 件套:
#   1. A+B review  — ticket.json `review:` 字段 ({group_a, group_b, master})
#   2. README.md    — jira/epics/EPIC-XXX/README.md 存在 + 非空
#   3. LESSONS.md   — jira/epics/EPIC-XXX/LESSONS-LEARNED.md 存在 + 含 "教训:" 章节
#   4. master_signoff — epic.json `master_signoff:` = "APPROVED"
#
# Usage:
#   bash scripts/verify/check-epic-4-piece.sh <EPIC_ID>
#   bash scripts/verify/check-epic-4-piece.sh --skip-history <EPIC_ID>   # 旧 EPIC 跳过
#
# Exit codes:
#   0  PASS — 4 件套 全有 (或 旧 EPIC --skip-history)
#   1  FAIL — 缺任一件套
#   2  ERROR — EPIC_ID 缺失/格式错/EPIC 目录不存在
#
# 跟 Rule 6/7 经验沉淀强制化 联合 (CLAUDE.md §6+7). 优于 eket (无 EPIC 体系).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---------------- Args parsing ----------------
SKIP_HISTORY=0
EPIC_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-history)
            SKIP_HISTORY=1
            shift
            ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        -*)
            echo "ERROR: unknown flag: $1" >&2
            exit 2
            ;;
        *)
            EPIC_ID="$1"
            shift
            ;;
    esac
done

if [[ -z "$EPIC_ID" ]]; then
    # Auto-discover from staged files or branch (mirrors check-assumption-clarity v2.0.8 pattern).
    # 0-arg invocation happens when pre-commit wrapper loops through check-*.sh.
    staged="$(git diff --cached --name-only 2>/dev/null || true)"
    EPIC_ID="$(echo "$staged" | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
    if [[ -z "$EPIC_ID" ]]; then
        EPIC_ID="$(git diff --cached 2>/dev/null | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
    fi
    if [[ -z "$EPIC_ID" ]]; then
        branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        EPIC_ID="$(echo "$branch" | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
    fi
    if [[ -z "$EPIC_ID" ]]; then
        echo "WARN: check-epic-4-piece skipped (no EPIC_ID from arg/staged/branch)" >&2
        exit 0
    fi
    echo "INFO: auto-discovered EPIC_ID=$EPIC_ID" >&2
    # 4-piece is for CLOSING an EPIC. If epic still in creation (status != done), skip.
    # Probe staged index first (worktree: file staged but not on disk in KALLAX_ROOT).
    _STATUS=""
    _STAGED_EPIC=$(git diff --cached --name-only 2>/dev/null | grep -E "jira/epics/${EPIC_ID}/epic\.json$" | head -1 || true)
    if [[ -n "$_STAGED_EPIC" ]]; then
        _STATUS=$(git show ":$_STAGED_EPIC" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
    fi
    if [[ -z "$_STATUS" ]]; then
        _EPIC_JSON_PROBE="$KALLAX_ROOT/jira/epics/$EPIC_ID/epic.json"
        if [[ -f "$_EPIC_JSON_PROBE" ]]; then
            _STATUS=$(python3 -c "import json; print(json.load(open('$_EPIC_JSON_PROBE')).get('status',''))" 2>/dev/null || echo "")
        fi
    fi
    if [[ "$_STATUS" != "done" ]] && [[ "$_STATUS" != "completed" ]]; then
        echo "INFO: EPIC $EPIC_ID status=${_STATUS:-not-yet-created} (not closing) — 4-piece check skipped" >&2
        exit 0
    fi
fi

if [[ ! "$EPIC_ID" =~ ^EPIC-[0-9]+$ ]]; then
    echo "ERROR: invalid EPIC_ID format: $EPIC_ID (expected EPIC-NNN)" >&2
    exit 2
fi

EPIC_DIR="$KALLAX_ROOT/jira/epics/$EPIC_ID"
EPIC_JSON="$EPIC_DIR/epic.json"

echo "=========================================="
echo "EPIC 4-Piece Enforcer — $EPIC_ID"
echo "=========================================="

if [[ ! -d "$EPIC_DIR" ]]; then
    echo "ERROR: EPIC directory not found: $EPIC_DIR" >&2
    exit 2
fi

# ---------------- History detection (Q3 决策) ----------------
# 旧 EPIC 定义: epic.json 中 start_time < 2026-06-29 (武器 4 实施日).
# 旧 EPIC 在 --skip-history 模式下直接跳过 (Q3 决策: 不补历史 4 件套, 避免装饰).
# 适用于 status=done (历史完成) 或 status=active (进行中, 无 retro 必要).
if [[ "$SKIP_HISTORY" -eq 1 ]]; then
    if [[ -f "$EPIC_JSON" ]]; then
        START_TIME=$(python3 -c "import json,sys; d=json.load(open('$EPIC_JSON')); print(d.get('start_time',''))" 2>/dev/null || echo "")
        if [[ -n "$START_TIME" ]] && [[ "$START_TIME" < "2026-06-29" ]]; then
            echo ">>> [SKIP] 旧 EPIC (历史, start_time=$START_TIME, < 2026-06-29)"
            echo "    Q3 决策: 不补历史 4 件套 (避免装饰)"
            echo ""
            echo "=========================================="
            echo "RESULT: SKIP — 旧 EPIC 跳过 (per Q3)"
            echo "=========================================="
            exit 0
        fi
    fi
fi

# ---------------- 4 件套 检查 ----------------
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=4
MISSING=()

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); MISSING+=("$1"); }

echo ""
echo ">>> Piece 1: A+B review (ticket.json review:{group_a, group_b, master})"
TICKETS_WITH_REVIEW=0
TICKETS_TOTAL=0
if [[ -d "$KALLAX_ROOT/jira/tickets" ]]; then
    for ticket_dir in "$KALLAX_ROOT/jira/tickets"/${EPIC_ID}-*/; do
        [[ -d "$ticket_dir" ]] || continue
        TICKETS_TOTAL=$((TICKETS_TOTAL+1))
        ticket_json="$ticket_dir/ticket.json"
        [[ -f "$ticket_json" ]] || continue
        # Check review field has group_a=group_b=master all PASS/APPROVED
        REVIEW_INFO=$(python3 -c "
import json, sys
try:
    d = json.load(open('$ticket_json'))
    rev = d.get('review', {})
    if not isinstance(rev, dict):
        print('NO_REVIEW')
        sys.exit(0)
    ga = rev.get('group_a', '')
    gb = rev.get('group_b', '')
    m = rev.get('master', '')
    if ga == 'PASS' and gb == 'PASS' and m == 'APPROVED':
        print('PASS')
    else:
        print(f'INCOMPLETE: ga={ga} gb={gb} m={m}')
except Exception as e:
    print(f'ERROR: {e}')
" 2>/dev/null || echo "ERROR")
        if [[ "$REVIEW_INFO" == "PASS" ]]; then
            TICKETS_WITH_REVIEW=$((TICKETS_WITH_REVIEW+1))
        fi
    done
fi
if [[ "$TICKETS_TOTAL" -eq 0 ]]; then
    fail "A+B review: no tickets found under jira/tickets/${EPIC_ID}-*"
elif [[ "$TICKETS_WITH_REVIEW" -eq "$TICKETS_TOTAL" ]] && [[ "$TICKETS_WITH_REVIEW" -gt 0 ]]; then
    pass "A+B review: $TICKETS_WITH_REVIEW/$TICKETS_TOTAL tickets have review:{group_a=PASS, group_b=PASS, master=APPROVED}"
else
    fail "A+B review: only $TICKETS_WITH_REVIEW/$TICKETS_TOTAL tickets have complete review field"
fi
echo ""

echo ">>> Piece 2: README.md (jira/epics/$EPIC_ID/README.md 存在 + 非空)"
README_FILE="$EPIC_DIR/README.md"
if [[ -f "$README_FILE" ]] && [[ -s "$README_FILE" ]]; then
    SIZE=$(wc -c < "$README_FILE")
    pass "README.md exists and non-empty (${SIZE} bytes)"
else
    fail "README.md missing or empty: $README_FILE"
fi
echo ""

echo ">>> Piece 3: LESSONS-LEARNED.md (含 '教训:' 章节)"
LESSONS_FILE="$EPIC_DIR/LESSONS-LEARNED.md"
if [[ -f "$LESSONS_FILE" ]] && [[ -s "$LESSONS_FILE" ]]; then
    if grep -q "教训" "$LESSONS_FILE"; then
        SIZE=$(wc -c < "$LESSONS_FILE")
        pass "LESSONS-LEARNED.md exists, non-empty (${SIZE} bytes), contains '教训' section"
    else
        fail "LESSONS-LEARNED.md exists but missing '教训' section"
    fi
else
    fail "LESSONS-LEARNED.md missing or empty: $LESSONS_FILE"
fi
echo ""

echo ">>> Piece 4: master_signoff (epic.json master_signoff == APPROVED)"
if [[ -f "$EPIC_JSON" ]]; then
    SIGNOFF=$(python3 -c "
import json
d = json.load(open('$EPIC_JSON'))
v = d.get('master_signoff', '')
print(v if v else 'EMPTY')
" 2>/dev/null || echo "PARSE_ERROR")
    if [[ "$SIGNOFF" == "APPROVED" ]]; then
        pass "master_signoff == 'APPROVED' in epic.json"
    else
        fail "master_signoff missing or != 'APPROVED' (got: $SIGNOFF)"
    fi
else
    fail "epic.json missing: $EPIC_JSON"
fi
echo ""

# ---------------- Summary ----------------
echo "=========================================="
echo "4-Piece Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL_CHECKS)"
echo "=========================================="
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "RESULT: FAIL — 缺 ${FAIL_COUNT} 件套:"
    for m in "${MISSING[@]}"; do
        echo "  - $m"
    done
    echo ""
    echo "Action: 完成 4 件套后再 close EPIC (per Rule 6/7 经验沉淀强制化)"
    exit 1
fi
echo "RESULT: PASS — 4 件套 全部就绪 (可 close EPIC)"
exit 0