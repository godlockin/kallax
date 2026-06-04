/**
 * KALLAX Span Tracer
 * Structured observability — events > console.log.
 * Every critical path records a Span for querying, aggregation, and alerting.
 *
 * console.log is un-queryable in production — use structured spans instead.
 */

import type Database from 'better-sqlite3';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from './sqlite/index.js';
import { createTraceOps } from './sqlite/trace-ops.js';
import type { TraceLogRow } from './sqlite/trace-ops.js';

export interface SpanContext {
  readonly traceId: string;
  readonly spanId: string;
  readonly parentSpanId?: string | undefined;
}

export interface SpanData {
  readonly name: string;
  readonly kind: SpanKind;
  readonly startTime: number;
  readonly endTime?: number;
  readonly status: SpanStatus;
  readonly attributes: Readonly<Record<string, unknown>>;
  readonly events: SpanEvent[];
}

export type SpanKind = 'internal' | 'server' | 'client' | 'producer' | 'consumer';

export type SpanStatus = 'ok' | 'error' | 'unset';

export interface SpanEvent {
  readonly name: string;
  readonly timestamp: number;
  readonly attributes: Readonly<Record<string, unknown>>;
}

export interface Span {
  readonly context: SpanContext;
  readonly data: SpanData;
  setAttribute: (key: string, value: unknown) => void;
  addEvent: (name: string, attributes?: Record<string, unknown>) => void;
  setStatus: (status: SpanStatus) => void;
  end: () => void;
}

export interface SpanTracer {
  startSpan: (name: string, attributes?: Record<string, unknown>) => Span;
  getActiveSpan: () => Span | null;
  withSpan: <T>(name: string, fn: (span: Span) => Promise<T>) => Promise<T>;
}

// ── Trace Log ─────────────────────────────────────────────────────────────────

export interface TraceEntry {
  readonly traceId: string;
  readonly timestamp: number;
  readonly actor: string;
  readonly action: string;
  readonly target: string;
  readonly detail: Readonly<Record<string, unknown>>;
  readonly result: 'success' | 'failure' | 'pending';
  readonly parentTraceId?: string;
}

export interface TraceLog {
  record: (entry: Omit<TraceEntry, 'traceId' | 'timestamp'>) => string;
  getChain: (traceId: string) => TraceEntry[];
  getTaskTrace: (taskId: string) => TraceEntry[];
  getPerformerTrace: (performerId: string) => TraceEntry[];
}

let idCounter = 0;

function generateId(): string {
  idCounter++;
  return `${Date.now().toString(36)}_${idCounter.toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createSpanTracer(db?: SQLiteManager): SpanTracer {
  const activeSpans = new Map<string, Span>();

  function createSpan(
    name: string,
    attributes?: Record<string, unknown>,
    parentSpanId?: string,
  ): Span {
    const spanId = generateId();
    const traceId = parentSpanId === undefined
      ? generateId()
      : (activeSpans.get(parentSpanId)?.context.traceId ?? generateId());

    const context: SpanContext = { traceId, spanId, parentSpanId };

    const span: Span = {
      context,
      data: {
        name,
        kind: 'internal',
        startTime: Date.now(),
        status: 'unset',
        attributes: Object.freeze({ ...attributes }),
        events: [],
      },

      setAttribute(key: string, value: unknown): void {
        (span.data as { attributes: Record<string, unknown> }).attributes = {
          ...span.data.attributes,
          [key]: value,
        };
      },

      addEvent(name: string, attrs?: Record<string, unknown>): void {
        const event: SpanEvent = {
          name,
          timestamp: Date.now(),
          attributes: Object.freeze({ ...attrs }),
        };
        span.data.events.push(event);
        logger.debug(
          { spanId, spanName: span.data.name, eventName: name, attributes: attrs },
          'span event',
        );
      },

      setStatus(status: SpanStatus): void {
        (span.data as { status: SpanStatus }).status = status;
      },

      end(): void {
        (span.data as { endTime: number }).endTime = Date.now();
        activeSpans.delete(spanId);

        const duration = span.data.endTime! - span.data.startTime;
        logger.info(
          {
            spanId,
            traceId,
            spanName: span.data.name,
            durationMs: duration,
            status: span.data.status,
            eventCount: span.data.events.length,
            attributes: span.data.attributes,
          },
          'span ended',
        );

        // Persist to DB if available
        if (db !== undefined) {
          try {
            db.enqueueMessage({
              id: `span_${spanId}`,
              type: 'span',
              payload: {
                context: span.context,
                name: span.data.name,
                startTime: span.data.startTime,
                endTime: span.data.endTime,
                durationMs: duration,
                status: span.data.status,
                events: span.data.events,
                attributes: span.data.attributes,
              },
              priority: 0, // LOW
              createdAt: Date.now(),
            });
          } catch {
            logger.warn({ spanId }, 'failed to persist span');
          }
        }
      },
    };

    activeSpans.set(spanId, span);
    logger.debug({ spanId, traceId, spanName: name }, 'span started');
    return span;
  }

  return {
    startSpan(name: string, attributes?: Record<string, unknown>): Span {
      return createSpan(name, attributes);
    },

    getActiveSpan(): Span | null {
      if (activeSpans.size === 0) return null;
      const lastId = Array.from(activeSpans.keys()).pop();
      return lastId ? (activeSpans.get(lastId) ?? null) : null;
    },

    async withSpan<T>(
      name: string,
      fn: (span: Span) => Promise<T>,
    ): Promise<T> {
      const span = this.startSpan(name);
      try {
        const result = await fn(span);
        span.setStatus('ok');
        return result;
      } catch (error: unknown) {
        span.setStatus('error');
        span.addEvent('exception', {
          message: error instanceof Error ? error.message : String(error),
        });
        throw error;
      } finally {
        span.end();
      }
    },
  };
}

let defaultTracer: SpanTracer | null = null;

export function getSpanTracer(db?: SQLiteManager): SpanTracer {
  if (defaultTracer === null) {
    defaultTracer = createSpanTracer(db);
  }
  return defaultTracer;
}

// ── Trace Log Implementation ──────────────────────────────────────────────────

function generateTraceId(): string {
  return `tr_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function rowToTraceEntry(row: TraceLogRow): TraceEntry {
  return {
    traceId: row.trace_id,
    timestamp: row.timestamp,
    actor: row.actor,
    action: row.action,
    target: row.target,
    detail: JSON.parse(row.detail) as Record<string, unknown>,
    result: row.result as TraceEntry['result'],
    parentTraceId: row.parent_trace_id !== null ? row.parent_trace_id : undefined,
  };
}

export function createTraceLog(db: Database.Database): TraceLog {
  const ops = createTraceOps(db);

  return {
    record(entry: Omit<TraceEntry, 'traceId' | 'timestamp'>): string {
      const traceId = generateTraceId();
      const timestamp = Date.now();
      ops.insertTrace({
        trace_id: traceId,
        timestamp,
        actor: entry.actor,
        action: entry.action,
        target: entry.target,
        detail: JSON.stringify(entry.detail),
        result: entry.result,
        parent_trace_id: entry.parentTraceId !== undefined ? entry.parentTraceId : null,
      });
      return traceId;
    },

    getChain(traceId: string): TraceEntry[] {
      return ops.getTraceChain(traceId).map(rowToTraceEntry);
    },

    getTaskTrace(taskId: string): TraceEntry[] {
      return ops.getTracesByTarget(taskId).map(rowToTraceEntry);
    },

    getPerformerTrace(performerId: string): TraceEntry[] {
      return ops.getTracesByActor(performerId).map(rowToTraceEntry);
    },
  };
}
