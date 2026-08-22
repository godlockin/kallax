/**
 * Event-log module — DSH Gap #2 双事件轨卡 D 埋点 (EPIC-282)
 *
 * Re-exports:
 * - types: SessionEvent discriminated union + row 映射
 * - event-store: append-only event store + monotonic guards
 * - emit: SessionEventEmitter (auto-assign seq + persist)
 * - instrument: withSessionTrace 装饰器 (wrap async tool calls)
 */

export type {
  SessionEvent,
  SessionEventBase,
  SessionEventType,
  SessionEventRow,
} from './types.js';
export { SESSION_FORMAT_VERSION, rowToSessionEvent, sessionEventToRow } from './types.js';

export type { EventStore } from './event-store.js';
export { createEventStore } from './event-store.js';

export type { EmitInput, SessionEventEmitter } from './emit.js';
export { createEventEmitter } from './emit.js';

export type { InstrumentOptions } from './instrument.js';
export { withSessionTrace } from './instrument.js';
