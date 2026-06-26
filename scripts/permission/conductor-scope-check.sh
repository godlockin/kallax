#!/bin/bash
# scripts/permission/conductor-scope-check.sh
# Conductor Scope Check — focused validation for conductor role
#
# Validates:
#   1. Conductor can perform conductor-scope actions (task.assign, testing.merge, etc.)
#   2. Conductor CANNOT perform miao.write / miao.merge / release.tag
#   3. Performer cannot perform conductor-scope actions
#   4. Master can do everything (except emergency-only instance.terminate)
#   5. Readonly/auditor limited to read actions
#
# Usage: conductor-scope-check.sh --action <action> [--actor <name>]
# Example: conductor-scope-check.sh --action miao.write --actor "Steven Chen"
#
# P0 修复项 (跟 PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3 + §4 联合):
#   - set -euo pipefail (BE-23 / BE-25 / BE-26 fixes in place)
#   - SIGTERM handler (防 session_start.sh 类卡死, EPIC-026-A)
#   - fail-closed: 任何错误 exit 1 deny
#   - realpath 执行顺序在前
#   - role 必从 state.json 读, 禁止 env 兜底 (PHASE-002 9c + security review)
#   - FIFO 非阻塞写 (防 audit log 卡死, EPIC-026-A)
#   - role name validation (allowlist 防 trailing space, typo)
#
# 联动:
#   - 跟 EPIC-022-B Pre-commit Hook + Conductor Scope Check 联合
#   - 跟 BE-23 branch-aware action mapping 联合
#   - 跟 BE-25 check-scope-creep TICKET_ID detection 联合
#   - 跟 BE-26 pre-commit hook governance 联合
#   - 跟 EPIC-022-A 3 Role Definition 联合
#   - 跟 EPIC-026-A Bash hot path 6 P0 fixes 联合
#   - 跟"翻篇&精进" 战略 联合 0 简单 记录

set -euo pipefail

# ── SIGTERM handler (P0 fix: prevent session_start.sh style hang) ──────
cleanup() {
  echo "DEBUG: conductor-scope-check.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

# ── Paths (realpath first, P0 fix) ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DB_DIR="${KALLAX_ROOT}/.kallax/data"
AUDIT_LOG="${AUDIT_DB_DIR}/conductor-scope-audit.log"
AUDIT_LOCK="${AUDIT_LOG}.lock"
AUDIT_FALLBACK="${AUDIT_LOG}.fallback"

# ── Defaults ───────────────────────────────────────────────────────────
ACTION=""
ACTOR=""

# ── Argument parsing ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 --action <action> [--actor <name>]

Conductor Scope Check — focused validation for conductor role.
Reads role from $STATE_FILE (env fallback removed per PHASE-002 9c).

Actions:
  Conductor: task.assign, testing.merge, testing.write, instance.read, log.read, ticket.read
  Master:    all except instance.terminate
  Performer: task.claim, worktree.create, worktree.commit, ticket.read, log.read
  Readonly:  *.read
  Auditor:   *.read, audit.export
EOF
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --action <action> [--actor <name>]" >&2
      exit 1
      ;;
  esac
done

# ── Validate required arguments (P0: fail-closed) ──────────────────────
if [[ -z "$ACTION" ]]; then
  echo "ERROR: --action is required" >&2
  exit 1
fi

# Actor defaults to GIT_AUTHOR_NAME (pre-commit) or "unverified-unknown"
if [[ -z "$ACTOR" ]]; then
  ACTOR="${GIT_AUTHOR_NAME:-unverified-unknown}"
fi

# Sanitize actor: strip control chars, allowlist
ACTOR="$(printf %s "$ACTOR" | tr -d '\r\n\0' | LC_ALL=C tr -cd 'A-Za-z0-9 _.\-@<>,' || echo "UNKNOWN")"
if [[ -z "$ACTOR" ]]; then
  ACTOR="UNKNOWN"
fi

# ── Read role from state.json (P0: no env fallback per PHASE-002 9c) ────
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state.json not found: $STATE_FILE" >&2
  exit 1
fi

ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"
if [[ -z "$ROLE" ]]; then
  echo "ERROR: No role in state.json ($STATE_FILE)" >&2
  exit 1
fi

# Re-validate loaded role against allowlist (P0: fail-closed)
if [[ "$ROLE" != "master" ]] && [[ "$ROLE" != "conductor" ]] && \
   [[ "$ROLE" != "performer" ]] && [[ "$ROLE" != "readonly" ]] && \
   [[ "$ROLE" != "auditor" ]]; then
  echo "ERROR: Role not in allowlist: '$ROLE'" >&2
  exit 1
fi

# ── Conductor scope action definitions ─────────────────────────────────
# Conductor-scope: actions a conductor CAN perform
# Source: PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3
# 跟 EPIC-022-A 3 Role Definition 联合
# 跟 node/src/permissions/conductor-scope.ts 联合 (TS side already defines)
CONDUCTOR_SCOPE_ACTIONS=(
  "task.assign"
  "testing.merge"
  "testing.write"
  "instance.read"
  "log.read"
  "ticket.read"
)

# Conductor-blocked: actions a conductor CANNOT perform
# 跟 跟 conductor blocked miao 联合
CONDUCTOR_BLOCKED_ACTIONS=(
  "miao.write"
  "miao.merge"
  "release.tag"
  "task.claim"
  "worktree.create"
  "worktree.commit"
  "instance.terminate"
)

# ── Permission check (P0: fail-closed, allowlist pattern) ──────────────
# Mirrors node/src/permissions/conductor-scope.ts verifyScope() for parity
check_conductor_scope() {
  local role="$1"
  local action="$2"

  case "$role" in
    master)
      # Master can do everything except emergency-only
      [[ "$action" != "instance.terminate" ]]
      return $?
      ;;
    conductor)
      # Conductor: blocked list (miao.write etc.) takes precedence
      for blocked in "${CONDUCTOR_BLOCKED_ACTIONS[@]}"; do
        if [[ "$action" == "$blocked" || "$action" == "$blocked."* ]]; then
          return 1
        fi
      done
      # Conductor: explicit allowlist (task.assign, testing.merge, etc.)
      for allowed in "${CONDUCTOR_SCOPE_ACTIONS[@]}"; do
        if [[ "$action" == "$allowed" || "$action" == "$allowed."* ]]; then
          return 0
        fi
      done
      # Default deny for any action not in allowlist (P0: fail-closed)
      return 1
      ;;
    performer)
      # Performer scope: task.claim, worktree.*, ticket.read, log.read
      case "$action" in
        task.claim|worktree.create|worktree.commit|ticket.read|log.read)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    readonly)
      # Readonly: read-only
      [[ "$action" == *.read ]]
      return $?
      ;;
    auditor)
      # Auditor: inherits readonly + audit.export
      [[ "$action" == *.read ]] || [[ "$action" == "audit.export" ]]
      return $?
      ;;
    *)
      # Unknown role = deny (P0: fail-closed)
      return 1
      ;;
  esac
}

