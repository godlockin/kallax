/**
 * KALLAX Master Election — 3-level degradation: Redis → SQLite → filesystem.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

export type ElectionLevel = 1 | 2 | 3;

export interface ElectionConfig {
  readonly instanceId: string;
  readonly ttlMs: number;
  readonly renewIntervalMs: number;
  readonly redisUrl?: string;
  readonly lockDir?: string;
}

export interface ElectionState {
  readonly isMaster: boolean;
  readonly level: ElectionLevel;
  readonly instanceId: string;
  readonly acquiredAt: number;
  readonly lastRenewedAt: number;
  readonly term: number;
}

export interface MasterElection {
  campaign: () => Promise<KallaxResult<ElectionState>>;
  renew: () => Promise<KallaxResult<ElectionState>>;
  resign: () => Promise<KallaxResult<void>>;
  getState: () => Promise<KallaxResult<ElectionState>>;
  startAutoRenew: () => KallaxResult<() => void>;
  tryUpgrade: () => Promise<KallaxResult<ElectionState>>;
}

const DEFAULT_TTL_MS = 30_000;
const DEFAULT_RENEW_MS = 10_000;
const DEFAULT_LOCK_DIR = '.kallax/election';

// ── Level 3: Filesystem lock ───────────────────────────────────────────────

async function fsCampaign(lockDir: string, instanceId: string): Promise<boolean> {
  const { mkdir } = await import('node:fs/promises');
  try {
    await mkdir(lockDir, { recursive: true });
    const lockFile = `${lockDir}/master.lock`;
    const { writeFile } = await import('node:fs/promises');
    await writeFile(lockFile, JSON.stringify({
      instanceId, acquiredAt: Date.now(), term: 0,
    }), { flag: 'wx' });
    return true;
  } catch (error: unknown) {
    const code = (error as { code?: string }).code;
    if (code === 'EEXIST') {
      try {
        const { stat, unlink, writeFile } = await import('node:fs/promises');
        const lockFile = `${lockDir}/master.lock`;
        const st = await stat(lockFile);
        const age = Date.now() - st.mtimeMs;
        if (age > DEFAULT_TTL_MS * 2) {
          await unlink(lockFile);
          await writeFile(lockFile, JSON.stringify({
            instanceId, acquiredAt: Date.now(), term: 1,
          }), { flag: 'wx' });
          logger.warn({ age, instanceId }, 'took over stale filesystem lock');
          return true;
        }
      } catch { /* lock disappeared */ }
    }
    return false;
  }
}

async function fsRenew(lockDir: string, instanceId: string): Promise<boolean> {
  try {
    const { readFile } = await import('node:fs/promises');
    const lockFile = `${lockDir}/master.lock`;
    const data = JSON.parse(await readFile(lockFile, 'utf-8'));
    if (data.instanceId !== instanceId) return false;
    const { utimes } = await import('node:fs/promises');
    const now = new Date();
    await utimes(lockFile, now, now);
    return true;
  } catch { return false; }
}

async function fsResign(lockDir: string): Promise<void> {
  try { await (await import('node:fs/promises')).unlink(`${lockDir}/master.lock`); }
  catch { /* already gone */ }
}

// ── Level 2: SQLite INSERT OR IGNORE ──────────────────────────────────────

async function sqliteCampaign(_sqlitePath: string, instanceId: string): Promise<boolean> {
  try {
    const { getSqliteManager } = await import('./sqlite-manager.js');
    const db = getSqliteManager();

    db.run(`
      CREATE TABLE IF NOT EXISTS master_election (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        instance_id TEXT NOT NULL,
        acquired_at INTEGER NOT NULL,
        renewed_at INTEGER NOT NULL,
        term INTEGER NOT NULL DEFAULT 0,
        ttl_ms INTEGER NOT NULL DEFAULT 30000
      )
    `);

    const now = Date.now();
    const insertResult = db.run(
      'INSERT OR IGNORE INTO master_election (id, instance_id, acquired_at, renewed_at, term) VALUES (1, ?, ?, ?, 0)',
      [instanceId, now, now],
    );

    if (insertResult.changes > 0) return true;

    const row = db.get(
      'SELECT instance_id, renewed_at FROM master_election WHERE id = 1',
    ) as { instance_id: string; renewed_at: number } | undefined;

    if (!row) return false;

    if (now - row.renewed_at > DEFAULT_TTL_MS * 2) {
      db.run(
        'UPDATE master_election SET instance_id = ?, acquired_at = ?, renewed_at = ?, term = term + 1 WHERE id = 1',
        [instanceId, now, now],
      );
      logger.warn({ previousMaster: row.instance_id, age: now - row.renewed_at }, 'took over stale SQLite lock');
      return true;
    }
    return false;
  } catch (error: unknown) {
    logger.warn({ error: error instanceof Error ? error.message : String(error) }, 'SQLite election failed');
    return false;
  }
}

async function sqliteRenew(_sqlitePath: string, instanceId: string): Promise<boolean> {
  try {
    const { getSqliteManager } = await import('./sqlite-manager.js');
    const db = getSqliteManager();
    const result = db.run(
      'UPDATE master_election SET renewed_at = ? WHERE id = 1 AND instance_id = ?',
      [Date.now(), instanceId],
    );
    return result.changes > 0;
  } catch { return false; }
}

async function sqliteResign(_sqlitePath: string, instanceId: string): Promise<void> {
  try {
    const { getSqliteManager } = await import('./sqlite-manager.js');
    getSqliteManager().run(
      'DELETE FROM master_election WHERE id = 1 AND instance_id = ?',
      [instanceId],
    );
  } catch { /* ignore */ }
}

// ── Level 1: Redis SETNX ──────────────────────────────────────────────────

