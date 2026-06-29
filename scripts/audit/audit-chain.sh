#!/bin/bash
#===============================================================================
# audit-chain.sh — 武器 1 Hash-Chained Audit Log (治根 SEC-002)
# 跟 BE-7 修复模式 联合 (chmod 600 / flock / atomic write)
# 跟 Rule 31 独立见证机制 联合
#
# 用法:
#   bash scripts/audit/audit-chain.sh append <jsonl_file> <json_entry_object>
#   bash scripts/audit/audit-chain.sh verify <jsonl_file>
#   bash scripts/audit/audit-chain.sh show   <jsonl_file> [<line_range>]
#   bash scripts/audit/audit-chain.sh migrate <jsonl_file>
#   bash scripts/audit/audit-chain.sh help
#
# Hash chain 规则:
#   - 每条 entry 加 2 字段:
#     - prev_hash:   上一条 entry.chain_hash (第一条为 "0"*64)
#     - chain_hash:  sha256(prev_hash || canonical_entry_without_chain_hash)
#   - canonical_entry = 字段按字典序排序的紧凑 JSON (jq -S -c)
#
# 跟 audit-log-sink.sh 区别:
#   - audit-log-sink.sh: per-ticket 独立 file (BE-7 fix 模式, 保留, 不动)
#   - audit-chain.sh:    JSONL append 日志 (decision-/scoring-/alert-*.jsonl),
#                        用 SHA256 chain 校验内容完整性
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="${AUDIT_DIR:-$KALLAX_ROOT/.kallax/audit}"

# 工具探测
SHA256_TOOL=""
if command -v sha256sum >/dev/null 2>&1; then
    SHA256_TOOL="sha256sum"
fi

# 计算 canonical JSON (字段按字典序排序的紧凑 JSON, 用于 hash)
# 入参: entry JSON
canonical_json() {
    local entry="$1"
    # 去除 chain_hash 字段 (hash 不能包含自身)
    local no_self
    no_self=$(echo "$entry" | jq -c 'del(.chain_hash)' 2>/dev/null || echo "$entry")
    # 字段按 key 排序 (递归)
    echo "$no_self" | jq -c -S '.' 2>/dev/null
}

# 计算 SHA256 hex digest of a string
sha256_hex() {
    local data="$1"
    if [[ -n "$SHA256_TOOL" ]]; then
        printf '%s' "$data" | sha256sum | awk '{print $1}'
    else
        # 兜底: python3 stdlib
        printf '%s' "$data" | python3 -c "import sys, hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"
    fi
}

# 计算 entry 的 chain_hash (V310 hotfix S-006: 双 sha256 抗 collision)
# 算法: chain_algo = "sha256-v2" → chain_hash = sha256(sha256(prev_hash || canonical_entry))
# 入参: prev_hash, entry (无 chain_hash 字段), algo (默认 sha256-v2)
calc_chain_hash() {
    local prev_hash="$1"
    local entry_no_self="$2"
    local algo="${3:-sha256-v2}"
    local canonical
    canonical=$(canonical_json "$entry_no_self")
    if [[ "$algo" == "sha256-v2" ]]; then
        # 双 sha256: 抗 collision 强化 (跟 V310-B-REVIEW S-006 P1 联合)
        local inner
        inner=$(sha256_hex "${prev_hash}${canonical}")
        sha256_hex "$inner"
    else
        # sha256-v1: 旧 log 兼容性 (single sha256)
        sha256_hex "${prev_hash}${canonical}"
    fi
}

# 读最后一条 entry 的 chain_hash; 文件不存在/空 → 返回 "0"*64
read_last_chain_hash() {
    local file="$1"
    if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
        printf '%064d' 0
        return 0
    fi
    # 取最后一行
    local last
    last=$(tail -n 1 "$file" 2>/dev/null || true)
    if [[ -z "$last" ]]; then
        printf '%064d' 0
        return 0
    fi
    # 提取 chain_hash (如果有)
    local h
    h=$(echo "$last" | jq -r '.chain_hash // empty' 2>/dev/null || true)
    if [[ -z "$h" ]]; then
        printf '%064d' 0
        return 0
    fi
    echo "$h"
}

