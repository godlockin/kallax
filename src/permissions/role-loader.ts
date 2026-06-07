/**
 * Role Loader — 运行时加载 + 验证角色定义
 *
 * P0 修复项:
 * - fail-closed: 任何错误 exit 1 deny
 * - set -euo pipefail (bash 层)
 * - role 名称 validation (防 trailing space, typo)
 * - 循环继承检测
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §4
 */

import * as fs from 'fs';
import * as path from 'path';
import { PermissionsSchema, Role, RoleBinding } from './permissions-schema.js';

export class RoleLoader {
  private schema: PermissionsSchema | null = null;
  private bindings: RoleBinding[] = [];
  private cache: Map<string, { grants: string[]; denies: string[] }> = new Map();

  constructor(
    private configPath: string = '.kallax/config/permissions.yml',
    private bindingPath: string = '.kallax/data/role-bindings.json'
  ) {}

  /**
   * 加载并验证权限配置
   * fail-closed: 任何解析错误 throws Error
   */
  load(): void {
    try {
      // 加载 schema
      const schemaContent = fs.readFileSync(this.configPath, 'utf-8');
      this.schema = this.parseYaml(schemaContent);

      // 验证 schema
      this.validateSchema();

      // 加载 bindings
      if (fs.existsSync(this.bindingPath)) {
        const bindingContent = fs.readFileSync(this.bindingPath, 'utf-8');
        this.bindings = JSON.parse(bindingContent);
      }

      // 清空缓存
      this.cache.clear();
    } catch (e: unknown) {
      // P0: fail-closed — 任何错误 deny
      const message = e instanceof Error ? e.message : 'Unknown error';
      throw new Error(`Role load failed: ${message}`);
    }
  }

  /**
   * 获取角色权限
   * @param roleName 角色名
   * @returns { grants: string[], denies: string[] }
   */
  getRolePermissions(roleName: string): { grants: string[]; denies: string[] } {
    // 检查缓存
    if (this.cache.has(roleName)) {
      return this.cache.get(roleName)!;
    }

    if (!this.schema) {
      throw new Error('Schema not loaded. Call load() first.');
    }

    // 验证 role 名称 (P0: 防 trailing space, typo)
    this.validateRoleName(roleName);

    const role = this.schema.roles[roleName];
    if (!role) {
      throw new Error(`Role not found: ${roleName}`);
    }

    // 收集所有 grants (包括 inherited)
    const grants = new Set<string>(role.grants || []);
    const denies = new Set<string>(role.denies || []);

    // 处理继承
    if (role.inherits) {
      const parent = this.getRolePermissions(role.inherits);
      parent.grants.forEach(g => grants.add(g));
      parent.denies.forEach(d => denies.add(d));

      // P0: 循环继承检测
      this.detectCycle(roleName, new Set([roleName]));
    }

    const result = {
      grants: Array.from(grants),
      denies: Array.from(denies)
    };

    this.cache.set(roleName, result);
    return result;
  }

  /**
   * 检查是否有权限执行 action
   * @param roleName 角色名
   * @param action 操作 (e.g., 'task.claim', '*.write')
   * @returns boolean
   */
  can(roleName: string, action: string): boolean {
    const { grants, denies } = this.getRolePermissions(roleName);

    // 检查 explicit deny
    if (denies.some(d => this.matchAction(d, action))) {
      return false;
    }

    // 检查 grant
    if (grants.some(g => this.matchAction(g, action))) {
      return true;
    }

    // 默认 deny (fail-closed)
    return false;
  }

  /**
   * 获取用户的所有 role bindings
   */
  getBindingsForUser(userId: string): RoleBinding[] {
    const now = new Date();
    return this.bindings.filter(b =>
      b.subject_id === userId &&
      b.status === 'active' &&
      (b.expires_at === null || new Date(b.expires_at) > now)
    );
  }

  /**
   * 检查 binding 是否有效
   */
  isBindingValid(bindingId: string): boolean {
    const binding = this.bindings.find(b => b.id === bindingId);
    if (!binding || binding.status !== 'active') {
      return false;
    }
    if (binding.expires_at && new Date(binding.expires_at) < new Date()) {
      return false;
    }
    return true;
  }

  // === Private methods ===

