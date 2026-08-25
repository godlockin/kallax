import { afterEach, describe, expect, it, vi } from 'vitest';
import { withSessionTrace, type SessionEventEmitter, type SessionEvent } from '../../../src/core/event-log/index.js';

const SESSION_ID = 'session-instrument-test';

function fakeEmitter(): { emitter: SessionEventEmitter; events: SessionEvent[] } {
  const events: SessionEvent[] = [];
  const emitter: SessionEventEmitter = {
    emit: (sessionId, input) => {
      const event = {
        ...input,
        seq: events.length + 1,
        ts: 0,
        sessionId,
        sourceEventSeqs: input.sourceEventSeqs ?? [],
      } as SessionEvent;
      events.push(event);
      return event;
    },
    store: {
      append: (event) => event,
      readRange: () => events,
      lastSeq: () => events.length,
    },
  };
  return { emitter, events };
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('withSessionTrace', () => {
  it('emits start, expert activation, and successful completion', async () => {
    vi.spyOn(Date, 'now').mockReturnValueOnce(1_000).mockReturnValueOnce(1_042);
    const { emitter, events } = fakeEmitter();

    const result = await withSessionTrace(
      emitter,
      { sessionId: SESSION_ID, expertId: 'architect', step: 'claim' },
      async () => 'done',
    );

    expect(result).toBe('done');
    expect(events).toHaveLength(3);
    expect(events[0]).toMatchObject({
      sessionId: SESSION_ID,
      type: 'card-d/trace-step',
      step: 'claim/start',
      payload: { ts: 1_000 },
    });
    expect(events[1]).toMatchObject({
      sessionId: SESSION_ID,
      type: 'card-d/expert-activation',
      expertId: 'architect',
    });
    expect(events[2]).toMatchObject({
      sessionId: SESSION_ID,
      type: 'card-d/trace-complete',
      expertId: 'architect',
      duration_ms: 42,
    });
  });

  it('emits completion on failure and rethrows original error', async () => {
    vi.spyOn(Date, 'now').mockReturnValueOnce(2_000).mockReturnValueOnce(2_017);
    const { emitter, events } = fakeEmitter();
    const failure = new Error('original failure');

    await expect(
      withSessionTrace(
        emitter,
        { sessionId: SESSION_ID, expertId: 'auditor', step: 'verify' },
        async () => {
          throw failure;
        },
      ),
    ).rejects.toBe(failure);

    expect(events).toHaveLength(3);
    expect(events[2]).toMatchObject({
      sessionId: SESSION_ID,
      type: 'card-d/trace-complete',
      expertId: 'auditor',
      duration_ms: 17,
    });
  });
});
