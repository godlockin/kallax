/**
 * KALLAX Instance Registry
 * Track and manage Conductor/Performer instances
 *
 * EPIC-054-B: 升级 TTL 30s → 7d (Resource Management 硬要求)
 *   - instanceCache TTL = 7 * 24 * 60 * 60 * 1000 ms (7 天)
 *   - register() 检查 lastHeartbeat, 超 7 天自动 unregister 老实例
 *   - markInstancesByTTL(thresholdMs) 新增 — LRU 排序 + 超 threshold unregister
 *   - 跟 scripts/instance/cleanup.sh 联动 (shell 层 + node 层双覆盖)
 */

import * as os from 'node:os';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Instance, InstanceRole, InstanceStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { createCache, type Cache } from './cache-layer.js';
import type { SQLiteManager } from './sqlite/index.js';

// EPIC-054-B: TTL 7 days = 604,800,000 ms (was 30s)
export const INSTANCE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
export const INSTANCE_CACHE_MAX = 100;
// Protected roles that survive TTL expiry (conductor/master are precious)
export const PROTECTED_ROLES: ReadonlySet<InstanceRole | string> = new Set(['conductor', 'master']);

export interface InstanceRegistry {
  register: (role: InstanceRole, capabilities?: string[]) => Promise<KallaxResult<Instance>>;
  unregister: (instanceId: string) => Promise<KallaxResult<void>>;
  updateStatus: (instanceId: string, status: InstanceStatus) => Promise<KallaxResult<void>>;
  heartbeat: (instanceId: string) => Promise<KallaxResult<void>>;
  getById: (instanceId: string) => Promise<KallaxResult<Instance | null>>;
  listByRole: (role: InstanceRole) => Promise<KallaxResult<Instance[]>>;
  listActive: () => Promise<KallaxResult<Instance[]>>;
  markStaleInstances: (thresholdMs: number) => Promise<KallaxResult<Instance[]>>;
  markInstancesByTTL: (thresholdMs: number) => Promise<KallaxResult<Instance[]>>;
  getCurrentInstance: () => Instance | null;
}

