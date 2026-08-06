#!/bin/bash
# scripts/permission/workspace-switch.sh — Switch KALLAX workspace
#
# 跟 EPIC-022-C 联合 (Workspace Switch + Read-Only Path)
# 跟 BE-19 KALLAX authz bypass 联合 (role MUST come from state.json)
# 跟 BE-23/BE-25/BE-26 pre-commit 联合 0 --no-verify
#
# P0 fixes (跟 templates/scripts/permission/* 升级, 0 简单 记录):
#   - set -euo pipefail
#   - fail-closed: any error exit 1 deny
#   - realpath 执行顺序在前 (防 symlink 绕过)
#   - SIGTERM handler (防 session_start.sh 类卡死)
#   - transition requires auditor+ role (master/conductor/auditor)
#   - role MUST come from state.json (--role CLI removed, PHASE-002 9c)
#   - jq -n safe JSONL 序列化 (治 BE-19 authz bypass)
#   - flock 串行化 audit log (治 KALLAX 并发)
#
# Usage: workspace-switch.sh --workspace <name> --actor <actor>
# Example: workspace-switch.sh --workspace conductor --actor "Steven Chen"
#
# Exit codes:
#   0  allowed
#   1  denied (fail-closed)
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

cleanup() {
  echo "DEBUG: workspace-switch.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

# Default values
WORKSPACE=""
ACTOR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
Usage: $0 --workspace <name> --actor <actor>

Options:
  --workspace <name>   Target workspace: master|conductor|performer|readonly|auditor
  --actor <name>       Actor performing the switch (audit field)

Exit codes:
  0  allowed
  1  denied (fail-closed)
USAGE
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --workspace <name> --actor <actor>" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$WORKSPACE" ]]; then
  echo "ERROR: --workspace is required" >&2
  exit 1
fi

if [[ -z "$ACTOR" ]]; then
  echo "ERROR: --actor is required" >&2
  exit 1
fi

# P0 fix: realpath 执行顺序在前 (防 symlink 绕过)
# 解析 STATE_FILE 的真实路径, 防止通过 symlink 绕过 role 检查
REAL_STATE_FILE="$(realpath "$STATE_FILE" 2>/dev/null || echo "$STATE_FILE")"
if [[ ! -f "$REAL_STATE_FILE" ]]; then
  echo "ERROR: state.json not found at $REAL_STATE_FILE" >&2
  exit 1
fi

# Validate workspace name (allowlist)
VALID_WORKSPACES="master conductor performer readonly auditor"
case " $VALID_WORKSPACES " in
  *" $WORKSPACE "*)
    ;;
  *)
    echo "ERROR: Unknown workspace: '$WORKSPACE'" >&2
    echo "Valid workspaces: $VALID_WORKSPACES" >&2
    exit 1
    ;;
esac

# P0 fix: role comes only from authoritative state.json.
ROLE="$(jq -r '.role // ""' "$REAL_STATE_FILE" 2>/dev/null)"
if [[ -z "$ROLE" ]]; then
  echo "ERROR: No role in state.json ($REAL_STATE_FILE)" >&2
  exit 1
fi

# Re-validate loaded role against allowlist (fail-closed)
case " $VALID_WORKSPACES " in
  *" $ROLE "*)
    ;;
  *)
    echo "ERROR: Role not in allowlist: '$ROLE'" >&2
    exit 1
    ;;
esac

# Sanitize actor: strip control chars + SQL/shell meta (defense-in-depth)
ACTOR="$(printf %s "$ACTOR" | tr -d '\r\n\0' | LC_ALL=C tr -cd 'A-Za-z0-9 _.\-@<>,' || echo "UNKNOWN")"
if [[ -z "$ACTOR" ]]; then
  ACTOR="UNKNOWN"
fi

# P0 fix: jq -n safe JSONL 序列化 (治 BE-19 authz bypass via injection)
log_workspace_switch() {
  local from_role="$1"
  local to_workspace="$2"
  local result="$3"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

  mkdir -p "$(dirname "$AUDIT_DB")" 2>/dev/null || true

  local log_entry
  log_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg from "$from_role" \
    --arg to "$to_workspace" \
    --arg actor "$ACTOR" \
    --arg result "$result" \
    '{timestamp: $ts, event: "workspace_switch", from_role: $from, to_workspace: $to, actor: $actor, result: $result}')

  # P0 fix: flock 串行化 audit log (治 KALLAX 并发)
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n "${AUDIT_DB}.log.lock" bash -c 'cat >> "$1"' bash "$AUDIT_DB.log" 2>/dev/null <<<"$log_entry"; then
      # Fallback: best-effort append (read-only action so we don't fail-closed)
      printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null || \
        echo "WARN: audit log write failed for workspace_switch $from_role→$to_workspace" >&2
    fi
  else
    # macOS fallback: direct append
    printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log" 2>/dev/null || \
      printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null || \
      echo "WARN: audit log write failed for workspace_switch $from_role→$to_workspace" >&2
  fi
}

# Transition rules: who can switch to which workspace
# Only master/conductor/auditor can switch workspaces
can_switch() {
  local from_role="$1"
  local to_workspace="$2"

  case "$from_role" in
    master|conductor|auditor)
      # Performer workspace is not switchable (must stay in performer)
      if [[ "$to_workspace" == "performer" ]]; then
        return 1
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Perform switch check
if can_switch "$ROLE" "$WORKSPACE"; then
  log_workspace_switch "$ROLE" "$WORKSPACE" "ALLOWED"
  echo "ALLOWED: workspace switch $ROLE -> $WORKSPACE (actor: $ACTOR)"
  exit 0
else
  log_workspace_switch "$ROLE" "$WORKSPACE" "DENIED"
  echo "DENIED: workspace switch to $WORKSPACE for role $ROLE (actor: $ACTOR)" >&2
  exit 1
fi
