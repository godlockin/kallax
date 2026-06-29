#!/usr/bin/env bash
# scripts/epic/epic-close.sh — kallax epic:close CLI (武器 4, EPIC iter7-w4)
#
# 责任:
#   1. 调用 scripts/verify/check-epic-4-piece.sh 强制 4 件套
#   2. 4 件套 完整 → 更新 epic.json status="closed" + 写 master_signoff="APPROVED"
#   3. 缺任一件套 → 拒绝 close + 列出缺失项 (跟 武器 4 治根 PROD-001 一致)
#
# Usage:
#   bash scripts/epic/epic-close.sh <EPIC_ID>
#   bash scripts/epic/epic-close.sh --skip-history <EPIC_ID>   # 旧 EPIC 跳过
#   bash scripts/epic/epic-close.sh --dry-run <EPIC_ID>        # 只验证, 不写
#
# 跟 Rule 6/7 经验沉淀强制化 + Rule 10/13 角色边界 (Conductor 调, 不 Master 写) 联合.
# 优于 eket (无 EPIC 体系, 4 件套 是 KALLAX 胜于蓝).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$KALLAX_ROOT/scripts/verify/check-epic-4-piece.sh"

# ---------------- Args parsing ----------------
SKIP_HISTORY=0
DRY_RUN=0
EPIC_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-history)
            SKIP_HISTORY=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            sed -n '2,25p' "$0"
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
    echo "ERROR: EPIC_ID required" >&2
    echo "Usage: $0 [--skip-history] [--dry-run] <EPIC_ID>" >&2
    exit 2
fi

echo "=========================================="
echo "kallax epic:close — $EPIC_ID"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "(dry-run mode: 不写 epic.json)"; fi
echo "=========================================="
echo ""

# ---------------- 4 件套 强制 check ----------------
CHECK_ARGS=("$EPIC_ID")
if [[ "$SKIP_HISTORY" -eq 1 ]]; then
    CHECK_ARGS=("--skip-history" "$EPIC_ID")
fi

set +e
bash "$VERIFY_SCRIPT" "${CHECK_ARGS[@]}"
CHECK_RC=$?
set -e

echo ""
if [[ "$CHECK_RC" -ne 0 ]] && [[ "$CHECK_RC" -ne 2 ]]; then
    echo "=========================================="
    echo "CLOSE FAILED — 4 件套 不完整"
    echo "=========================================="
    echo "Action: 按上面 [FAIL] 项补全 4 件套后再 close (per Rule 6/7 经验沉淀强制化)"
    echo "Tip: 旧 EPIC 可用 --skip-history 跳过 (Q3 决策)"
    exit 1
fi

if [[ "$CHECK_RC" -eq 2 ]]; then
    echo "ERROR: 验证脚本 ERROR (exit 2)" >&2
    exit 2
fi

# ---------------- Close EPIC ----------------
EPIC_JSON="$KALLAX_ROOT/jira/epics/$EPIC_ID/epic.json"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "=========================================="
    echo "DRY-RUN RESULT: 4 件套 验证通过 (skip 了 close 动作)"
    echo "=========================================="
    exit 0
fi

echo ">>> Closing EPIC: $EPIC_ID"

python3 - "$EPIC_JSON" <<'PYEOF'
import json, sys, datetime
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
old_status = d.get('status', 'unknown')
d['status'] = 'closed'
d['master_signoff'] = 'APPROVED'
if 'closure_time' not in d:
    d['closure_time'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
with open(path, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f"  Epic status: {old_status} → closed")
print(f"  master_signoff: APPROVED (set)")
print(f"  closure_time: {d['closure_time']}")
PYEOF

echo ""
echo "=========================================="
echo "EPIC CLOSED: $EPIC_ID"
echo "=========================================="
exit 0