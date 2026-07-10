#!/usr/bin/env bash
# scripts/epic/epic-create.sh — kallax epic:create CLI (EPIC-111)
#
# 责任:
#   1. 创建 jira/epics/<EPIC_ID>/epic.json 骨架
#   2. 强制 checkin_points >= 1 (跟 epic-schema.json 联合)
#   3. 缺 --checkin-point → 拒绝 create + 提示
#
# Usage:
#   bash scripts/epic/epic-create.sh \
#       --id EPIC-XXX --title "Title" \
#       --checkin-point "name:gate" \
#       [--checkin-point "name2:gate2"] ...
#
#   gate ∈ {master-signoff, 4-expert, main-review, smoke-test}
#
# Examples:
#   bash scripts/epic/epic-create.sh --id EPIC-200 --title "New feature" \
#       --checkin-point "design-review:4-expert" \
#       --checkin-point "ship:master-signoff"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EPIC_ID=""
TITLE=""
CHECKIN_POINTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id) EPIC_ID="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --checkin-point) CHECKIN_POINTS+=("$2"); shift 2 ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$EPIC_ID" ]]; then
    echo "ERROR: --id required" >&2; exit 2
fi
if [[ -z "$TITLE" ]]; then
    echo "ERROR: --title required" >&2; exit 2
fi

# EPIC-111 强制: checkin_points >= 1
if [[ ${#CHECKIN_POINTS[@]} -lt 1 ]]; then
    echo "=========================================="
    echo "EPIC CREATE REJECTED — checkin_points < 1"
    echo "=========================================="
    echo "REQUIREMENT: 至少 1 个 --checkin-point (EPIC-111 拍板点协议)"
    echo "Valid gates: master-signoff | 4-expert | main-review | smoke-test"
    echo ""
    echo "Example:"
    echo "  $0 --id $EPIC_ID --title \"$TITLE\" \\"
    echo "     --checkin-point \"design-review:4-expert\" \\"
    echo "     --checkin-point \"ship:master-signoff\""
    exit 1
fi

EPIC_DIR="$KALLAX_ROOT/jira/epics/$EPIC_ID"
EPIC_JSON="$EPIC_DIR/epic.json"

if [[ -e "$EPIC_JSON" ]]; then
    echo "ERROR: $EPIC_JSON already exists" >&2
    exit 1
fi

mkdir -p "$EPIC_DIR"

# Build checkin_points JSON array + validate gate
CHECKIN_JSON="["
first=1
for cp in "${CHECKIN_POINTS[@]}"; do
    name="${cp%%:*}"
    gate="${cp#*:}"
    case "$gate" in
        master-signoff|4-expert|main-review|smoke-test) ;;
        *)
            echo "ERROR: invalid gate '$gate' for checkin-point '$name'" >&2
            echo "Valid gates: master-signoff | 4-expert | main-review | smoke-test" >&2
            exit 2 ;;
    esac
    if [[ -z "$name" ]] || [[ "$name" == "$cp" ]]; then
        echo "ERROR: bad --checkin-point format '$cp' (expect 'name:gate')" >&2
        exit 2
    fi
    if [[ $first -eq 0 ]]; then CHECKIN_JSON+=","; fi
    CHECKIN_JSON+="{\"name\":\"$name\",\"gate\":\"$gate\",\"status\":\"pending\"}"
    first=0
done
CHECKIN_JSON+="]"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 - "$EPIC_JSON" "$EPIC_ID" "$TITLE" "$NOW" "$CHECKIN_JSON" <<'PYEOF'
import json, sys
path, epic_id, title, now, checkin_json = sys.argv[1:6]
d = {
    "id": epic_id,
    "title": title,
    "status": "planning",
    "start_time": now,
    "tickets": [],
    "checkin_points": json.loads(checkin_json),
}
with open(path, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f"CREATED: {path}")
print(f"  id={epic_id} title={title!r}")
print(f"  checkin_points={len(d['checkin_points'])}")
for cp in d['checkin_points']:
    print(f"    - {cp['name']} [{cp['gate']}]")
PYEOF

exit 0
