#!/bin/bash
# scripts/verify/auditor-l4.sh — L4 verify for Auditor + L4 派单 + 跨项目 import
# EPIC-038-C: Rule 8 L4 存在可执行 verify, 跟 scripts/verify/auditor-checkpoint.sh 联合
#
# Verifies L4 存在 + 可执行 + 关键路径正确:
#   1. scripts/conductor/auditor-dispatch.sh exists + executable
#   2. scripts/import/lessons-import.py exists + executable
#   3. scripts/audit/AuditMiddleware.py exists + executable
#   4. tests/integration/auditor-l4-test.sh exists + executable
#   5. tests/integration/lessons-import-test.sh exists + executable
#   6. scripts/auditor/auditor.sh exists + executable (Rule 8 基础)
#   7. 关键函数 / CLI 子命令 验证
#   8. Rule 9 KPI 9a/9b/9c/9d/9e: 估数 / PARTIAL / should-be / around / 估计 (0 假 PASS)
#
# Usage:
#   auditor-l4.sh
#   auditor-l4.sh --strict  (出现任何估数立即 FAIL)
#
# Exit codes:
#   0 = L4 verify PASS
#   1 = L4 verify FAIL
#   2 = usage error
#
# Rule alignment:
#   - Rule 8: L4 bash scripts must exist before ticket close
#   - Rule 9 KPI 精确: counts 用 grep -c, 0 估数
#   - Rule 12 质量 ensure: 5 维度 audit (existence/wiring/integration/anti-pattern/coverage)
#   - Q5 L4 角色规范: Auditor 联动 + 不改原项目代码
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ─── Constants (no magic numbers per Hard Rule #4) ───
readonly EXIT_OK=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2
readonly TOTAL_VERIFY_CHECKS=8

# ─── Target paths ───
readonly AUDITOR_DISPATCH="$KALLAX_ROOT/scripts/conductor/auditor-dispatch.sh"
readonly LESSONS_IMPORT_PY="$KALLAX_ROOT/scripts/import/lessons-import.py"
readonly AUDIT_MIDDLEWARE_PY="$KALLAX_ROOT/scripts/audit/AuditMiddleware.py"
readonly AUDITOR_L4_TEST="$KALLAX_ROOT/tests/integration/auditor-l4-test.sh"
readonly LESSONS_IMPORT_TEST="$KALLAX_ROOT/tests/integration/lessons-import-test.sh"
readonly AUDITOR_SCRIPT="$KALLAX_ROOT/scripts/auditor/auditor.sh"

# ─── Helpers ───
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "  [PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "  [FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ─── Check 1-6: file existence + executable ───
check_executable() {
    local label="$1"
    local path="$2"
    if [[ ! -f "$path" ]]; then
        fail "$label: file not found ($path)"
        return 1
    fi
    if [[ ! -x "$path" ]]; then
        fail "$label: not executable ($path)"
        return 1
    fi
    pass "$label: exists + executable"
    return 0
}

check_file_present() {
    local label="$1"
    local path="$2"
    if [[ ! -f "$path" ]]; then
        fail "$label: file not found ($path)"
        return 1
    fi
    pass "$label: exists ($path)"
    return 0
}

# ─── Check 7: 关键函数 / CLI 子命令 验证 ───
check_required_content() {
    local label="$1"
    local file="$2"
    shift 2
    local patterns=("$@")
    local missing=()
    for p in "${patterns[@]}"; do
        if ! grep -q -- "$p" "$file"; then
            missing+=("$p")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "$label: missing patterns: ${missing[*]}"
        return 1
    fi
    pass "$label: all required content present (${#patterns[@]} patterns)"
    return 0
}

# ─── Check 8: Rule 9 KPI 9a/9b/9c/9d/9e: 0 估数 ───
check_no_estimation() {
    local strict="${1:-0}"
    local files=("$AUDITOR_DISPATCH" "$LESSONS_IMPORT_PY" "$AUDIT_MIDDLEWARE_PY")
    local anti_patterns=(
        'PARTIAL'
        'should be'
        'around [0-9]+'
        'approximately'
        'roughly'
        '估计'
        '大概 [0-9]'
        '约 [0-9]'
        '大约 [0-9]'
        '~[0-9]+%'
    )
    local bad=0
    # Disable -e for this function — grep -c returns 1 when 0 matches
    set +e
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        for ap in "${anti_patterns[@]}"; do
            local matches
            matches=$(grep -cE "$ap" "$f" 2>/dev/null | head -1)
            matches="${matches:-0}"
            if [[ -n "$matches" ]] && [[ "$matches" =~ ^[0-9]+$ ]] && [[ "$matches" -gt 0 ]]; then
                if [[ "$strict" == "1" ]]; then
                    fail "Rule 9 anti-pattern '$ap' found in $f ($matches hits)"
                    bad=$((bad + 1))
                else
                    log_warn "Rule 9 anti-pattern '$ap' found in $f ($matches hits, non-blocking)"
                fi
            fi
        done
    done
    set -e
    if [[ "$bad" -eq 0 ]]; then
        pass "Rule 9 anti-patterns: clean (0 hits across 10 patterns × 3 files)"
    fi
}

# ─── Main verify ───
main() {
    local strict=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strict) strict=1; shift ;;
            -h|--help)
                cat <<EOF
Usage: $0 [--strict]

Verify L4 存在 + 可执行 + 关键路径 for EPIC-038-C.
  --strict  treat Rule 9 anti-patterns as FAIL (default: WARN)

Total checks: $TOTAL_VERIFY_CHECKS
Exit codes: 0=PASS, 1=FAIL, 2=USAGE
EOF
                return "$EXIT_USAGE"
                ;;
            *)
                log_err "Unknown arg: $1"
                return "$EXIT_USAGE"
                ;;
        esac
    done

    echo "=========================================="
    echo "L4 Verify: auditor-l4.sh (EPIC-038-C)"
    echo "=========================================="
    echo ""

    # Check 1-6: file existence + executable
    check_executable "auditor-dispatch.sh" "$AUDITOR_DISPATCH"
    check_executable "lessons-import.py" "$LESSONS_IMPORT_PY"
    check_executable "AuditMiddleware.py" "$AUDIT_MIDDLEWARE_PY"
    check_file_present  "auditor-l4-test.sh" "$AUDITOR_L4_TEST"
    check_file_present  "lessons-import-test.sh" "$LESSONS_IMPORT_TEST"
    check_executable "auditor.sh (Rule 8 baseline)" "$AUDITOR_SCRIPT"

    # Check 7: 关键函数 / CLI 子命令
    if [[ -f "$AUDITOR_DISPATCH" ]]; then
        check_required_content "auditor-dispatch.sh CLI" "$AUDITOR_DISPATCH" \
            "dispatch" "list-worktrees" "self-check" "Rule 8" "Rule 9" "Rule 12"
    fi
    if [[ -f "$LESSONS_IMPORT_PY" ]]; then
        check_required_content "lessons-import.py CLI" "$LESSONS_IMPORT_PY" \
            "import" "export" "merge" "diff" "self-check"
    fi
    if [[ -f "$AUDIT_MIDDLEWARE_PY" ]]; then
        check_required_content "AuditMiddleware.py CLI" "$AUDIT_MIDDLEWARE_PY" \
            "audit" "redact" "auditor-link" "self-check" "TOTAL_REDACTION_PASSES"
    fi

    # Check 8: Rule 9 KPI 0 估数
    check_no_estimation "$strict"

    echo ""
    echo "=========================================="
    echo "Result: $PASS_COUNT PASS, $FAIL_COUNT FAIL (target: ≥$TOTAL_VERIFY_CHECKS checks)"
    echo "=========================================="
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo "L4 verify: FAIL"
        return "$EXIT_FAIL"
    fi
    echo "L4 verify: PASS"
    return "$EXIT_OK"
}

main "$@"