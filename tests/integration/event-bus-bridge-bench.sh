#!/usr/bin/env bash
# tests/integration/event-bus-bridge-bench.sh — Rust vs Node.js publish/subscribe perf
# EPIC-060-B Phase 3 Sub-Task 2: simple benchmark 1 publish/subscribe comparison
# 跟 EPIC-060-B 阶段 1 benchmark 联合 (3 任务 json/sqlite/hash, 4.19× max)
# AC: 1 simple publish/subscribe benchmark (Rust vs Node.js in-process)
set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly RUST_BIN="$KALLAX_ROOT/rust/target/debug/event_bus_bridge_cli"
readonly BRIDGE_MODULE="$KALLAX_ROOT/node/src/core/event-bus-bridge.ts"

readonly BENCH_ITERATIONS="${BENCH_ITERATIONS:-2000}"
readonly NODE_DIR="$KALLAX_ROOT/node"

echo "=========================================="
echo " Event Bus Bridge — 1 simple benchmark"
echo " Iterations: $BENCH_ITERATIONS (publish + recv each)"
echo " Rust: rust binary bridge"
echo " Node.js: in-process L2 fallback"
echo "=========================================="

# ── Rust benchmark: feed N publish+recv pairs through the REPL CLI ──────
bench_rust() {
    local channel="$1"
    local n="$2"
    local bench_file="$NODE_DIR/.bench-rust-$RANDOM.mjs"

    # Build a single multi-line stdin script: N publish + N recv interleaved
    local script_file="$NODE_DIR/.bench-rust-input-$RANDOM.txt"
    : > "$script_file"
    local i
    for ((i = 1; i <= n; i++)); do
        printf '%s\n' "{\"op\":\"recv\",\"channel\":\"$channel\"}" >> "$script_file"
        printf '%s\n' "{\"op\":\"publish\",\"channel\":\"$channel\",\"eventId\":\"e$i\",\"eventType\":\"Bench\",\"payload\":{\"i\":$i},\"priority\":1}" >> "$script_file"
    done
    # 1 warmup recv to register subscriber

    local start_ns end_ns elapsed_ms
    start_ns=$(date +%s%N)
    "$RUST_BIN" < "$script_file" > /dev/null
    end_ns=$(date +%s%N)
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

    rm -f "$script_file" "$bench_file"
    echo "$elapsed_ms"
}

# ── Node.js benchmark: in-process bridge with same N publish/recv ────────
bench_node() {
    local channel="$1"
    local n="$2"
    local bench_file="$NODE_DIR/.bench-node-$RANDOM.mjs"

    cat > "$bench_file" << EOF
import { createEventBusBridge } from '$BRIDGE_MODULE';

const N = Number(process.env.N);
const ch = process.env.CH;

const bridge = createEventBusBridge({ mode: 'in-process' });
await bridge.subscribe(ch, () => {});

const start = Date.now();
for (let i = 0; i < N; i++) {
  await bridge.publish(ch, { eventType: 'Bench', payload: { i }, priority: 1 });
}
const elapsed = Date.now() - start;
console.log('ELAPSED_MS=' + elapsed);
await bridge.close();
EOF

    local elapsed_ms
    if (cd "$NODE_DIR" && N="$n" CH="$channel" npx tsx "$bench_file") 2>/dev/null | grep -oE '[0-9]+'; then
        :
    fi
    rm -f "$bench_file"
}

# ── Run benchmark ────────────────────────────────────────────────────────

CHANNEL="bench-channel-$$-$RANDOM"

echo ""
echo "[Rust binary bridge]"
RUST_MS=$(bench_rust "$CHANNEL" "$BENCH_ITERATIONS")
echo "  elapsed: ${RUST_MS}ms ($BENCH_ITERATIONS publish+recv roundtrips)"

echo ""
echo "[Node.js in-process bridge]"
NODE_OUTPUT=$(bench_node "$CHANNEL" "$BENCH_ITERATIONS" 2>&1)
NODE_MS=$(echo "$NODE_OUTPUT" | grep -oE '[0-9]+' | tail -1)
echo "  elapsed: ${NODE_MS}ms ($BENCH_ITERATIONS publish roundtrips)"

# Note: the two benchmarks are NOT 1:1 comparable — Rust does publish+recv per
# iter (spawn + IPC), Node.js does publish-only in-process. The point is to
# record a baseline number for the Rust bridge per iteration under spawn.
echo ""
echo "=========================================="
echo " RESULT: rust=${RUST_MS}ms, node=${NODE_MS}ms"
echo " (rust: per-iter spawn+IPC; node: in-process only)"
echo "=========================================="

# Save results to confluence for the EPIC-060-B phase 3 report
echo "rust_ms=$RUST_MS,node_ms=$NODE_MS,iterations=$BENCH_ITERATIONS" > "$NODE_DIR/.bench-result.txt"
echo "Benchmark complete. Results saved to .bench-result.txt"
exit 0