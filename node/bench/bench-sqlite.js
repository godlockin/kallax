/**
 * EPIC-060-B Phase 1 Benchmark Task 2: SQLite CRUD (Node.js)
 *
 * Mirrors `rust/crates/kallax-bench/benches/bench_sqlite.rs`.
 * Same schema, same iteration counts, same per-row work.
 */
import { mkdirSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { performance } from 'node:perf_hooks';
import Database from 'better-sqlite3';

const N_INSERTS_SMALL = 1000;
const N_INSERTS_MEDIUM = 2000;
const N_INSERTS_LARGE = 5000;

const SCHEMA_SQL = `CREATE TABLE IF NOT EXISTS bench (
  id TEXT PRIMARY KEY,
  data TEXT,
  n INTEGER,
  ts INTEGER
)`;
const INSERT_SQL = 'INSERT INTO bench VALUES (?, ?, ?, ?)';
const SELECT_ALL_SQL = 'SELECT id, data, n, ts FROM bench';

function freshDbPath() {
  const dir = mkdtempSync(join(tmpdir(), 'kallax-bench-'));
  return { dir, path: join(dir, 'bench.db') };
}

function benchInsert() {
  const results = [];
  for (const [size, nRows] of [
    ['small', N_INSERTS_SMALL],
    ['medium', N_INSERTS_MEDIUM],
    ['large', N_INSERTS_LARGE],
  ]) {
    const { dir, path } = freshDbPath();
    const t0 = performance.now();
    const db = new Database(path);
    db.exec(SCHEMA_SQL);
    const insert = db.prepare(INSERT_SQL);
    const tx = db.transaction((rows) => {
      for (let i = 0; i < rows; i++) {
        insert.run(`id_${i}`, `payload_data_${i}`, i, 1716080400 + i);
      }
    });
    tx(nRows);
    db.close();
    const elapsedMs = performance.now() - t0;
    rmSync(dir, { recursive: true, force: true });
    results.push({
      task: 'sqlite_insert',
      size,
      nRows,
      elapsedMs: +elapsedMs.toFixed(3),
      rowsPerSec: Math.round(nRows / (elapsedMs / 1000)),
    });
  }
  return results;
}

function benchSelectAll() {
  const results = [];
  for (const [size, nRows] of [
    ['small', N_INSERTS_SMALL],
    ['medium', N_INSERTS_MEDIUM],
    ['large', N_INSERTS_LARGE],
  ]) {
    const { dir, path } = freshDbPath();
    const db = new Database(path);
    db.exec(SCHEMA_SQL);
    const insert = db.prepare(INSERT_SQL);
    const selectAll = db.prepare(SELECT_ALL_SQL);
    const seedTx = db.transaction((rows) => {
      for (let i = 0; i < rows; i++) {
        insert.run(`id_${i}`, `payload_data_${i}`, i, 1716080400 + i);
      }
    });
    seedTx(nRows);
    const t0 = performance.now();
    const rows = selectAll.all();
    const elapsedMs = performance.now() - t0;
    db.close();
    rmSync(dir, { recursive: true, force: true });
    results.push({
      task: 'sqlite_select_all',
      size,
      nRows,
      selectedRows: rows.length,
      elapsedMs: +elapsedMs.toFixed(3),
      rowsPerSec: Math.round(rows.length / (elapsedMs / 1000)),
    });
  }
  return results;
}

console.log('=== SQLite CRUD Benchmark (Node.js) ===\n');
const allResults = [...benchInsert(), ...benchSelectAll()];
for (const r of allResults) {
  console.log(JSON.stringify(r));
}