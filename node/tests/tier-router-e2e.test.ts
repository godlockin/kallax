/**
 * Tests for TierRouter end-to-end (EPIC-097)
 * 治 v3.8.0 TierRouter stub 复发 + Rust startup latency
 */
import { describe, it, expect, vi } from 'vitest';
import { tierRouter, type Operation } from '../src/core/tier-router.js';
import * as rustBridge from '../src/core/rust-bridge.js';

describe('TierRouter end-to-end (EPIC-097)', () => {
  it('retries isAlive with backoff before giving up (Rust startup latency)', async () => {
    const spy = vi.spyOn(rustBridge, 'getRustBridge');
    // First 2 isAlive calls return false (Rust still starting), 3rd returns true
    const mockBridge = {
      isAlive: vi.fn()
        .mockResolvedValueOnce(false)
        .mockResolvedValueOnce(false)
        .mockResolvedValueOnce(true),
      getStatus: vi.fn().mockResolvedValue({ isOk: () => true, value: { status: 'ok' } }),
      createTicket: vi.fn().mockResolvedValue({ isOk: () => true, value: { ticket_id: 'T-test' } }),
      listTickets: vi.fn().mockResolvedValue({ isOk: () => true, value: { tickets: [] } }),
      assignTask: vi.fn().mockResolvedValue({ isOk: () => true, value: { task_id: 'T-1', performer_id: 'P-1' } }),
      completeTask: vi.fn().mockResolvedValue({ isOk: () => true, value: { task_id: 'T-1', status: 'completed' } }),
    };
    spy.mockReturnValue(mockBridge as any);

    const result = await tierRouter.execute('ticket.create' as Operation, { title: 'test' }, { preferTier: 0 });
    // 3 isAlive calls (2 false + 1 true) before actual op
    expect(mockBridge.isAlive).toHaveBeenCalledTimes(3);
    expect(result.ok).toBe(true);
  });

  it('after 3 isAlive retries all false → fail-closed (no fallback to lower tier)', async () => {
    const spy = vi.spyOn(rustBridge, 'getRustBridge');
    const mockBridge = {
      isAlive: vi.fn().mockResolvedValue(false),
      getStatus: vi.fn(),
      createTicket: vi.fn(),
      listTickets: vi.fn(),
      assignTask: vi.fn(),
      completeTask: vi.fn(),
    };
    spy.mockReturnValue(mockBridge as any);

    const result = await tierRouter.execute('ticket.create' as Operation, { title: 'test' }, { preferTier: 0 });
    expect(mockBridge.isAlive).toHaveBeenCalledTimes(3);
    expect(result.ok).toBe(false);
  });

  it('Node tier (2) executes immediately without Rust retry', async () => {
    const result = await tierRouter.execute('ticket.list' as Operation, {});
    expect(result.tier).toBe(2);
    expect(result.ok).toBe(true);
  });
});