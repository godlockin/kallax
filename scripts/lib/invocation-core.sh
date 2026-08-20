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

  export -f _epic_jsonl_locked_body
  with_lock "epic_jsonl" _epic_jsonl_locked_body "$epic_file" "$payload" || {
    LAST_ERROR="failed to write to $epic_file"
    return 1
  }
}

_epic_jsonl_locked_body() {
  # 不用 local. 参数从父 shell 传入.
  echo "$2" >> "$1"
}

# Internal emit to SQLite
sqlite_emit() {
  local payload="$1"
  sqlite3 "$SQLITE_DB" "CREATE TABLE IF NOT EXISTS invocations (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, ts INTEGER DEFAULT (strftime('%s','now')))" 2>/dev/null
  # EPIC-277 AC4: 同 emit() 修法 — 不用 sh -c (子 shell 看不到函数定义).
  # 参数顺序: _sqlite_emit_locked_body "$payload" "$SQLITE_DB"
  # 注意 with_lock 把第一个实参当命令, "$1" 是该命令的 $0, "$2" 是 $1.
  # 这里直接传: $1=payload, $2=db_path.
  export -f _sqlite_emit_locked_body
  export -f _sqlite_emit_locked_body
  with_lock "sqlite" _sqlite_emit_locked_body "$payload" "$SQLITE_DB"
}

_sqlite_emit_locked_body() {
  # 不用 local (子 shell exec 函数体, local 无效).
  # 参数已从父 shell 传入, 不再依赖外部变量.
  safe=$(printf "%s" "$1" | sed "s/'/''/g")
  sqlite3 "$2" "INSERT INTO invocations (payload) VALUES ('$safe');"
}

# Internal emit to file
file_emit() {
  local payload="$1"
  # EPIC-277 AC4: 同 emit() 修法 — 不用 sh -c.
  # 参数顺序: _file_emit_locked_body "$INVOCATION_FILE" "$payload"
  export -f _file_emit_locked_body
  export -f _file_emit_locked_body
  with_lock "file" _file_emit_locked_body "$INVOCATION_FILE" "$payload" || {
    LAST_ERROR="ENOSPC: cannot write to $INVOCATION_FILE"
    return 1
  }
  lru_archive
}

_file_emit_locked_body() {
  # 不用 local.
  if ! touch "$1" 2>/dev/null; then
    echo "ENOSPC" >&2
    return 1
  fi
  echo "$2" >> "$1"
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

  # EPIC-277 AC4: emit() 内的 with_lock ... sh -c '...' 子 shell 看不到父 shell
  # 的函数定义 (get_backend / json_escape / probe_redis / probe_sqlite /
  # sqlite_emit / file_emit / write_state_invocations / epic_jsonl_emit /
  # set_backend / try_upgrade_redis) — 导致 emit 静默成功但 0 写入 (实测 SQLite
  # 2 个多月 0 新行).
  #
  # 修法: 把逻辑搬到父 shell 里, 在 with_lock 之外执行. with_lock 内部本来就有
  # 自己的子 shell 拿锁, 那个子 shell 跑的是 _emit_locked_body 函数 (父 shell
  # 已定义), 不会再有 sh -c 子 shell 隔离.
  # export -f 是必需的: with_lock 内部 `"$@"` 是 fork+exec, 函数定义不自动继承.
  export -f _emit_locked_body
  with_lock "emit_drain" _emit_locked_body
}

# EPIC-277 AC4: 拆出的锁内执行体. 这个函数在父 shell 中被 emit() 通过
# with_lock 调用, 因此它能看到所有父 shell 函数 (get_backend 等). 变量
# __emit_expert_id / __emit_ticket_id / __emit_ts 由 emit() 在调用前赋值.
_emit_locked_body() {
    # 不用 `local`: 这里是子 shell exec 函数体 (with_lock 内部 fork+exec),
    # `local` 在该上下文无效 (会报 "can only be used in a function").
    # 这些变量只在函数内用, 不污染父 shell.
    backend=$(get_backend)

    if [ "$backend" != "redis" ]; then
      try_upgrade_redis && backend=$(get_backend)
    fi

    safe_expert_id=$(json_escape "$__emit_expert_id")
    safe_ticket_id=$(json_escape "$__emit_ticket_id")
    payload="{\"expert_id\":\"$safe_expert_id\",\"ticket_id\":\"$safe_ticket_id\",\"ts\":$__emit_ts,\"backend\":\"$backend\"}"

    if [ "$backend" = "redis" ]; then
      if probe_redis; then
        if redis-cli -x XADD "$REDIS_KEY" '*' payload "$payload" 2>/dev/null; then
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
      epic_jsonl_emit "$__emit_expert_id" "__emit_ticket_id" "$__emit_ts" "$backend"
    fi
}

drain() {
  local backend=$(get_backend)
  # EPIC-277 AC4: 不再包 sh -c (子 shell 看不到 get_backend 等父函数).
  # export -f 让 with_lock 内部子 shell 继承函数定义.
  # 注意 with_lock 把"_"当 $0, "$1" 是第一个真参数. 不用 "_" 占位:
  #   with_lock "drain" _drain_locked_body "$backend" "$REDIS_KEY" ...
  #   -> _drain_locked_body 内部 $1=$backend, $2=$REDIS_KEY, ...
  export -f _drain_locked_body
  with_lock "drain" _drain_locked_body "$backend" "$REDIS_KEY" "$SQLITE_DB" "$INVOCATION_FILE"
}

# EPIC-277 AC4: drain 锁内执行体, 父 shell 直接执行可访问 get_backend 等.
_drain_locked_body() {
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

  # EPIC-277 AC4: 同 emit() 修法 — 不用 sh -c.
  # 8 个参数顺序: state_file, expert_id, ticket_id, ts, backend, lru_max, output_len, truncated
  export -f _state_json_locked_body
  with_lock "state_json" _state_json_locked_body \
    "$state_file" "$expert_id" "$ticket_id" "$ts" "$backend" "$LRU_MAX" "0" "false"
}

_state_json_locked_body() {
  # 不用 local. 8 个参数从父 shell 传入.
  tmp="${1}.tmp.$$"
  output_len="${7:-0}"
  truncated="${8:-false}"
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
