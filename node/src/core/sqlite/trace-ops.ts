/**
 * KALLAX SQLite Trace Operations
 * Raw SQL operations for the trace_logs table.
 * Used internally by TraceLog (span-tracer.ts).
 */

import type Database from 'better-sqlite3';

export interface TraceLogRow {
  trace_id: string;
  timestamp: number;
  actor: string;
  action: string;
  target: string;
  detail: string;
  result: string;
  parent_trace_id: string | null;
}

export interface TraceOperations {
  insertTrace: (entry: TraceLogRow) => void;
  getTraceById: (traceId: string) => TraceLogRow | undefined;
  getTracesByTarget: (target: string) => TraceLogRow[];
  getTracesByActor: (actor: string) => TraceLogRow[];
  getTraceChain: (traceId: string) => TraceLogRow[];
}

export function createTraceOps(db: Database.Database): TraceOperations {
  return {
    insertTrace(entry: TraceLogRow): void {
      db.prepare(`
        INSERT INTO trace_logs (trace_id, timestamp, actor, action, target, detail, result, parent_trace_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        entry.trace_id,
        entry.timestamp,
        entry.actor,
        entry.action,
        entry.target,
        entry.detail,
        entry.result,
        entry.parent_trace_id,
      );
    },

    getTraceById(traceId: string): TraceLogRow | undefined {
      return db.prepare('SELECT * FROM trace_logs WHERE trace_id = ?').get(traceId) as TraceLogRow | undefined;
    },

    getTracesByTarget(target: string): TraceLogRow[] {
      return db.prepare('SELECT * FROM trace_logs WHERE target = ? ORDER BY timestamp ASC').all(target) as TraceLogRow[];
    },

    getTracesByActor(actor: string): TraceLogRow[] {
      return db.prepare('SELECT * FROM trace_logs WHERE actor = ? ORDER BY timestamp DESC').all(actor) as TraceLogRow[];
    },

    getTraceChain(traceId: string): TraceLogRow[] {
      return db.prepare(`
        WITH RECURSIVE chain AS (
          SELECT * FROM trace_logs WHERE trace_id = ?
          UNION ALL
          SELECT tl.* FROM trace_logs tl
          JOIN chain c ON tl.trace_id = c.parent_trace_id
          UNION ALL
          SELECT tl.* FROM trace_logs tl
          JOIN chain c ON tl.parent_trace_id = c.trace_id
        )
        SELECT DISTINCT * FROM chain ORDER BY timestamp ASC
      `).all(traceId) as TraceLogRow[];
    },
  };
}
