/**
 * Unit tests for RoleLoader
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §4
 *
 * P0 测试项:
 * - fail-closed: 任何错误 deny
 * - role 名称 validation
 * - 循环继承检测
 */

import { RoleLoader } from '../../src/permissions/role-loader';
import { DEFAULT_ROLES } from '../../src/permissions/permissions-schema';

describe('RoleLoader', () => {
  let loader: RoleLoader;

  beforeEach(() => {
    loader = new RoleLoader(
      '.kallax/config/authz.yml',
      '.kallax/data/role-bindings.json'
    );
    // Mock fs.readFileSync
    jest.spyOn(require('fs'), 'readFileSync').mockImplementation((path: string) => {
      if (path.includes('authz.yml')) {
        return `
roles:
  master:       { inherits: conductor, grants: [miao.write, miao.merge] }
  conductor:    { inherits: null,     grants: [testing.merge] }
  performer:    { inherits: null,     grants: [task.claim] }
  readonly:     { inherits: null,     grants: [*.read], denies: [*.write] }
  auditor:      { inherits: readonly, grants: [audit.export] }
  broken-cycle: { inherits: broken-cycle, grants: [] }
scope_bindings:
  EPIC-022-A:
    allowed_paths: ["jira/tickets/EPIC-022-A/**"]
    ttl_seconds: 10800
action_grants: []
`;
      }
      return '[]';
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('load()', () => {
    it('should load schema without error', () => {
      expect(() => loader.load()).not.toThrow();
    });
  });

  describe('getRolePermissions()', () => {
    it('should return grants and denies for valid role', () => {
      loader.load();
      const perms = loader.getRolePermissions('readonly');
      expect(perms.grants).toContain('*.read');
      expect(perms.denies).toContain('*.write');
    });

    it('should throw on unknown role', () => {
      loader.load();
      expect(() => loader.getRolePermissions('unknown-role')).toThrow('Unknown role');
    });

    it('should throw on invalid role name (trailing space)', () => {
      loader.load();
      // Role name validation happens in getRolePermissions
      expect(() => loader.getRolePermissions('conductor ')).toThrow();
    });

    it('should detect circular inheritance', () => {
      loader.load();
      expect(() => loader.getRolePermissions('broken-cycle')).toThrow('Circular inheritance');
    });
  });

  describe('can()', () => {
    beforeEach(() => loader.load());

    it('should return true for allowed action', () => {
      expect(loader.can('readonly', 'ticket.read')).toBe(true);
    });

    it('should return false for denied action', () => {
      expect(loader.can('readonly', '*.write')).toBe(false);
    });

    it('should return false for unknown action (fail-closed)', () => {
      expect(loader.can('readonly', 'instance.terminate')).toBe(false);
    });

    it('should support wildcard matching', () => {
      expect(loader.can('readonly', 'anything.read')).toBe(true);
    });
  });

  describe('getBindingsForUser()', () => {
    it('should return active bindings for user', () => {
      loader.load();
      // Mock bindings are empty, so test returns empty array
      const bindings = loader.getBindingsForUser('conductor');
      expect(Array.isArray(bindings)).toBe(true);
    });
  });

  describe('isBindingValid()', () => {
    it('should return false for unknown binding', () => {
      loader.load();
      expect(loader.isBindingValid('unknown')).toBe(false);
    });
  });
});

describe('DEFAULT_ROLES', () => {
  it('should contain all required roles', () => {
    const requiredRoles = ['master', 'conductor', 'performer', 'readonly', 'auditor'];
    requiredRoles.forEach(role => {
      expect(DEFAULT_ROLES[role]).toBeDefined();
    });
  });

  it('should have valid inheritance chain (no cycles for default roles)', () => {
    const visited = new Set<string>();
    for (const roleName of Object.keys(DEFAULT_ROLES)) {
      const chain = new Set<string>();
      let current: string | null = roleName;
      while (current) {
        expect(chain.has(current)).toBe(false); // Would indicate cycle
        chain.add(current);
        current = DEFAULT_ROLES[current]?.inherits || null;
      }
    }
  });
});