#!/bin/bash
#===============================================================================
# audit-verify.sh — kallax audit verify command 入口 (武器 1 Iter 4)
# 跟 audit-chain.sh verify 联合
# 遍历 .kallax/audit/*.jsonl 校验 hash chain 完整性
#
# 用法:
#   bash scripts/audit/audit-verify.sh                    # 全部 *.jsonl
#   bash scripts/audit/audit-verify.sh <date>             # 单日 (YYYY-MM-DD)
#   bash scripts/audit/audit-verify.sh --migrate <date>   # 迁移 legacy entries
#   bash scripts/audit/audit-verify.sh --help
#
# 退出码:
#   0 = 全部 PASS
#   1 = 有 FAIL
#   2 = 参数错误
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="${AUDIT_DIR:-$KALLAX_ROOT/.kallax/audit}"
CHAIN_SH="$SCRIPT_DIR/audit-chain.sh"

usage() {
    cat <<EOF
kallax audit verify — 校验 audit log hash chain 完整性

Usage:
  bash scripts/audit/audit-verify.sh                       校验全部 *.jsonl
  bash scripts/audit/audit-verify.sh <YYYY-MM-DD>          校验单日 *.jsonl
  bash scripts/audit/audit-verify.sh --migrate <date>      迁移 legacy entries
  bash scripts/audit/audit-verify.sh --help

Examples:
  bash scripts/audit/audit-verify.sh
  bash scripts/audit/audit-verify.sh 2026-06-29
  bash scripts/audit/audit-verify.sh --migrate 2026-06-28

Exit codes:
  0  全部 PASS
  1  有 FAIL (含权限错误 / chain 不一致)
  2  参数错误
EOF
}

# 校验单个文件
verify_one() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "INFO: $file does not exist"
        return 0
    fi
    bash "$CHAIN_SH" verify "$file"
}

# 校验指定日期的 *.jsonl
verify_day() {
    local date_arg="$1"
    local pattern="${AUDIT_DIR}/*-${date_arg}.jsonl"
    local files
    files=$(ls $pattern 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        echo "INFO: No audit logs found for $date_arg in $AUDIT_DIR"
        return 0
    fi

    local fail=0
    for f in $files; do
        if ! verify_one "$f"; then
            fail=1
        fi
    done
    return $fail
}

# 校验所有 *.jsonl
verify_all() {
    local files
    files=$(ls "${AUDIT_DIR}"/*.jsonl 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        echo "INFO: No audit logs found in $AUDIT_DIR"
        return 0
    fi

    local fail=0
    for f in $files; do
        if ! verify_one "$f"; then
            fail=1
        fi
    done
    return $fail
}

# 迁移指定日期
migrate_day() {
    local date_arg="$1"
    local pattern="${AUDIT_DIR}/*-${date_arg}.jsonl"
    local files
    files=$(ls $pattern 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        echo "INFO: No audit logs found for $date_arg"
        return 0
    fi

    for f in $files; do
        bash "$CHAIN_SH" migrate "$f"
    done
}

# CLI 入口
main() {
    case "${1:-}" in
        --help|-h|help)
            usage
            ;;
        --migrate)
            [[ -z "${2:-}" ]] && { echo "ERROR: --migrate needs <YYYY-MM-DD>" >&2; exit 2; }
            migrate_day "$2"
            ;;
        "")
            # 默认校验全部
            verify_all
            ;;
        -*)
            echo "ERROR: unknown flag: $1" >&2
            usage
            exit 2
            ;;
        *)
            # 单日校验
            verify_day "$1"
            ;;
    esac
}

main "$@"