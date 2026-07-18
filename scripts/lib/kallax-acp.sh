#!/usr/bin/env bash
# scripts/lib/kallax-acp.sh — EPIC-122-H: KALLAX ACP (Agent Communication Protocol)
#
# 参照 grok-build xai-acp-lib/src/message.rs 的 AcpArgs 模式。
# 轻量版 JSON-over-stdin/stdout 协议，用于 pipeline / CI / headless 模式。
#
# 5 个核心方法:
#   session_open    — 打开新 session，返回 session_id
#   session_close   — 关闭 session
#   invoke_expert  — 调用 expert，返回 invocation_id
#   query_invocations — 查询 invocation 状态
#   cancel_invocation — 取消 running invocation
#
# Wire format: JSON-RPC 2.0
#   Request:  {"method":"method_name","params":{...},"id":N}
#   Response: {"result":{...},"error":null,"id":N}
#   Notify:   {"method":"method_name","params":{...}}  (no id)
#
# Usage:
#   # 交互模式
#   bash scripts/lib/kallax-acp.sh session_open | jq .
#
#   # Headless 模式 (pipe)
#   echo '{"method":"invoke_expert","params":{"expert_id":"backend","ticket_id":"EPIC-001"},"id":1}' \
#     | bash scripts/lib/kallax-acp.sh
#
set -euo pipefail

PROTOCOL_VERSION="1.0"
SESSION_ID=""
INVOCATION_COUNTER=0

# === Protocol Errors (参照 grok-build error_codes.rs) ===
readonly E_INVALID_METHOD="INVALID_METHOD"
readonly E_INVALID_PARAMS="INVALID_PARAMS"
readonly E_SESSION_NOT_FOUND="SESSION_NOT_FOUND"
readonly E_INVOCATION_NOT_FOUND="INVOCATION_NOT_FOUND"
readonly E_ALREADY_CANCELLED="ALREADY_CANCELLED"
readonly E_INTERNAL_ERROR="INTERNAL_ERROR"

# === Global state (in-memory for headless, would be disk for daemon) ===
declare -A SESSIONS=()      # session_id -> session_state
declare -A INVOCATIONS=()   # invocation_id -> invocation_state (pending/running/done/cancelled)

# === Utility ===
send_response() {
  local id="$1"
  local result="${2:-null}"
  local error="${3:-null}"
  jq -n \
    --argjson id "$id" \
    --argjson result "$result" \
    --argjson error "$error" \
    '{result: $result, error: $error, id: $id}'
}

send_error() {
  local id="$1"
  local code="$2"
  local message="$3"
  jq -n \
    --argjson id "$id" \
    --argjson errcode "$code" \
    --arg msg "$message" \
    '{result: null, error: {code: $errcode, message: $msg}, id: $id}'
}

# === Methods ===

do_session_open() {
  local params="$1"
  local session_id
  session_id=$(date +%s)-$((RANDOM % 10000))
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  SESSIONS["$session_id"]="{\"session_id\":\"$session_id\",\"opened_at\":\"$now\",\"status\":\"active\"}"
  echo "{\"session_id\":\"$session_id\",\"status\":\"active\",\"protocol\":\"$PROTOCOL_VERSION\"}"
}

do_session_close() {
  local session_id="$1"
  if [[ -z "${SESSIONS[$session_id]:-}" ]]; then
    echo "{\"error\":\"$E_SESSION_NOT_FOUND\"}"
    return 1
  fi
  SESSIONS["$session_id"]=""
  echo "{\"session_id\":\"$session_id\",\"status\":\"closed\"}"
}

do_invoke_expert() {
  local session_id="$1"
  local expert_id="$2"
  local ticket_id="$3"

  if [[ -z "${SESSIONS[$session_id]:-}" ]]; then
    echo "{\"error\":\"$E_SESSION_NOT_FOUND\"}"
    return 1
  fi

  INVOCATION_COUNTER=$((INVOCATION_COUNTER + 1))
  local invocation_id="inv-${INVOCATION_COUNTER}"
  local ts
  ts=$(date +%s)

  INVOCATIONS["$invocation_id"]="{\"id\":\"$invocation_id\",\"expert_id\":\"$expert_id\",\"ticket_id\":\"$ticket_id\",\"session_id\":\"$session_id\",\"ts\":$ts,\"status\":\"running\"}"
  echo "{\"invocation_id\":\"$invocation_id\",\"status\":\"pending\",\"expert_id\":\"$expert_id\",\"ticket_id\":\"$ticket_id\"}"
}

