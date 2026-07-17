#!/usr/bin/env bash
# scripts/verify/check-checkin-points.sh — 拍板点验证 (EPIC-111)
#
# 责任:
#   1. 读 jira/epics/<EPIC_ID>/epic.json
#   2. 强制 checkin_points 数组存在 + length >= 1
#   3. --require-passed 模式: 所有 checkin_points 必须 status="passed"
#
# Usage:
#   bash scripts/verify/check-checkin-points.sh <EPIC_ID>
#   bash scripts/verify/check-checkin-points.sh --require-passed <EPIC_ID>
#
# Exit:
#   0 = pass
#   1 = fail (missing / <1 / has pending when --require-passed)
#   2 = error (missing file / bad json / bad args)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

REQUIRE_PASSED=0
EPIC_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --require-passed) REQUIRE_PASSED=1; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        -*) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
        *) EPIC_ID="$1"; shift ;;
    esac
done

if [[ -z "$EPIC_ID" ]]; then
    # Auto-discover from staged files or branch (mirrors check-assumption-clarity v2.0.8 pattern).
    # 0-arg invocation happens when pre-commit wrapper loops through check-*.sh.
    # In pre-commit context (KALLAX_PRE_COMMIT=1), skip auto-discovery to avoid
    # false positives from pre-existing EPIC references in code comments.
    if [[ "${KALLAX_PRE_COMMIT:-0}" == "1" ]]; then
        echo "WARN: check-checkin-points skipped (pre-commit context, auto-discovery deferred to CI)" >&2
        exit 0
    fi
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
        echo "WARN: check-checkin-points skipped (no EPIC_ID detected from arg, staged files, or branch)" >&2
        exit 0
    fi
    echo "INFO: auto-discovered EPIC_ID=$EPIC_ID" >&2
fi

EPIC_JSON="jira/epics/$EPIC_ID/epic.json"
if [[ ! -f "$EPIC_JSON" ]]; then
    # Fallback: try branch EPIC if auto-discovery found a non-existent one
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    BRANCH_EPIC="$(echo "$branch" | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
    if [[ -n "$BRANCH_EPIC" && "$BRANCH_EPIC" != "$EPIC_ID" ]]; then
        EPIC_ID="$BRANCH_EPIC"
        EPIC_JSON="jira/epics/$EPIC_ID/epic.json"
        echo "INFO: falling back to branch EPIC_ID=$EPIC_ID" >&2
    fi
fi
if [[ ! -f "$EPIC_JSON" ]]; then
    echo "ERROR: $EPIC_JSON not found" >&2
    exit 2
fi

echo "=========================================="
echo "Checkin Points Check — $EPIC_ID"
echo "=========================================="

python3 - "$EPIC_JSON" "$REQUIRE_PASSED" <<'PYEOF'
import json, sys
path, require_passed = sys.argv[1], sys.argv[2] == "1"
try:
    with open(path) as f:
        d = json.load(f)
except Exception as e:
    print(f"ERROR: parse fail: {e}", file=sys.stderr)
    sys.exit(2)

cps = d.get("checkin_points", [])
if not isinstance(cps, list) or len(cps) < 1:
    print(f"FAIL: checkin_points missing or empty (need >=1)")
    print(f"  found: {cps!r}")
    print(f"REQUIREMENT: EPIC must declare >=1 checkin_point at create (EPIC-111)")
    sys.exit(1)

print(f"checkin_points: {len(cps)}")
for cp in cps:
    name = cp.get("name", "?")
    gate = cp.get("gate", "?")
    status = cp.get("status", "pending")
    marker = {"pending":"[ ]", "passed":"[x]", "failed":"[!]"}.get(status, "[?]")
    print(f"  {marker} {name} [{gate}] status={status}")

if require_passed:
    unpassed = [cp for cp in cps if cp.get("status") != "passed"]
    if unpassed:
        print(f"")
        print(f"FAIL: --require-passed but {len(unpassed)} checkin_points not passed")
        for cp in unpassed:
            print(f"  - {cp.get('name')} status={cp.get('status', 'pending')}")
        sys.exit(1)

print("")
print("PASS: checkin_points requirement met")
PYEOF
