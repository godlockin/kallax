#!/usr/bin/env bash
# scripts/lib/invocation-core.sh
# Core invocation queue logic: emit, drain, health, query
# Part of expert-invocation-queue.sh modularization (EPIC-122-J)

set -euo pipefail

# Constants (shared with parent)
INVOCATION_DIR="${HOME}/.kallax/queue"
INVOCATION_FILE="${INVOCATION_DIR}/expert_invocations.jsonl"
ARCHIVE_FILE="${HOME}/.kallax/state/expert_invocations.archive.jsonl"
SQLITE_DB="${HOME}/.kallax/state/expert_invocations.db"
REDIS_KEY="expert_invocations"
LRU_MAX=1000
LAST_ERROR="${LAST_ERROR:-}"

# LAST_ERROR setter (accessible from subshell)
# EPIC-122-E: Extract EPIC from ticket_id
extract_epic() {
  local ticket_id="$1"
  if [[ "$ticket_id" =~ ^([A-Z]+-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "DEFAULT"
  fi
}

# EPIC-122-E: Write to EPIC-specific jsonl
epic_jsonl_emit() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="$3"
  local backend="$4"

  local epic
  epic=$(extract_epic "$ticket_id")

  local epic_dir="${INVOCATION_DIR}/${epic}"
  local epic_file="${epic_dir}/invocations.jsonl"

  mkdir -p "$epic_dir"
  chmod 0700 "$epic_dir" 2>/dev/null || true

  local payload
  payload=$(jq -n \
    --arg eid "$expert_id" \
    --arg tid "$ticket_id" \
    --argjson ts "$ts" \
    --arg b "$backend" \
    '{expert_id: $eid, ticket_id: $tid, ts: $ts, backend: $b}')

  with_lock "epic_jsonl" sh -c '
    echo "$2" >> "$1"
  ' _ "$epic_file" "$payload" || {
    LAST_ERROR="failed to write to $epic_file"
    return 1
  }
}

# Internal emit to SQLite
sqlite_emit() {
  local payload="$1"
  sqlite3 "$SQLITE_DB" "CREATE TABLE IF NOT EXISTS invocations (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, ts INTEGER DEFAULT (strftime('%s','now')))" 2>/dev/null
  with_lock "sqlite" sh -c '
    local safe
    safe=$(printf "%s" "$1" | sed "s/'\''/'\'''\''/g")
    sqlite3 "$2" "INSERT INTO invocations (payload) VALUES ('\''$safe'\'');"
  ' _ "$payload" "$SQLITE_DB"
}

# Internal emit to file
file_emit() {
  local payload="$1"
  with_lock "file" sh -c '
    if ! touch "$1" 2>/dev/null; then
      echo "ENOSPC" >&2
      return 1
    fi
    echo "$2" >> "$1"
  ' _ "$INVOCATION_FILE" "$payload" || {
    LAST_ERROR="ENOSPC: cannot write to $INVOCATION_FILE"
    return 1
  }
  lru_archive
}

lru_archive() {
  if [ ! -f "$INVOCATION_FILE" ]; then
    return 0
  fi
  local line_count
  line_count=$(wc -l < "$INVOCATION_FILE" 2>/dev/null || echo 0)
  if [ "$line_count" -gt "$LRU_MAX" ]; then
    local overflow=$(( line_count - LRU_MAX ))
    local tmp="${INVOCATION_FILE}.lru.$$"
    tail -n "$overflow" "$INVOCATION_FILE" >> "$ARCHIVE_FILE"
    head -n "$LRU_MAX" "$INVOCATION_FILE" > "$tmp" && mv "$tmp" "$INVOCATION_FILE"
  fi
}

# emit: write one invocation
emit() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="${3:-$(date +%s)}"

  if ! validate_input "$expert_id" "$ticket_id"; then
    echo "ERROR: $LAST_ERROR" >&2
    return 1
  fi

  if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
    LAST_ERROR="ts must be numeric"
    echo "ERROR: $LAST_ERROR" >&2
    return 1
  fi

  __emit_expert_id="$expert_id"
  __emit_ticket_id="$ticket_id"
  __emit_ts="$ts"

  with_lock "emit_drain" sh -c '
    local backend
    backend=$(get_backend)

    if [ "$backend" != "redis" ]; then
      try_upgrade_redis && backend=$(get_backend)
    fi

    local safe_expert_id safe_ticket_id
    safe_expert_id=$(json_escape "$__emit_expert_id")
    safe_ticket_id=$(json_escape "$__emit_ticket_id")
    local payload="{\"expert_id\":\"$safe_expert_id\",\"ticket_id\":\"$safe_ticket_id\",\"ts\":$__emit_ts,\"backend\":\"$backend\"}"

    if [ "$backend" = "redis" ]; then
      if probe_redis; then
        if redis-cli -x XADD "$REDIS_KEY" '"'"'*'"'"' payload "$payload" 2>/dev/null; then
          write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          epic_jsonl_emit "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          return 0
        fi
        LAST_ERROR="redis XADD failed despite probe success (ACL/stream config?)"
      fi
      set_backend sqlite
      backend="sqlite"
    fi

    if [ "$backend" = "sqlite" ]; then
      if probe_sqlite; then
        if sqlite_emit "$payload"; then
          write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          epic_jsonl_emit "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          return 0
        fi
      fi
      set_backend file
      backend="file"
    fi

    if [ "$backend" = "file" ]; then
      file_emit "$payload"
      write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
      epic_jsonl_emit "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
    fi
  '
}

