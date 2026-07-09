/**
 * Tests for TierRouter (EPIC-071-A4)
 * 治 v3.8.0 red-blue review A4: 三级降级仅观测未接线.
 * 新增 TierRouter 真实路由 contract + Node tier stub 执行.
 */
import { describe, it, expect } from 'vitest';
import { tierRouter, type Operation } from '../src/core/tier-router.js';

describe('TierRouter (EPIC-071-A4)', () => {
  it('executes on current tier (Node=2) successfully', async () => {
    const result = await tierRouter.execute('ticket.list' as Operation, { filter: 'all' });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(2);
  });

  it('routes preferTier=2 explicitly', async () => {
    const result = await tierRouter.execute('ticket.create' as Operation, { title: 'test' }, { preferTier: 2 });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(2);
    expect(result.value).toMatchObject({ op: 'ticket.create', tier: 2 });
  });

  it('returns error for tier 0/1/3 (not yet wired in v3.9.0)', async () => {
    const result = await tierRouter.execute('ticket.list' as Operation, {}, { preferTier: 0 });
    expect(result.ok).toBe(false);
    expect(result.error).toContain('not yet wired');
  });

  it('does not crash with empty payload', async () => {
    const result = await tierRouter.execute('task.assign' as Operation, {});
    expect(result.tier).toBe(2);
  });
});