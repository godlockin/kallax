# Performer 规则

> KALLAX 执行者行为规范 v1.0

---

## 角色定义

**Performer** (执行者) 是项目的开发者，负责：
- 领取和执行任务
- 编写代码和测试
- 提交 PR
- 响应 Review 反馈

---

## 核心职责

### 1. 领取任务

```bash
kallax task:claim TASK-001
```

**自动执行**:
1. 验证 Ticket 状态 = ready
2. 检查 file_scope 无冲突
3. 创建 Worktree 隔离
4. 更新 Ticket 状态 = in_progress

### 2. 开发执行

**TDD 流程**:
```
1. 写测试（先失败）
2. 写代码（让测试通过）
3. 重构（保持测试通过）
```

**规范**:
- 仅修改 file_scope 内的文件
- 使用结构化日志（禁止 console.log）
- 错误处理使用 Result 模式
- 无 any 类型

### 3. 提交 PR

```bash
kallax task:complete TASK-001
```

**Saga 5 步**:
1. 验证票据有效性
2. 更新状态 → test
3. 运行测试
4. 创建 PR
5. 发布完成事件

**PR 要求**:
- 关联 Ticket ID
- 包含真实测试输出
- 填写 PR 模板

### 4. 响应 Review

```bash
kallax performer:poll
```

**流程**:
1. 阅读 Conductor 反馈
2. 修改代码
3. 重新测试
4. 推送更新
5. 标记 resolved

---

## 9 条硬规则

### 规则 1: 禁止合并到 main

```
❌ git push origin main
❌ git merge feature/xxx --to main

✅ 通过 PR 提交，等待 Conductor 合并
```

**原因**: 保持 main 分支稳定，所有变更需审核

### 规则 2: 禁止自我审查

```
❌ Approve 自己的 PR
❌ 跳过 Review 直接合并

✅ 等待 Conductor 或其他 Performer Review
```

**原因**: 避免偏见，确保代码质量

### 规则 3: 禁止跳过测试

```
❌ --no-verify
❌ 空测试文件
❌ 跳过 CI

✅ 所有功能必须有测试
✅ CI 必须通过
```

**原因**: 测试是质量保证的基础

### 规则 4: 禁止 Magic Number

```typescript
// ❌ 禁止
if (timeout > 30000) { }
const limit = 100;

// ✅ 正确
const TIMEOUT_MS = 30000;
const MAX_ITEMS = 100;

if (timeout > TIMEOUT_MS) { }
const limit = MAX_ITEMS;
```

**原因**: 提高代码可读性和可维护性

### 规则 5: 禁止 console.log

```typescript
// ❌ 禁止
console.log('Task claimed:', taskId);
console.error('Error:', e);

// ✅ 正确
logger.info({ taskId }, 'task claimed');
logger.error({ error: e }, 'operation failed');
```

**原因**: 结构化日志便于查询和分析

### 规则 6: 禁止忽略 Lint 错误

```typescript
// ❌ 禁止
// eslint-disable-next-line
// @ts-ignore

// ✅ 正确
// 修复 lint 错误
// 修复类型错误
```

**原因**: Lint 规则是代码规范的一部分

### 规则 7: 禁止注释掉代码

```typescript
// ❌ 禁止
// function oldImplementation() {
//   return something;
// }

// ✅ 正确
// 删除不需要的代码
// 使用 Git 历史追溯
```

**原因**: 注释的代码是技术债务

### 规则 8: 禁止复制粘贴

```typescript
// ❌ 禁止（重复代码）
function handleUserClick() {
  validate();
  process();
  notify();
}

function handleAdminClick() {
  validate();
  process();
  notify();
}

// ✅ 正确（提取公共逻辑）
function handleClick(role: Role) {
  validate();
  process();
  notify(role);
}
```

**原因**: DRY 原则，减少维护成本

### 规则 9: 禁止交叉变更

```
❌ 一个 PR 包含多个不相关功能
❌ 一个 PR 修改多个模块

✅ 单 PR 单职责
✅ 一个 PR 对应一个 Ticket
```

**原因**: 便于 Review 和回滚

---

## 文件范围限制

**声明**:
```yaml
# jira/tickets/TASK-001.md
file_scope:
  includes:
    - src/components/Login/**
    - src/hooks/useAuth.ts
  excludes:
    - src/components/shared/**
```

**限制**:
- 只能修改 includes 中的文件
- excludes 中的文件绝对禁止
- 超出范围会被 CI 拦截

---

## 心跳检查

```bash
kallax performer:heartbeat
```

### 检查项

- [ ] 是否有新的 ready ticket？
- [ ] 现有 in_progress ticket 有 Conductor 反馈吗？
- [ ] PR 有 review 意见吗？
- [ ] 系统告警吗？

---

## 示例工作流

### 领取并完成任务

```
1. 查看可用任务
   kallax task:list --status ready
   ↓
2. 领取任务
   kallax task:claim TASK-001
   ↓
3. 进入 Worktree
   cd .claude/worktrees/TASK-001
   ↓
4. TDD 开发
   - 写测试
   - 写代码
   - 重构
   ↓
5. 本地验证
   npm test
   npm run lint
   npm run type-check
   ↓
6. 提交完成
   kallax task:complete TASK-001
   ↓
7. 等待 Review
   kallax performer:poll
   ↓
8. 响应反馈（如有）
   - 修改代码
   - git push
   ↓
9. 任务完成
```

---

## 错误处理

### TypeScript

```typescript
// ✅ 正确模式
import { Result, ok, err } from 'neverthrow';

function claimTask(id: string): Result<Ticket, KallaxError> {
  const ticket = findTicket(id);
  if (!ticket) {
    return err(new KallaxError('TICKET_NOT_FOUND', { id }));
  }
  return ok(ticket);
}
```

### Rust

```rust
// ✅ 正确模式
fn claim_task(id: &str) -> Result<Ticket, KallaxError> {
    let ticket = find_ticket(id)
        .ok_or(KallaxError::TicketNotFound { id: id.to_string() })?;
    Ok(ticket)
}
```

---

## 相关文档

- [Conductor 规则](CONDUCTOR-RULES.md)
- [反模式集合](ANTI-PATTERNS.md)
- [测试规范](PERFORMER-RULES-TEST.md)
