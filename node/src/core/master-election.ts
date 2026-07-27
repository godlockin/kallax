/**
 * KALLAX Master Election — 3-level degradation: Redis → SQLite → filesystem.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { registerCleanupHandler } from '../utils/process-cleanup.js';
import { redactErrorMessage, redactRedisUrl } from '../utils/redact-secret.js';
import type { Redis } from 'ioredis';

export type ElectionLevel = 1 | 2 | 3;

export interface ElectionConfig {
  readonly instanceId: string;
  readonly ttlMs: number;
  readonly renewIntervalMs: number;
  readonly redisUrl?: string;
  readonly lockDir?: string;
}

// ── Redis connection pool (singleton per URL to fix connection leak) ──────

const redisPool = new Map<string, Redis>();

async function getRedis(redisUrl: string): Promise<Redis | null> {
  try {
    const cached = redisPool.get(redisUrl);
    if (cached?.status === 'ready') return cached;
    // v3.5.0 hotfix (跟 B 组 S-005 fix ): overwrite 旧 connection 前先 quit (防 fd leak)
    // After the early return above, cached.status is guaranteed to be != 'ready'
    // when cached is defined, so this branch only runs for stale/in-flight connections.
    if (cached !== undefined) {
      try { await cached.quit(); } catch { /* ignore, fd may already be closed */ }
      redisPool.delete(redisUrl);
    }
    let redis: Redis | undefined = cached;
    // Create or recreate
    const { Redis: IORedis } = await import('ioredis');
    redis = new IORedis(redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 2,
      enableOfflineQueue: false,
    });
    await redis.connect();
    redisPool.set(redisUrl, redis);
    return redis;
  } catch (error: unknown) {
    logger.warn(
      {
        error: redactErrorMessage(error instanceof Error ? error.message : String(error)),
        redisUrl: redactRedisUrl(redisUrl),
      },
      'redis connect failed',
    );
    return null;
  }
}

// v3.5.0 hotfix (跟 B 组 S-005 fix ): Node.js exit 时 close 全部 redisPool 连接 (跟 redis-pubsub.ts:144 模式 1:1)
registerCleanupHandler('redis-election-pool', async () => {
  const conns = Array.from(redisPool.values());
  redisPool.clear();
  for (const conn of conns) {
    try { await conn.quit(); } catch { /* ignore */ }
  }
});

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
        // EPIC-076 P1-1 split-brain fix: 缩 TTL grace 60s→45s, 加 EEXIST 重试防 unlink 失败
        // 原来: DEFAULT_TTL_MS * 2 = 60s grace (过长, Redis 抖动 3s 后 lock 残留)
        // 修: DEFAULT_TTL_MS + DEFAULT_TTL_MS / 2 = 45s grace, 加快 split-brain 检测
        if (age > DEFAULT_TTL_MS + DEFAULT_TTL_MS / 2) {
          try {
            await unlink(lockFile);
          } catch (unlinkErr: unknown) {
            // EACCES / ENOENT: lock 已被其他进程处理, 试一次 EEXIST 重新加锁
            const uCode = (unlinkErr as { code?: string }).code;
            if (uCode !== 'ENOENT') {
              logger.warn({ unlinkErr: unlinkErr instanceof Error ? unlinkErr.message : String(unlinkErr) }, 'lock unlink failed');
              return false;
            }
          }
          // 重试: 写新 lock
          try {
            await writeFile(lockFile, JSON.stringify({
              instanceId, acquiredAt: Date.now(), term: 1,
            }), { flag: 'wx' });
            logger.warn({ age, instanceId }, 'took over stale filesystem lock');
            return true;
          } catch {
            return false; // 其他进程抢先, 让出
          }
        }
      } catch (error: unknown) {
    logger.debug({ error: error instanceof Error ? error.message : String(error) }, 'non-critical election op failed');
    /* lock disappeared */ }
    }
    return false;
  }
}

