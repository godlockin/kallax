#!/usr/bin/env bash
# tests/integration/redis-pubsub-test.sh — TDD integration test for ioredis Pub/Sub
# EPIC-060-C: ioredis Pub/Sub 启用
# AC: 2/2 PASS (TC1 publish 验证 + TC2 subscribe 验证)
#
# Verifies:
#   TC1: ioredis publish to a channel reaches a separate ioredis subscriber
#        (raw protocol verification, no module in the path)
#   TC2: RedisPubSubBus (node/src/core/redis-pubsub.ts) — end-to-end cross-process
#        publish/subscribe using the production module
#
# 跟 v2.4.1 Hard Rule #3 联合: never skip tests, real exec, no mocks
# 跟 v2.4.1 Hard Rule #5 联合: 0 console.log in module under test
# Rule 9 KPI X/Y: 2/2 = 100.0%

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly TMP_DIR="$(mktemp -d -t redis-pubsub-XXXXXX)"
readonly REDIS_PORT="${REDIS_PUBSUB_TEST_PORT:-6390}"
readonly REDIS_PID_FILE="$TMP_DIR/redis.pid"
readonly REDIS_LOG_FILE="$TMP_DIR/redis.log"
readonly MODULE_PATH="$KALLAX_ROOT/node/src/core/redis-pubsub.ts"

# Cleanup on exit
cleanup() {
    if [ -f "$REDIS_PID_FILE" ]; then
        local pid
        pid="$(cat "$REDIS_PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 0.2
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
    rm -rf "$TMP_DIR"
    # Clean up any test-generated .mjs files in node/
    rm -f "$KALLAX_ROOT"/node/.redis-pubsub-tc1-*.mjs \
          "$KALLAX_ROOT"/node/.redis-pubsub-tc2-sub-*.mjs \
          "$KALLAX_ROOT"/node/.redis-pubsub-tc2-pub-*.mjs 2>/dev/null || true
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=2

# ── TC1: raw ioredis publish + subscribe ───────────────────────────────────
# Verifies the ioredis library itself delivers a message between two clients
# on the same Redis server. This is the "ioredis enabled" smoke test.
run_tc1() {
    echo ""
    echo "─── TC1: ioredis raw publish/subscribe ───"

    local out_file="$TMP_DIR/tc1.out"
    local test_channel="kallax-tc1-$RANDOM-$RANDOM"
    local test_payload="tc1-payload-$(date +%s%N)"

    # Write a plain-JS script (no TS syntax) that uses ioredis directly.
    # Put it inside node/ so Node's module resolution can find ioredis in
    # node_modules. Cleanup removes the file.
    local script_file="$KALLAX_ROOT/node/.redis-pubsub-tc1-$RANDOM.mjs"
    cat > "$script_file" << EOF
import {Redis} from 'ioredis';
const ch = '$test_channel';
const expected = '$test_payload';
const port = Number(process.env.PORT);
const sub = new Redis({port, maxRetriesPerRequest: 1});
const pub = new Redis({port, maxRetriesPerRequest: 1});
let done = false;
const timer = setTimeout(() => {
  console.error('TIMEOUT waiting for message');
  sub.quit().catch(() => {}); pub.quit().catch(() => {});
  process.exit(2);
}, 3000);
sub.subscribe(ch, (err) => {
  if (err) { console.error('sub err:', err.message); process.exit(1); }
  pub.publish(ch, expected).then((n) => {
    console.log('PUBLISH_OK subscribers=' + n);
  });
});
sub.on('message', (channel, message) => {
  if (channel === ch && message === expected) {
    done = true;
    clearTimeout(timer);
    console.log('RECEIVE_OK channel=' + channel + ' message=' + message);
    sub.quit().finally(() => pub.quit().finally(() => process.exit(0)));
  }
});
sub.on('error', (e) => { console.error('sub error:', e.message); process.exit(1); });
pub.on('error', (e) => { console.error('pub error:', e.message); process.exit(1); });
EOF

    if (cd "$KALLAX_ROOT/node" && PORT="$REDIS_PORT" npx tsx "$script_file") > "$out_file" 2>&1; then
        if grep -q "RECEIVE_OK" "$out_file" && grep -q "PUBLISH_OK" "$out_file"; then
            echo "  [PASS] TC1: ioredis publish delivered to subscriber"
            echo "    channel=$test_channel"
            echo "    stdout: $(tr '\n' ' ' < "$out_file" | head -c 200)"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] TC1: missing RECEIVE_OK or PUBLISH_OK in output"
            cat "$out_file"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "  [FAIL] TC1: node script exited non-zero"
        cat "$out_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    rm -f "$script_file"
}

