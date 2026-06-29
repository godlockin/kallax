# Role Binding Specification

> **Schema ID**: role-binding
> **Version**: 1.0
> **Created**: 2026-06-07
> **Source**: `confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.1`

---

## 概述

Role Binding 定义 role ↔ user/group 的绑定关系。支持:
- User-level binding (单一用户)
- Group-level binding (用户组)
- Ticket-scoped binding (单 ticket 权限)
- Session-scoped binding (临时权限)

## Schema

```yaml
# .kallax/config/authz.yml (role_binding section)
role_bindings:
  - id: rb_001                    # 唯一标识
    role: performer               # 绑定到的 role
    subject_type: user           # user | group | service
    subject_id: conductor_StevenMacBook-Pro.local  # 具体 ID
    granted_by: master           # 授权人
    granted_at: "2026-06-07T10:00:00Z"  # 授权时间
    expires_at: "2026-06-07T12:00:00Z"  # 过期时间 (null = 永不过期)
    ticket_scope: EPIC-022-A      # ticket-scoped 限制 (可选)
    reason: "EPIC-022 implementation"  # 授权原因
    status: active               # active | revoked | expired

  - id: rb_002
    role: auditor
    subject_type: group
    subject_id: security-review-team
    granted_by: master
    granted_at: "2026-06-07T00:00:00Z"
    expires_at: null
    ticket_scope: null
    reason: "Security audit access"
    status: active
```

## 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识, 格式 `rb_<6位数字>` |
| `role` | enum | ✅ | master/conductor/performer/auditor/readonly/super-admin/emergency-responder |
| `subject_type` | enum | ✅ | user/group/service |
| `subject_id` | string | ✅ | 具体 ID (username 或 group name) |
| `granted_by` | string | ✅ | 授权人 (role 或 user) |
| `granted_at` | ISO8601 | ✅ | 授权时间 |
| `expires_at` | ISO8601 | ❌ | 过期时间, null = 永不过期 |
| `ticket_scope` | string | ❌ | ticket-scoped 限制, null = 全局 |
| `reason` | string | ✅ | 授权原因 (audit 必需) |
| `status` | enum | ✅ | active/revoked/expired |

## 验证规则

1. **Role 名称 validation**:
   - 不允许 trailing space (`conductor ` → reject)
   - 不允许 typo (`condctor` → reject)
   - 使用正则: `^[a-z][a-z0-9-]*$`

2. **循环继承检测**:
   ```
   A inherits B, B inherits A → REJECT
   ```

3. **过期检测**:
   - `expires_at` < now → status = expired
   - expired binding 不能用于任何 action

4. **权限检查顺序**:
   ```
   1. 检查 binding 存在
   2. 检查 status = active
   3. 检查 expires_at > now (或 null)
   4. 检查 role has permission
   5. 检查 ticket_scope 匹配 (如适用)
   ```

## Ticket-Scoped Binding

```yaml
# EPIC-022-A scoped performer
role_bindings:
  - id: rb_003
    role: performer
    subject_type: user
    subject_id: performer-EPIC-022
    granted_by: conductor
    granted_at: "2026-06-07T10:00:00Z"
    expires_at: "2026-06-07T18:00:00Z"  # 8h work day
    ticket_scope: EPIC-022-A  # 仅 EPIC-022-A ticket
    reason: "EPIC-022-A implementation"
    status: active
```

## CLI 操作

```bash
# 列出所有 binding
kallax role:binding:list

# 列出用户的 binding
kallax role:binding:list --user conductor_StevenMacBook-Pro.local

# 授予 binding
kallax role:binding:grant --role performer --user performer-EPIC-022 --ticket EPIC-022-A --ttl 8h

# 撤销 binding
kallax role:binding:revoke --id rb_003

# 检查 binding 有效性
kallax role:binding:check --user performer-EPIC-022 --action task.claim
```

---

**P0 修复项** (内置于此 spec):
- fail-closed: binding 不存在 → deny
- set -euo pipefail
-循环继承检测