async function redisCampaign(redisUrl: string, instanceId: string, ttlMs: number): Promise<boolean> {
  try {
    const { Redis } = await import('ioredis');
    const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 1 });
    try {
      await redis.connect();
      // SET key value NX PX ttl → returns OK if set, null if already exists
      const result = await redis.set('kallax:master:lock', instanceId, 'PX', ttlMs, 'NX');
      await redis.quit();
      return result === 'OK';
    } catch {
      await redis.quit().catch(() => {});
      return false;
    }
  } catch { return false; }
}

async function redisRenew(redisUrl: string, instanceId: string, ttlMs: number): Promise<boolean> {
  try {
    const { Redis } = await import('ioredis');
    const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 1 });
    try {
      await redis.connect();
      const current = await redis.get('kallax:master:lock');
      if (current === instanceId) {
        await redis.pexpire('kallax:master:lock', ttlMs);
        await redis.quit();
        return true;
      }
      await redis.quit();
      return false;
    } catch {
      await redis.quit().catch(() => {});
      return false;
    }
  } catch { return false; }
}

async function redisResign(redisUrl: string, instanceId: string): Promise<void> {
  try {
    const { Redis } = await import('ioredis');
    const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 1 });
    try {
      await redis.connect();
      const current = await redis.get('kallax:master:lock');
      if (current === instanceId) {
        await redis.del('kallax:master:lock');
      }
      await redis.quit();
    } catch { await redis.quit().catch(() => {}); }
  } catch { /* ignore */ }
}

// ── Main Export ────────────────────────────────────────────────────────────

export function createMasterElection(config: ElectionConfig): MasterElection {
  const lockDir = config.lockDir ?? DEFAULT_LOCK_DIR;
  const ttlMs = config.ttlMs ?? DEFAULT_TTL_MS;
  const renewIntervalMs = config.renewIntervalMs ?? DEFAULT_RENEW_MS;
  let state: ElectionState = {
    isMaster: false, level: 3, instanceId: config.instanceId,
    acquiredAt: 0, lastRenewedAt: 0, term: 0,
  };
  let renewTimer: ReturnType<typeof setInterval> | null = null;

  async function campaignLevel(level: ElectionLevel): Promise<boolean> {
    switch (level) {
      case 1: return config.redisUrl ? redisCampaign(config.redisUrl, config.instanceId, ttlMs) : false;
      case 2: return sqliteCampaign('.kallax/data/kallax.db', config.instanceId);
      case 3: return fsCampaign(lockDir, config.instanceId);
    }
  }

  async function renewLevel(level: ElectionLevel): Promise<boolean> {
    switch (level) {
      case 1: return config.redisUrl ? redisRenew(config.redisUrl, config.instanceId, ttlMs) : false;
      case 2: return sqliteRenew('.kallax/data/kallax.db', config.instanceId);
      case 3: return fsRenew(lockDir, config.instanceId);
    }
  }

  async function resignLevel(level: ElectionLevel): Promise<void> {
    switch (level) {
      case 1: if (config.redisUrl) await redisResign(config.redisUrl, config.instanceId); break;
      case 2: await sqliteResign('.kallax/data/kallax.db', config.instanceId); break;
      case 3: await fsResign(lockDir); break;
    }
  }

  return {
    async campaign(): Promise<KallaxResult<ElectionState>> {
      const now = Date.now();
      for (const level of [1, 2, 3] as ElectionLevel[]) {
        const won = await campaignLevel(level);
        if (won) {
          state = { isMaster: true, level, instanceId: config.instanceId, acquiredAt: now, lastRenewedAt: now, term: state.term + 1 };
          logger.info({ level, instanceId: config.instanceId, term: state.term }, 'elected as master');
          return ok({ ...state });
        }
      }
      state = { ...state, isMaster: false };
      return ok({ ...state });
    },

    async renew(): Promise<KallaxResult<ElectionState>> {
      if (!state.isMaster) {
        return err(new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'not master'));
      }
      const won = await renewLevel(state.level);
      if (!won) {
        logger.warn({ level: state.level }, 'lease renewal failed, re-campaigning');
        return this.campaign();
      }
      state = { ...state, lastRenewedAt: Date.now() };
      return ok({ ...state });
    },

    async resign(): Promise<KallaxResult<void>> {
      if (state.isMaster) {
        await resignLevel(state.level);
        state = { ...state, isMaster: false };
        logger.info({ instanceId: config.instanceId }, 'resigned from master');
      }
      return ok(undefined);
    },

    async getState(): Promise<KallaxResult<ElectionState>> {
      return ok({ ...state });
    },

    startAutoRenew(): KallaxResult<() => void> {
      if (renewTimer) {
        return err(new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'auto-renew already started'));
      }
      renewTimer = setInterval(async () => {
        if (state.isMaster) {
          const result = await this.renew();
          if (result.isErr()) logger.error({ error: result.error.message }, 'auto-renew failed');
        }
      }, renewIntervalMs);
      logger.info({ intervalMs: renewIntervalMs }, 'auto-renew started');
      const stop = () => { if (renewTimer) { clearInterval(renewTimer); renewTimer = null; } };
      return ok(stop);
    },

    async tryUpgrade(): Promise<KallaxResult<ElectionState>> {
      if (state.level <= 1) return ok({ ...state });
      for (const level of [1, 2] as ElectionLevel[]) {
        if (level >= state.level) continue;
        const won = await campaignLevel(level);
        if (won) {
          await resignLevel(state.level);
          state = { ...state, level, lastRenewedAt: Date.now() };
          logger.info({ from: state.level, to: level }, 'upgraded election level');
          return ok({ ...state });
        }
      }
      return ok({ ...state });
    },
  };
}
