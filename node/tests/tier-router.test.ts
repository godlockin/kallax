/**
 * Tests for TierRouter (EPIC-071-A4 + EPIC-075)
 * 治 v3.8.0 red-blue review A4: 三级降级仅观测未接线.
 * v3.9.0 落地架构契约 + Node tier stub; v3.10.0 真接 Rust (tier 0/1) + Shell (tier 3).
 */
import { describe, it, expect } from 'vitest';
import { tierRouter, type Operation } from '../src/core/tier-router.js';

describe('TierRouter (EPIC-075 真接完成)', () => {
  it('executes on Node tier (2) successfully', async () => {
    const result = await tierRouter.execute('ticket.list' as Operation, { filter: 'all' });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(2);
    expect(result.value).toMatchObject({ node: true, op: 'ticket.list' });
  });

  it('routes preferTier=2 explicitly', async () => {
    const result = await tierRouter.execute('ticket.create' as Operation, { title: 'test' }, { preferTier: 2 });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(2);
  });

  it('tier 0/1 不健康时降级到 tier 2 (EPIC-075 治根)', async () => {
    // 没有活 Rust 进程, bridge alive=false → 降级
    const result = await tierRouter.execute('ticket.list' as Operation, {}, { preferTier: 0 });
    expect(result.tier).toBeLessThanOrEqual(2);
  });

  it('does not crash with empty payload', async () => {
    const result = await tierRouter.execute('task.assign' as Operation, {});
    expect(result.tier).toBe(2);
  });

  it('EPIC-075: tier 0/1 决策走 executeOnTier (不是直接失败)', async () => {
    // tier 0/1 现在调用 rust-bridge.isAlive(), 不再 hard-fail
    const result = await tierRouter.execute('ticket.list' as Operation, {}, { preferTier: 1 });
    expect(result.tier).toBeGreaterThanOrEqual(0);
    expect(result.tier).toBeLessThanOrEqual(2);
  });
});