  private parseYaml(content: string): PermissionsSchema {
    // 简化的 YAML 解析 (实际应使用 yaml 库)
    // P0: 此处应加 try/catch + fail-closed
    try {
      const lines = content.split('\n');
      const schema: PermissionsSchema = { roles: {}, scope_bindings: {}, action_grants: [] };
      let currentSection: 'roles' | 'scope_bindings' | 'action_grants' | null = null;

      for (const line of lines) {
        if (line.startsWith('roles:')) {
          currentSection = 'roles';
        } else if (line.startsWith('scope_bindings:')) {
          currentSection = 'scope_bindings';
        } else if (line.startsWith('action_grants:')) {
          currentSection = 'action_grants';
        } else if (currentSection === 'roles' && line.includes(':')) {
          const [key, value] = line.split(':').map(s => s.trim());
          if (key && value) {
            schema.roles[key] = this.parseRoleValue(value);
          }
        }
      }

      return schema;
    } catch (e: unknown) {
      throw new Error(`YAML parse failed: ${e instanceof Error ? e.message : 'Unknown'}`);
    }
  }

  private parseRoleValue(value: string): Role {
    // 解析 "inherits: conductor, grants: [a, b]"
    const role: Role = { inherits: null, grants: [], denies: [] };

    const parts = value.split(',').map(p => p.trim());
    for (const part of parts) {
      if (part.startsWith('inherits:')) {
        role.inherits = part.replace('inherits:', '').trim();
      } else if (part.startsWith('grants:')) {
        const grantsStr = part.replace('grants:', '').replace(/[\[\]]/g, '');
        role.grants = grantsStr.split(' ').filter(s => s);
      } else if (part.startsWith('denies:')) {
        const deniesStr = part.replace('denies:', '').replace(/[\[\]]/g, '');
        role.denies = deniesStr.split(' ').filter(s => s);
      }
    }

    return role;
  }

  private validateSchema(): void {
    if (!this.schema) {
      throw new Error('Schema is null');
    }

    // 验证每个 role 的继承不形成循环
    for (const roleName of Object.keys(this.schema.roles)) {
      this.detectCycle(roleName, new Set());
    }
  }

  private validateRoleName(roleName: string): void {
    // P0: 防 trailing space, typo
    // 正则: 小写字母开头, 后续小写字母/数字/连字符
    const validPattern = /^[a-z][a-z0-9-]*$/;

    if (!validPattern.test(roleName)) {
      throw new Error(`Invalid role name: "${roleName}". Must match ^[a-z][a-z0-9-]*$`);
    }

    // 检查是否为已知 role
    if (this.schema && !this.schema.roles[roleName]) {
      throw new Error(`Unknown role: ${roleName}`);
    }
  }

  private detectCycle(roleName: string, visited: Set<string>): void {
    if (!this.schema) return;

    const role = this.schema.roles[roleName];
    if (!role || !role.inherits) return;

    if (visited.has(role.inherits)) {
      throw new Error(`Circular inheritance detected: ${roleName} → ${role.inherits}`);
    }

    visited.add(role.inherits);
    this.detectCycle(role.inherits, visited);
  }

  private matchAction(pattern: string, action: string): boolean {
    // 支持通配符: *.read, task.*
    if (pattern === '*') return true;
    if (pattern === action) return true;

    const patternParts = pattern.split('.');
    const actionParts = action.split('.');

    // 逐段匹配
    for (let i = 0; i < patternParts.length; i++) {
      if (patternParts[i] === '*') {
        // 通配符匹配剩余部分
        return true;
      }
      if (patternParts[i] !== actionParts[i]) {
        return false;
      }
    }

    return patternParts.length === actionParts.length;
  }
}

// === CLI Commands ===

export function createRoleLoader(): RoleLoader {
  const loader = new RoleLoader();
  loader.load();
  return loader;
}

// CLI entry points
export async function roleList(): Promise<void> {
  const loader = createRoleLoader();
  console.log('Available roles:');
  for (const [name, role] of Object.entries(loader['schema']!.roles)) {
    const inherits = role.inherits ? ` (inherits ${role.inherits})` : '';
    console.log(`  - ${name}${inherits}`);
  }
}

export async function roleWhoami(): Promise<void> {
  const loader = createRoleLoader();
  // 从环境变量或 state.json 获取当前 role
  const currentRole = process.env['KALLAX_CURRENT_ROLE'] || 'unknown';
  const permissions = loader.getRolePermissions(currentRole);
  console.log(`Current role: ${currentRole}`);
  console.log(`Grants: ${permissions.grants.join(', ')}`);
  console.log(`Denies: ${permissions.denies.join(', ')}`);
}

export async function roleCheck(action: string): Promise<void> {
  const loader = createRoleLoader();
  const currentRole = process.env['KALLAX_CURRENT_ROLE'] || 'unknown';

  if (loader.can(currentRole, action)) {
    console.log(`ALLOWED: ${action} for role ${currentRole}`);
    process.exit(0);
  } else {
    console.log(`DENIED: ${action} for role ${currentRole}`);
    process.exit(1); // P0: fail-closed
  }
}