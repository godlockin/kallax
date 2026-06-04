/**
 * Role Selector tests: env detection, file config, auto-detect fallback.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createRoleSelector } from '../src/core/role-selector.js';
import { InstanceRole } from '../src/types/index.js';

describe('RoleSelector', () => {
  let selector: ReturnType<typeof createRoleSelector>;

  beforeEach(() => { selector = createRoleSelector(); });

  afterEach(() => { delete process.env['KALLAX_ROLE']; });

  it('getRoleFromEnv returns conductor from env var', () => {
    process.env['KALLAX_ROLE'] = 'conductor';
    const result = selector.getRoleFromEnv();
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(InstanceRole.CONDUCTOR);
  });

  it('getRoleFromEnv returns performer from env var', () => {
    process.env['KALLAX_ROLE'] = 'performer';
    const result = selector.getRoleFromEnv();
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(InstanceRole.PERFORMER);
  });

  it('getRoleFromEnv returns null when var not set', () => {
    const result = selector.getRoleFromEnv();
    expect(result._unsafeUnwrap()).toBeNull();
  });

  it('getRoleFromEnv returns err for invalid role', () => {
    process.env['KALLAX_ROLE'] = 'invalid';
    const result = selector.getRoleFromEnv();
    expect(result.isErr()).toBe(true);
  });

  it('getRoleFromFile returns null when file missing', async () => {
    const result = await selector.getRoleFromFile('/nonexistent');
    expect(result._unsafeUnwrap()).toBeNull();
  });

  it('detectRole defaults to performer when no env or file', async () => {
    const result = await selector.detectRole('/nonexistent');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().role).toBe(InstanceRole.PERFORMER);
    expect(result._unsafeUnwrap().configSource).toBe('auto');
  });

  it('detectRole prefers env over file', async () => {
    process.env['KALLAX_ROLE'] = 'conductor';
    const result = await selector.detectRole('/some/project');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().configSource).toBe('env');
    expect(result._unsafeUnwrap().role).toBe(InstanceRole.CONDUCTOR);
  });

  it('setRole writes config and returns ok', async () => {
    const result = await selector.setRole('/tmp/test-project', InstanceRole.CONDUCTOR);
    expect(result.isOk()).toBe(true);
  });

  it('detectRole returns RoleConfig with proper shape', async () => {
    process.env['KALLAX_ROLE'] = 'performer';
    const result = await selector.detectRole('/project');
    expect(result._unsafeUnwrap()).toHaveProperty('role');
    expect(result._unsafeUnwrap()).toHaveProperty('configSource');
    expect(result._unsafeUnwrap()).toHaveProperty('configuredAt');
  });
});