do_query_invocations() {
  local session_id="$1"
  local invocation_ids="${2:-}"

  if [[ -z "${SESSIONS[$session_id]:-}" ]]; then
    echo "{\"error\":\"$E_SESSION_NOT_FOUND\"}"
    return 1
  fi

  if [[ -z "$invocation_ids" ]]; then
    # Return all for session
    local results="[]"
    for key in "${!INVOCATIONS[@]}"; do
      local inv="${INVOCATIONS[$key]}"
      if echo "$inv" | jq -e --arg sid "$session_id" '.session_id == $sid' >/dev/null 2>&1; then
        results=$(echo "$results" | jq ". + [$inv]")
      fi
    done
    echo "$results"
  else
    # Return specific ids
    local results="[]"
    for id in $invocation_ids; do
      if [[ -n "${INVOCATIONS[$id]:-}" ]]; then
        results=$(echo "$results" | jq ". + [\"${INVOCATIONS[$id]}\"]")
      fi
    done
    echo "$results"
  fi
}

do_cancel_invocation() {
  local invocation_id="$1"
  local inv="${INVOCATIONS[$invocation_id]:-}"
  if [[ -z "$inv" ]]; then
    echo "{\"error\":\"$E_INVOCATION_NOT_FOUND\"}"
    return 1
  fi

  local status
  status=$(echo "$inv" | jq -r '.status')
  if [[ "$status" == "cancelled" ]]; then
    echo "{\"error\":\"$E_ALREADY_CANCELLED\"}"
    return 1
  fi

  INVOCATIONS["$invocation_id"]=$(echo "$inv" | jq '.status = "cancelled"')
  echo "{\"invocation_id\":\"$invocation_id\",\"status\":\"cancelled\"}"
}

# === Router ===
route() {
  local method="$1"
  local params="$2"
  local id="${3:-null}"

  case "$method" in
    session_open)
      if [[ "$id" == "null" ]]; then
        do_session_open "$params"
      else
        result=$(do_session_open "$params")
        send_response "$id" "$result" "null"
      fi
      ;;
    session_close)
      local session_id
      session_id=$(echo "$params" | jq -r '.session_id // empty')
      if [[ "$id" == "null" ]]; then
        do_session_close "$session_id"
      else
        result=$(do_session_close "$session_id")
        send_response "$id" "$result" "null"
      fi
      ;;
    invoke_expert)
      local session_id expert_id ticket_id
      session_id=$(echo "$params" | jq -r '.session_id // empty')
      expert_id=$(echo "$params" | jq -r '.expert_id // empty')
      ticket_id=$(echo "$params" | jq -r '.ticket_id // empty')
      if [[ -z "$session_id" || -z "$expert_id" || -z "$ticket_id" ]]; then
        send_error "$id" "$E_INVALID_PARAMS" "session_id, expert_id, ticket_id required"
        return
      fi
      result=$(do_invoke_expert "$session_id" "$expert_id" "$ticket_id")
      send_response "$id" "$result" "null"
      ;;
    query_invocations)
      local session_id invocation_ids
      session_id=$(echo "$params" | jq -r '.session_id // empty')
      invocation_ids=$(echo "$params" | jq -r '.invocation_ids // ""')
      if [[ -z "$session_id" ]]; then
        send_error "$id" "$E_INVALID_PARAMS" "session_id required"
        return
      fi
      result=$(do_query_invocations "$session_id" "$invocation_ids")
      send_response "$id" "$result" "null"
      ;;
    cancel_invocation)
      local invocation_id
      invocation_id=$(echo "$params" | jq -r '.invocation_id // empty')
      if [[ -z "$invocation_id" ]]; then
        send_error "$id" "$E_INVALID_PARAMS" "invocation_id required"
        return
      fi
      result=$(do_cancel_invocation "$invocation_id")
      send_response "$id" "$result" "null"
      ;;
    *)
      send_error "$id" "$E_INVALID_METHOD" "Unknown method: $method"
      ;;
  esac
}

# === Main loop ===
# Read JSON-RPC requests from stdin (or single request as argument)
main() {
  if [[ -t 0 ]]; then
    # Interactive usage with arguments
    if [[ $# -gt 0 ]]; then
      local method="$1"
      local params="${2:-{}}"
      route "$method" "$params" "null"
    else
      echo "Usage: kallax-acp.sh <method> [params_json]" >&2
      echo "Or pipe JSON-RPC requests to stdin" >&2
      exit 1
    fi
  else
    # Pipeline mode: read JSON-RPC from stdin
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      local method id params
      method=$(echo "$line" | jq -r '.method // empty')
      id=$(echo "$line" | jq -r '.id // "null"')
      params=$(echo "$line" | jq '.params // {}')
      if [[ -z "$method" ]]; then
        echo "{\"error\":\"INVALID_REQUEST\"}" >&2
        continue
      fi
      route "$method" "$params" "$id"
    done
  fi
}

main "$@"
