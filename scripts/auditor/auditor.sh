#!/usr/bin/env bash
# scripts/auditor/auditor.sh — Auditor role implementation
# PHASE-008-E: Auditor 角色落地 (跟 Q5 L4 角色规范对齐)
#
# Auditor 角色权限:
#   ✅ 跨 worktree 读 (只读分析)
#   ✅ 写 .kallax/lessons/ (反哺框架)
#   ❌ 不改原项目代码 (跟 Q5 L4 角色规范一致)
#
# 触发场景:
#   - subagent 报 PASS 但 Master 强验证 6 维度发现 FAIL
#   - 12 subagent 强验证 (EPIC-039-D 实证)
#
# 集成:
#   - strong-verify-6d.sh (EPIC-039-D 11/11 PASS) 联动
#   - review.sh (EPIC-039-B 4/4 PASS 修后) 联动
#   - ticket-status-sync.sh (EPIC-039-A Rule 16 Step 1) 联动
#
# Rule alignment:
#   - Rule 8: L4 bash script must exist before ticket close
#   - Rule 16 Step 4: review.sh 5 验证
#   - Rule 17 Step 3: conflict-detect.sh 联动
#   - Rule 18: KPI falsification 反模式黑名单
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_LOG="${AUDIT_LOG:-$KALLAX_ROOT/.kallax/lessons/auditor-audit-$(date +%Y%m).jsonl}"
LESSONS_DIR="${LESSONS_DIR:-$KALLAX_ROOT/.kallax/lessons}"

# 计数器
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "[PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "[FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }
info() { echo "[INFO] $1"; }

# ----------------------------------------
# 辅助函数: 确保 lessons 目录存在
# ----------------------------------------
ensure_lessons_dir() {
    if [[ ! -d "$LESSONS_DIR" ]]; then
        umask 077
        install -d -m 700 "$LESSONS_DIR" 2>/dev/null || {
            echo "ERROR: Cannot create lessons directory: $LESSONS_DIR"
            return 1
        }
        info "Created lessons directory: $LESSONS_DIR"
    fi
}

# ----------------------------------------
# 辅助函数: 写 audit log
# ----------------------------------------
write_audit_log() {
    local ticket_id="$1"
    local verdict="$2"  # PASS/FAIL
    local finding="$3"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local instance_id="${KALLAX_INSTANCE_ID:-auditor_unknown_$$}"
    echo "{\"ts\":\"$timestamp\",\"ticket\":\"$ticket_id\",\"verdict\":\"$verdict\",\"finding\":\"$finding\",\"instance\":\"$instance_id\"}" >> "$AUDIT_LOG"
}

# ----------------------------------------
# 辅助函数: 跨 worktree 读
# ----------------------------------------
read_worktree_file() {
    local worktree_path="$1"
    local file_path="$2"
    local worktree_root
    worktree_root="$(git -C "$worktree_path" rev-parse --show-toplevel 2>/dev/null || echo "")"
    if [[ -z "$worktree_root" ]]; then
        echo "ERROR: Not a valid git worktree: $worktree_path"
        return 1
    fi
    local full_path="$worktree_root/$file_path"
    if [[ ! -f "$full_path" ]]; then
        echo "ERROR: File not found in worktree: $full_path"
        return 1
    fi
    cat "$full_path"
}

# ----------------------------------------
# 辅助函数: 列出所有 worktrees
# ----------------------------------------
list_worktrees() {
    git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2}' | grep -v "^$KALLAX_ROOT$"
}

# ----------------------------------------
# 辅助函数: 检查文件是否在原项目代码范围
# ----------------------------------------
is_original_project_code() {
    local file_path="$1"
    # 原项目代码目录白名单
    local original_paths=(
        "scripts/"
        "jira/"
        "confluence/"
        "tests/"
        "template/"
        "docs/"
        ".kallax/"
    )
    for path in "${original_paths[@]}"; do
        if [[ "$file_path" == "$path"* ]]; then
            return 0
        fi
    done
    return 1
}

