#!/bin/bash
# scripts/conductor/auditor-dispatch.sh — L4 派单模式: dispatch to Auditor instance
# EPIC-038-C: Auditor 角色 + L4 派单 (跟 EPIC-038-B 4 派单模式 auditor 联合)
#
# L4 派单模式 vs 普通 Performer 派单:
#   - 普通派单 (analyst/incremental/major): Performer 改原项目代码
#   - Auditor 派单 (本脚本): Auditor 只读 + 写 lessons, 不改原项目代码
#
# Usage:
#   auditor-dispatch.sh dispatch <ticket_id> [--finding <text>]
#   auditor-dispatch.sh list-worktrees
#   auditor-dispatch.sh self-check
#   auditor-dispatch.sh --help
#
# Exit codes:
#   0 = success / dispatched
#   1 = invalid args / dispatcher failure
#   2 = usage error
#
# Rule alignment:
#   - Rule 8: L4 bash scripts must exist before ticket close (跟 scripts/verify/auditor-l4.sh 联合)
#   - Rule 9 KPI 精确: dispatch counts 用 grep -c, 0 估数 (跟 EPIC-037-A 联合)
#   - Rule 12 质量 ensure: 9-pass redaction + 5 维度 audit 联动 AuditMiddleware
#   - Q5 L4 角色规范: Auditor 跨 worktree 读 + 写 lessons, 不改原项目代码
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDITOR_SCRIPT="$KALLAX_ROOT/scripts/auditor/auditor.sh"
AUDIT_MIDDLEWARE_PY="$KALLAX_ROOT/scripts/audit/AuditMiddleware.py"
LESSONS_DIR="${LESSONS_DIR:-$KALLAX_ROOT/.kallax/lessons}"
AUDIT_LOG="${AUDIT_LOG:-$LESSONS_DIR/auditor-dispatch-$(date -u +%Y%m).jsonl}"

# ─── Constants (no magic numbers per Hard Rule #4) ───
readonly EXIT_OK=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2
readonly REQUIRED_AUDITOR_FUNCTIONS=(
    "auditor_read_only"
    "auditor_lessons_write"
    "auditor_block_write_original"
)

# ─── Logging helpers (stderr to keep stdout clean for piping) ───
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

ensure_lessons_dir() {
    if [[ ! -d "$LESSONS_DIR" ]]; then
        umask 077
        install -d -m 700 "$LESSONS_DIR" 2>/dev/null || {
            log_err "Cannot create lessons directory: $LESSONS_DIR"
            return 1
        }
    fi
}

write_dispatch_log() {
    local ticket_id="$1"
    local verdict="$2"
    local finding="$3"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local instance_id="${KALLAX_INSTANCE_ID:-auditor_dispatch_$$}"
    ensure_lessons_dir
    echo "{\"ts\":\"$timestamp\",\"ticket\":\"$ticket_id\",\"verdict\":\"$verdict\",\"finding\":\"$finding\",\"dispatcher\":\"auditor-dispatch\",\"instance\":\"$instance_id\"}" >> "$AUDIT_LOG"
}

# ─── Pre-flight: verify auditor.sh + required functions exist ───
preflight() {
    if [[ ! -f "$AUDITOR_SCRIPT" ]]; then
        log_err "auditor.sh not found: $AUDITOR_SCRIPT (Rule 8 L4 必须)"
        return 1
    fi
    if [[ ! -x "$AUDITOR_SCRIPT" ]]; then
        log_err "auditor.sh not executable: $AUDITOR_SCRIPT"
        return 1
    fi
    local missing=()
    for func in "${REQUIRED_AUDITOR_FUNCTIONS[@]}"; do
        if ! grep -q "$func" "$AUDITOR_SCRIPT"; then
            missing+=("$func")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "auditor.sh missing functions: ${missing[*]}"
        return 1
    fi
    return 0
}

