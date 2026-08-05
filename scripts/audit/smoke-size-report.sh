#!/usr/bin/env bash
# scripts/audit/smoke-size-report.sh
# EPIC-174: Smoke Size Report
# 报告当前所有 smoke 测试状态 (行数 + 价值判定)
# Exit: 0=PASS, 1=FAIL, 2=BLOCKED-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE_DIR="$PROJECT_ROOT/tests/integration"
THRESHOLD=500

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; YELLOW=''; GREEN=''; BLUE=''; NC=''
fi

log_info() { echo "[INFO] $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

EPIC-174 Smoke Size Report
报告所有 smoke 测试的行数和价值判定

OPTIONS:
    -h, --help          显示帮助
    -j, --json          JSON 输出格式
    -v, --verbose       详细输出

EXIT CODES:
    0   报告生成成功
    2   BLOCKED - 环境问题
EOF
}

JSON_OUTPUT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -j|--json) JSON_OUTPUT=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        *) echo "Unknown: $1"; usage; exit 2 ;;
    esac
done

if [ ! -d "$SMOKE_DIR" ]; then
    log_fail "SMOKE_DIR not found: $SMOKE_DIR"
    exit 2
fi

# Find all smoke test files
smoke_files=()
while IFS= read -r f; do
    [ -n "$f" ] && smoke_files+=("$f")
done < <(find "$SMOKE_DIR" -name "*-smoke.test.sh" -type f 2>/dev/null | sort)

# Value assessment function
assess_value() {
    local file="$1"
    local lines="$2"

    # Check for regression background (Rule 4)
    if grep -q "EPIC-[0-9]" "$file" 2>/dev/null; then
        echo "regression"
    elif [ "$lines" -ge "$THRESHOLD" ]; then
        echo "overdue-refactor"
    elif grep -q "CLI\|runtime\|--help\|--version" "$file" 2>/dev/null; then
        echo "cli-behavior"
    elif grep -q "contract\|schema\|boundary" "$file" 2>/dev/null; then
        echo "control-plane"
    else
        echo "unknown"
    fi
}

# Generate report
if [ "$JSON_OUTPUT" = true ]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"threshold\": $THRESHOLD,"
    echo "  \"smoke_tests\": ["

    first=true
    if [ ${#smoke_files[@]} -gt 0 ]; then
        for file in "${smoke_files[@]}"; do
            lines=$(wc -l < "$file")
            value=$(assess_value "$file" "$lines")
            status="ok"
            if [ "$lines" -ge "$THRESHOLD" ]; then
                status="violation"
            fi

            [ "$first" = false ] && echo ","
            first=false
            echo "    {"
            echo "      \"file\": \"$(basename "$file")\","
            echo "      \"path\": \"$file\","
            echo "      \"lines\": $lines,"
            echo "      \"value\": \"$value\","
            echo "      \"status\": \"$status\""
            echo -n "    }"
        done
    fi

    echo ""
    echo "  ],"

    total=${#smoke_files[@]}
    violations=0
    if [ ${#smoke_files[@]} -gt 0 ]; then
        for file in "${smoke_files[@]}"; do
            lines=$(wc -l < "$file")
            if [ "$lines" -ge "$THRESHOLD" ]; then
                violations=$((violations + 1))
            fi
        done
    fi

    echo "  \"summary\": {"
    echo "    \"total\": $total,"
    echo "    \"violations\": $violations,"
    echo "    \"threshold\": $THRESHOLD"
    echo "  }"
    echo "}"
else
    echo "=============================================="
    echo "KALLAX Smoke Size Report"
    echo "Generated: $(date)"
    echo "Threshold: $THRESHOLD lines"
    echo "=============================================="
    echo ""

    if [ ${#smoke_files[@]} -eq 0 ]; then
        log_info "No smoke test files found"
        exit 0
    fi

    printf "%-45s %8s %12s %10s\n" "FILE" "LINES" "STATUS" "VALUE"
    echo "----------------------------------------------"

    total=0
    violations=0

    for file in "${smoke_files[@]}"; do
        lines=$(wc -l < "$file")
        value=$(assess_value "$file" "$lines")
        total=$((total + lines))

        if [ "$lines" -ge "$THRESHOLD" ]; then
            status="${RED}VIOLATION${NC}"
            violations=$((violations + 1))
        else
            status="${GREEN}ok${NC}"
        fi

        printf "%-45s %8d %12s %10s\n" "$(basename "$file")" "$lines" "$status" "$value"
    done

    echo "----------------------------------------------"
    printf "%-45s %8d %12d %10d\n" "TOTAL" "$total" "$violations" "${#smoke_files[@]}"
    echo ""

    if [ $violations -gt 0 ]; then
        log_warn "Found $violations smoke test(s) exceeding threshold"
        log_info "Run: bash scripts/check-smoke-retention.sh --strict"
        exit 1
    fi

    log_pass "All smoke tests within threshold"
fi

exit 0
