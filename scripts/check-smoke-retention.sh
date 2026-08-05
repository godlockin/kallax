#!/usr/bin/env bash
# scripts/check-smoke-retention.sh
# EPIC-174: Smoke Retention Policy Scanner
# 检测 >=500 行的 smoke 测试，输出告警和建议
# Exit: 0=PASS, 1=FAIL, 2=BLOCKED-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SMOKE_DIR="$PROJECT_ROOT/tests/integration"
THRESHOLD=500

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    YELLOW=''
    GREEN=''
    NC=''
fi

log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
log_info() { echo "[INFO] $*"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

EPIC-174 Smoke Retention Policy Scanner
检测 tests/integration/*-smoke.test.sh 文件行数

OPTIONS:
    -h, --help          显示帮助
    -v, --verbose       详细输出
    -t, --threshold N   设置阈值 (默认: 500)
    --strict            超过阈值 exit 1 (默认)
    --warn-only         超过阈值仅警告，不 exit 1

EXIT CODES:
    0   PASS - 所有 smoke 测试 <= 阈值
    1   FAIL - 存在 >= 阈值 的 smoke 测试
    2   BLOCKED - 环境变量缺失或其他阻塞问题

EXAMPLES:
    $(basename "$0")                    # 默认检测
    $(basename "$0") -t 300             # 阈值 300 行
    $(basename "$0") --warn-only        # 不强制失败
EOF
}

THRESHOLD_OVERRIDE=""
STRICT_MODE=true
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -t|--threshold) THRESHOLD_OVERRIDE="$2"; shift 2 ;;
        --strict) STRICT_MODE=true; shift ;;
        --warn-only) STRICT_MODE=false; shift ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if [ -n "$THRESHOLD_OVERRIDE" ]; then
    if ! [[ "$THRESHOLD_OVERRIDE" =~ ^[0-9]+$ ]]; then
        log_fail "Invalid threshold: $THRESHOLD_OVERRIDE"
        exit 2
    fi
    THRESHOLD="$THRESHOLD_OVERRIDE"
fi

# Check environment (EPIC-131/132 style)
if [ ! -d "$SMOKE_DIR" ]; then
    log_fail "SMOKE_DIR not found: $SMOKE_DIR"
    exit 2
fi

# Find all smoke test files
smoke_files=()
while IFS= read -r f; do
    [ -n "$f" ] && smoke_files+=("$f")
done < <(find "$SMOKE_DIR" -name "*-smoke.test.sh" -type f 2>/dev/null | sort)

if [ ${#smoke_files[@]} -eq 0 ]; then
    log_info "No smoke test files found in $SMOKE_DIR"
    log_pass "Smoke Retention Policy: PASS (0 smoke tests)"
    exit 0
fi

log_info "Scanning ${#smoke_files[@]} smoke test(s) (threshold: ${THRESHOLD} lines)"
echo ""

total_violations=0
violation_files=()

for file in "${smoke_files[@]}"; do
    lines=$(wc -l < "$file")
    filename=$(basename "$file")

    if [ "$VERBOSE" = true ]; then
        log_info "$filename: $lines lines"
    fi

    if [ "$lines" -ge "$THRESHOLD" ]; then
        total_violations=$((total_violations + 1))
        violation_files+=("$file:$lines")

        if [ "$STRICT_MODE" = true ]; then
            log_warn "$filename: $lines lines (>= $THRESHOLD)"
            echo "  Suggestion: Split into smaller smoke tests or move to integration/"
        else
            log_warn "$filename: $lines lines"
        fi
    else
        log_pass "$filename: $lines lines"
    fi
done

echo ""
log_info "Summary: $total_violations violation(s) found"

if [ $total_violations -gt 0 ]; then
    echo ""
    log_info "Violations:"
    for vf in "${violation_files[@]}"; do
        IFS=':' read -r vf_file vf_lines <<< "$vf"
        echo "  - $(basename "$vf_file"): $vf_lines lines"
    done
fi

if [ "$STRICT_MODE" = true ] && [ $total_violations -gt 0 ]; then
    echo ""
    log_fail "Smoke Retention Policy: FAIL ($total_violations violation(s))"
    echo "  Consider: scripts/audit/smoke-size-report.sh for full report"
    exit 1
fi

log_pass "Smoke Retention Policy: PASS"
exit 0