async function fsRenew(lockDir: string, instanceId: string): Promise<boolean> {
  try {
    const { readFile } = await import('node:fs/promises');
    const lockFile = `${lockDir}/master.lock`;
    const data = JSON.parse(await readFile(lockFile, 'utf-8')) as { instanceId?: string };
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
    const { getSqliteManager } = await import('./sqlite/index.js');
    const db = getSqliteManager();

    db.exec(`
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
    const insertResult = db.prepare(
      'INSERT OR IGNORE INTO master_election (id, instance_id, acquired_at, renewed_at, term) VALUES (1, ?, ?, ?, 0)',
    ).run(instanceId, now, now);

    if (insertResult.changes > 0) return true;

    const row = db.prepare(
      'SELECT instance_id, renewed_at FROM master_election WHERE id = 1',
    ).get() as { instance_id: string; renewed_at: number } | undefined;

    if (!row) return false;

    if (now - row.renewed_at > DEFAULT_TTL_MS * 2) {
      db.prepare(
        'UPDATE master_election SET instance_id = ?, acquired_at = ?, renewed_at = ?, term = term + 1 WHERE id = 1',
      ).run(instanceId, now, now);
      logger.warn({ previousMaster: row.instance_id, age: now - row.renewed_at }, 'took over stale SQLite lock');
      return true;
    }
    return false;
  } catch (error: unknown) {
    logger.warn({ error: redactErrorMessage(error instanceof Error ? error.message : String(error)) }, 'SQLite election failed');
    return false;
  }
}

async function sqliteRenew(_sqlitePath: string, instanceId: string): Promise<boolean> {
  try {
    const { getSqliteManager } = await import('./sqlite/index.js');
    const db = getSqliteManager();
    const result = db.prepare(
      'UPDATE master_election SET renewed_at = ? WHERE id = 1 AND instance_id = ?',
    ).run(Date.now(), instanceId);
    return result.changes > 0;
  } catch { return false; }
}

async function sqliteResign(_sqlitePath: string, instanceId: string): Promise<void> {
  try {
    const { getSqliteManager } = await import('./sqlite/index.js');
    getSqliteManager().prepare(
      'DELETE FROM master_election WHERE id = 1 AND instance_id = ?',
    ).run(instanceId);
  } catch (error: unknown) {
    logger.debug({ error: error instanceof Error ? error.message : String(error) }, 'non-critical election op failed');
    /* ignore */ }
}

// ── Level 1: Redis SETNX ──────────────────────────────────────────────────

async function redisCampaign(redisUrl: string, instanceId: string, ttlMs: number): Promise<boolean> {
  const redis = await getRedis(redisUrl);
  if (!redis) return false;
  try {
    const result = await redis.set('kallax:master:lock', instanceId, 'PX', ttlMs, 'NX');
    return result === 'OK';
  } catch (error: unknown) {
    logger.warn({ error: redactErrorMessage(error instanceof Error ? error.message : String(error)) }, 'redis campaign failed');
    return false;
  }
}

async function redisRenew(redisUrl: string, instanceId: string, ttlMs: number): Promise<boolean> {
  const redis = await getRedis(redisUrl);
  if (!redis) return false;
  try {
    // Atomic Lua: renew only if we still own the lock (fixes TOCTOU race)
    const lua = `
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('PEXPIRE', KEYS[1], ARGV[2])
      else
        return 0
      end
    `;
    const result = await redis.eval(lua, 1, 'kallax:master:lock', instanceId, String(ttlMs));
    return (result as number) === 1;
  } catch (error: unknown) {
    logger.warn({ error: redactErrorMessage(error instanceof Error ? error.message : String(error)) }, 'redis renew failed');
    return false;
  }
}

async function redisResign(redisUrl: string, instanceId: string): Promise<void> {
  const redis = await getRedis(redisUrl);
  if (!redis) return;
  try {
    // Atomic Lua: delete only if we own the lock (fixes TOCTOU race)
    const lua = `
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    `;
    await redis.eval(lua, 1, 'kallax:master:lock', instanceId);
  } catch (error: unknown) {
    logger.warn({ error: redactErrorMessage(error instanceof Error ? error.message : String(error)) }, 'redis resign failed');
  }
}

// ── Main Export ────────────────────────────────────────────────────────────

export function createMasterElection(config: ElectionConfig): MasterElection {
  const lockDir = config.lockDir ?? DEFAULT_LOCK_DIR;
  const ttlMs = config.ttlMs;
  const renewIntervalMs = config.renewIntervalMs;
  let state: ElectionState = {
    isMaster: false, level: 3, instanceId: config.instanceId,
    acquiredAt: 0, lastRenewedAt: 0, term: 0,
  };
  let renewTimer: ReturnType<typeof setInterval> | null = null;

  async function campaignLevel(level: ElectionLevel): Promise<boolean> {
    switch (level) {
      case 1: return config.redisUrl != null ? redisCampaign(config.redisUrl, config.instanceId, ttlMs) : false;
      case 2: return sqliteCampaign('.kallax/data/kallax.db', config.instanceId);
      case 3: return fsCampaign(lockDir, config.instanceId);
    }
  }

  async function renewLevel(level: ElectionLevel): Promise<boolean> {
    switch (level) {
      case 1: return config.redisUrl != null ? redisRenew(config.redisUrl, config.instanceId, ttlMs) : false;
      case 2: return sqliteRenew('.kallax/data/kallax.db', config.instanceId);
      case 3: return fsRenew(lockDir, config.instanceId);
    }
  }

  async function resignLevel(level: ElectionLevel): Promise<void> {
    switch (level) {
      case 1: if (config.redisUrl != null) await redisResign(config.redisUrl, config.instanceId); break;
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

    getState(): Promise<KallaxResult<ElectionState>> {
      return Promise.resolve(ok({ ...state }));
    },

    startAutoRenew(): KallaxResult<() => void> {
      if (renewTimer) {
        return err(new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'auto-renew already started'));
      }
      renewTimer = setInterval(() => {
        if (state.isMaster) {
          void (async (): Promise<void> => {
            const result = await this.renew();
            if (result.isErr()) logger.error({ error: result.error.message }, 'auto-renew failed');
          })();
        }
      }, renewIntervalMs);
      logger.info({ intervalMs: renewIntervalMs }, 'auto-renew started');
      const stop = (): void => { if (renewTimer) { clearInterval(renewTimer); renewTimer = null; } };
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
