# Readonly Role Specification

> **Role ID**: readonly
> **Inherits**: null
> **Priority**: P0 (零风险, 纯加)
> **Created**: 2026-06-07
> **Source**: `confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2`

---

## 角色概述

Readonly 角色限制所有写操作。零冲突, 纯加权限。用于 stakeholder 查看、observer 模式。

## 权限 Grants

| Action | 允许 | 说明 |
|--------|------|------|
| `*.read` | ✅ | 读取所有资源 |
| `ticket.read` | ✅ | 读取 ticket 信息 |
| `worktree.read` | ✅ | 读取 worktree 内容 |
| `instance.read` | ✅ | 读取 instance 状态 |
| `log.read` | ✅ | 读取操作日志 |
| `*.write` | ❌ | 禁止写入 |
| `*.commit` | ❌ | 禁止提交 |
| `*.merge` | ❌ | 禁止合并 |
| `task.claim` | ❌ | 禁止领取任务 |
| `worktree.create` | ❌ | 禁止创建 worktree |

## 约束 Constraints

1. **只读强化**: 所有写操作必须 fail-closed (exit 1)
2. **无继承**: readonly 不继承任何 role
3. **TTL**: 无 delegation TTL (readonly 是静态 role)

## 拒绝场景 (Explicit Deny)

```bash
# 以下操作被明确拒绝
kallax task:claim TASK-001      # → DENIED (task.claim)
kallax workspace:switch conductor # → DENIED (workspace.switch requires conductor+)
git commit -m "fix"              # → DENIED (*.commit)
gh pr merge                      # → DENIED (*.merge)
```

## 使用场景

- Stakeholder review
- Observer mode
- Read-only audit
- Guest access

## 实现要求

```typescript
// src/permissions/roles/readonly.ts
const READONLY_GRANTS = ['*.read', 'ticket.read', 'worktree.read', 'instance.read', 'log.read'];
const READONLY_DENIES = ['*.write', '*.commit', '*.merge', 'task.claim', 'worktree.create'];
```

## 验证命令

```bash
kallax role:check ticket.read   # → ALLOWED
kallax role:check task.claim     # → DENIED
```

## 与其他角色关系

```
readonly ← auditor ← master
readonly ← performer (performer inherits readonly grants)
readonly ← conductor (conductor inherits readonly grants)
```

---

**P0 修复项** (内置于此 spec):
- fail-closed: 任何写操作 deny
- set -euo pipefail
- realpath 执行顺序在前 (防 symlink 绕过)