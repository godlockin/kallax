/**
 * KALLAX SessionEvent emit API — DSH Gap #2 双事件轨卡 D 埋点 (EPIC-282)
 *
 * 提供 `emitSessionEvent` 封装, 接受"partial event" (无 seq),
 * 由 store 自动分配 nextSeq + 持久化.
 *
 * 不变量: store.append runtime assert 已覆盖 monotonic + sourceEventSeqs.
 */

import type Database from 'better-sqlite3';
import { createEventStore } from './event-store.js';
import type { EventStore } from './event-store.js';
import type { SessionEvent } from './types.js';

/**
 * Partial event payload (without seq — store auto-assigns).
 * sourceEventSeqs 可省略 (默认空数组).
 */
export type EmitInput =
  | { readonly type: 'card-d/expert-activation'; readonly expertId: string; readonly sourceEventSeqs?: readonly number[] }
  | { readonly type: 'card-d/trace-step'; readonly step: string; readonly payload: unknown; readonly sourceEventSeqs?: readonly number[] }
  | {
      readonly type: 'card-d/trace-complete';
      readonly duration_ms: number;
      readonly expertId: string;
      readonly sourceEventSeqs?: readonly number[];
    };

export interface SessionEventEmitter {
  /** Emit one event. Auto-assigns seq = lastSeq+1 within session. */
  emit: (sessionId: string, input: EmitInput) => SessionEvent;
  /** Underlying store, for readRange/lastSeq callers (dashboards, telemetry). */
  store: EventStore;
}

export function createEventEmitter(db: Database.Database): SessionEventEmitter {
  const store = createEventStore(db);

  function emit(sessionId: string, input: EmitInput): SessionEvent {
    const nextSeq = store.lastSeq(sessionId) + 1;
    const sourceEventSeqs = input.sourceEventSeqs ?? [];
    const ts = Date.now();
    let event: SessionEvent;
    switch (input.type) {
      case 'card-d/expert-activation':
        event = {
          seq: nextSeq,
          ts,
          sessionId,
          sourceEventSeqs,
          type: 'card-d/expert-activation',
          expertId: input.expertId,
        };
        break;
      case 'card-d/trace-step':
        event = {
          seq: nextSeq,
          ts,
          sessionId,
          sourceEventSeqs,
          type: 'card-d/trace-step',
          step: input.step,
          payload: input.payload,
        };
        break;
      case 'card-d/trace-complete':
        event = {
          seq: nextSeq,
          ts,
          sessionId,
          sourceEventSeqs,
          type: 'card-d/trace-complete',
          duration_ms: input.duration_ms,
          expertId: input.expertId,
        };
        break;
    }
    return store.append(event);
  }

  return { emit, store };
}
