/**
 * KALLAX Instance Registry
 * Track and manage Conductor/Performer instances
 */

import * as os from 'node:os';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Instance, InstanceRole, InstanceStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { createCache, type Cache } from './cache-layer.js';
import type { SQLiteManager } from './sqlite-manager.js';

export interface InstanceRegistry {
  register: (role: InstanceRole, capabilities?: string[]) => Promise<KallaxResult<Instance>>;
  unregister: (instanceId: string) => Promise<KallaxResult<void>>;
  updateStatus: (instanceId: string, status: InstanceStatus) => Promise<KallaxResult<void>>;
  heartbeat: (instanceId: string) => Promise<KallaxResult<void>>;
  getById: (instanceId: string) => Promise<KallaxResult<Instance | null>>;
  listByRole: (role: InstanceRole) => Promise<KallaxResult<Instance[]>>;
  listActive: () => Promise<KallaxResult<Instance[]>>;
  markStaleInstances: (thresholdMs: number) => Promise<KallaxResult<Instance[]>>;
  getCurrentInstance: () => Instance | null;
}

function generateInstanceId(): string {
  return `inst_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createInstanceRegistry(db: SQLiteManager): InstanceRegistry {
  let currentInstance: Instance | null = null;

  // Local cache for faster lookups
  const instanceCache: Cache<string, Instance> = createCache('instance-registry', {
    max: 100,
    ttlMs: 30000, // 30 seconds
  });

  return {
    async register(role, capabilities = []): Promise<KallaxResult<Instance>> {
      const now = Date.now();
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

      instanceCache.set(instance.id, instance);
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

    getCurrentInstance(): Instance | null {
      return currentInstance;
    },
  };
}
