#!/usr/bin/env bash
# tests/integration/data-adapter-bridge-test.sh — TDD integration test for Node.js ↔ Rust data-adapter bridge
# EPIC-060-B Phase 3 sub-task 3: 3/3 PASS verification
#
# Verifies:
#   TC1: query — Node.js spawns Rust CLI, sends SELECT, parses typed rows
#   TC2: execute — Node.js spawns Rust CLI, sends INSERT, verifies rows changed
#   TC3: transaction — Node.js spawns Rust CLI, sends batch of execute+query,
#        verifies atomic commit + ordered results
#
# 跟 v2.4.1 Hard Rule #3 联合: never skip tests, real exec, no mocks
# 跟 v2.4.1 Hard Rule #5 联合: 0 console.log in module under test
# 跟 Rule 9 KPI X/Y 格式: 3/3 = 100.0%
# 跟 v2.7.4 派遣 Checklist §11 EPIC-059-D Fact-Forcing 联合: PASS 报告含 raw test output

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly TMP_DIR="$(mktemp -d -t data-adapter-bridge-XXXXXX)"
readonly DEBUG_BIN="$KALLAX_ROOT/rust/target/debug/kallax-data-adapter"
readonly RELEASE_BIN="$KALLAX_ROOT/rust/target/release/kallax-data-adapter"
readonly NODE_BRIDGE_PATH="$KALLAX_ROOT/node/src/core/data-adapter-bridge.ts"
readonly TC1_SCRIPT="$TMP_DIR/tc1-query.mjs"
readonly TC2_SCRIPT="$TMP_DIR/tc2-execute.mjs"
readonly TC3_SCRIPT="$TMP_DIR/tc3-transaction.mjs"

