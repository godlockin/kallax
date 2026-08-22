/**
 * KALLAX SessionEvent Store — DSH Gap #2 双事件轨卡 D 埋点 (EPIC-282)
 *
 * Append-only event store with monotonic seq assertion per session.
 *
 * 关键不变量 (DSH §2.2 + §2.3, runtime fail-closed):
 *   invariant(event.seq > lastSeq, 'event seq must monotonically increase')
 *   invariant(event.sourceEventSeqs.every(s => s <= event.seq),
 *             'sourceEventSeqs 必指过去')
 *
 * 用法:
 *   const store = createEventStore(db);
 *   const ev = await store.append({ type: 'card-d/...', ... });
 *   const chain = await store.readRange(sessionId, start, end);
 */

import type Database from 'better-sqlite3';
import { rowToSessionEvent, sessionEventToRow } from './types.js';
import type { SessionEvent, SessionEventRow } from './types.js';

export interface EventStore {
  /**
   * Append a SessionEvent to the event_seq table.
   * Throws on monotonic seq violation or future sourceEventSeqs.
   */
  append: (event: SessionEvent) => SessionEvent;
  /**
   * Read events in a session, ordered by seq ASC.
   * range [start, end] inclusive (use 0..Number.MAX_SAFE_INTEGER for full).
   */
  readRange: (sessionId: string, start: number, end: number) => SessionEvent[];
  /**
   * Latest seq for a session, or 0 if empty.
   */
  lastSeq: (sessionId: string) => number;
}

export function createEventStore(db: Database.Database): EventStore {
  const insertStmt = db.prepare(`
    INSERT INTO event_seq (seq, session_id, type, ts, source_event_seqs, payload, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  const rangeStmt = db.prepare(`
    SELECT * FROM event_seq
    WHERE session_id = ? AND seq BETWEEN ? AND ?
    ORDER BY seq ASC
  `);
  const maxSeqStmt = db.prepare(`
    SELECT COALESCE(MAX(seq), 0) AS maxSeq FROM event_seq WHERE session_id = ?
  `);

  function append(event: SessionEvent): SessionEvent {
    const last = (maxSeqStmt.get(event.sessionId) as { maxSeq: number }).maxSeq;
    // DSH §2.2 strong constraint: monotonic seq (runtime assert, fail-closed).
    if (event.seq <= last) {
      throw new Error(
        `event seq must monotonically increase: sessionId=${event.sessionId} ` +
          `got seq=${String(event.seq)}, lastSeq=${String(last)}`,
      );
    }
    // DSH §2.3: sourceEventSeqs 必指过去 (DAG 拓扑约束).
    if (event.sourceEventSeqs.some((s) => s > event.seq)) {
      throw new Error(
        `sourceEventSeqs 必须指过去: sessionId=${event.sessionId} ` +
          `seq=${String(event.seq)}, sourceEventSeqs=[${[...event.sourceEventSeqs].join(',')}]`,
      );
    }
    const row: SessionEventRow = sessionEventToRow(event);
    insertStmt.run(
      row.seq,
      row.session_id,
      row.type,
      row.ts,
      row.source_event_seqs,
      row.payload,
      row.created_at,
    );
    return event;
  }

  function readRange(sessionId: string, start: number, end: number): SessionEvent[] {
    const rows = rangeStmt.all(sessionId, start, end) as SessionEventRow[];
    return rows.map(rowToSessionEvent);
  }

  function lastSeq(sessionId: string): number {
    return (maxSeqStmt.get(sessionId) as { maxSeq: number }).maxSeq;
  }

  return { append, readRange, lastSeq };
}
