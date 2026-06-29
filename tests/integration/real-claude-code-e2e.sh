#!/usr/bin/env bash
# tests/integration/real-claude-code-e2e.sh — v3.1.0 Track 4 武器 5 真实 Claude Code E2E 集成
#
# 验证 KALLAX Hook Server 真实接收 Claude Code 发来的 6 phase requests:
#   1. 启动 KALLAX hook server (background, 用 bun + tsx-equivalent)
#   2. 用 curl 模拟 Claude Code 发 6 phase requests (pre-tool-use, post-tool-use,
#      compact, permission, session-start, session-end)
#   3. 验证 6 endpoints 都返回 200 + 写 audit
#   4. 验证 hash-chain 通过 (sha256:genesis → sha256:xxx, 完整 chain)
#   5. 验证 /hooks/audit endpoint 返回 events
#   6. 验证 /hooks/replay endpoint 能 replay 历史到 target session
#
# Rule 9 KPI X/Y 格式: 4-6 raw stdout 验证 PASS (no estimate)
# Rule 8 4-Level Fact-Forcing: L1 启动 server + L2 写 audit + L3 audit query + L4 replay
# Rule 17 文件并发竞争 5 步: cleanup trap 保证 fixture 不残留
#
# Source: v3.1.0 Track 4 (主公 Issue 治根 "武器 5 真实 Claude Code 集成")
# 跟 node/src/hooks/http-hook-server.ts:80-356 + hook-events-store.ts:138-232 1:1 验证
# 跟 docs/guides/claude-code-integration.md 1:1 验证

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly FIXTURE_DIR="/tmp/kallax-real-e2e-$$"
readonly AUDIT_FILE="$FIXTURE_DIR/.kallax/audit/hook-events.jsonl"
readonly BOOT_SCRIPT="$FIXTURE_DIR/boot-server.mjs"
readonly API_KEY="test-api-key-e2e-$(date +%s)"

# ============================================================
# Test infrastructure
# ============================================================
TOTAL=0
PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); TOTAL=$((TOTAL + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); TOTAL=$((TOTAL + 1)); }
section() { echo ""; echo "============================================"; echo "$1"; echo "============================================"; }

# ============================================================
# Setup: fixture dir + audit file + boot script
# ============================================================
setup_fixture() {
  echo "[setup] creating fixture dir $FIXTURE_DIR ..."
  mkdir -p "$FIXTURE_DIR/.kallax/audit"

  # Write boot script — minimal bun-runnable module that imports the hook server
  cat > "$BOOT_SCRIPT" <<BOOT_EOF
import { ok } from 'neverthrow';
import { createHookEventsStore } from '${KALLAX_ROOT}/node/src/hooks/hook-events-store.ts';
import { createHookDispatcher }   from '${KALLAX_ROOT}/node/src/hooks/dispatcher.ts';
import { createHookServer }       from '${KALLAX_ROOT}/node/src/hooks/http-hook-server.ts';

const projectRoot = '${FIXTURE_DIR}';
const port = Number(process.env.PORT || 0);
const apiKey = process.env.KALLAX_API_KEY || '';
const store = createHookEventsStore({ projectRoot });
const dispatcher = createHookDispatcher(undefined, store);

// Register a no-op logging hook so phase endpoints have something to run.
// MUST return neverthrow ok(...) — http-hook-server.ts:262 calls result.isErr() / .value
dispatcher.register({
  name: 'e2e-noop',
  phases: ['pre-tool-use','post-tool-use','pre-compact','post-compact','pre-permission','post-permission','session-start','session-end'],
  priority: 100,
  async execute() { return ok({ allowed: true }); },
});

const server = createHookServer(dispatcher, { port, apiKey, auditStore: store });
const r = await server.start();
if (r.isErr()) { console.error('start failed:', r.error.message); process.exit(1); }
const actualPort = server.getPort();
console.log('PORT=' + actualPort);

process.on('SIGTERM', async () => { await server.stop(); process.exit(0); });
process.on('SIGINT',  async () => { await server.stop(); process.exit(0); });
BOOT_EOF

  echo "[setup] fixture ready"
}

# ============================================================
# Cleanup trap (Rule 17 文件并发竞争 5 步)
# ============================================================
cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[cleanup] killing server PID $SERVER_PID"
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [ -d "$FIXTURE_DIR" ]; then
    echo "[cleanup] removing fixture dir $FIXTURE_DIR"
    rm -rf "$FIXTURE_DIR"
  fi
}
trap cleanup EXIT

