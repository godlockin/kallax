#!/usr/bin/env bash
# KALLAX Quick Benchmark — run basic performance benchmarks and report results
# Usage: ./scripts/benchmark-quick.sh [--json]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON_OUT="${1:-}"

CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

cd "$PROJECT_ROOT"
echo "=== KALLAX Quick Benchmark ==="
echo ""

RESULTS="[]"

# ── 1. DAG scheduler throughput ──────────────────────────────
if [ -f "${PROJECT_ROOT}/rust/Cargo.toml" ]; then
  info "Benchmarking DAG scheduler (Rust)..."
  TIMING=$( (cd rust && cargo run --release --example dag-bench 2>/dev/null) || echo "N/A")
  echo "  ${TIMING}"
fi

# ── 2. Recommender matching speed ────────────────────────────
if [ -f "${PROJECT_ROOT}/node/package.json" ]; then
  info "Benchmarking recommender matcher (Node)..."

  START=$(date +%s%N)
  node -e "
    const { Recommender } = require('./node/src/core/recommender/matcher');
    const r = new Recommender();
    // Simulate 1000 tasks, 100 performers
    for (let i = 0; i < 1000; i++) {
      r.registerTask({ id: 'T-' + i, capabilities: ['rust', 'ts', 'go'].slice(i % 3) });
    }
    for (let i = 0; i < 100; i++) {
      r.matchByCapability('PERF-' + i, ['rust', 'ts']);
    }
  " 2>/dev/null || echo "  WARN: Recommender benchmark failed (may need build)"

  END=$(date +%s%N)
  DURATION_MS=$(( (END - START) / 1000000 ))
  echo "  Recommender (1000 tasks): ${DURATION_MS}ms"
fi

# ── 3. SQLite query speed ────────────────────────────────────
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"
if [ -f "$DB_PATH" ]; then
  info "Benchmarking SQLite queries..."
  START=$(date +%s%N)
  for _ in $(seq 1 100); do
    sqlite3 "$DB_PATH" "SELECT count(*) FROM tasks;" 2>/dev/null || true
  done >/dev/null
  END=$(date +%s%N)
  DURATION_MS=$(( (END - START) / 1000000 ))
  echo "  SQLite (100 queries): ${DURATION_MS}ms"
fi

# ── 4. Startup time ──────────────────────────────────────────
info "Benchmarking startup time..."
if [ -f "${PROJECT_ROOT}/node/dist/server.js" ]; then
  START=$(date +%s%N)
  timeout 5 node -e "
    const start = Date.now();
    require('./node/dist/server');
    console.log(Date.now() - start);
    process.exit(0);
  " 2>/dev/null || echo "  WARN: Server startup benchmark failed"
  END=$(date +%s%N)
  DURATION_MS=$(( (END - START) / 1000000 ))
  echo "  Server startup: ${DURATION_MS}ms"
fi

echo ""
info "Benchmarks complete."
