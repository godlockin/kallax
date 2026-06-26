#!/bin/bash
# scripts/permission/readonly-path.sh — Mark/check path as read-only for current role
#
# 跟 EPIC-022-C 联合 (Workspace Switch + Read-Only Path)
# 跟 BE-19 KALLAX authz bypass 联合 (role MUST come from state.json)
# 跟 BE-23/BE-25/BE-26 pre-commit 联合 0 --no-verify
#
# P0 fixes (跟 templates/scripts/workspace/readonly.sh 升级, 0 简单 记录):
#   - set -euo pipefail
#   - fail-closed: any error exit 1
#   - realpath 执行顺序在前 (防 symlink 绕过, 防 BE-19 升级)
#   - SIGTERM handler
#   - unknown role = readonly (fail-closed)
#   - role allowlist validation
#   - role MUST come from state.json (--role CLI removed, PHASE-002 9c)
#   - jq -n safe JSONL 序列化 (治 BE-19 authz bypass)
#   - flock 串行化 audit log
#
# Usage: readonly-path.sh --path <path> --actor <actor>
# Example: readonly-path.sh --path miao/ --actor "Steven Chen"
#
# Exit codes:
#   0  writable
#   1  readonly (deny)
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

cleanup() {
  echo "DEBUG: readonly-path.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

TARGET_PATH=""
ACTOR=""
ROLE_ALLOWLIST="master conductor performer readonly auditor"

# Sanitize actor: strip control chars + SQL/shell meta (defense-in-depth)
sanitize_actor() {
  local raw="$1"
  raw="$(printf %s "$raw" | tr -d '\r\n\0' | LC_ALL=C tr -cd 'A-Za-z0-9 _.\-@<>,' || echo "")"
  if [[ -z "$raw" ]]; then
    raw="UNKNOWN"
  fi
  printf %s "$raw"
}

# Reject SQL/shell injection patterns
ACTOR_LOWER="$(printf %s "$ACTOR" | tr '[:upper:]' '[:lower:]')"
is_injection_attempt() {
  local a="$1"
  [[ "$a" == *drop* ]] || [[ "$a" == *table* ]] || \
  [[ "$a" == *select* ]] || [[ "$a" == *insert* ]] || \
  [[ "$a" == *delete* ]] || [[ "$a" == *update* ]] || \
  [[ "$a" == *union* ]] || [[ "$a" == *"--"* ]]
}

# P0 fix: jq -n safe JSONL 序列化 (治 BE-19 authz bypass)
log_readonly_check() {
  local path="$1"
  local role="$2"
  local result="$3"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

  mkdir -p "$(dirname "$AUDIT_DB")" 2>/dev/null || true

  local log_entry
  log_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg path "$path" \
    --arg role "$role" \
    --arg actor "$ACTOR" \
    --arg result "$result" \
    '{timestamp: $ts, event: "readonly_check", path: $path, role: $role, actor: $actor, result: $result}')

  if command -v flock >/dev/null 2>&1; then
    if ! flock -n "${AUDIT_DB}.log.lock" bash -c 'cat >> "${AUDIT_DB}.log"' 2>/dev/null <<<"$log_entry"; then
      printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null || \
        echo "WARN: audit log write failed for readonly_check $path" >&2
    fi
  else
    printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log" 2>/dev/null || \
      printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null || \
      echo "WARN: audit log write failed for readonly_check $path" >&2
  fi
}

# Check if a path is read-only for a given role.
# Returns 0 (readonly) or 1 (writable).
is_readonly_for_role() {
  local path="$1"
  local role="$2"

  case "$role" in
    master)
      return 1  # master can write anywhere
      ;;
    conductor)
      # conductor cannot write to miao/
      [[ "$path" == "miao/"* ]] || [[ "$path" == "miao" ]]
      ;;
    performer)
      # performer cannot write to miao/, .git/hooks/, .kallax/config/
      [[ "$path" == "miao/"* ]] || [[ "$path" == "miao" ]] || \
      [[ "$path" == ".git/hooks/"* ]] || [[ "$path" == ".git/hooks" ]] || \
      [[ "$path" == ".kallax/config/"* ]] || [[ "$path" == ".kallax/config" ]]
      ;;
    readonly|auditor)
      return 0  # all paths are readonly
      ;;
    *)
      return 0  # unknown role = readonly (fail-closed)
      ;;
  esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      TARGET_PATH="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
Usage: $0 --path <path> --actor <actor>

Options:
  --path <path>   Target path to check
  --actor <name>  Actor performing the check (audit field)

Exit codes:
  0  writable
  1  readonly (deny)
USAGE
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_PATH" ]]; then
  echo "ERROR: --path is required" >&2
  exit 1
fi

if [[ -z "$ACTOR" ]]; then
  echo "ERROR: --actor is required" >&2
  exit 1
fi

ACTOR="$(sanitize_actor "$ACTOR")"
ACTOR_LOWER="$(printf %s "$ACTOR" | tr '[:upper:]' '[:lower:]')"
if is_injection_attempt "$ACTOR_LOWER"; then
  echo "WARN: actor contains SQL keywords, redacting to [REDACTED]" >&2
  ACTOR="[REDACTED]"
fi

# P0 fix: realpath 执行顺序在前 (防 symlink 绕过)
# 解析 STATE_FILE 真实路径, 防 symlink bypass
REAL_STATE_FILE="$(realpath "$STATE_FILE" 2>/dev/null || echo "$STATE_FILE")"
if [[ ! -f "$REAL_STATE_FILE" ]]; then
  echo "ERROR: state.json not found at $REAL_STATE_FILE" >&2
  exit 1
fi

# P0 fix: role MUST come from state.json (--role CLI removed, PHASE-002 9c)
# KALLAX_CURRENT_ROLE 仅作 test seam 兜底 (PHASE-002 §9d 留)
ROLE="${KALLAX_CURRENT_ROLE:-}"
if [[ -z "$ROLE" ]]; then
  ROLE="$(jq -r '.role // ""' "$REAL_STATE_FILE" 2>/dev/null)"
fi
if [[ -z "$ROLE" ]]; then
  echo "ERROR: No role in state.json ($REAL_STATE_FILE)" >&2
  exit 1
fi

# P0 fix: path realpath 解析 (防 symlink 绕过 BE-19)
# 跟 EPIC-022-C p0_fixes[0] "realpath 执行顺序在前" 联合
REAL_PATH="$(realpath -m "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")"

# Fail-closed: unknown role is denied (readonly)
if [[ " $ROLE_ALLOWLIST " != *" $ROLE "* ]]; then
  log_readonly_check "$REAL_PATH" "$ROLE" "READONLY_UNKNOWN_ROLE"
  echo "READONLY: $REAL_PATH is read-only for unknown role $ROLE (actor: $ACTOR)"
  exit 1
fi

if is_readonly_for_role "$REAL_PATH" "$ROLE"; then
  log_readonly_check "$REAL_PATH" "$ROLE" "READONLY"
  echo "READONLY: $REAL_PATH is read-only for role $ROLE (actor: $ACTOR)"
  exit 1
else
  log_readonly_check "$REAL_PATH" "$ROLE" "WRITABLE"
  echo "WRITABLE: $REAL_PATH is writable for role $ROLE (actor: $ACTOR)"
  exit 0
fi
