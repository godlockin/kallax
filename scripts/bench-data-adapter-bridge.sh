#!/usr/bin/env bash
# scripts/bench-data-adapter-bridge.sh — EPIC-060-B Phase 3 simple benchmark
#
# Compares the Rust bridge (L1) vs better-sqlite3 (L2) for a 1000-row insert
# workload. Output is a deterministic single-line report.
#
# Usage: bash scripts/bench-data-adapter-bridge.sh [N_ROWS]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
N_ROWS="${1:-1000}"
DEBUG_BIN="$REPO_ROOT/rust/target/debug/kallax-data-adapter"
RELEASE_BIN="$REPO_ROOT/rust/target/release/kallax-data-adapter"
TMP_DIR="$(mktemp -d -t bench-bridge-XXXXXX)"

if [ -x "$RELEASE_BIN" ]; then
    BRIDGE_BIN="$RELEASE_BIN"
elif [ -x "$DEBUG_BIN" ]; then
    BRIDGE_BIN="$DEBUG_BIN"
else
    echo "BENCH_FAIL: bridge binary not built"
    exit 1
fi

# Build the benchmark Node script under node/ so module resolution finds
# better-sqlite3 / tsx. Cleanup removes it.
BENCH_SCRIPT="$REPO_ROOT/node/.bench-bridge-tmp.mjs"
cat > "$BENCH_SCRIPT" << EOF
import {createDataAdapterBridge} from '$REPO_ROOT/node/src/core/data-adapter-bridge.ts';
import Database from 'better-sqlite3';
import {performance} from 'node:perf_hooks';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

const N = Number(process.env.N_ROWS);
const dir = mkdtempSync(join(tmpdir(), 'kallax-bench-'));
const bridgeDbPath = join(dir, 'bridge.db');
const nodeDbPath = join(dir, 'node.db');
const SCHEMA = 'CREATE TABLE IF NOT EXISTS bench (id TEXT PRIMARY KEY, data TEXT, n INTEGER, ts INTEGER)';
const INSERT_SQL = 'INSERT INTO bench VALUES (?, ?, ?, ?)';
const SELECT_ALL_SQL = 'SELECT id, data, n, ts FROM bench';

// ── L1: Rust bridge ──
const bridge = createDataAdapterBridge(bridgeDbPath);
if (!bridge) { console.error('BENCH_FAIL bridge-not-found'); process.exit(2); }
const t0 = performance.now();
await bridge.execute(SCHEMA, []);
for (let i = 0; i < N; i++) {
  await bridge.execute(INSERT_SQL, [
    {type:'Text',value:'id_'+i},
    {type:'Text',value:'payload_'+i},
    {type:'Integer',value:i},
    {type:'Integer',value:1716080400 + i},
  ]);
}
const t1 = performance.now();
const bridgeRows = await bridge.query(SELECT_ALL_SQL, []);
const t2 = performance.now();
bridge.close();

// ── L2: better-sqlite3 (separate db to avoid UNIQUE collisions) ──
const db = new Database(nodeDbPath);
db.exec(SCHEMA);
const stmt = db.prepare(INSERT_SQL);
const t3 = performance.now();
for (let i = 0; i < N; i++) {
  stmt.run('id_'+i, 'payload_'+i, i, 1716080400 + i);
}
const t4 = performance.now();
const selStmt = db.prepare(SELECT_ALL_SQL);
const nodeRows = selStmt.all();
const t5 = performance.now();
db.close();

rmSync(dir, {recursive:true, force:true});

const bridgeInsertMs = +(t1 - t0).toFixed(3);
const bridgeSelectMs = +(t2 - t1).toFixed(3);
const nodeInsertMs = +(t4 - t3).toFixed(3);
const nodeSelectMs = +(t5 - t4).toFixed(3);
const totalRows = bridgeRows.length === nodeRows.length ? bridgeRows.length : -1;

const ratioInsert = +(nodeInsertMs / bridgeInsertMs).toFixed(2);
const ratioSelect = +(nodeSelectMs / bridgeSelectMs).toFixed(2);

console.log('BENCH_RESULT n=' + N +
  ' bridge_insert_ms=' + bridgeInsertMs +
  ' bridge_select_ms=' + bridgeSelectMs +
  ' node_insert_ms=' + nodeInsertMs +
  ' node_select_ms=' + nodeSelectMs +
  ' ratio_insert=' + ratioInsert + 'x' +
  ' ratio_select=' + ratioSelect + 'x' +
  ' rows_match=' + totalRows);
EOF

(cd "$REPO_ROOT/node" && N_ROWS="$N_ROWS" npx tsx "$BENCH_SCRIPT")
rm -f "$BENCH_SCRIPT"