# ── append: 加 prev_hash + chain_hash, 原子追加到 JSONL
# 入参: <jsonl_file> <entry_object_json>
# 行为: 读 last_chain_hash → 计算 → 原子写
append_entry() {
    local file="$1"
    local entry="$2"

    # 确保目录存在 (chmod 700, 跟 BE-7 fix 模式 一致)
    local dir
    dir=$(dirname "$file")
    if [[ ! -d "$dir" ]]; then
        umask 077
        install -d -m 700 "$dir" 2>/dev/null || {
            echo "ERROR: Cannot create audit dir: $dir" >&2
            return 1
        }
    fi

    # 验证 entry 是合法 JSON
    if ! echo "$entry" | jq -e . >/dev/null 2>&1; then
        echo "ERROR: entry is not valid JSON" >&2
        return 1
    fi

    # 验证 entry 没有 chain_hash 字段 (强制重新算)
    if echo "$entry" | jq -e 'has("chain_hash")' >/dev/null 2>&1; then
        echo "ERROR: entry must not contain chain_hash field (will be computed)" >&2
        return 1
    fi

    # 读上一条 chain_hash
    local prev_hash
    prev_hash=$(read_last_chain_hash "$file")

    # 计算 chain_hash — 必须跟 verify 视角一致:
    #   verify 看到磁盘 entry (含 prev_hash + chain_hash), 重算时去掉 chain_hash
    #   append 也必须按"含 prev_hash 但无 chain_hash" 计算
    # V310 hotfix S-006: 默认 sha256-v2 (双 sha256), 通过 chain_algo 字段标记
    local entry_with_prev
    entry_with_prev=$(echo "$entry" | jq -c --arg ph "$prev_hash" \
        '. + {prev_hash:$ph, chain_algo:"sha256-v2"}')
    local chain_hash
    chain_hash=$(calc_chain_hash "$prev_hash" "$entry_with_prev" "sha256-v2")

    # 构造最终 entry (字段按字典序 + prev_hash + chain_algo + chain_hash)
    local final
    final=$(echo "$entry_with_prev" | jq -c --arg ch "$chain_hash" \
        '. + {chain_hash:$ch}' | jq -c -S '.')

    # 原子追加 (跨平台: mkdir 互斥锁 + temp + mv, BE-7 模式 兼容)
    local lock_dir="${file}.lock"
    local acquired=false
    for _ in 1 2 3 4 5 10 20 40 80 100; do
        if mkdir "$lock_dir" 2>/dev/null; then
            acquired=true
            break
        fi
        sleep 0.05
    done
    if [[ "$acquired" != "true" ]]; then
        echo "ERROR: Cannot acquire lock for $file" >&2
        return 1
    fi

    # 验证文件权限 (如果已存在)
    if [[ -f "$file" ]]; then
        local perms
        perms=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || echo "")
        if [[ "$perms" != "600" && "$perms" != "400" ]]; then
            echo "ERROR: $file permissions incorrect: $perms (expected 600 or 400)" >&2
            rmdir "$lock_dir" 2>/dev/null
            return 1
        fi
    fi

    local tmp="${file}.tmp.$$"
    printf '%s\n' "$final" > "$tmp"
    chmod 600 "$tmp"
    cat "$tmp" >> "$file"
    rm -f "$tmp"
    chmod 600 "$file"
    rmdir "$lock_dir" 2>/dev/null
}

# ── verify: 校验整条 chain + 文件权限
# 入参: <jsonl_file>
# 输出: PASS 或 FAIL + 详情; 返回 0=PASS, 1=FAIL
verify_file() {
    local file="$1"
    local fail_count=0
    local line_count=0

    # 文件不存在
    if [[ ! -f "$file" ]]; then
        echo "INFO: $file does not exist (no audit log to verify)"
        return 0
    fi

    # 文件存在但为空
    if [[ ! -s "$file" ]]; then
        echo "INFO: $file is empty"
        return 0
    fi

    # 1. 校验文件权限 (跟 BE-7 模式 一致)
    local perms
    perms=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || echo "")
    if [[ "$perms" != "600" && "$perms" != "400" ]]; then
        echo "FAIL: $file permissions incorrect: $perms (expected 600 or 400)"
        fail_count=$((fail_count + 1))
    fi

    # 2. 逐行校验 hash chain
    local prev_hash
    prev_hash=$(printf '%064d' 0)
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # 跳过空行
        [[ -z "$line" ]] && continue

        # 验证 JSON
        if ! echo "$line" | jq -e . >/dev/null 2>&1; then
            echo "FAIL: $file:$line_num invalid JSON"
            fail_count=$((fail_count + 1))
            continue
        fi

        # 提取 prev_hash 和 chain_hash
        local entry_prev
        local entry_chain
        local entry_algo
        entry_prev=$(echo "$line" | jq -r '.prev_hash // empty' 2>/dev/null)
        entry_chain=$(echo "$line" | jq -r '.chain_hash // empty' 2>/dev/null)
        entry_algo=$(echo "$line" | jq -r '.chain_algo // "sha256-v1"' 2>/dev/null)

        # legacy entry (无 hash 字段) → 跳过 (向后兼容)
        if [[ -z "$entry_chain" ]]; then
            echo "INFO: $file:$line_num legacy entry (no chain_hash), skipping"
            continue
        fi

        # 校验 prev_hash 跟上一条一致
        if [[ "$entry_prev" != "$prev_hash" ]]; then
            echo "FAIL: $file:$line_num prev_hash mismatch (expected=$prev_hash actual=$entry_prev)"
            fail_count=$((fail_count + 1))
        fi

        # 校验 chain_hash: V310 hotfix S-006 派 algo (默认 sha256-v1 兼容旧 log)
        local expected_chain
        expected_chain=$(calc_chain_hash "$entry_prev" "$line" "$entry_algo")

        if [[ "$expected_chain" != "$entry_chain" ]]; then
            echo "FAIL: $file:$line_num chain_hash mismatch (algo=$entry_algo expected=$expected_chain actual=$entry_chain)"
            fail_count=$((fail_count + 1))
        fi

        prev_hash="$entry_chain"
    done < "$file"

    line_count=$line_num

    if [[ $fail_count -eq 0 ]]; then
        echo "PASS: $file chain verified ($line_count lines)"
        return 0
    else
        echo "FAIL: $file $fail_count integrity issue(s) in $line_count lines"
        return 1
    fi
}