drain() {
  local backend=$(get_backend)
  with_lock "drain" sh -c '
    case "$1" in
      redis)
        redis-cli XRANGE "$2" - + 2>/dev/null
        redis-cli XTRIM "$2" MAXLEN 0 2>/dev/null
        ;;
      sqlite)
        sqlite3 "$3" "BEGIN; SELECT payload FROM invocations; DELETE FROM invocations; COMMIT;" 2>/dev/null
        ;;
      file)
        if [ -f "$4" ]; then
          mv "$4" "${4}.drain.$$"
          cat "${4}.drain.$$"
          rm -f "${4}.drain.$$"
        fi
        ;;
    esac
  ' _ "$backend" "$REDIS_KEY" "$SQLITE_DB" "$INVOCATION_FILE"
}

health() {
  local backend=$(get_backend)
  local latency
  latency=$(get_latency_ms)
  local size
  size=$(get_queue_size)
  local safe_error
  safe_error=$(sanitize_error "$LAST_ERROR")
  cat <<EOF
{
  "backend": "$backend",
  "latency_ms": $latency,
  "queue_size": $size,
  "last_error": "$safe_error"
}
EOF
}

write_state_invocations() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="$3"
  local backend="$4"

  local state_file="${HOME}/.kallax/state/state.json"
  if [ ! -f "$state_file" ]; then
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    LAST_ERROR="jq not found, state.json LRU not maintained"
    return 1
  fi

  with_lock "state_json" sh -c '
    local tmp="${1}.tmp.$$"
    local output_len="${7:-0}"
    local truncated="${8:-false}"
    jq --arg eid "$2" \
       --arg tid "$3" \
       --argjson ts "$4" \
       --arg b "$5" \
       --argjson max "$6" \
       --argjson olen "$output_len" \
       --argjson trunc "$truncated" \
       ".expert_invocations = ((.expert_invocations // []) + [{expert_id:\$eid, ticket_id:\$tid, ts:\$ts, backend:\$b, output_length:\$olen, output_truncated:\$trunc}]) |
        if (.expert_invocations | length) > \$max then
          .expert_invocations |= .[-\$max:]
        else . end" \
       "$1" > "$tmp" && mv "$tmp" "$1"
  ' _ "$state_file" "$expert_id" "$ticket_id" "$ts" "$backend" "$LRU_MAX" "0" "false"
}

get_latency_ms() {
  case "$(get_backend)" in
    redis)
      local start
      start=$(date +%s%N)
      if probe_redis; then
        local end
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
      else
        echo -1
      fi
      ;;
    sqlite)
      local start
      start=$(date +%s%N)
      if probe_sqlite; then
        local end
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
      else
        echo -1
      fi
      ;;
    file) echo 1 ;;
    *) echo -1 ;;
  esac
}

get_queue_size() {
  case "$(get_backend)" in
    redis) redis-cli XLEN "$REDIS_KEY" 2>/dev/null || echo 0 ;;
    sqlite) sqlite3 "$SQLITE_DB" "SELECT COUNT(*) FROM invocations" 2>/dev/null || echo 0 ;;
    file) wc -l < "$INVOCATION_FILE" 2>/dev/null || echo 0 ;;
    *) echo 0 ;;
  esac
}

query_invocations() {
  local ids="${1:-}"
  local backend
  backend=$(get_backend)
  local results="[]"

  case "$backend" in
    file)
      if [ -f "$INVOCATION_FILE" ]; then
        if [ -z "$ids" ]; then
          results=$(tail -100 "$INVOCATION_FILE" 2>/dev/null | jq -s '.' || echo "[]")
        else
          for id in $ids; do
            local rec
            rec=$(grep -F "\"$id\"" "$INVOCATION_FILE" 2>/dev/null | tail -1 || echo "")
            if [ -n "$rec" ]; then
              results=$(echo "$results" | jq ". + [$rec]")
            fi
          done
        fi
      fi
      ;;
    sqlite)
      if [ -z "$ids" ]; then
        results=$(sqlite3 "$SQLITE_DB" "SELECT payload FROM invocations ORDER BY id DESC LIMIT 100" 2>/dev/null | jq -s '.' || echo "[]")
      else
        for id in $ids; do
          local rec
          rec=$(sqlite3 "$SQLITE_DB" "SELECT payload FROM invocations WHERE id = '$id'" 2>/dev/null || echo "")
          if [ -n "$rec" ]; then
            results=$(echo "$results" | jq ". + [$rec]")
          fi
        done
      fi
      ;;
    redis)
      if [ -f "${INVOCATION_FILE}.cancelled" ]; then
        results=$(cat "${INVOCATION_FILE}.cancelled" 2>/dev/null | jq -s '.' || echo "[]")
      else
        results="[]"
      fi
      ;;
  esac

  echo "$results"
}
