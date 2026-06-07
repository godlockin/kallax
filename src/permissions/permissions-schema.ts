/**
 * Permissions Schema — KALLAX Permission Model v1
 *
 * 定义角色、scope_bindings、action_grants 的类型
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2
 */

export type RoleId =
  | 'master'
  | 'conductor'
  | 'performer'
  | 'readonly'
  | 'auditor'
  | 'super-admin'
  | 'emergency-responder';

export interface Role {
  inherits: string | null;
  grants: string[];
  denies: string[];
}

export interface ScopeBinding {
  allowed_paths: string[];
  ttl_seconds: number;
}

export interface ActionGrant {
  id: string;
  role: RoleId;
  action: string;
  ticket?: string;
  granted_by: string;
  granted_at: string;
  expires_at: string | null;
  status: 'active' | 'revoked' | 'expired';
}

export interface RoleBinding {
  id: string;
  role: RoleId;
  subject_type: 'user' | 'group' | 'service';
  subject_id: string;
  granted_by: string;
  granted_at: string;
  expires_at: string | null;
  ticket_scope: string | null;
  reason: string;
  status: 'active' | 'revoked' | 'expired';
}

export interface PermissionsSchema {
  roles: Record<string, Role>;
  scope_bindings: Record<string, ScopeBinding>;
  action_grants: ActionGrant[];
}

/**
 * 默认角色定义 (来自 PERMISSION-MODEL.md §2.3)
 */
export const DEFAULT_ROLES: Record<string, Role> = {
  master: {
    inherits: 'conductor',
    grants: ['miao.write', 'miao.merge', 'release.tag', 'instance.gc'],
    denies: []
  },
  conductor: {
    inherits: null,
    grants: ['testing.merge', 'testing.write', 'task.assign'],
    denies: []
  },
  performer: {
    inherits: null,
    grants: ['task.claim', 'worktree.create', 'worktree.commit'],
    denies: []
  },
  readonly: {
    inherits: null,
    grants: ['*.read'],
    denies: ['*.write', '*.commit', '*.merge', 'task.claim', 'worktree.create']
  },
  auditor: {
    inherits: 'readonly',
    grants: ['audit.export', 'instance.read', 'log.read'],
    denies: []
  },
  'super-admin': {
    inherits: 'master',
    grants: ['authz.modify', 'emergency.override'],
    denies: []
  },
  'emergency-responder': {
    inherits: 'super-admin',
    grants: ['instance.terminate'],
    denies: []
  }
};

/**
 * KALLAX Permission JSON Schema (用于验证)
 */
export const KALLAX_PERMISSION_SCHEMA = {
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["roles", "scope_bindings", "action_grants"],
  "properties": {
    "roles": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": {
          "type": "object",
          "required": ["inherits", "grants"],
          "properties": {
            "inherits": {
              "oneOf": [
                { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
                { "type": "null" }
              ]
            },
            "grants": {
              "type": "array",
              "items": { "type": "string" }
            },
            "denies": {
              "type": "array",
              "items": { "type": "string" }
            }
          }
        }
      }
    },
    "scope_bindings": {
      "type": "object",
      "patternProperties": {
        "^EPIC-[0-9]+-[A-Z]$": {
          "type": "object",
          "required": ["allowed_paths", "ttl_seconds"],
          "properties": {
            "allowed_paths": {
              "type": "array",
              "items": { "type": "string" }
            },
            "ttl_seconds": {
              "type": "number",
              "minimum": 60
            }
          }
        }
      }
    },
    "action_grants": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "role", "action", "granted_by", "granted_at", "status"],
        "properties": {
          "id": { "type": "string", "pattern": "^perm_[0-9]+$" },
          "role": {
            "enum": ["master", "conductor", "performer", "readonly", "auditor", "super-admin", "emergency-responder"]
          },
          "action": { "type": "string" },
          "ticket": { "type": "string" },
          "granted_by": { "type": "string" },
          "granted_at": { "type": "string", "format": "date-time" },
          "expires_at": { "oneOf": [{ "type": "string", "format": "date-time" }, { "type": "null" }] },
          "status": { "enum": ["active", "revoked", "expired"] }
        }
      }
    }
  }
};

/**
 * 验证 permissions.yml 配置
 */
export function validatePermissionsConfig(config: unknown): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!config || typeof config !== 'object') {
    return { valid: false, errors: ['Config must be an object'] };
  }

  const cfg = config as PermissionsSchema;

  // 验证 roles
  if (!cfg.roles || typeof cfg.roles !== 'object') {
    errors.push('Missing or invalid roles');
  } else {
    // 验证每个 role 名称
    for (const roleName of Object.keys(cfg.roles)) {
      if (!/^[a-z][a-z0-9-]*$/.test(roleName)) {
        errors.push(`Invalid role name: "${roleName}" (must match ^[a-z][a-z0-9-]*$)`);
      }
    }

    // 检测循环继承
    const visited = new Set<string>();
    for (const roleName of Object.keys(cfg.roles)) {
      const chain = new Set<string>();
      let current: string | null = roleName;

      while (current) {
        if (chain.has(current)) {
          errors.push(`Circular inheritance detected: ${roleName}`);
          break;
        }
        chain.add(current);
        current = cfg.roles[current]?.inherits || null;
      }
    }
  }

  // 验证 scope_bindings
  if (cfg.scope_bindings) {
    for (const [scope, binding] of Object.entries(cfg.scope_bindings)) {
      if (!/^EPIC-[0-9]+-[A-Z]$/.test(scope)) {
        errors.push(`Invalid scope name: "${scope}" (must match EPIC-NNN-X)`);
      }
      if (!Array.isArray(binding.allowed_paths)) {
        errors.push(`scope_bindings.${scope}.allowed_paths must be array`);
      }
      if (typeof binding.ttl_seconds !== 'number' || binding.ttl_seconds < 60) {
        errors.push(`scope_bindings.${scope}.ttl_seconds must be >= 60`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}