# ============================================================
# Start server in background, capture port
# ============================================================
start_server() {
  echo "[boot] starting KALLAX hook server (bun + tsx-equivalent) ..."

  if ! command -v bun >/dev/null 2>&1; then
    echo "  [FATAL] bun not found — install bun (https://bun.sh) to run this test"
    exit 2
  fi

  cd "$KALLAX_ROOT"

  # Start bun in background; capture stdout for PORT= line
  PORT=0 KALLAX_API_KEY="$API_KEY" bun "$BOOT_SCRIPT" > "$FIXTURE_DIR/server.log" 2>&1 &
  SERVER_PID=$!

  # Wait for PORT= line (max 30s)
  local timeout=30
  while [ "$timeout" -gt 0 ]; do
    if grep -q '^PORT=' "$FIXTURE_DIR/server.log" 2>/dev/null; then
      break
    fi
    sleep 1
    timeout=$((timeout - 1))
  done

  if ! grep -q '^PORT=' "$FIXTURE_DIR/server.log" 2>/dev/null; then
    echo "  [FATAL] server failed to start within 30s"
    cat "$FIXTURE_DIR/server.log"
    return 1
  fi

  # Parse port
  SERVER_PORT=$(grep '^PORT=' "$FIXTURE_DIR/server.log" | head -1 | cut -d= -f2)
  echo "[boot] server running on port $SERVER_PORT (PID $SERVER_PID)"

  # Sanity check: GET /hooks/audit
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "http://127.0.0.1:$SERVER_PORT/hooks/audit" 2>/dev/null)
  if [ "$code" != "200" ]; then
    echo "  [FATAL] sanity check failed: HTTP $code (expected 200)"
    return 1
  fi

  return 0
}

# ============================================================
# Phase 1: 6 phase endpoints — POST + 200 + audit entry
# ============================================================
test_phase_endpoints() {
  section "Phase 1: 6 phase endpoints (curl mock Claude Code)"

  local phases=("pre-tool-use" "post-tool-use" "compact" "permission" "session-start" "session-end")
  local session="e2e-session-$$"
  local ok=0
  local fail=0

  for phase in "${phases[@]}"; do
    local tool="Bash"
    [ "$phase" = "session-start" ] && tool="SessionStart"
    [ "$phase" = "session-end" ] && tool="SessionEnd"
    [ "$phase" = "compact" ] && tool="Compact"
    [ "$phase" = "permission" ] && tool="Permission"

    local code
    code=$(curl -sS -o "$FIXTURE_DIR/last-response.json" -w '%{http_code}' \
      -X POST \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"sessionId\":\"$session\",\"toolName\":\"$tool\",\"toolParams\":{\"command\":\"echo e2e\"},\"metadata\":{\"e2e\":true}}" \
      "http://127.0.0.1:$SERVER_PORT/hooks/$phase" 2>/dev/null)

    if [ "$code" = "200" ]; then
      log_pass "[E2E.P1.$phase] POST /hooks/$phase → 200"
      ok=$((ok + 1))
    else
      log_fail "[E2E.P1.$phase] POST /hooks/$phase → $code (expected 200)"
      cat "$FIXTURE_DIR/last-response.json" 2>/dev/null | head -3
      fail=$((fail + 1))
    fi
  done

  # Allow async audit writes to flush
  sleep 0.5

  # Verify audit file has 6 entries (one per phase)
  local count
  count=$(wc -l < "$AUDIT_FILE" 2>/dev/null | tr -d ' ')
  if [ "$count" = "6" ]; then
    log_pass "[E2E.P1.AUDIT] audit file has 6 entries (1 per phase)"
  else
    log_fail "[E2E.P1.AUDIT] audit file has $count entries (expected 6)"
  fi

  echo "  -- raw stdout: 6 phase endpoints --"
  for phase in "${phases[@]}"; do
    local last_entry
    last_entry=$(grep "\"hookType\":.*\"$phase\"\|\"$phase\"" "$AUDIT_FILE" 2>/dev/null | tail -1)
    if [ -n "$last_entry" ]; then
      echo "    $phase: $(echo "$last_entry" | jq -c '{seq, hookType, resultCode, toolName, hash}' 2>/dev/null || echo "$last_entry" | head -c 100)"
    fi
  done
}

