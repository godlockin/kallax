# 并行隔离策略

> KALLAX 核心模式 | 解决 并行冲突问题

---

## 问题背景

历史项目中多个 Performer 并行工作时经常发生：
- 文件冲突（两个 Agent 同时修改同一文件）
- 隐式依赖（Agent A 的修改影响 Agent B）
- 合并困难（复杂的 3-way merge）

**损失**: 平均每次冲突阻塞 2-3 小时

---

## KALLAX 解决方案

### 1. 强制 Worktree 隔离

每个 Performer 必须在独立 Git Worktree 中工作：

```bash
# 领取任务时自动创建 Worktree
kallax task:claim TASK-001
# 内部执行:
# git worktree add .claude/worktrees/TASK-001 -b feature/TASK-001

# 目录结构
.claude/worktrees/
├── TASK-001/           # Performer A 的隔离空间
├── TASK-002/           # Performer B 的隔离空间
└── TASK-003/           # Performer C 的隔离空间
```

### 2. File Scope 声明

每个 Ticket 必须声明允许修改的文件范围：

```yaml
# jira/tickets/TASK-001.md
file_scope:
  includes:
    - src/components/Login/**
    - src/hooks/useAuth.ts
  excludes:
    - src/components/shared/**
    - src/utils/**
```

### 3. 范围重叠检查

Conductor 派发前必须检查文件范围是否重叠：

```bash
kallax isolation:check TASK-001 TASK-002

# 输出示例 (无重叠):
# ✅ No overlap detected
# TASK-001: src/components/Login/**
# TASK-002: src/components/Register/**

# 输出示例 (有重叠):
# ❌ Overlap detected:
#   - src/utils/validators.ts (TASK-001 ∩ TASK-002)
# Action: Reject dispatch or coordinate handoff
```

---

## 配置

```yaml
# .kallax/config.yml
isolation:
  # 强制 Worktree（默认 true）
  enforce_worktree: true
  
  # 文件范围检查（默认 true）
  file_scope_check: true
  
  # 最大并行 Performer 数
  max_parallel_performers: 5
  
  # 范围重叠处理策略
  # reject: 拒绝派发（默认）
  # warn: 警告但允许
  # allow: 静默允许（不推荐）
  scope_overlap_action: reject
```

---

## 工作流

### Conductor 派发任务

```
1. 创建 Ticket 并声明 file_scope
2. 检查与现有 in_progress 任务的范围重叠
   - 无重叠 → 派发
   - 有重叠 → 重新划分范围或等待
3. 通知 Performer
```

### Performer 执行任务

```
1. kallax task:claim TASK-NNN
   - 自动创建 Worktree
   - 验证 file_scope 无冲突
2. 在 Worktree 中开发
   - 只能修改 file_scope.includes 中的文件
   - 修改超出范围会被阻止
3. kallax task:complete TASK-NNN
   - 验证修改符合 file_scope
   - 提交 PR
```

### 共享文件处理

当多个任务需要修改同一文件时：

```
方案 A: 串行执行
  TASK-001 完成 → TASK-002 开始

方案 B: 范围细分
  TASK-001: src/utils/validators.ts (前 50 行)
  TASK-002: src/utils/validators.ts (后 50 行)

方案 C: 先合并后继续
  TASK-001 先完成并合并 → TASK-002 rebase 后继续
```

---

## 代码实现

### isolation-checker.ts

```typescript
import { glob } from 'glob';

interface FileScope {
  includes: string[];
  excludes: string[];
}

export class IsolationChecker {
  /**
   * 检查两个任务的文件范围是否重叠
   */
  async checkOverlap(
    scopeA: FileScope,
    scopeB: FileScope
  ): Promise<{ overlap: boolean; files: string[] }> {
    const filesA = await this.expandScope(scopeA);
    const filesB = await this.expandScope(scopeB);
    
    const overlap = filesA.filter(f => filesB.includes(f));
    
    return {
      overlap: overlap.length > 0,
      files: overlap,
    };
  }

  /**
   * 展开 glob 模式为具体文件列表
   */
  private async expandScope(scope: FileScope): Promise<string[]> {
    const included = await glob(scope.includes, {
      ignore: scope.excludes,
    });
    return included;
  }
}
```

### worktree-manager.ts

```typescript
import { execFileSync } from 'child_process';
import { existsSync, mkdirSync } from 'fs';
import path from 'path';

export class WorktreeManager {
  private readonly baseDir = '.claude/worktrees';

  /**
   * 为任务创建 Worktree
   */
  create(ticketId: string): string {
    const worktreePath = path.join(this.baseDir, ticketId);
    const branchName = `feature/${ticketId}`;

    if (existsSync(worktreePath)) {
      throw new Error(`Worktree already exists: ${worktreePath}`);
    }

    mkdirSync(this.baseDir, { recursive: true });

    // 使用 execFileSync 避免 shell 注入
    execFileSync('git', ['worktree', 'add', worktreePath, '-b', branchName], {
      stdio: 'inherit',
    });

    return worktreePath;
  }

  /**
   * 移除 Worktree
   */
  remove(ticketId: string): void {
    const worktreePath = path.join(this.baseDir, ticketId);
    
    execFileSync('git', ['worktree', 'remove', worktreePath], {
      stdio: 'inherit',
    });
  }

  /**
   * 列出所有活跃 Worktree
   */
  list(): string[] {
    const output = execFileSync('git', ['worktree', 'list', '--porcelain']).toString();
    return output
      .split('\n')
      .filter(line => line.startsWith('worktree '))
      .map(line => line.replace('worktree ', ''));
  }
}
```

---

## 最佳实践

1. **范围最小化**: 声明最小必要的文件范围
2. **共享文件谨慎**: 尽量避免共享文件，必要时串行执行
3. **及时合并**: 完成后尽快合并，减少分支存活时间
4. **Rebase 优于 Merge**: 保持线性历史

---

## 参考

- [架构经验教训](../research/architecture-lessons-learned.md)
- [Ticket Schema - File Scope](../../jira/schemas/ticket-schema.md#file-scope-规则-kallax-新增)
