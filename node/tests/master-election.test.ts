/**
 * Master Election L3 (filesystem) tests: campaign, renew, takeover, resign, auto-renew.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdir, writeFile, rm, utimes } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { createMasterElection } from '../src/core/master-election.js';

const TTL = 30_000;
const RENEW_INTERVAL = 10_000;

describe('MasterElection L3', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = join(tmpdir(), `kallax-election-${randomUUID()}`);
    await mkdir(tmpDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true });
  });

  it('campaign wins L3 filesystem lock', async () => {
    const e = createMasterElection({ instanceId: 'i1', ttlMs: TTL, renewIntervalMs: RENEW_INTERVAL, lockDir: tmpDir });
    const r = await e.campaign();
    expect(r.isOk()).toBe(true);
    expect(r.value.isMaster).toBe(true);
    expect(r.value.level).toBe(3);
  });

  it('renews own lock successfully', async () => {
    const e = createMasterElection({ instanceId: 'i1', ttlMs: TTL, renewIntervalMs: RENEW_INTERVAL, lockDir: tmpDir });
    await e.campaign();
    await new Promise((r) => setTimeout(r, 5));
    const r = await e.renew();
    expect(r.isOk()).toBe(true);
    expect(r.value.isMaster).toBe(true);
    expect(r.value.lastRenewedAt).toBeGreaterThan(r.value.acquiredAt);
  });

  it('takes over expired lock', async () => {
    const lockFile = join(tmpDir, 'master.lock');
    await writeFile(lockFile, JSON.stringify({ instanceId: 'stale', acquiredAt: 0, term: 0 }));
    const past = new Date(Date.now() - 120_000);
    await utimes(lockFile, past, past);

    const e = createMasterElection({ instanceId: 'i2', ttlMs: TTL, renewIntervalMs: RENEW_INTERVAL, lockDir: tmpDir });
    const r = await e.campaign();
    expect(r.isOk()).toBe(true);
    expect(r.value.isMaster).toBe(true);
    // Term incremented on takeover
    expect(r.value.term).toBeGreaterThanOrEqual(1);
  });

  it('resign releases lock for another instance', async () => {
    const e1 = createMasterElection({ instanceId: 'i1', ttlMs: TTL, renewIntervalMs: RENEW_INTERVAL, lockDir: tmpDir });
    await e1.campaign();
    await e1.resign();
    const s1 = await e1.getState();
    expect(s1.value.isMaster).toBe(false);

    const e2 = createMasterElection({ instanceId: 'i2', ttlMs: TTL, renewIntervalMs: RENEW_INTERVAL, lockDir: tmpDir });
    const r2 = await e2.campaign();
    expect(r2.value.isMaster).toBe(true);
  });

  it('auto-renew starts and stops cleanly', async () => {
    const e = createMasterElection({ instanceId: 'i1', ttlMs: TTL, renewIntervalMs: 100, lockDir: tmpDir });
    await e.campaign();

    const sr = e.startAutoRenew();
    expect(sr.isOk()).toBe(true);
    const stop = sr.value;
    expect(typeof stop).toBe('function');
    stop();

    // Can start again after stop
    const sr2 = e.startAutoRenew();
    expect(sr2.isOk()).toBe(true);
    sr2.value();
  });
});
