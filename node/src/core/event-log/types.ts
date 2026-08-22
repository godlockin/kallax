/**
 * KALLAX SessionEvent types — DSH Gap #2 双事件轨卡 D 埋点 (EPIC-282)
 *
 * 设计要点:
 * - `seq` 单调追加 per session, append-only
 * - `sourceEventSeqs` 关联上游 SessionEvent 形成 DAG (DSH §2.3)
 * - `payload` 必有 type tag (TypeScript discriminated union)
 * - `SESSION_FORMAT_VERSION` 强升级 (DSH §2.4)
 *
 * 不变量 (runtime fail-closed):
 *   invariant(event.seq > lastSeq, 'event seq must monotonically increase')
 *   invariant(event.sourceEventSeqs.every(s => s <= event.seq), 'sourceEventSeqs 必指过去')
 */

export const SESSION_FORMAT_VERSION = 1;

/**
 * SessionEvent 基础字段 — 所有事件类型共享
 */
export interface SessionEventBase {
  readonly seq: number;
  readonly ts: number;
  readonly sessionId: string;
  /** 关联上游 SessionEvent seq 列表 (形成 DAG). 可空数组. */
  readonly sourceEventSeqs: readonly number[];
}

/**
 * SessionEvent 类型: 'card-d/...' 是 EPIC-277 卡 D 当前唯一消费者.
 * 新 event type 需加 discriminated union 成员 + Jest 序列化测试.
 */
export type SessionEventType = 'card-d/expert-activation' | 'card-d/trace-step' | 'card-d/trace-complete';

/**
 * SessionEvent: 跟 DSH §2.2 对齐, payload 用 discriminated union.
 */
export type SessionEvent =
  | (SessionEventBase & {
      readonly type: 'card-d/expert-activation';
      readonly expertId: string;
    })
  | (SessionEventBase & {
      readonly type: 'card-d/trace-step';
      readonly step: string;
      readonly payload: unknown;
    })
  | (SessionEventBase & {
      readonly type: 'card-d/trace-complete';
      readonly duration_ms: number;
      readonly expertId: string;
    });

/**
 * SessionEvent 跟 SQLite event_seq 表 row 映射.
 * payload 列存 JSON (discriminated union 序列化).
 */
export interface SessionEventRow {
  readonly seq: number;
  readonly ts: number;
  readonly session_id: string;
  readonly type: string;
  readonly source_event_seqs: string; // JSON: number[]
  readonly payload: string;            // JSON: discriminated union payload
  readonly created_at: number;
}

/**
 * row → SessionEvent (parser). 信任 caller 提供正确 row 来源 (event-store).
 */
export function rowToSessionEvent(row: SessionEventRow): SessionEvent {
  const sourceEventSeqs = JSON.parse(row.source_event_seqs) as number[];
  const payload = JSON.parse(row.payload) as unknown;
  const base: SessionEventBase = {
    seq: row.seq,
    ts: row.ts,
    sessionId: row.session_id,
    sourceEventSeqs,
  };
  switch (row.type) {
    case 'card-d/expert-activation': {
      const p = payload as { expertId: string };
      return { ...base, type: 'card-d/expert-activation', expertId: p.expertId };
    }
    case 'card-d/trace-step': {
      const p = payload as { step: string; payload: unknown };
      return { ...base, type: 'card-d/trace-step', step: p.step, payload: p.payload };
    }
    case 'card-d/trace-complete': {
      const p = payload as { duration_ms: number; expertId: string };
      return {
        ...base,
        type: 'card-d/trace-complete',
        duration_ms: p.duration_ms,
        expertId: p.expertId,
      };
    }
    default:
      throw new Error(`Unknown session event type: ${row.type}`);
  }
}

/**
 * 序列化 SessionEvent 为 row. caller 必先通过 invariant asserts.
 */
export function sessionEventToRow(event: SessionEvent): SessionEventRow {
  let payload: Record<string, unknown>;
  switch (event.type) {
    case 'card-d/expert-activation':
      payload = { expertId: event.expertId };
      break;
    case 'card-d/trace-step':
      payload = { step: event.step, payload: event.payload };
      break;
    case 'card-d/trace-complete':
      payload = { duration_ms: event.duration_ms, expertId: event.expertId };
      break;
  }
  return {
    seq: event.seq,
    ts: event.ts,
    session_id: event.sessionId,
    type: event.type,
    source_event_seqs: JSON.stringify([...event.sourceEventSeqs]),
    payload: JSON.stringify(payload),
    created_at: Date.now(),
  };
}
