# Auditor Role Specification

> **Role ID**: auditor
> **Inherits**: readonly
> **Priority**: P1 (合规要求)
> **Created**: 2026-06-07
> **Source**: `confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2`

---

## 角色概述

Auditor 角色提供只读访问 + 审计导出能力。用于合规审查、安全审计、 incident postmortem。

## 权限 Grants

| Action | 允许 | 说明 |
|--------|------|------|
| `*.read` | ✅ | 读取所有资源 |
| `audit.export` | ✅ | 导出审计日志 |
| `instance.read` | ✅ | 读取 instance 状态 |
| `log.read` | ✅ | 读取操作日志 |
| `ticket.read` | ✅ | 读取 ticket 信息 |
| `worktree.read` | ✅ | 读取 worktree 内容 |
| `*.write` | ❌ | 禁止写入 |
| `*.merge` | ❌ | 禁止合并 |
| `instance.terminate` | ❌ | 禁止终止 instance |
| `authz.modify` | ❌ | 禁止修改权限 |

## 约束 Constraints

1. **只读强化**: 所有写操作必须 fail-closed (exit 1)
2. **审计追踪**: 所有 action 记录到 `.kallax/data/authz.db`
3. **TTL**: 无 delegation TTL (auditor 是静态 role)
4. **继承readonly**: auditor 继承所有 readonly 限制

## 使用场景

- 安全 review
- 合规审计
- Incident postmortem
- 性能分析

## 实现要求

```typescript
// src/permissions/roles/auditor.ts
const AUDITOR_GRANTS = ['*.read', 'audit.export', 'instance.read', 'log.read'];
const AUDITOR_DENIES = ['*.write', '*.merge', 'instance.terminate', 'authz.modify'];
```

## 验证命令

```bash
kallax role:check audit.export  # → ALLOWED
kallax role:check instance.terminate  # → DENIED
```

## 与其他角色关系

```
master (full grants)
  └── conductor (testing.merge, task.assign)
        └── performer (task.claim, worktree.create)
              └── readonly (*.read)
                    └── auditor (*.read + audit.export)
                          └── super-admin (authz.modify)
                                └── emergency-responder (instance.terminate)
```

---

**P0 修复项** (内置于此 spec):
- fail-closed: audit export 失败时 deny
- set -euo pipefail
- role 名称 validation