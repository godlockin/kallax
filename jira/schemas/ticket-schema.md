# KALLAX Ticket Schema

## Frontmatter 字段定义

```yaml
---
# 必填字段
id: string              # 格式: TASK-{NNN}
title: string           # 简短标题
type: TaskType          # 任务类型
priority: Priority      # 优先级
status: TicketStatus    # 状态
created_by: string      # 创建者
created_at: date        # 创建时间

# 可选字段
updated_at: date        # 更新时间
performer: string|null  # 执行者 ID
worktree: string|null   # Worktree 路径
dependencies: string[]  # 依赖的其他 Ticket
file_scope:             # 文件范围 (KALLAX 必填)
  includes: string[]    # 包含的文件/目录模式
  excludes: string[]    # 排除的文件/目录模式
acceptance_criteria: string[]  # 接受标准
estimated_hours: number # 预估工时
actual_hours: number    # 实际工时
---
```

## 枚举值

### TaskType (任务类型)

| 值 | 说明 |
|---|---|
| `feature` | 新功能 |
| `bug` | 缺陷修复 |
| `chore` | 杂项任务 |
| `docs` | 文档更新 |
| `test` | 测试任务 |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `security` | 安全修复 |

### Priority (优先级)

| 值 | 说明 |
|---|---|
| `P0` | 紧急 - 阻塞生产 |
| `P1` | 高 - 本迭代必须完成 |
| `P2` | 中 - 本迭代尽量完成 |
| `P3` | 低 - 有空再做 |

### TicketStatus (状态)

```
backlog → analysis → ready → gate_review → in_progress → test → pr_review → done
                                                    ↓
                                                 blocked → unblocked → in_progress
```

| 值 | 说明 | 负责角色 |
|---|---|---|
| `backlog` | 待办池 | - |
| `analysis` | 分析中 | Conductor |
| `ready` | 待领取 | - |
| `gate_review` | 门卡审查 | Conductor |
| `in_progress` | 执行中 | Performer |
| `test` | 测试中 | Performer |
| `pr_review` | PR 审核 | Conductor |
| `done` | 完成 | - |
| `blocked` | 阻塞 | - |

## File Scope 规则 (KALLAX 新增)

### 目的
解决 并行冲突问题，确保多个 Performer 不会同时修改同一文件。

### 格式
```yaml
file_scope:
  includes:
    - src/components/Login/**    # Glob 模式
    - src/hooks/useAuth.ts       # 具体文件
  excludes:
    - src/components/shared/**   # 排除共享目录
```

### 规则
1. **Performer 只能修改 includes 中的文件**
2. **excludes 优先级高于 includes**
3. **Conductor 派发前必须检查范围重叠**
4. **共享文件需要显式协调**

### 检查命令
```bash
kallax isolation:check TASK-001 TASK-002
# 输出:
# ✓ No overlap detected
# 或
# ✗ Overlap detected:
#   - src/utils/helpers.ts (TASK-001 ∩ TASK-002)
```

## 正文结构

```markdown
# TASK-{NNN}: {title}

## 需求描述
[详细描述任务内容]

## 接受标准 (AC)
1. [AC1]
2. [AC2]
...

## 技术方案
[实现方案，可选]

## 测试计划
[测试策略，可选]

## 实现记录
[Performer 填写]

### 开发日志
[过程记录]

### PR 链接
[PR URL]

### 测试结果
[测试输出]

---

## 状态变更历史
| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
```

## 验证规则

### Conductor 创建时
- [ ] id 唯一
- [ ] title 非空
- [ ] type 有效
- [ ] priority 有效
- [ ] acceptance_criteria 非空
- [ ] file_scope.includes 非空 (KALLAX 必填)

### Performer 领取时
- [ ] status == ready
- [ ] performer == null
- [ ] file_scope 不与其他 in_progress 任务重叠

### Performer 完成时
- [ ] 所有 AC 已满足
- [ ] PR 已提交
- [ ] 测试通过
- [ ] 修改仅限于 file_scope