# ── show: 显示 entry (带行号)
show_file() {
    local file="$1"
    local line_filter="${2:-}"

    if [[ ! -f "$file" ]]; then
        echo "INFO: $file does not exist"
        return 0
    fi

    if [[ -n "$line_filter" ]]; then
        sed -n "${line_filter}p" "$file" | jq .
    else
        nl -ba "$file" | while IFS= read -r line; do
            local num
            num=$(echo "$line" | awk '{print $1}')
            local rest
            rest=$(echo "$line" | cut -f2-)
            printf '%4d: %s\n' "$num" "$(echo "$rest" | jq -c .)"
        done
    fi
}

# ── migrate: 一次性 backfill — 给 legacy entries 加 hash chain
# 规则:
#   - 第一条 legacy entry: prev_hash="0"*64, chain_hash = sha256(...)
#   - 后续 legacy entry: prev_hash = 上一条 chain_hash
#   - 已 hash 的 entry: 跳过
# 写入模式: 全部读到内存, 计算后整体覆盖原文件 (原子写)
migrate_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "INFO: $file does not exist, nothing to migrate"
        return 0
    fi

    if [[ ! -s "$file" ]]; then
        echo "INFO: $file is empty, nothing to migrate"
        return 0
    fi

    local tmp="${file}.migrate.$$"
    local prev_hash
    prev_hash=$(printf '%064d' 0)
    local migrated_count=0
    local skipped_count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # 已带 chain_hash → 直接写
        local existing_chain
        existing_chain=$(echo "$line" | jq -r '.chain_hash // empty' 2>/dev/null)
        if [[ -n "$existing_chain" ]]; then
            echo "$line" >> "$tmp"
            skipped_count=$((skipped_count + 1))
            prev_hash="$existing_chain"
            continue
        fi

        # Legacy → 加 prev_hash + chain_hash
        # 必须按 verify 视角计算 (entry 含 prev_hash 但不含 chain_hash)
        local entry_with_prev
        entry_with_prev=$(echo "$line" | jq -c --arg ph "$prev_hash" '. + {prev_hash:$ph}')
        local chain_hash
        chain_hash=$(calc_chain_hash "$prev_hash" "$entry_with_prev")
        local new_entry
        new_entry=$(echo "$entry_with_prev" | jq -c --arg ch "$chain_hash" \
            '. + {chain_hash:$ch}' | jq -c -S '.')

        echo "$new_entry" >> "$tmp"
        migrated_count=$((migrated_count + 1))
        prev_hash="$chain_hash"
    done < "$file"

    # 原子替换
    mv "$tmp" "$file"
    chmod 600 "$file"

    echo "PASS: migrated $migrated_count entries, skipped $skipped_count (already chained) in $file"
}

# ── CLI 入口
usage() {
    cat <<EOF
Usage: $0 <command> [args...]

Commands:
  append <jsonl_file> <entry_json>  Hash-chain append entry to JSONL file
  verify <jsonl_file>                Verify hash chain integrity
  show   <jsonl_file> [<line_range>] Show entries (e.g. show file 1-5)
  migrate <jsonl_file>                Backfill hash chain for legacy entries
  help                                Show this help

Examples:
  $0 append .kallax/audit/decision-2026-06-29.jsonl '{"action":"test","actor":"x"}'
  $0 verify .kallax/audit/decision-2026-06-29.jsonl
  $0 migrate .kallax/audit/decision-2026-06-29.jsonl
EOF
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        append)
            [[ $# -lt 2 ]] && { echo "ERROR: append needs <file> <entry>"; usage; exit 1; }
            append_entry "$1" "$2"
            ;;
        verify)
            [[ $# -lt 1 ]] && { echo "ERROR: verify needs <file>"; usage; exit 1; }
            verify_file "$1"
            ;;
        show)
            [[ $# -lt 1 ]] && { echo "ERROR: show needs <file>"; usage; exit 1; }
            show_file "$1" "${2:-}"
            ;;
        migrate)
            [[ $# -lt 1 ]] && { echo "ERROR: migrate needs <file>"; usage; exit 1; }
            migrate_file "$1"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            echo "ERROR: unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"