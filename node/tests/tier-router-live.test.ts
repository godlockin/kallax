/**
 * EPIC-101: 真端到端 live test (server running, not mock)
 * 跟 v3.8.0 reviewer 同样标准 — 真跑而非 mock
 *
 * 前提: `kallax-server` Rust binary 跑在 http://127.0.0.1:3000
 */
import { describe, it, expect, beforeAll } from 'vitest';
import { tierRouter } from '../src/core/tier-router.js';
import { getRustBridge } from '../src/core/rust-bridge.js';

// Requires live Rust server on :3000. Set RUST_LIVE=1 to run.
describe.skipIf(!process.env.RUST_LIVE)('TierRouter live (real Rust server on :3000)', () => {
  beforeAll(async () => {
    // Verify server reachable
    const bridge = getRustBridge();
    const alive = await bridge.isAlive();
    if (!alive) {
      throw new Error('Rust server not running on :3000 — start it first');
    }
  });

  it('tier 0 (Rust) 真接 — list tickets', async () => {
    const result = await tierRouter.execute('ticket.list' as any, {}, { preferTier: 0 });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(0);
    expect((result.value as { rust: boolean }).rust).toBe(true);
  });

  it('tier 0 (Rust) 真接 — create ticket', async () => {
    const result = await tierRouter.execute('ticket.create' as any, { title: 'EPIC-101 live' }, { preferTier: 0 });
    expect(result.ok).toBe(true);
    expect(result.tier).toBe(0);
    expect((result.value as { ticket_id: string }).ticket_id).toMatch(/^TICKET-/);
  });
});