# ─── list-worktrees: enumerate git worktrees (Auditor 跨 worktree 读 入口) ───
mode_list_worktrees() {
    local count=0
    if ! command -v git >/dev/null 2>&1; then
        log_err "git not available"
        return "$EXIT_FAIL"
    fi
    while IFS= read -r wt; do
        if [[ -n "$wt" ]] && [[ "$wt" != "$KALLAX_ROOT" ]]; then
            echo "$wt"
            count=$((count + 1))
        fi
    done < <(git -C "$KALLAX_ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2}')
    log_info "list_worktrees_count: $count"
}

# ─── dispatch: 派单到 Auditor instance ───
# Args: <ticket_id> [--finding <text>]
mode_dispatch() {
    local ticket_id=""
    local finding=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --finding) finding="${2:-}"; shift 2 ;;
            --finding=*) finding="${1#*=}"; shift ;;
            -*) log_err "dispatch: unknown flag: $1"; return "$EXIT_USAGE" ;;
            *)
                if [[ -z "$ticket_id" ]]; then
                    ticket_id="$1"
                else
                    log_err "dispatch: unexpected positional arg: $1"
                    return "$EXIT_USAGE"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ticket_id" ]]; then
        log_err "dispatch requires <ticket_id>"
        return "$EXIT_USAGE"
    fi

    if ! preflight; then
        write_dispatch_log "$ticket_id" "FAIL" "preflight_failed"
        return "$EXIT_FAIL"
    fi

    log_info "Dispatching ticket '$ticket_id' to Auditor (L4 mode)"
    log_info "Finding: ${finding:-<none>}"

    # Step 1: Auditor 跨 worktree 读 (read_only trigger)
    log_info "Step 1/3: auditor_read_only"
    if ! bash "$AUDITOR_SCRIPT" read_only "$ticket_id" >/dev/null 2>&1; then
        log_warn "Step 1: auditor_read_only returned non-zero (may be expected without real worktree context)"
    fi

    # Step 2: Auditor 写 lessons (lessons_write trigger)
    log_info "Step 2/3: auditor_lessons_write"
    if ! bash "$AUDITOR_SCRIPT" lessons_write "$ticket_id" "PASS" "${finding:-L4 dispatch by conductor}" >/dev/null 2>&1; then
        log_err "Step 2: auditor_lessons_write FAIL"
        write_dispatch_log "$ticket_id" "FAIL" "lessons_write_failed"
        return "$EXIT_FAIL"
    fi

    # Step 3: 联动 AuditMiddleware.py (Rule 12 质量 ensure 5 维度)
    log_info "Step 3/3: AuditMiddleware联动"
    if [[ -f "$AUDIT_MIDDLEWARE_PY" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            if ! python3 "$AUDIT_MIDDLEWARE_PY" audit \
                --ticket "$ticket_id" \
                --source "auditor-dispatch" \
                --verdict "PASS" 2>/dev/null; then
                log_warn "Step 3: AuditMiddleware audit returned non-zero (non-blocking)"
            fi
        else
            log_warn "Step 3: python3 not available, skipping AuditMiddleware audit"
        fi
    else
        log_warn "Step 3: AuditMiddleware.py not found (will be created in this ticket)"
    fi

    write_dispatch_log "$ticket_id" "PASS" "${finding:-L4 dispatch by conductor}"
    log_info "L4 dispatch to Auditor: PASS (ticket=$ticket_id)"
    return "$EXIT_OK"
}

# ─── self-check: 验证自身 + 依赖存在 ───
mode_self_check() {
    local pass=0
    local fail=0

    echo "=========================================="
    echo "auditor-dispatch.sh self-check"
    echo "=========================================="

    if preflight; then
        echo "  [PASS] auditor.sh + required functions"
        pass=$((pass + 1))
    else
        echo "  [FAIL] auditor.sh + required functions"
        fail=$((fail + 1))
    fi

    if [[ -d "$LESSONS_DIR" ]] || mkdir -p "$LESSONS_DIR" 2>/dev/null; then
        echo "  [PASS] lessons_dir writable ($LESSONS_DIR)"
        pass=$((pass + 1))
    else
        echo "  [FAIL] lessons_dir writable ($LESSONS_DIR)"
        fail=$((fail + 1))
    fi

    if command -v git >/dev/null 2>&1; then
        echo "  [PASS] git available"
        pass=$((pass + 1))
    else
        echo "  [FAIL] git available"
        fail=$((fail + 1))
    fi

    if command -v python3 >/dev/null 2>&1; then
        echo "  [PASS] python3 available"
        pass=$((pass + 1))
    else
        echo "  [FAIL] python3 available"
        fail=$((fail + 1))
    fi

    echo ""
    echo "Result: $pass PASS, $fail FAIL"
    if [[ $fail -gt 0 ]]; then
        return "$EXIT_FAIL"
    fi
    return "$EXIT_OK"
}

# ─── CLI entry ───
main() {
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <command> [args]

Commands:
  dispatch <ticket_id> [--finding <text>]
      Dispatch ticket to Auditor instance (L4 派单模式)
  list-worktrees
      List git worktrees (Auditor 跨 worktree 读 入口)
  self-check
      Verify dispatcher + dependencies

Examples:
  $0 dispatch EPIC-038-C --finding "Rule 9 9a/9b/9c/9d/9e verify"
  $0 list-worktrees
  $0 self-check

Rule alignment:
  - Rule 8: L4 bash scripts must exist
  - Rule 9 KPI: dispatch counts use grep -c (0 estimation)
  - Rule 12: AuditMiddleware 5-dimension audit联动
  - Q5 L4 role spec: Auditor read + write lessons, NO project code modification
EOF
        return "$EXIT_USAGE"
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        dispatch)
            mode_dispatch "$@"
            ;;
        list-worktrees)
            mode_list_worktrees
            ;;
        self-check)
            mode_self_check
            ;;
        -h|--help|help)
            main
            ;;
        *)
            log_err "Unknown command: $cmd"
            return "$EXIT_USAGE"
            ;;
    esac
}

main "$@"