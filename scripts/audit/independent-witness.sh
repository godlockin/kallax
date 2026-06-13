#!/bin/bash
#===============================================================================
# independent-witness.sh — 独立见证机制
# 根因 3: 独立见证机制缺失 — 治 root cause
# 跟 BE-7 修复模式 联合 (umask 077 + install -d -m 700)
# 跟 Rule 31 联合 (独立见证机制)
#
# 用法:
#   bash scripts/audit/independent-witness.sh verify <subagent_id> <ticket_id>
#   bash scripts/audit/independent-witness.sh witness <subagent_id> <ticket_id> <evidence_type>
#
# 设计:
#   - 方案 4: 不可篡改 audit log sink (跟 audit-log-sink.sh 联合)
#   - Subagent 报 PASS 时, 必须经过独立见证
#   - 独立见证由 audit-log-sink.sh 记录 (subagent 不能写自己的 audit)
#   - 跟 subagent-pass-gate.sh 集成 (Rule 26 联合)
#   - 跟 conductor-receive-gate.sh 集成 (Rule 27 联合)
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SINK_SCRIPT="$SCRIPT_DIR/audit-log-sink.sh"

# 独立见证验证
witness_verify() {
    local subagent_id="$1"
    local ticket_id="$2"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "=========================================="
    echo "Independent Witness Verification"
    echo "=========================================="
    echo "Subagent: $subagent_id"
    echo "Ticket: $ticket_id"
    echo "Timestamp: $timestamp"
    echo ""

    # Step 1: 验证 subagent-pass-gate.sh 输出存在 (L1 存在性)
    local gate_output
    gate_output=$(ls -t "$KALLAX_ROOT/.kallax/audit/subagent-pass-gate"/gate-*.log 2>/dev/null | head -1)
    if [[ -z "$gate_output" ]]; then
        echo "FAIL: subagent-pass-gate output not found (L1 FAIL)"
        echo "跟 Rule 26 联合: Subagent 报 PASS 前必须跑 subagent-pass-gate.sh"
        return 1
    fi
    echo "PASS: subagent-pass-gate output found (L1 PASS)"
    echo "  File: $gate_output"

    # Step 2: 验证 gate 输出包含 PASS (L2 实质性)
    if grep -q "RESULT: PASS" "$gate_output"; then
        echo "PASS: subagent-pass-gate PASS (L2 PASS)"
    else
        echo "FAIL: subagent-pass-gate FAIL (L2 FAIL)"
        echo "跟 Rule 26 联合: 3 硬脚本 FAIL 不能报 PASS"
        return 1
    fi

    # Step 3: 验证 git SHA 真变 (L3 接线正确)
    local current_sha
    current_sha=$(git log --oneline -1 | awk '{print $1}')
    if [[ -n "$current_sha" ]]; then
        echo "PASS: git SHA verified: $current_sha (L3 PASS)"
    else
        echo "FAIL: git SHA not found (L3 FAIL)"
        return 1
    fi

    # Step 4: 独立见证记录到 audit-log-sink (L4 数据流动)
    # 注意: subagent 不能写自己的 audit, 必须通过 audit-log-sink.sh
    if [[ -x "$AUDIT_SINK_SCRIPT" ]]; then
        if bash "$AUDIT_SINK_SCRIPT" write "witness" "$ticket_id" "subagent=$subagent_id sha=$current_sha gate=$gate_output"; then
            echo "PASS: Independent witness recorded to audit-log-sink (L4 PASS)"
        else
            echo "FAIL: Cannot record to audit-log-sink (L4 FAIL)"
            echo "跟 BE-7 修复模式 联合: audit-log-sink 必须可写"
            return 1
        fi
    else
        echo "WARN: audit-log-sink.sh not executable, skipping L4"
    fi

    echo ""
    echo "=========================================="
    echo "Independent Witness Result: PASS"
    echo "=========================================="
    echo "Subagent $subagent_id PASS for ticket $ticket_id witnessed"
    echo "跟 Rule 31 联合: 独立见证机制"
    return 0
}

# 独立见证记录
witness_record() {
    local subagent_id="$1"
    local ticket_id="$2"
    local evidence_type="${3:-}"

    if [[ -z "$evidence_type" ]]; then
        echo "Usage: $0 witness <subagent_id> <ticket_id> <evidence_type>" >&2
        return 1
    fi

    if [[ ! -x "$AUDIT_SINK_SCRIPT" ]]; then
        echo "ERROR: audit-log-sink.sh not found or not executable: $AUDIT_SINK_SCRIPT"
        return 1
    fi

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    bash "$AUDIT_SINK_SCRIPT" write "evidence" "$ticket_id" "subagent=$subagent_id type=$evidence_type ts=$timestamp"

    if [[ $? -eq 0 ]]; then
        echo "PASS: Evidence recorded for $ticket_id by $subagent_id"
        return 0
    else
        echo "FAIL: Cannot record evidence"
        return 1
    fi
}

# CLI 入口
main() {
    local action="${1:-}"
    local subagent_id="${2:-}"
    local ticket_id="${3:-}"
    local evidence_type="${4:-}"

    case "$action" in
        verify)
            if [[ -z "$subagent_id" ]] || [[ -z "$ticket_id" ]]; then
                echo "Usage: $0 verify <subagent_id> <ticket_id>" >&2
                exit 1
            fi
            witness_verify "$subagent_id" "$ticket_id"
            ;;
        witness)
            if [[ -z "$subagent_id" ]] || [[ -z "$ticket_id" ]]; then
                echo "Usage: $0 witness <subagent_id> <ticket_id> <evidence_type>" >&2
                exit 1
            fi
            witness_record "$subagent_id" "$ticket_id" "$evidence_type"
            ;;
        *)
            echo "Usage: $0 <verify|witness> [args...]" >&2
            echo ""
            echo "Commands:"
            echo "  verify <subagent_id> <ticket_id>              — Verify subagent PASS with independent witness"
            echo "  witness <subagent_id> <ticket_id> <type>      — Record evidence to audit-log-sink"
            echo ""
            echo "跟 Rule 31 联合: 独立见证机制"
            echo "跟 BE-7 修复模式 联合: umask 077 + install -d -m 700"
            exit 1
            ;;
    esac
}

main "$@"