# Cleanup on exit — remove the test db + tmp scripts + any generated artifacts
cleanup() {
    rm -f "$TMP_DIR"/kallax-bridge-test.db "$TMP_DIR"/kallax-bridge-test.db-* \
          "$TC1_SCRIPT" "$TC2_SCRIPT" "$TC3_SCRIPT" \
          "$KALLAX_ROOT"/node/.data-adapter-bridge-tc*.mjs 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=3

# ── Setup: build the Rust bridge binary if missing ─────────────────────────
echo "=========================================="
echo " KALLAX Data Adapter Bridge — Integration"
echo " EPIC-060-B Phase 3 sub-task 3: 3/3 PASS"
echo "=========================================="

if [ ! -x "$DEBUG_BIN" ] && [ ! -x "$RELEASE_BIN" ]; then
    echo "[setup] bridge binary missing, building (cargo build --package kallax-bridge --bin kallax-data-adapter)"
    if ! (cd "$KALLAX_ROOT/rust" && cargo build --package kallax-bridge --bin kallax-data-adapter > "$TMP_DIR/build.log" 2>&1); then
        echo "FATAL: bridge build failed"
        tail -20 "$TMP_DIR/build.log"
        echo "0/$TOTAL PASS (0.0%)"
        exit 1
    fi
fi

if [ -x "$DEBUG_BIN" ]; then
    BRIDGE_BIN="$DEBUG_BIN"
elif [ -x "$RELEASE_BIN" ]; then
    BRIDGE_BIN="$RELEASE_BIN"
fi
echo "[setup] bridge binary: $BRIDGE_BIN"

TEST_DB="$TMP_DIR/kallax-bridge-test.db"
# Always start with a fresh DB so the test is deterministic
rm -f "$TEST_DB" "$TEST_DB-wal" "$TEST_DB-shm"

# ── TC1: query — Node.js sends a SELECT through the bridge and parses typed rows ──
run_tc1() {
    echo ""
    echo "─── TC1: bridge query (cross-process SELECT) ───"

    cat > "$TC1_SCRIPT" << EOF
import {createDataAdapterBridge} from '$NODE_BRIDGE_PATH';
const bin = process.env.BRIDGE_BIN;
const dbPath = process.env.DB_PATH;
const bridge = createDataAdapterBridge(dbPath);
if (!bridge) { console.error('bridge-not-found'); process.exit(2); }
if (bridge.bridgeBinaryPath !== bin) { console.error('bridge-binary-mismatch got=' + bridge.bridgeBinaryPath + ' want=' + bin); process.exit(3); }

// Seed two phases via execute so the SELECT has data to return.
await bridge.execute(
  'INSERT INTO phases (id,title,scope,status) VALUES (?1,?2,?3,?4)',
  [
    {type:'Text',value:'P-1'},
    {type:'Text',value:'Phase-1'},
    {type:'Text',value:'scope-1'},
    {type:'Text',value:'active'},
  ],
);
await bridge.execute(
  'INSERT INTO phases (id,title,scope,status) VALUES (?1,?2,?3,?4)',
  [
    {type:'Text',value:'P-2'},
    {type:'Text',value:'Phase-2'},
    {type:'Text',value:'scope-2'},
    {type:'Text',value:'done'},
  ],
);

const rows = await bridge.query('SELECT id,title,status FROM phases ORDER BY id', []);
const ping = await bridge.ping();
const stats = await bridge.poolStats();

bridge.close();

// Emit a single line the bash side can grep deterministically.
const ok =
  ping === true &&
  rows.length === 2 &&
  rows[0].columns.join(',') === 'id,title,status' &&
  rows[0].values[0].type === 'Text' && rows[0].values[0].value === 'P-1' &&
  rows[0].values[1].type === 'Text' && rows[0].values[1].value === 'Phase-1' &&
  rows[1].values[0].value === 'P-2' &&
  stats.max_size === 8 && stats.size >= 1 && stats.idle >= 1;

console.log(ok ? 'TC1_OK rows=' + rows.length + ' ping=' + ping + ' stats=' + JSON.stringify(stats) : 'TC1_FAIL');
process.exit(ok ? 0 : 1);
EOF

    local out_file="$TMP_DIR/tc1.out"
    if (cd "$KALLAX_ROOT/node" && BRIDGE_BIN="$BRIDGE_BIN" DB_PATH="$TEST_DB" npx tsx "$TC1_SCRIPT") > "$out_file" 2>&1; then
        if grep -q "^TC1_OK" "$out_file"; then
            local summary
            summary="$(grep '^TC1_OK' "$out_file")"
            echo "  [PASS] TC1: bridge query delivered typed rows + ping + pool stats"
            echo "    $summary"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] TC1: TC1_OK marker not found in output"
            cat "$out_file"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "  [FAIL] TC1: node script exited non-zero"
        cat "$out_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── TC2: execute — Node.js sends INSERT and verifies rows changed ──
run_tc2() {
    echo ""
    echo "─── TC2: bridge execute (cross-process INSERT) ───"

    cat > "$TC2_SCRIPT" << EOF
import {createDataAdapterBridge} from '$NODE_BRIDGE_PATH';
const dbPath = process.env.DB_PATH;
const bridge = createDataAdapterBridge(dbPath);
if (!bridge) { console.error('bridge-not-found'); process.exit(2); }

// Insert three epics and verify each returns changes=1.
const r1 = await bridge.execute(
  'INSERT INTO epics (id,phase_id,title,scope,status) VALUES (?1,?2,?3,?4,?5)',
  [
    {type:'Text',value:'E-1'},
    {type:'Text',value:'P-1'},
    {type:'Text',value:'epic-one'},
    {type:'Text',value:'s'},
    {type:'Text',value:'active'},
  ],
);
const r2 = await bridge.execute(
  'INSERT INTO epics (id,phase_id,title,scope,status) VALUES (?1,?2,?3,?4,?5)',
  [
    {type:'Text',value:'E-2'},
    {type:'Text',value:'P-1'},
    {type:'Text',value:'epic-two'},
    {type:'Text',value:'s'},
    {type:'Text',value:'active'},
  ],
);
const r3 = await bridge.execute(
  'INSERT INTO epics (id,phase_id,title,scope,status) VALUES (?1,?2,?3,?4,?5)',
  [
    {type:'Text',value:'E-3'},
    {type:'Text',value:'P-2'},
    {type:'Text',value:'epic-three'},
    {type:'Text',value:'s'},
    {type:'Text',value:'done'},
  ],
);

// UPDATE one and verify changes=1.
const r4 = await bridge.execute(
  'UPDATE epics SET status = ?1 WHERE id = ?2',
  [{type:'Text',value:'completed'},{type:'Text',value:'E-3'}],
);

// Verify the count via query.
const countRows = await bridge.query('SELECT COUNT(*) AS c FROM epics', []);
const count = countRows[0].values[0].value;

bridge.close();

const ok =
  r1 === 1 && r2 === 1 && r3 === 1 && r4 === 1 &&
  Number(count) === 3;

console.log(ok ? 'TC2_OK inserts=' + [r1,r2,r3,r4].join(',') + ' count=' + count : 'TC2_FAIL got=' + JSON.stringify([r1,r2,r3,r4,count]));
process.exit(ok ? 0 : 1);
EOF

    local out_file="$TMP_DIR/tc2.out"
    if (cd "$KALLAX_ROOT/node" && DB_PATH="$TEST_DB" npx tsx "$TC2_SCRIPT") > "$out_file" 2>&1; then
        if grep -q "^TC2_OK" "$out_file"; then
            local summary
            summary="$(grep '^TC2_OK' "$out_file")"
            echo "  [PASS] TC2: bridge execute INSERT/UPDATE returned correct row counts"
            echo "    $summary"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] TC2: TC2_OK marker not found in output"
            cat "$out_file"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "  [FAIL] TC2: node script exited non-zero"
        cat "$out_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── TC3: transaction — Node.js sends batch of execute+query atomically ──
run_tc3() {
    echo ""
    echo "─── TC3: bridge transaction (atomic batch) ───"

    cat > "$TC3_SCRIPT" << EOF
import {createDataAdapterBridge} from '$NODE_BRIDGE_PATH';
const dbPath = process.env.DB_PATH;
const bridge = createDataAdapterBridge(dbPath);
if (!bridge) { console.error('bridge-not-found'); process.exit(2); }

// Atomically insert two tickets and query back within one transaction.
const outcome = await bridge.transaction([
  {
    op: 'execute',
    sql: 'INSERT INTO project_tickets (id,epic_id,title,priority,status) VALUES (?1,?2,?3,?4,?5)',
    params: [
      {type:'Text',value:'T-1'},
      {type:'Text',value:'E-1'},
      {type:'Text',value:'first'},
      {type:'Text',value:'high'},
      {type:'Text',value:'ready'},
    ],
  },
  {
    op: 'execute',
    sql: 'INSERT INTO project_tickets (id,epic_id,title,priority,status) VALUES (?1,?2,?3,?4,?5)',
    params: [
      {type:'Text',value:'T-2'},
      {type:'Text',value:'E-2'},
      {type:'Text',value:'second'},
      {type:'Text',value:'normal'},
      {type:'Text',value:'ready'},
    ],
  },
  {
    op: 'query',
    sql: 'SELECT id,title FROM project_tickets ORDER BY id',
    params: [],
  },
]);

// Verify the outside-of-transaction query sees both rows (commit succeeded).
const external = await bridge.query('SELECT COUNT(*) AS c FROM project_tickets', []);
const externalCount = external[0].values[0].value;

bridge.close();

const ok =
  outcome.results.length === 3 &&
  outcome.results[0].kind === 'execute' && outcome.results[0].changes === 1 &&
  outcome.results[1].kind === 'execute' && outcome.results[1].changes === 1 &&
  outcome.results[2].kind === 'query' && outcome.results[2].rows.length === 2 &&
  outcome.results[2].rows[0].values[0].value === 'T-1' &&
  outcome.results[2].rows[1].values[0].value === 'T-2' &&
  Number(externalCount) === 2;

console.log(ok ? 'TC3_OK results=' + outcome.results.length + ' externalCount=' + externalCount : 'TC3_FAIL');
process.exit(ok ? 0 : 1);
EOF

    local out_file="$TMP_DIR/tc3.out"
    if (cd "$KALLAX_ROOT/node" && DB_PATH="$TEST_DB" npx tsx "$TC3_SCRIPT") > "$out_file" 2>&1; then
        if grep -q "^TC3_OK" "$out_file"; then
            local summary
            summary="$(grep '^TC3_OK' "$out_file")"
            echo "  [PASS] TC3: bridge transaction committed atomically + ordered results"
            echo "    $summary"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] TC3: TC3_OK marker not found in output"
            cat "$out_file"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "  [FAIL] TC3: node script exited non-zero"
        cat "$out_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_tc1
run_tc2
run_tc3

echo ""
echo "=========================================="
echo " RESULT: $PASS_COUNT/$TOTAL PASS"
if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo " STATUS: PASS (跟 EPIC-060-B Phase 3 sub-task 3 AC 联合, 跟 Rule 3 0 skip tests 联合)"
    echo "=========================================="
    exit 0
else
    echo " STATUS: FAIL — expected 3/3, got $PASS_COUNT/$TOTAL"
    echo "=========================================="
    exit 1
fi