# ── Audit logging (P0: fail-closed for state-changing, FIFO non-blocking) ─
# Mirrors authz/check.sh log_audit() pattern; 跟 EPIC-026-A 联合
log_audit() {
  local role="$1"
  local action="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"

  mkdir -p "$AUDIT_DB_DIR" 2>/dev/null || true

  # Use jq to safely construct JSONL entry (P0: prevent injection)
  local log_entry
  log_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg role "$role" \
    --arg action "$action" \
    --arg actor "$ACTOR" \
    --arg result "$result" \
    --arg check "conductor-scope" \
    '{timestamp: ($ts | tonumber), role: $role, action: $action, actor: $actor, result: $result, check: $check}')

  # is_read_only: gate for audit-fail-closed behavior
  is_read_only() {
    case "$1" in
      *.read|log.read|ticket.read|instance.read|audit.export|*.list|*.get|*.show|*.status)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }

  local audit_ok=false
  if command -v flock >/dev/null 2>&1; then
    # herestring avoids variable expansion in bash -c (P0: injection prevention)
    if flock -n "$AUDIT_LOCK" bash -c 'cat >> "$1"' _ "$AUDIT_LOG" 2>/dev/null <<<"$log_entry"; then
      audit_ok=true
    else
      # Fallback path
      if printf '%s\n' "$log_entry" >> "$AUDIT_FALLBACK" 2>/dev/null; then
        if is_read_only "$action"; then
          echo "WARN: primary audit flock failed for read-only; wrote to fallback" >&2
          audit_ok=true
        fi
      fi
    fi
  else
    # macOS fallback
    if printf '%s\n' "$log_entry" >> "$AUDIT_LOG" 2>/dev/null; then
      audit_ok=true
    elif printf '%s\n' "$log_entry" >> "$AUDIT_FALLBACK" 2>/dev/null; then
      if is_read_only "$action"; then
        echo "WARN: primary audit log write failed on macOS; wrote to fallback" >&2
        audit_ok=true
      fi
    fi
  fi

  # State-changing actions: fail-closed if audit cannot be written
  if [[ "$audit_ok" != "true" ]] && ! is_read_only "$action"; then
    echo "ERROR: audit log write failed for state-changing action $ACTION — fail-closed" >&2
    return 1
  fi

  return 0
}

# ── Perform check (P0: fail-closed) ────────────────────────────────────
if check_conductor_scope "$ROLE" "$ACTION"; then
  if ! log_audit "$ROLE" "$ACTION" "ALLOWED"; then
    echo "DENIED: $ACTION — audit log write failed for state-changing action" >&2
    exit 1
  fi
  exit 0
else
  # Log DENIED result (best-effort, don't fail if audit log is unwritable)
  log_audit "$ROLE" "$ACTION" "DENIED" || true
  echo "DENIED: $ACTION for role $ROLE (actor: $ACTOR) — conductor scope check" >&2
  exit 1
fi
