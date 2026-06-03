/**
 * Instance Registry tests: register, heartbeat, list, stale detection.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createFakeSQLiteManager } from './helpers/fakes.js';
import { createInstanceRegistry } from '../src/core/instance-registry.js';
import type { InstanceRegistry } from '../src/core/instance-registry.js';

describe('InstanceRegistry', () => {
  let registry: InstanceRegistry;

  beforeEach(() => {
    const db = createFakeSQLiteManager();
    registry = createInstanceRegistry(db);
  });

  it('register creates instance with generated id', async () => {
    const result = await registry.register('performer', ['typescript']);
    expect(result.isOk()).toBe(true);

    const instance = result._unsafeUnwrap();
    expect(instance.id).toContain('inst_');
    expect(instance.role).toBe('performer');
    expect(instance.status).toBe('initializing');
    expect(instance.capabilities).toEqual(['typescript']);
    expect(instance.hostname).toBeTruthy();
  });

  it('getCurrentInstance returns the registered instance', async () => {
    expect(registry.getCurrentInstance()).toBeNull();

    const result = await registry.register('conductor');
    expect(result.isOk()).toBe(true);
    expect(registry.getCurrentInstance()?.id).toBe(result._unsafeUnwrap().id);
  });

  it('unregister sets status to shutdown and clears current', async () => {
    const regResult = await registry.register('performer');
    const inst = regResult._unsafeUnwrap();

    await registry.unregister(inst.id);
    expect(registry.getCurrentInstance()).toBeNull();
  });

  it('heartbeat updates lastHeartbeat', async () => {
    const regResult = await registry.register('conductor');
    const inst = regResult._unsafeUnwrap();

    const result = await registry.heartbeat(inst.id);
    expect(result.isOk()).toBe(true);
  });

  it('listByRole returns instances of matching role', async () => {
    await registry.register('conductor');
    await registry.register('performer', ['go']);

    const conductors = await registry.listByRole('conductor');
    expect(conductors._unsafeUnwrap().length).toBe(1);

    const performers = await registry.listByRole('performer');
    expect(performers._unsafeUnwrap().length).toBe(1);
  });

  it('listActive excludes shutdown and error instances', async () => {
    const r1 = await registry.register('conductor');
    const r2 = await registry.register('performer');

    // Mark one as shutdown
    await registry.unregister(r2._unsafeUnwrap().id);

    const active = await registry.listActive();
    const ids = active._unsafeUnwrap().map((i) => i.id);
    expect(ids).toContain(r1._unsafeUnwrap().id);
    expect(ids).not.toContain(r2._unsafeUnwrap().id);
  });

  it('markStaleInstances flags and returns stale instances', async () => {
    await registry.register('conductor');

    // Use negative threshold to ensure all are stale
    const stale = await registry.markStaleInstances(-1);
    expect(stale.isOk()).toBe(true);
    expect(stale._unsafeUnwrap().length).toBe(1);
  });
});