# ============================================================
# Phase 2: hash-chain validation (sha256:genesis → ... → sha256:N)
# ============================================================
test_hash_chain() {
  section "Phase 2: hash-chain validation (sha256:genesis → sha256:N)"

  local chain_ok=true
  local prev_hash="sha256:genesis"
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [ -z "$line" ] && continue

    local seq entry_prev entry_hash
    seq=$(echo "$line" | jq -r '.seq' 2>/dev/null)
    entry_prev=$(echo "$line" | jq -r '.prevHash' 2>/dev/null)
    entry_hash=$(echo "$line" | jq -r '.hash' 2>/dev/null)

    if [ "$entry_prev" != "$prev_hash" ]; then
      log_fail "[E2E.P2.L$line_num] seq=$seq prevHash=$entry_prev (expected $prev_hash)"
      chain_ok=false
      break
    fi

    # Format check: sha256:64hex
    if ! echo "$entry_hash" | grep -qE '^sha256:[a-f0-9]{64}$'; then
      log_fail "[E2E.P2.L$line_num] seq=$seq hash=$entry_hash (invalid format)"
      chain_ok=false
      break
    fi

    prev_hash="$entry_hash"
  done < "$AUDIT_FILE"

  if [ "$chain_ok" = "true" ]; then
    log_pass "[E2E.P2.CHAIN] $line_num entries, sha256 chain valid (genesis → sha256:${prev_hash#sha256:})"
  fi

  echo "  -- raw stdout: chain head + tail --"
  echo "    head: $(head -1 "$AUDIT_FILE" | jq -c '{seq, prevHash, hash}' 2>/dev/null)"
  echo "    tail: $(tail -1 "$AUDIT_FILE" | jq -c '{seq, prevHash, hash}' 2>/dev/null)"
}

# ============================================================
# Phase 3: GET /hooks/audit endpoint (query)
# ============================================================
test_audit_endpoint() {
  section "Phase 3: GET /hooks/audit endpoint"

  local resp_file="$FIXTURE_DIR/audit-response.json"
  local code
  code=$(curl -sS -o "$resp_file" -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "http://127.0.0.1:$SERVER_PORT/hooks/audit" 2>/dev/null)

  if [ "$code" = "200" ]; then
    log_pass "[E2E.P3.GET] GET /hooks/audit → 200"
  else
    log_fail "[E2E.P3.GET] GET /hooks/audit → $code"
    return
  fi

  local total
  total=$(jq -r '.total' "$resp_file" 2>/dev/null)
  if [ "$total" = "6" ]; then
    log_pass "[E2E.P3.TOTAL] /hooks/audit returned total=6"
  else
    log_fail "[E2E.P3.TOTAL] /hooks/audit returned total=$total (expected 6)"
  fi

  # Verify path field
  local path
  path=$(jq -r '.path' "$resp_file" 2>/dev/null)
  if echo "$path" | grep -q "hook-events.jsonl"; then
    log_pass "[E2E.P3.PATH] /hooks/audit path=$path"
  else
    log_fail "[E2E.P3.PATH] /hooks/audit path=$path (unexpected)"
  fi

  echo "  -- raw stdout: /hooks/audit response (first 2 events) --"
  jq -c '.events[:2]' "$resp_file" 2>/dev/null
}

