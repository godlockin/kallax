#!/usr/bin/env bash
# scripts/verify/release-gate.sh — Release Gate 综合验证 (EPIC-112)
#
# 责任: 综合运行 5 项 gate check, 汇总 PASS/FAIL, 用于 release 前最后一道门。
#
# 5 项 gate (跟 EPIC-110 + EPIC-111 联合):
#   G1. check-decorative-claim.sh  (法律 1: 0 装饰)
#   G2. check-narrative.sh          (法律 2: 0 narrative 包装)
#   G3. check-fail-closed.sh        (法律 3: 0 fail-open)
#   G4. check-self-heal.sh          (法律 4: self-heal pattern)
#   G5. check-checkin-points.sh     (EPIC-111: 拍板点)
#
# Usage:
#   bash scripts/verify/release-gate.sh                    # 全 repo, 4 法律 only
#   bash scripts/verify/release-gate.sh --epic EPIC-XXX    # + G5 checkin points
#   bash scripts/verify/release-gate.sh --json             # JSON 输出
#   bash scripts/verify/release-gate.sh --strict           # G5 --require-passed
#
# Exit:
#   0 = all pass
#   1 = 1+ gate fail
#   2 = error (bad args / missing file)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

EPIC_ID=""
JSON_MODE=0
STRICT_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --epic) EPIC_ID="$2"; shift 2 ;;
        --json) JSON_MODE=1; shift ;;
        --strict) STRICT_MODE=1; shift ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Collect results
RESULTS=()
FAIL_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0

check_gate() {
    local name="$1"
    local script="$2"
    shift 2
    local out rc

    if [[ ! -f "$script" ]]; then
        RESULTS+=("$name|SKIP|script missing: $script")
        SKIP_COUNT=$((SKIP_COUNT+1))
        return
    fi

    out=$(bash "$script" "$@" 2>&1)
    rc=$?
    local last_line
    last_line=$(echo "$out" | grep -E '^(PASS|FAIL):' | tail -1)
    [[ -z "$last_line" ]] && last_line=$(echo "$out" | tail -1)

    if [[ $rc -eq 0 ]]; then
        RESULTS+=("$name|PASS|$last_line")
        PASS_COUNT=$((PASS_COUNT+1))
    else
        RESULTS+=("$name|FAIL|$last_line (exit=$rc)")
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

# Run 4 laws (staged-only OFF → full repo scan)
check_gate "G1-decorative" "scripts/verify/check-decorative-claim.sh"
check_gate "G2-narrative"  "scripts/verify/check-narrative.sh"
check_gate "G3-fail-closed" "scripts/verify/check-fail-closed.sh"
check_gate "G4-self-heal"  "scripts/verify/check-self-heal.sh"

# G5: checkin points (only when --epic given)
if [[ -n "$EPIC_ID" ]]; then
    if [[ $STRICT_MODE -eq 1 ]]; then
        check_gate "G5-checkin-$EPIC_ID" "scripts/verify/check-checkin-points.sh" --require-passed "$EPIC_ID"
    else
        check_gate "G5-checkin-$EPIC_ID" "scripts/verify/check-checkin-points.sh" "$EPIC_ID"
    fi
else
    RESULTS+=("G5-checkin|SKIP|no --epic given")
    SKIP_COUNT=$((SKIP_COUNT+1))
fi

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))

# Output
if [[ $JSON_MODE -eq 1 ]]; then
    printf '{\n'
    printf '  "release_gate": {\n'
    printf '    "total": %d,\n' "$TOTAL"
    printf '    "pass": %d,\n' "$PASS_COUNT"
    printf '    "fail": %d,\n' "$FAIL_COUNT"
    printf '    "skip": %d,\n' "$SKIP_COUNT"
    printf '    "epic": "%s",\n' "$EPIC_ID"
    printf '    "strict": %s,\n' "$([[ $STRICT_MODE -eq 1 ]] && echo true || echo false)"
    printf '    "gates": [\n'
    local_i=0
    for r in "${RESULTS[@]}"; do
        IFS='|' read -r n s msg <<< "$r"
        [[ $local_i -gt 0 ]] && printf ',\n'
        # escape quotes in msg
        msg_esc=${msg//\"/\\\"}
        printf '      {"name":"%s","status":"%s","message":"%s"}' "$n" "$s" "$msg_esc"
        local_i=$((local_i+1))
    done
    printf '\n    ]\n'
    printf '  }\n'
    printf '}\n'
else
    echo "=========================================="
    echo "Release Gate — 5 checks"
    [[ -n "$EPIC_ID" ]] && echo "EPIC: $EPIC_ID $([[ $STRICT_MODE -eq 1 ]] && echo '(strict)')"
    echo "=========================================="
    for r in "${RESULTS[@]}"; do
        IFS='|' read -r n s msg <<< "$r"
        case "$s" in
            PASS) marker="[x]" ;;
            FAIL) marker="[!]" ;;
            SKIP) marker="[-]" ;;
            *)    marker="[?]" ;;
        esac
        printf '  %s %-30s %s\n' "$marker" "$n" "$msg"
    done
    echo ""
    echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT (total=$TOTAL)"
fi

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
