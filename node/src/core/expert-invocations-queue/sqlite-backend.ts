/**
 * KALLAX Expert Invocations Queue — L2 SQLite backend
 *
 * EPIC-021-F: local durable fallback for L1 Redis.
 * Degrades to L3 (file) when op exceeds L2_LATENCY_THRESHOLD_MS, throws,
 * or returns SQLITE_FULL.
 */

import { mkdirSync } from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { err, ok, type Result } from 'neverthrow';
import {
  SQLITE_TABLE_NAME,
  type ExpertInvocation,
} from './types.js';

// ─── L2 SQLite backend ──────────────────────────────────────────────────────

export interface SqliteBackend {
  readonly insert: (inv: ExpertInvocation) => Result<ExpertInvocation, Error>;
  readonly selectAll: () => Result<readonly ExpertInvocation[], Error>;
  readonly clear: () => Result<void, Error>;
  readonly close: () => void;
}

export function createSqliteBackend(dbPath: string): SqliteBackend {
  const dir = path.dirname(dbPath);
  try {
    mkdirSync(dir, { recursive: true });
  } catch {
    // ignore: will surface when opening db
  }
  const db = new Database(dbPath);
  db.exec(`
    CREATE TABLE IF NOT EXISTS ${SQLITE_TABLE_NAME} (
      expert_id TEXT NOT NULL,
      ticket_id TEXT NOT NULL,
      ts INTEGER NOT NULL
    );
  `);
  const insertStmt = db.prepare(
    `INSERT INTO ${SQLITE_TABLE_NAME} (expert_id, ticket_id, ts) VALUES (?, ?, ?)`,
  );
  const selectStmt = db.prepare(
    `SELECT expert_id, ticket_id, ts FROM ${SQLITE_TABLE_NAME} ORDER BY ts ASC`,
  );
  const clearStmt = db.prepare(`DELETE FROM ${SQLITE_TABLE_NAME}`);

  return {
    insert(inv) {
      try {
        insertStmt.run(inv.expertId, inv.ticketId, inv.timestamp);
        return ok(inv);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    selectAll() {
      try {
        const rows = selectStmt.all() as Array<{
          expert_id: string;
          ticket_id: string;
          ts: number;
        }>;
        return ok(
          rows.map((r) => ({
            expertId: r.expert_id,
            ticketId: r.ticket_id,
            timestamp: r.ts,
          })),
        );
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    clear() {
      try {
        clearStmt.run();
        return ok(undefined);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    close() {
      try {
        db.close();
      } catch {
        // ignore: db may already be closed
      }
    },
  };
}

export function createFallbackSqliteBackend(): SqliteBackend {
  return {
    insert() {
      return err(new Error('SQLite unavailable'));
    },
    selectAll() {
      return err(new Error('SQLite unavailable'));
    },
    clear() {
      return err(new Error('SQLite unavailable'));
    },
    close() {},
  };
}
