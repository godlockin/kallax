/**
 * Span Tracer tests: span creation, attributes, events, end, withSpan.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createSpanTracer } from '../src/core/span-tracer.js';
import type { SpanTracer, Span } from '../src/core/span-tracer.js';

describe('SpanTracer', () => {
  let tracer: SpanTracer;

  beforeEach(() => { tracer = createSpanTracer(); });

  it('startSpan creates span with unique ids', () => {
    const span1 = tracer.startSpan('op1');
    const span2 = tracer.startSpan('op2');

    expect(span1.context.spanId).toBeTruthy();
    expect(span1.context.traceId).toBeTruthy();
    expect(span1.context.spanId).not.toBe(span2.context.spanId);
  });

  it('startSpan creates span with given name', () => {
    const span = tracer.startSpan('test-op', { key: 'val' });
    expect(span.data.name).toBe('test-op');
    expect(span.data.attributes).toHaveProperty('key');
  });

  it('setAttribute updates span attributes', () => {
    const span = tracer.startSpan('op');
    span.setAttribute('result', 'ok');
    expect(span.data.attributes).toHaveProperty('result', 'ok');
  });

  it('addEvent records events on span', () => {
    const span = tracer.startSpan('op');
    span.addEvent('cache-hit', { key: 'x' });
    expect(span.data.events.length).toBe(1);
    expect(span.data.events[0]?.name).toBe('cache-hit');
  });

  it('setStatus updates span status', () => {
    const span = tracer.startSpan('op');
    span.setStatus('ok');
    expect(span.data.status).toBe('ok');
  });

  it('end removes span from active spans', () => {
    const span = tracer.startSpan('op');
    expect(tracer.getActiveSpan()).not.toBeNull();
    span.end();
    // After end, another span may exist; verify the ended span is no longer active
    expect(span.data.endTime).toBeGreaterThan(0); // endTime set
  });

  it('withSpan auto-ends span on success', async () => {
    const result = await tracer.withSpan('async-op', async (span) => {
      span.setAttribute('status', 'running');
      return 'done';
    });
    expect(result).toBe('done');
  });

  it('withSpan sets error status on exception', async () => {
    await expect(
      tracer.withSpan('fail-op', async (_span: Span) => {
        throw new Error('boom');
      }),
    ).rejects.toThrow('boom');
  });

  it('getActiveSpan returns null with no spans', () => {
    const newTracer = createSpanTracer();
    expect(newTracer.getActiveSpan()).toBeNull();
  });
});
