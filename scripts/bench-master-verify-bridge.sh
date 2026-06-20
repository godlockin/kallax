#!/usr/bin/env bash
# scripts/bench-master-verify-bridge.sh — Simple verify_all benchmark
# EPIC-060-B 阶段 3 子任务 4: master-verify Rust napi-rs bridge benchmark
# 跟 eket "1 simple benchmark" 派遣 Checklist §3 联合
#
# Benchmark: run verify_all 100 times on master-verify source files,
# measure Rust vs Node.js fallback wall-clock time.
# 跟 Rule 8 (no copy-paste) 联合: 1 fixture set, 1 timer function, 0 duplicate.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ITERATIONS="${BENCH_ITERATIONS:-100}"
FIXTURE_DIR="$KALLAX_ROOT/node/src/core/master-verify"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

if [ ! -d "$FIXTURE_DIR" ]; then
    warn "fixture dir missing: $FIXTURE_DIR"
    exit 1
fi

cd "$KALLAX_ROOT"
echo "=========================================="
echo " KALLAX Master Verify Bridge Benchmark"
echo " Iterations: $ITERATIONS"
echo " Fixture:    $FIXTURE_DIR"
echo "=========================================="
echo ""

# ----------------------------------------
# 1. Rust path (cargo run --example smoke)
# ----------------------------------------
info "1. Rust verify_all benchmark ($ITERATIONS iterations)..."
RUST_TIMES_FILE="/tmp/bench-rust-times.txt"
> "$RUST_TIMES_FILE"

if [ -f "$KALLAX_ROOT/rust/crates/kallax-bridge/examples/smoke.rs" ]; then
    for i in $(seq 1 "$ITERATIONS"); do
        START=$(date +%s%N)
        (cd "$KALLAX_ROOT/rust" && cargo run --example smoke --quiet --offline -- "$FIXTURE_DIR/index.ts" 2>/dev/null) > /dev/null
        END=$(date +%s%N)
        echo $(( (END - START) / 1000000 )) >> "$RUST_TIMES_FILE"
    done
    RUST_AVG=$(awk '{ sum += $1; n++ } END { if (n > 0) printf "%.2f", sum/n; else print 0 }' "$RUST_TIMES_FILE")
    RUST_MIN=$(sort -n "$RUST_TIMES_FILE" | head -1)
    RUST_MAX=$(sort -n "$RUST_TIMES_FILE" | tail -1)
    ok "Rust: avg=${RUST_AVG}ms min=${RUST_MIN}ms max=${RUST_MAX}ms"
else
    warn "examples/smoke.rs missing — Rust path skipped"
fi
echo ""

# ----------------------------------------
# 2. Node.js fallback path
# ----------------------------------------
info "2. Node.js verify_all benchmark ($ITERATIONS iterations)..."
NODE_TIMES_FILE="/tmp/bench-node-times.txt"
> "$NODE_TIMES_FILE"

for i in $(seq 1 "$ITERATIONS"); do
    START=$(date +%s%N)
    (cd "$KALLAX_ROOT" && node --input-type=module -e "
import { verifyAllAsync, getLoadStatus } from './node/src/core/master-verify-bridge.ts';
const status = getLoadStatus();
const r = await verifyAllAsync('$FIXTURE_DIR/index.ts');
console.log(r.total_passed + '/' + r.total_dimensions + ' ' + r.source);
" 2>/dev/null) > /dev/null
    END=$(date +%s%N)
    echo $(( (END - START) / 1000000 )) >> "$NODE_TIMES_FILE"
done
NODE_AVG=$(awk '{ sum += $1; n++ } END { if (n > 0) printf "%.2f", sum/n; else print 0 }' "$NODE_TIMES_FILE")
NODE_MIN=$(sort -n "$NODE_TIMES_FILE" | head -1)
NODE_MAX=$(sort -n "$NODE_TIMES_FILE" | tail -1)
ok "Node.js: avg=${NODE_AVG}ms min=${NODE_MIN}ms max=${NODE_MAX}ms"
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
echo " Benchmark Summary"
echo "=========================================="
if [ -f "$RUST_TIMES_FILE" ] && [ -s "$RUST_TIMES_FILE" ]; then
    echo " Rust:   avg=${RUST_AVG}ms (min=${RUST_MIN}, max=${RUST_MAX})"
fi
echo " Node.js: avg=${NODE_AVG}ms (min=${NODE_MIN}, max=${NODE_MAX})"
echo ""
ok "verify_all benchmark complete ($ITERATIONS iterations × 2 paths)"
exit 0