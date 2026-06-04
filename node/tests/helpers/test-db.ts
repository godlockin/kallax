/**
 * Test helpers for multi-session simulation.
 * Fake/test DB setup for isolated testing.
 */
import Database from 'better-sqlite3';
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../../src/types/index.js';
import { KallaxError, KallaxErrorCode } from '../../src/types/index.js';

export interface TestDB {
  readonly path: string;
  readonly db: Database.Database;
  cleanup: () => void;
}

/** Create a temp SQLite DB for isolated testing. Returns cleanup function. */
export function createTestDB(): TestDB {
  const { mkdtempSync, rmSync, existsSync, mkdirSync } = require('node:fs');
  const { join } = require('node:path');
  const { tmpdir } = require('node:os');
  const dir = mkdtempSync(join(tmpdir(), 'kallax-test-'));
  const path = join(dir, 'test.db');
  mkdirSync(dir, { recursive: true });
  const db = new Database(path);
  db.pragma('journal_mode = WAL');
  db.pragma('synchronous = NORMAL');
  db.exec(`
    CREATE TABLE IF NOT EXISTS tickets (id TEXT PRIMARY KEY, title TEXT, status TEXT, priority TEXT,
      assignee_id TEXT, created_at INTEGER, updated_at INTEGER, description TEXT DEFAULT '',
      acceptance_criteria TEXT DEFAULT '[]', labels TEXT DEFAULT '[]', file_scope TEXT, worktree_path TEXT);
    CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, ticket_id TEXT, type TEXT, status TEXT,
      performer_id TEXT, created_at INTEGER, updated_at INTEGER, progress INTEGER DEFAULT 0,
      output TEXT, error TEXT);
    CREATE TABLE IF NOT EXISTS instances (id TEXT PRIMARY KEY, role TEXT, status TEXT, hostname TEXT,
      pid INTEGER, started_at INTEGER, last_heartbeat INTEGER, current_task_id TEXT,
      capabilities TEXT DEFAULT '[]');
    CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
    CREATE INDEX IF NOT EXISTS idx_instances_role ON instances(role);
  `);
  return {
    path,
    db,
    cleanup: () => { db.close(); try { rmSync(dir, { recursive: true }); } catch {} },
  };
}