# ── TC2: RedisPubSubBus module end-to-end ──────────────────────────────────
# Verifies the production module (node/src/core/redis-pubsub.ts) — a subscriber
# running in a separate process receives data published by another process.
# This is the "ioredis Pub/Sub 启用" core AC.
run_tc2() {
    echo ""
    echo "─── TC2: RedisPubSubBus module cross-process ───"

    local sub_out="$TMP_DIR/tc2-sub.out"
    local pub_out="$TMP_DIR/tc2-pub.out"
    local test_channel="kallax-tc2-$RANDOM-$RANDOM"
    # Build a JSON object payload (跟 ioredis 跨进程 通信 联合, payload 是 JSON)
    local test_payload
    test_payload="$(printf '{"src":"tc2-publisher","ts":%s,"channel":"%s"}' "$(date +%s%N)" "$test_channel")"

    # Subscriber script: signals READY, then waits up to 5s for matching payload.
    # Put it inside node/ so ioredis resolves from node_modules.
    local sub_script="$KALLAX_ROOT/node/.redis-pubsub-tc2-sub-$RANDOM.mjs"
    cat > "$sub_script" << EOF
import {createRedisPubSubBus} from '$MODULE_PATH';
import fs from 'node:fs';
const bus = createRedisPubSubBus({host: '127.0.0.1', port: Number(process.env.PORT)});
const ch = process.env.CH;
const expected = process.env.PAYLOAD;
const out = process.env.OUT;
let got = null;
const timer = setTimeout(() => {
  fs.writeFileSync(out, 'TIMEOUT got=' + got);
  bus.close().finally(() => process.exit(2));
}, 5000);
await bus.subscribe(ch, (data) => {
  got = JSON.stringify(data);
  if (got === expected) {
    clearTimeout(timer);
    fs.writeFileSync(out, 'OK got=' + got);
    bus.close().finally(() => process.exit(0));
  } else {
    fs.writeFileSync(out, 'MISMATCH got=' + got + ' expected=' + expected);
  }
});
fs.writeFileSync(out, 'READY');
EOF

    # Publisher script: publishes a single message and exits.
    local pub_script="$KALLAX_ROOT/node/.redis-pubsub-tc2-pub-$RANDOM.mjs"
    cat > "$pub_script" << EOF
import {createRedisPubSubBus} from '$MODULE_PATH';
const bus = createRedisPubSubBus({host: '127.0.0.1', port: Number(process.env.PORT)});
await bus.publish(process.env.CH, JSON.parse(process.env.PAYLOAD));
await bus.close();
EOF

    # Start subscriber in background
    (
        cd "$KALLAX_ROOT/node"
        PORT="$REDIS_PORT" CH="$test_channel" PAYLOAD="$test_payload" OUT="$sub_out" \
            npx tsx "$sub_script" > "$TMP_DIR/tc2-sub.stderr" 2>&1 &
        echo $! > "$TMP_DIR/tc2-sub.pid"
    )

    # Wait for subscriber READY marker (max 5s)
    local wait_count=0
    while ! grep -q "^READY" "$sub_out" 2>/dev/null && [ "$wait_count" -lt 50 ]; do
        sleep 0.1
        wait_count=$((wait_count + 1))
    done
    if ! grep -q "^READY" "$sub_out" 2>/dev/null; then
        echo "  [FAIL] TC2: subscriber did not become READY within 5s"
        cat "$sub_out" 2>/dev/null || true
        cat "$TMP_DIR/tc2-sub.stderr" 2>/dev/null | head -10
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi
    sleep 0.3  # extra settle time for SUBSCRIBE to round-trip to redis

    # Run publisher (foreground)
    if ! (
        cd "$KALLAX_ROOT/node"
        PORT="$REDIS_PORT" CH="$test_channel" PAYLOAD="$test_payload" \
            npx tsx "$pub_script" > "$pub_out" 2>&1
    ); then
        echo "  [FAIL] TC2: publisher exited non-zero"
        cat "$pub_out"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    # Wait for subscriber to write OK marker (max 5s)
    wait_count=0
    while ! grep -q "^OK got=" "$sub_out" 2>/dev/null && [ "$wait_count" -lt 50 ]; do
        sleep 0.1
        wait_count=$((wait_count + 1))
    done

    # Wait for subscriber process to exit
    local sub_pid
    sub_pid="$(cat "$TMP_DIR/tc2-sub.pid" 2>/dev/null || true)"
    if [ -n "$sub_pid" ]; then
        wait "$sub_pid" 2>/dev/null || true
    fi
    rm -f "$sub_script" "$pub_script"

    if grep -q "^OK got=$test_payload$" "$sub_out"; then
        echo "  [PASS] TC2: RedisPubSubBus cross-process publish/subscribe OK"
        echo "    channel: $test_channel"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  [FAIL] TC2: subscriber did not receive expected payload"
        echo "    subscriber output:"
        cat "$sub_out" 2>/dev/null
        echo "    publisher output:"
        cat "$pub_out" 2>/dev/null
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    rm -f "$sub_script" "$pub_script"
}