# ----------------------------------------
# audit_read_only: Auditor 只读分析 (跨 worktree 读)
# ----------------------------------------
auditor_read_only() {
    local ticket_id="$1"
    info "=== Auditor Read-Only Analysis ==="

    # 列出所有 worktree
    local worktrees
    worktrees=$(list_worktrees)
    if [[ -z "$worktrees" ]]; then
        info "No worktrees found (besides main)"
        return 0
    fi

    info "Found $(echo "$worktrees" | wc -l | tr -d ' ') worktrees"

    # 读取每个 worktree 的最新 commit 信息
    local worktree_count=0
    for wt in $worktrees; do
        worktree_count=$((worktree_count+1))
        info "Worktree $worktree_count: $wt"

        # 获取 worktree 的 HEAD SHA 和 message
        local wt_head
        wt_head=$(git -C "$wt" log --oneline -1 2>/dev/null || echo "N/A")
        info "  HEAD: $wt_head"

        # 查找该 worktree 对应的 ticket
        local wt_branch
        wt_branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo "N/A")
        info "  Branch: $wt_branch"
    done

    pass "auditor_read_only: analyzed $worktree_count worktrees"
    return 0
}

# ----------------------------------------
# audit_lessons_write: Auditor 写 lessons (反哺框架)
# ----------------------------------------
auditor_lessons_write() {
    local ticket_id="$1"
    local verdict="$2"  # PASS/FAIL
    local finding="$3"
    info "=== Auditor Lessons Write ==="

    ensure_lessons_dir || return 1

    # 写 audit log
    write_audit_log "$ticket_id" "$verdict" "$finding"
    pass "auditor_lessons_write: logged to $AUDIT_LOG"

    # 检查是否需要写 LESSONS-LEARNED
    local epic_id
    epic_id=$(echo "$ticket_id" | grep -oE 'EPIC-[0-9]+' || echo "")
    if [[ -n "$epic_id" ]]; then
        local lessons_file="$KALLAX_ROOT/jira/epics/$epic_id/LESSONS-LEARNED.md"
        if [[ -f "$lessons_file" ]]; then
            info "Epic lessons file exists: $lessons_file"
            # 追加 auditor 发现
            local timestamp
            timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "" >> "$lessons_file"
            echo "## Auditor Finding (${timestamp})" >> "$lessons_file"
            echo "- Ticket: $ticket_id" >> "$lessons_file"
            echo "- Verdict: $verdict" >> "$lessons_file"
            echo "- Finding: $finding" >> "$lessons_file"
            pass "auditor_lessons_write: appended to $lessons_file"
        else
            info "No LESSONS-LEARNED.md for $epic_id yet"
        fi
    fi

    return 0
}

# ----------------------------------------
# audit_block_write_original: Auditor 禁止写原项目代码
# ----------------------------------------
auditor_block_write_original() {
    local file_path="$1"
    info "=== Auditor Block Write Original Project Code ==="

    if is_original_project_code "$file_path"; then
        fail "auditor_block_write_original: BLOCKED writing to original project code: $file_path"
        info "Auditor role cannot modify original project code (Q5 L4 role spec)"
        return 1
    fi

    pass "auditor_block_write_original: allowed non-project file: $file_path"
    return 0
}

# ----------------------------------------
# auditor联动_strong_verify_6d: 跟 Master 强验证 6 维度联动
# ----------------------------------------
auditor联动_strong_verify_6d() {
    local ticket_id="${1:-}"
    info "=== Auditor联动 strong-verify-6d ==="

    if [[ -z "$ticket_id" ]]; then
        info "No ticket_id provided, skipping strong-verify-6d联动"
        return 0
    fi

    # 检查 strong-verify-6d.sh 是否存在
    local strong_verify_script="$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"
    if [[ ! -f "$strong_verify_script" ]]; then
        fail "auditor联动_strong_verify_6d: strong-verify-6d.sh not found"
        return 1
    fi

    if [[ ! -x "$strong_verify_script" ]]; then
        fail "auditor联动_strong_verify_6d: strong-verify-6d.sh not executable"
        return 1
    fi

    # 运行 strong-verify-6d.sh
    info "Running strong-verify-6d.sh for ticket: $ticket_id"
    if bash "$strong_verify_script" "$ticket_id" >/dev/null 2>&1; then
        pass "auditor联动_strong_verify_6d: strong-verify-6d.sh PASS (6/6 dimensions)"
        return 0
    else
        fail "auditor联动_strong_verify_6d: strong-verify-6d.sh FAIL"
        info "Auditor triggers: subagent reported PASS but Master strong-verify found issues"
        # Auditor 写 lessons
        auditor_lessons_write "$ticket_id" "FAIL" "strong-verify-6d.sh FAIL"
        return 1
    fi
}

