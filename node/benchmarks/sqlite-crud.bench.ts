/**
 * SQLite CRUD performance benchmark
 */
import Database from 'better-sqlite3';
import { performance } from 'node:perf_hooks';

const DB_PATH = '.kallax/data/bench.db';
const SIZES = [100, 500, 1000] as const;

function createDb(): Database.Database {
  const { unlinkSync, existsSync, mkdirSync } = require('node:fs');
  if (existsSync(DB_PATH)) unlinkSync(DB_PATH);
  mkdirSync('.kallax/data/', { recursive: true });
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.exec(`CREATE TABLE IF NOT EXISTS bench (id TEXT PRIMARY KEY, data TEXT, n INTEGER, ts INTEGER)`);
  return db;
}

function measure(label: string, fn: () => void): number {
  const t0 = performance.now();
  fn();
  return +(performance.now() - t0).toFixed(2);
}

console.log('=== SQLite CRUD Benchmark ===\n');

for (const size of SIZES) {
  const db = createDb();
  const stmt = db.prepare('INSERT INTO bench VALUES (?, ?, ?, ?)');
  const ids: string[] = [];

  const insertMs = measure(`INSERT ${size}`, () => {
    const tx = db.transaction(() => {
      for (let i = 0; i < size; i++) {
        const id = `id_${i}`;
        ids.push(id);
        stmt.run(id, `data_${i}`, i, Date.now());
      }
    });
    tx();
  });

  const getMs = measure(`GET ${size}`, () => {
    for (const id of ids) db.prepare('SELECT * FROM bench WHERE id = ?').get(id);
  });

  const listMs = measure(`LIST ${size}`, () => {
    db.prepare('SELECT * FROM bench ORDER BY n DESC').all();
  });

  const updateMs = measure(`UPDATE ${size}`, () => {
    for (const id of ids) db.prepare('UPDATE bench SET ts = ? WHERE id = ?').run(Date.now(), id);
  });

  console.log(`Size ${String(size).padStart(4)}: INSERT=${String(insertMs).padStart(6)}ms  GET=${String(getMs).padStart(5)}ms  LIST=${String(listMs).padStart(5)}ms  UPDATE=${String(updateMs).padStart(5)}ms`);
  db.close();
}