# ── Setup: start a dedicated redis-server for the test ─────────────────────
echo "=========================================="
echo " KALLAX Redis Pub/Sub — Integration Test"
echo " EPIC-060-C: 2/2 PASS target"
echo "=========================================="

if ! command -v redis-server >/dev/null 2>&1; then
    echo "FATAL: redis-server not in PATH (跟 Rule 3 real tests 联合, 0 skip)"
    echo "0/2 PASS (0.0%)"
    exit 1
fi

# Kill any stale redis on our test port
if lsof -ti :"$REDIS_PORT" >/dev/null 2>&1; then
    lsof -ti :"$REDIS_PORT" | xargs -r kill -9 2>/dev/null || true
    sleep 0.3
fi

redis-server --daemonize yes \
    --port "$REDIS_PORT" \
    --pidfile "$REDIS_PID_FILE" \
    --logfile "$REDIS_LOG_FILE" \
    --save "" \
    --appendonly no >/dev/null

# Wait for redis ready (max 3s)
ready_count=0
while ! redis-cli -p "$REDIS_PORT" ping >/dev/null 2>&1; do
    if [ "$ready_count" -ge 30 ]; then
        echo "FATAL: redis-server on port $REDIS_PORT did not become ready"
        cat "$REDIS_LOG_FILE" 2>/dev/null || true
        echo "0/2 PASS (0.0%)"
        exit 1
    fi
    sleep 0.1
    ready_count=$((ready_count + 1))
done

run_tc1
run_tc2

echo ""
echo "=========================================="
echo " RESULT: $PASS_COUNT/$TOTAL PASS"
if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo " STATUS: PASS (跟 EPIC-060-C AC 联合, 跟 Rule 3 0 skip tests 联合)"
    echo "=========================================="
    exit 0
else
    echo " STATUS: FAIL"
    echo "=========================================="
    exit 1
fi