# ----------------------------------------
# auditor联动_review_sh: 跟 review.sh 联动
# ----------------------------------------
auditor联动_review_sh() {
    local ticket_id="${1:-}"
    info "=== Auditor联动 review.sh ==="

    local review_script="$KALLAX_ROOT/scripts/conductor/review.sh"
    if [[ ! -f "$review_script" ]]; then
        fail "auditor联动_review_sh: review.sh not found"
        return 1
    fi

    if [[ ! -x "$review_script" ]]; then
        fail "auditor联动_review_sh: review.sh not executable"
        return 1
    fi

    info "Running review.sh..."
    if bash "$review_script" >/dev/null 2>&1; then
        pass "auditor联动_review_sh: review.sh PASS (5/5 checks)"
        return 0
    else
        fail "auditor联动_review_sh: review.sh FAIL"
        return 1
    fi
}

# ----------------------------------------
# auditor联动_ticket_status_sync: 跟 ticket-status-sync.sh 联动
# ----------------------------------------
auditor联动_ticket_status_sync() {
    local ticket_id="$1"
    local new_status="$2"  # in_progress / done / fail
    info "=== Auditor联动 ticket-status-sync ==="

    local sync_script="$KALLAX_ROOT/scripts/conductor/ticket-status-sync.sh"
    if [[ ! -f "$sync_script" ]]; then
        info "ticket-status-sync.sh not found, skipping sync"
        return 0
    fi

    info "Would sync ticket $ticket_id to status: $new_status"
    info "(Actual sync requires Conductor role, Auditor only recommends)"
    pass "auditor联动_ticket_status_sync: recommendation logged"
    return 0
}

# ----------------------------------------
# 主流程: auditor audit
# ----------------------------------------
auditor_audit() {
    local trigger="${1:-}"  # trigger type: read_only / lessons_write / block_original / 联动
    local ticket_id="${2:-}"
    local file_path="${3:-}"
    local finding="${4:-}"

    info "=========================================="
    info "Auditor Role (PHASE-008-E)"
    info "Trigger: $trigger"
    info "Ticket: $ticket_id"
    info "Instance: ${KALLAX_INSTANCE_ID:-auditor_unknown_$$}"
    info "=========================================="
    echo ""

    case "$trigger" in
        read_only)
            auditor_read_only "$ticket_id"
            ;;
        lessons_write)
            auditor_lessons_write "$ticket_id" "PASS" "$finding"
            ;;
        block_original)
            auditor_block_write_original "$file_path"
            ;;
        联动_strong_verify_6d)
            auditor联动_strong_verify_6d "$ticket_id"
            ;;
        联动_review_sh)
            auditor联动_review_sh "$ticket_id"
            ;;
        联动_ticket_status_sync)
            auditor联动_ticket_status_sync "$ticket_id" "${new_status:-in_progress}"
            ;;
        *)
            info "Unknown trigger: $trigger"
            info "Usage: $0 <trigger> [ticket_id] [file_path] [finding]"
            info "Triggers: read_only, lessons_write, block_original, 联动_strong_verify_6d, 联动_review_sh, 联动_ticket_status_sync"
            exit 1
            ;;
    esac
}

# ----------------------------------------
# CLI 入口
# ----------------------------------------
main() {
    local trigger="${1:-}"
    local ticket_id="${2:-}"
    local file_path="${3:-}"
    local finding="${4:-}"

    if [[ -z "$trigger" ]]; then
        echo "Usage: $0 <trigger> [ticket_id] [file_path] [finding]"
        echo ""
        echo "Auditor Role (PHASE-008-E, Q5 L4 role spec):"
        echo "  - Cross-worktree read (read_only)"
        echo "  - Write lessons (lessons_write)"
        echo "  - Block write to original project code (block_original)"
        echo "  - Link with strong-verify-6d (联动_strong_verify_6d)"
        echo "  - Link with review.sh (联动_review_sh)"
        echo "  - Link with ticket-status-sync (联动_ticket_status_sync)"
        echo ""
        echo "Examples:"
        echo "  $0 read_only EPIC-039-A"
        echo "  $0 lessons_write EPIC-039-A 'strong-verify-6d FAIL'"
        echo "  $0 block_original scripts/auditor/auditor.sh"
        echo "  $0 联动_strong_verify_6d EPIC-039-A"
        echo "  $0 联动_review_sh EPIC-039-A"
        echo "  $0 联动_ticket_status_sync EPIC-039-A in_progress"
        exit 0
    fi

    auditor_audit "$trigger" "$ticket_id" "$file_path" "$finding"

    echo ""
    echo "=========================================="
    echo "Auditor Result: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
    echo "=========================================="

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"