# ============================================================
# Phase 4: POST /hooks/replay endpoint
# ============================================================
test_replay_endpoint() {
  section "Phase 4: POST /hooks/replay endpoint"

  # Source: e2e-session-$$  (the 6 events from Phase 1)
  local source_session="e2e-session-$$"
  local target_session="replay-target-$$"

  local resp_file="$FIXTURE_DIR/replay-response.json"
  local code
  code=$(curl -sS -o "$resp_file" -w '%{http_code}' \
    -X POST \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"sessionId\":\"$source_session\",\"targetSessionId\":\"$target_session\"}" \
    "http://127.0.0.1:$SERVER_PORT/hooks/replay" 2>/dev/null)

  if [ "$code" = "200" ]; then
    log_pass "[E2E.P4.POST] POST /hooks/replay → 200"
  else
    log_fail "[E2E.P4.POST] POST /hooks/replay → $code"
    cat "$resp_file" | head -3
    return
  fi

  local total_events replayed
  total_events=$(jq -r '.totalEvents' "$resp_file" 2>/dev/null)
  replayed=$(jq -r '.replayed' "$resp_file" 2>/dev/null)

  if [ "$total_events" = "6" ] && [ "$replayed" = "6" ]; then
    log_pass "[E2E.P4.COUNT] replayed $replayed/$total_events (6 source events → 6 replayed)"
  else
    log_fail "[E2E.P4.COUNT] replayed=$replayed totalEvents=$total_events (expected 6/6)"
  fi

  # Verify replay wrote new entries to target session
  sleep 0.5
  local target_count
  target_count=$(grep -c "\"sessionId\":\"$target_session\"" "$AUDIT_FILE" 2>/dev/null | tr -d ' ')

  if [ "$target_count" -ge "6" ]; then
    log_pass "[E2E.P4.AUDIT] replay wrote $target_count entries for target session"
  else
    log_fail "[E2E.P4.AUDIT] replay wrote $target_count entries (expected ≥ 6)"
  fi

  echo "  -- raw stdout: /hooks/replay response --"
  jq -c '{targetSessionId, sourceSessionId, totalEvents, replayed, resultsSummary: (.results | map({originalSeq, hookType, allowed}))}' "$resp_file" 2>/dev/null

  # Verify each result.allowed = true (no policy violations)
  local all_allowed
  all_allowed=$(jq -r '[.results[].allowed] | all' "$resp_file" 2>/dev/null)
  if [ "$all_allowed" = "true" ]; then
    log_pass "[E2E.P4.ALLOWED] all 6 replayed events allowed"
  else
    log_fail "[E2E.P4.ALLOWED] some replayed events blocked (allowed=$all_allowed)"
  fi
}

# ============================================================
# Phase 5: Error cases (auth + method + unknown endpoint)
# ============================================================
test_error_cases() {
  section "Phase 5: error cases (auth, method, unknown endpoint)"

  # 401: missing auth header
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST -H "Content-Type: application/json" -d '{}' \
    "http://127.0.0.1:$SERVER_PORT/hooks/pre-tool-use" 2>/dev/null)
  if [ "$code" = "401" ]; then
    log_pass "[E2E.P5.AUTH1] missing Bearer → 401"
  else
    log_fail "[E2E.P5.AUTH1] missing Bearer → $code (expected 401)"
  fi

  # 401: wrong api key
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST -H "Authorization: Bearer wrong-key" -H "Content-Type: application/json" -d '{}' \
    "http://127.0.0.1:$SERVER_PORT/hooks/pre-tool-use" 2>/dev/null)
  if [ "$code" = "401" ]; then
    log_pass "[E2E.P5.AUTH2] wrong Bearer → 401"
  else
    log_fail "[E2E.P5.AUTH2] wrong Bearer → $code (expected 401)"
  fi

  # 405: GET on phase endpoint (with valid auth; without auth server returns 401 first)
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "http://127.0.0.1:$SERVER_PORT/hooks/pre-tool-use" 2>/dev/null)
  if [ "$code" = "405" ]; then
    log_pass "[E2E.P5.METHOD] GET /hooks/pre-tool-use (with auth) → 405"
  else
    log_fail "[E2E.P5.METHOD] GET /hooks/pre-tool-use (with auth) → $code (expected 405)"
  fi

  # 404: unknown endpoint
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d '{}' \
    "http://127.0.0.1:$SERVER_PORT/hooks/unknown" 2>/dev/null)
  if [ "$code" = "404" ]; then
    log_pass "[E2E.P5.UNKNOWN] POST /hooks/unknown → 404"
  else
    log_fail "[E2E.P5.UNKNOWN] POST /hooks/unknown → $code (expected 404)"
  fi

  # 400: replay without targetSessionId
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d '{}' \
    "http://127.0.0.1:$SERVER_PORT/hooks/replay" 2>/dev/null)
  if [ "$code" = "400" ]; then
    log_pass "[E2E.P5.REPLAY] replay without targetSessionId → 400"
  else
    log_fail "[E2E.P5.REPLAY] replay without targetSessionId → $code (expected 400)"
  fi
}

# ============================================================
# Main
# ============================================================
main() {
  setup_fixture

  if ! start_server; then
    echo ""
    echo "============================================"
    echo "RESULT: SERVER FAILED TO START"
    echo "============================================"
    exit 1
  fi

  test_phase_endpoints
  test_hash_chain
  test_audit_endpoint
  test_replay_endpoint
  test_error_cases

  section "RESULT"
  echo "  PASS: $PASS_COUNT"
  echo "  FAIL: $FAIL_COUNT"
  echo "  TOTAL: $TOTAL"
  echo ""

  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  STATUS: FAIL"
    exit 1
  fi
  echo "  STATUS: ALL PASS"
  exit 0
}

main "$@"