function generateInstanceId(): string {
  return `inst_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createInstanceRegistry(db: SQLiteManager): InstanceRegistry {
  let currentInstance: Instance | null = null;

  // EPIC-054-B: TTL 30s → 7d (Resource Management 硬要求)
  // 7 天覆盖典型周末 + 短假, 平衡"及时清理僵尸" vs "误删活跃 session"
  const instanceCache: Cache<string, Instance> = createCache('instance-registry', {
    max: INSTANCE_CACHE_MAX,
    ttlMs: INSTANCE_TTL_MS,
    updateAgeOnGet: true,
  });

  return {
    async register(role, capabilities = []): Promise<KallaxResult<Instance>> {
      const now = Date.now();

      // EPIC-054-B: register 前先扫 TTL 过期实例 (RLU 自我清理)
      // 跟 scripts/instance/cleanup.sh 联动 — node 层 + shell 层双覆盖
      const staleResult = db.listInstances();
      if (staleResult.isOk()) {
        const stale = staleResult.value.filter((i) => {
          const ageMs = now - i.lastHeartbeat;
          return ageMs > INSTANCE_TTL_MS && !PROTECTED_ROLES.has(i.role);
        });
        if (stale.length > 0) {
          logger.info(
            { count: stale.length, thresholdMs: INSTANCE_TTL_MS },
            'EPIC-054-B: sweeping TTL-expired instances before register'
          );
          for (const old of stale) {
            const updateResult = db.updateInstance(old.id, { status: 'error' });
            if (updateResult.isOk()) {
              instanceCache.delete(old.id);
              logger.warn(
                { instanceId: old.id, lastHeartbeat: old.lastHeartbeat },
                'EPIC-054-B: instance auto-unregistered (>7d no heartbeat)'
              );
            }
          }
        }
      }

      const instance: Instance = {
        id: generateInstanceId(),
        role,
        status: 'initializing',
        hostname: os.hostname(),
        pid: process.pid,
        startedAt: now,
        lastHeartbeat: now,
        currentTaskId: null,
        capabilities,
      };

      const regResult = db.registerInstance(instance);
      if (regResult.isErr()) {
        return err(regResult.error);
      }

      instanceCache.set(instance.id, instance, INSTANCE_TTL_MS);
      currentInstance = instance;

      logger.info(
        { instanceId: instance.id, role, hostname: instance.hostname, pid: instance.pid },
        'instance registered'
      );

      return ok(instance);
    },

    async unregister(instanceId): Promise<KallaxResult<void>> {
      const result = db.updateInstance(instanceId, { status: 'shutdown' });
      if (result.isErr()) {
        return result;
      }

      instanceCache.delete(instanceId);
      if (currentInstance?.id === instanceId) {
        currentInstance = null;
      }

      logger.info({ instanceId }, 'instance unregistered');
      return ok(undefined);
    },

    async updateStatus(instanceId, status): Promise<KallaxResult<void>> {
      const result = db.updateInstance(instanceId, { status });
      if (result.isErr()) {
        return result;
      }

      const cached = instanceCache.get(instanceId);
      if (cached !== undefined) {
        instanceCache.set(instanceId, { ...cached, status });
      }

      if (currentInstance?.id === instanceId) {
        currentInstance = { ...currentInstance, status };
      }

      logger.debug({ instanceId, status }, 'instance status updated');
      return ok(undefined);
    },

    async heartbeat(instanceId): Promise<KallaxResult<void>> {
      const now = Date.now();
      const result = db.updateHeartbeat(instanceId);
      if (result.isErr()) {
        return result;
      }

      const cached = instanceCache.get(instanceId);
      if (cached !== undefined) {
        instanceCache.set(instanceId, { ...cached, lastHeartbeat: now });
      }

      if (currentInstance?.id === instanceId) {
        currentInstance = { ...currentInstance, lastHeartbeat: now };
      }

      logger.debug({ instanceId }, 'heartbeat recorded');
      return ok(undefined);
    },

    async getById(instanceId): Promise<KallaxResult<Instance | null>> {
      // Check cache first
      const cached = instanceCache.get(instanceId);
      if (cached !== undefined) {
        return ok(cached);
      }

      const result = db.getInstance(instanceId);
      if (result.isOk() && result.value !== null) {
        instanceCache.set(instanceId, result.value);
      }

      return result;
    },

    async listByRole(role): Promise<KallaxResult<Instance[]>> {
      return db.listInstances({ role });
    },

    async listActive(): Promise<KallaxResult<Instance[]>> {
      const result = db.listInstances();
      if (result.isErr()) {
        return result;
      }

      const active = result.value.filter(
        (i) => i.status !== 'shutdown' && i.status !== 'error'
      );
      return ok(active);
    },

    async markStaleInstances(thresholdMs): Promise<KallaxResult<Instance[]>> {
      const staleResult = db.getStaleInstances(thresholdMs);
      if (staleResult.isErr()) {
        return staleResult;
      }

      for (const instance of staleResult.value) {
        const updateResult = db.updateInstance(instance.id, { status: 'error' });
        if (updateResult.isErr()) {
          logger.warn({ instanceId: instance.id }, 'failed to mark instance as stale');
        } else {
          instanceCache.delete(instance.id);
          logger.warn(
            { instanceId: instance.id, lastHeartbeat: instance.lastHeartbeat },
            'marked instance as stale'
          );
        }
      }

      return ok(staleResult.value);
    },

    /**
     * EPIC-054-B: LRU 排序 + 超 thresholdMs unregister
     * 跟 scripts/instance/cleanup.sh 语义一致 — protected roles 优先保留
     * Sort by lastHeartbeat asc (oldest first = LRU victim first)
     */
    async markInstancesByTTL(thresholdMs): Promise<KallaxResult<Instance[]>> {
      const listResult = db.listInstances();
      if (listResult.isErr()) {
        return listResult;
      }

      const now = Date.now();
      // Filter: lastHeartbeat 超 threshold 且 role 非 protected
      const candidates = listResult.value.filter((i) => {
        const ageMs = now - i.lastHeartbeat;
        const expired = ageMs > thresholdMs;
        const protectedRole = PROTECTED_ROLES.has(i.role);
        return expired && !protectedRole;
      });

      // LRU 排序: 按 lastHeartbeat 升序 (oldest first)
      candidates.sort((a, b) => a.lastHeartbeat - b.lastHeartbeat);

      const removed: Instance[] = [];
      for (const instance of candidates) {
        const updateResult = db.updateInstance(instance.id, { status: 'error' });
        if (updateResult.isErr()) {
          logger.warn({ instanceId: instance.id }, 'failed to mark TTL-expired instance');
          continue;
        }
        instanceCache.delete(instance.id);
        removed.push(instance);
        logger.warn(
          {
            instanceId: instance.id,
            role: instance.role,
            lastHeartbeat: instance.lastHeartbeat,
            ageMs: now - instance.lastHeartbeat,
          },
          'EPIC-054-B: marked instance as TTL-expired (7d)'
        );
      }

      return ok(removed);
    },

    getCurrentInstance(): Instance | null {
      return currentInstance;
    },
  };
}
