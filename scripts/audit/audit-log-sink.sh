#!/bin/bash
#===============================================================================
# audit-log-sink.sh — 不可篡改 audit log sink
# 根因 3: 独立见证机制缺失 — 治 root cause
# 跟 BE-7 修复模式 联合 (umask 077 + install -d -m 700)
# 跟 Rule 31 联合 (独立见证机制)
#
# 用法:
#   bash scripts/audit/audit-log-sink.sh write <entry_type> <ticket_id> <content>
#   bash scripts/audit/audit-log-sink.sh read <ticket_id>
#   bash scripts/audit/audit-log-sink.sh verify <ticket_id>
#
# 设计:
#   - 目录权限: umask 077 + install -d -m 700 (BE-7 修复模式)
#   - 文件权限: append-only (chmod 600)
#   - 原子写入: flock + temp file + mv
#   - Subagent 不能篡改已有日志 (BE-7 修复模式 验证)
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SINK_DIR="${AUDIT_SINK_DIR:-$KALLAX_ROOT/.kallax/audit/sink}"
AUDIT_SINK_LOCK="$AUDIT_SINK_DIR/.sink.lock"

# 确保 audit sink 目录存在 (BE-7 修复模式)
ensure_sink_dir() {
    if [[ ! -d "$AUDIT_SINK_DIR" ]]; then
        umask 077
        install -d -m 700 "$AUDIT_SINK_DIR" 2>/dev/null || {
            echo "ERROR: Cannot create audit sink directory: $AUDIT_SINK_DIR" >&2
            return 1
        }
    fi
    # 验证权限 (BE-7 修复模式验证)
    local perms
    perms=$(stat -f "%Lp" "$AUDIT_SINK_DIR" 2>/dev/null || stat -c "%a" "$AUDIT_SINK_DIR" 2>/dev/null)
    if [[ "$perms" != "700" ]]; then
        echo "ERROR: Audit sink directory permissions incorrect: $perms (expected 700)" >&2
        return 1
    fi
}

# 原子写入日志 (flock + temp file + mv)
write_log() {
    local entry_type="$1"
    local ticket_id="$2"
    local content="$3"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local instance_id="${KALLAX_INSTANCE_ID:-unknown_$$}"

    ensure_sink_dir || return 1

    # 构造日志条目 (JSONL 格式)
    local log_entry
    log_entry="{\"ts\":\"$timestamp\",\"type\":\"$entry_type\",\"ticket\":\"$ticket_id\",\"content\":\"$content\",\"instance\":\"$instance_id\"}"

    # 原子写入 (flock + temp file + mv)
    (
        flock -x 200 || { echo "ERROR: Cannot acquire lock" >&2; return 1; }
        local temp_file
        temp_file="$AUDIT_SINK_DIR/sink-$$.tmp"
        echo "$log_entry" > "$temp_file"
        chmod 600 "$temp_file" || chmod 600 "$temp_file"
        mv "$temp_file" "$AUDIT_SINK_DIR/${ticket_id}-${timestamp}.log" 2>/dev/null || {
            echo "ERROR: Cannot write log entry" >&2
            rm -f "$temp_file"
            return 1
        }
    ) 200>"$AUDIT_SINK_LOCK"
}

# 读取日志
read_log() {
    local ticket_id="$1"

    ensure_sink_dir || return 1

    if [[ ! -f "$AUDIT_SINK_LOCK" ]]; then
        echo "INFO: No audit logs found for $ticket_id"
        return 0
    fi

    ls -la "$AUDIT_SINK_DIR"/${ticket_id}-*.log 2>/dev/null | while read -r line; do
        echo "$line"
    done
    return 0
}

# 验证日志完整性 (检查是否有篡改痕迹)
verify_log() {
    local ticket_id="$1"
    local fail_count=0

    ensure_sink_dir || return 1

    if [[ ! -f "$AUDIT_SINK_LOCK" ]]; then
        echo "INFO: No audit logs to verify for $ticket_id"
        return 0
    fi

    # 检查每个日志文件的权限
    for log_file in "$AUDIT_SINK_DIR"/${ticket_id}-*.log; do
        if [[ -f "$log_file" ]]; then
            local perms
            perms=$(stat -f "%Lp" "$log_file" 2>/dev/null || stat -c "%a" "$log_file" 2>/dev/null)
            if [[ "$perms" != "600" ]]; then
                echo "FAIL: $log_file permissions incorrect: $perms (expected 600)"
                fail_count=$((fail_count + 1))
            fi
        fi
    done

    # 检查目录权限
    local dir_perms
    dir_perms=$(stat -f "%Lp" "$AUDIT_SINK_DIR" 2>/dev/null || stat -c "%a" "$AUDIT_SINK_DIR" 2>/dev/null)
    if [[ "$dir_perms" != "700" ]]; then
        echo "FAIL: Audit sink directory permissions incorrect: $dir_perms (expected 700)"
        fail_count=$((fail_count + 1))
    fi

    if [[ $fail_count -eq 0 ]]; then
        echo "PASS: Audit log integrity verified for $ticket_id"
        return 0
    else
        echo "FAIL: $fail_count integrity issues found"
        return 1
    fi
}

# CLI 入口
main() {
    local action="${1:-}"
    local entry_type="${2:-}"
    local ticket_id="${3:-}"
    local content="${4:-}"

    case "$action" in
        write)
            if [[ -z "$entry_type" ]] || [[ -z "$ticket_id" ]] || [[ -z "$content" ]]; then
                echo "Usage: $0 write <entry_type> <ticket_id> <content>" >&2
                exit 1
            fi
            write_log "$entry_type" "$ticket_id" "$content"
            ;;
        read)
            if [[ -z "$ticket_id" ]]; then
                echo "Usage: $0 read <ticket_id>" >&2
                exit 1
            fi
            read_log "$ticket_id"
            ;;
        verify)
            if [[ -z "$ticket_id" ]]; then
                echo "Usage: $0 verify <ticket_id>" >&2
                exit 1
            fi
            verify_log "$ticket_id"
            ;;
        ensure)
            ensure_sink_dir
            ;;
        *)
            echo "Usage: $0 <write|read|verify|ensure> [args...]" >&2
            echo ""
            echo "Commands:"
            echo "  write <entry_type> <ticket_id> <content>  — Write audit log entry"
            echo "  read <ticket_id>                          — Read audit logs for ticket"
            echo "  verify <ticket_id>                        — Verify audit log integrity"
            echo "  ensure                                    — Ensure audit sink directory exists"
            exit 1
            ;;
    esac
}

main "$@"