# Ticket Schema — jira/tickets/*/ticket.json

> EPIC-118-B | v3.24.0 | Anthropic verified success dual evidence 借鉴

## 完整字段清单

```typescript
interface Ticket {
  // 身份
  id: string;                    // e.g. "EPIC-040-TASK-001"
  epicId: string;                // e.g. "EPIC-040"
  ticketId?: string;             // e.g. "TASK-001" (EPIC 内唯一)

  // 状态
  status: TicketStatus;
  type: TicketType;
  priority: 'P0' | 'P1' | 'P2' | 'P3';

  // 关联
  performer: string | null;       // performer instance id, e.g. "performer-EPIC-040-TASK-001@host"
  reviewer?: string;               // master 或指定 reviewer

  // 时间戳
  created_at: string;              // ISO 8601, e.g. "2026-06-12T00:00:00Z"
  assigned_at: string | null;     // ISO 8601, performer 认领时刻
  updated_at?: string;            // ISO 8601, 最后修改

  // PR / 代码交付 (EPIC-118-B 新增)
  pr_url: string | null;          // GitHub PR URL, e.g. "https://github.com/godlockin/kallax/pull/42"
  pr_number?: number;             // PR number (与 pr_url 二选一)
  verified_commit_sha: string | null; // PR merge commit SHA (master merge 后填, dual evidence 第二证)

  // Mastery (EPIC-118-B 新增)
  mastery_level: MasteryLevel | null; // performer 专属度: L1=novice / L2=intermediate / L3=expert

  // Scope
  file_scope: {
    includes: string[];
    excludes?: string[];
  };

  // 其他
  blocked_by?: string[];          // 依赖的 ticket id 列表
  parent?: string;                // 上级 ticket (如 EPIC-040 是 EPIC-038 的子)
}
```

## 枚举

```typescript
type TicketStatus =
  | 'backlog'      // 未开始
  | 'claimed'      // performer 认领, 未开始
  | 'in_progress'  // 开发中
  | 'in_review'    // PR open, 等待 merge
  | 'done'         // PR merged, 验收通过
  | 'failed'       // 失败, 需重启
  | 'abandoned';   // 超 48h 无 PR (系统填, 非人工)

type MasteryLevel =
  | 'L1'   // Novice: 需要每个子任务验证, checkpoints 密集
  | 'L2'   // Intermediate: 里程碑验证, moderate autonomy
  | 'L3';  // Expert: 只验收最终 PR, high autonomy
```

## 字段说明

### verified_commit_sha (EPIC-118-B 新增)

**用途**: Anthropic verified success dual evidence 第二证。

KALLAX 之前只检查 `status=done`，但 status 可被 performer 手动填假。verified_commit_sha 是 GitHub merge commit SHA，只能通过 GitHub API 获取，无法伪造。

**填值时机**: Master 执行 `gh pr merge` 之后，ticket.json 自动更新 `verified_commit_sha` 字段。

**验证逻辑**:
```
verified_success = status == "done" AND verified_commit_sha != null
```

### mastery_level (EPIC-118-B 新增)

**用途**: expertise-aware dispatch 差异化 checkpoints。

| Level | Performer 类型 | Checkpoints | Anthropic 对应 |
|-------|---------------|-------------|---------------|
| L1 | 新手, 历史上 abandonment > 15% | 每子任务必验证 | Novice (19% abandonment) |
| L2 | 有经验, abandonment 5-15% | 里程碑验证 | Intermediate |
| L3 | 专家, abandonment < 5% | 只验收最终 PR | Expert (5-7% abandonment) |

**填值时机**: Conductor 在派单时根据 performer 历史 abandonment_rate 动态判定，或 Master 手动 override。

## 弃用字段

- `performer_instance_id` → 统一用 `performer` (instance id 格式)
