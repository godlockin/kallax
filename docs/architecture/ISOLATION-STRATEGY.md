# KALLAX 并行隔离策略

> 解决 KALLAX 多 Agent 并行冲突问题

---

## 1. 问题背景

### 1.1 KALLAX 教训

在 KALLAX 项目中，多 Agent 并行执行导致以下问题:

| 问题 | 频率 | 影响 |
|-----|------|-----|
| Git 合并冲突 | 高 | 需要人工解决，阻塞流程 |
| 代码相互覆盖 | 中 | 功能丢失，需要重新开发 |
| 测试互相干扰 | 高 | CI 不稳定，误报失败 |
| 状态文件冲突 | 中 | .lock 文件冲突导致安装失败 |
| 数据库 Schema 冲突 | 低 | 迁移脚本编号冲突 |

### 1.2 根本原因

```
❌ KALLAX 模式: 共享工作区

project/
├── src/
│   ├── feature-a.ts    ← Performer #1 修改
│   └── feature-a.ts    ← Performer #2 同时修改 (冲突!)
└── ...

两个 Performer 在同一目录工作，必然产生冲突
```

---

## 2. KALLAX 解决方案

### 2.1 强制 Worktree 隔离

```
✅ KALLAX 模式: 物理隔离

project/
├── .worktrees/
│   ├── TASK-001/           ← Performer #1 独立工作区
│   │   ├── src/
│   │   │   └── feature-a.ts
│   │   └── ...
│   │
│   ├── TASK-002/           ← Performer #2 独立工作区
│   │   ├── src/
│   │   │   └── feature-b.ts
│   │   └── ...
│   │
│   └── TASK-003/           ← Performer #3 独立工作区
│
├── src/                     ← main 分支 (只读参考)
├── confluence/
└── jira/

每个 Performer 在完全隔离的目录中工作
```

### 2.2 自动 Worktree 创建

```bash
# Performer 领取任务
kallax task:claim TASK-001

# 内部自动执行:
# 1. 检查任务可领取
# 2. 创建隔离 worktree
git worktree add .worktrees/TASK-001 -b feature/TASK-001 origin/main

# 3. 切换到隔离目录
cd .worktrees/TASK-001

# 4. 安装依赖 (如果需要)
npm install

# 5. 记录 Performer 状态
echo "TASK-001: in_progress" >> .kallax/state/performers.yaml
```

### 2.3 Worktree 生命周期

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Worktree 生命周期                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. 创建 (task:claim)                                               │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ git worktree add .worktrees/{TASK-ID} -b feature/{TASK-ID} │ │
│     └──────────────────────────────────────────────────────────┘   │
│                          │                                          │
│                          ▼                                          │
│  2. 使用 (开发中)                                                   │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ • Performer 在隔离目录中开发                              │   │
│     │ • 所有修改只影响该 worktree                                │   │
│     │ • 定期 rebase 保持与 main 同步                            │   │
│     └──────────────────────────────────────────────────────────┘   │
│                          │                                          │
│                          ▼                                          │
│  3. 提交 PR                                                         │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ git push origin feature/{TASK-ID}                         │   │
│     │ gh pr create --base main --head feature/{TASK-ID}         │   │
│     └──────────────────────────────────────────────────────────┘   │
│                          │                                          │
│                          ▼                                          │
│  4. 清理 (task:complete 或 PR 合并后)                               │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ git worktree remove .worktrees/{TASK-ID}                  │   │
│     │ git branch -d feature/{TASK-ID}                           │   │
│     └──────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 文件范围声明

### 3.1 Ticket 必须声明文件范围

```yaml
# jira/tickets/TASK-001.yaml
id: TASK-001
title: 实现登录组件
type: feature
priority: P1

# 文件范围声明 (必填)
file_scope:
  includes:
    - src/components/Login/**      # 登录相关组件
    - src/hooks/useAuth.ts         # 认证 hook
    - src/styles/login.css         # 登录样式
    - tests/components/Login/**    # 登录测试
    
  excludes:
    - src/components/shared/**     # 共享组件 (被其他任务使用)
    - src/utils/**                 # 工具函数 (公共资源)
    
# 依赖声明 (可选)
depends_on:
  - TASK-000  # 前置任务

# 预估工作量
estimate: 4h
```

### 3.2 文件范围冲突检测

```typescript
// Conductor 派发前检测
interface FileScope {
  includes: string[];
  excludes: string[];
}

interface ConflictReport {
  hasConflict: boolean;
  overlappingFiles: string[];
  task1: string;
  task2: string;
  resolution: 'serialize' | 'split' | 'coordinate';
}

async function checkFileOverlap(
  task1: Ticket,
  task2: Ticket
): Promise<ConflictReport> {
  // 1. 展开 glob 模式
  const scope1 = await expandGlob(task1.fileScope.includes);
  const scope2 = await expandGlob(task2.fileScope.includes);
  
  // 2. 排除已排除的文件
  const effective1 = scope1.filter(f => 
    !task1.fileScope.excludes.some(ex => minimatch(f, ex))
  );
  const effective2 = scope2.filter(f => 
    !task2.fileScope.excludes.some(ex => minimatch(f, ex))
  );
  
  // 3. 检测重叠
  const overlap = effective1.filter(f => effective2.includes(f));
  
  if (overlap.length > 0) {
    return {
      hasConflict: true,
      overlappingFiles: overlap,
      task1: task1.id,
      task2: task2.id,
      resolution: suggestResolution(overlap)
    };
  }
  
  return { hasConflict: false };
}

function suggestResolution(overlap: string[]): Resolution {
  // 如果重叠文件少，建议拆分
  if (overlap.length <= 3) {
    return 'split';
  }
  // 如果重叠文件多，建议串行
  if (overlap.length > 10) {
    return 'serialize';
  }
  // 中等情况，需要协调
  return 'coordinate';
}
```

### 3.3 冲突解决策略

```
┌─────────────────────────────────────────────────────────────────────┐
│                       冲突解决策略                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  策略 1: 串行执行 (serialize)                                       │
│  ─────────────────────────────                                      │
│  适用: 大量文件重叠                                                  │
│                                                                      │
│  TASK-001 ─────────────────▶ 完成后                                │
│                                  │                                   │
│                                  ▼                                   │
│                             TASK-002 ─────────────────▶             │
│                                               ─────────────────────────┤
│                                                                      │
│  策略 2: 拆分范围 (split)                                           │
│  ─────────────────────────                                          │
│  适用: 少量文件重叠，可清晰划分                                      │
│                                                                      │
│  原 TASK-001: src/components/**                                     │
│  原 TASK-002: src/components/** + src/hooks/**                      │
│                                                                      │
│  拆分后:                                                             │
│  TASK-001: src/components/Login/**                                  │
│  TASK-002: src/components/Dashboard/** + src/hooks/**               │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  策略 3: 协调执行 (coordina                                    │
│  适用: 中等重叠，需要通信                                            │
│                                                                      │
│  1. Conductor 创建协调通道                                          │
│  2. Performer A 完成共享文件修改后通知                               │
│  3. Performer B 基于最新代码继续                                     │
│                                                                      │
│  TASK-001 ──────────▶ 修改 shared.ts ──notify──┐                    │
│                                                   │                   │
│  TASK-002 ─────▶ 等待 ◀────────────────────────┘                    │
│                    │                                                 │
│                    ▼                                                 │
│           git pull origin main                                       │
│                    │                                                 │
│                    ▼                                                 │
│           继续开发 ───────────▶                                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. 冲突预防机制

### 4.1 派发前检查

```bash
# Conductor 派发任务前自动检查
kallax isolation:check TASK-001 TASK-002

# 输出:
# Checking file scope overlap...
# 
# TASK-001 scope: src/components/Login/**, src/hooks/useAuth.ts
# TASK-002 scope: src/components/Dashboard/**, src/hooks/useData.ts
# 
# ✅ No overlap detected. Tasks can be executed in parallel.
```

```bash
# 检测到冲突的情况
kallax isolation:check TASK-001 TASK-003

# 输出:
# ⚠️  File scope overlap detected!
# 
# Overlapping files:
#   - src/hooks/useAuth.ts
#   - src/utils/validation.ts
# 
# Suggested resolution: split
# 
# Option 1: Split TASK-001 to exclude utils/**
# Option 2: Serialize TASK-001 → TASK-003
# Option 3: Coordinate via message queue
```

### 4.2 运行时监控

```typescript
// 监控 Performer 文件修改
class FileAccessMonitor {
  private scopes: Map<string, FileScope> = new Map();
  
  registerTask(taskId: string, scope: FileScope) {
    this.scopes.set(taskId, scope);
  }
  
  // 拦截文件写入
  async onFileWrite(taskId: string, filePath: string): Promise<void> {
    const scope = this.scopes.get(taskId);
    
    if (!scope) {
      throw new Error(`Task ${taskId} not registered`);
    }
    
    // 检查文件是否在声明范围内
    const isInScope = scope.includes.some(pattern => 
      minimatch(filePath, pattern)
    );
    
    const isExcluded = scope.excludes.some(pattern =>
      minimatch(filePath, pattern)
    );
    
    if (!isInScope || isExcluded) {
      logger.warn({
        event: 'file_access_violation',
        taskId,
        filePath,
        declaredScope: scope
      }, `Task ${taskId} attempting to modify file outside scope: ${filePath}`);
      
      // 根据配置决定行为
      if (config.isolation.strict_mode) {
        throw new FileAccessViolationError(taskId, filePath, scope);
      }
    }
  }
}
```

### 4.3 合并前验证

```bash
# PR 合并前检查是否有并行任务的冲突
kallax pr:pre-merge-check PR-42

# 输出:
# Checking for parallel task conflicts...
# 
# PR-42 (TASK-001):
#   Modified files:
#     - src/components/Login/index.tsx
#     - src/hooks/useAuth.ts
# 
# Parallel PRs:
#   - PR-43 (TASK-002): No overlap ✅
#   - PR-44 (TASK-003): Overlap detected ⚠️
#     - src/hooks/useAuth.ts
# 
# Recommendation: Merge PR-42 first, then rebase PR-44
```

---

## 5. 共享资源协调

### 5.1 共享文件标记

```yaml
# confluence/memory/shared-resources.yaml
shared_resources:
  - path: src/utils/**
    description: 工具函数
    modification_protocol: coordinate
    owner: null  # 无特定所有者
    
  - path: src/components/shared/**
    description: 共享 UI 组件
    modification_protocol: serialize
    owner: frontend_lead
    
  - path: prisma/schema.prisma
    description: 数据库 Schema
    modification_protocol: serialize
    owner: backend_lead
```

### 5.2 协调协议

```typescript
// 修改共享资源时的协调流程
async function modifySharedResource(
  taskId: string,
  resourcePath: string,
  modification: () => Promise<void>
): Promise<void> {
  const resource = await getSharedResourceConfig(resourcePath);
  
  switch (resource.modificationProtocol) {
    case 'serialize':
      // 获取独占锁
      const lock = await acquireLock(resourcePath, taskId, {
        timeout: 30000,  // 30 秒超时
        retry: 3
      });
      
      try {
        await modification();
        await notifyOtherPerformers(resourcePath, taskId);
      } finally {
        await releaseLock(lock);
      }
      break;
      
    case 'coordinate':
      // 发送协调请求
      await requestCoordination({
        taskId,
        resourcePath,
        intendedChanges: await describeChanges(modification)
      });
      
      // 等待 Conductor 批准
      await waitForApproval(taskId, resourcePath);
      
      await modification();
      
      // 通知完成
      await notifyCoordinationComplete(taskId, resourcePath);
      break;
      
    case 'none':
      // 直接修改
      await modification();
      break;
  }
}
```

---

## 6. 数据库 Migration 冲突处理

### 6.1 问题

多个 Performer 同时创建 migration 文件，编号冲突:

```
❌ 冲突情况:
migrations/
├── 20240115_001_create_users.sql     ← Performer #1
└── 20240115_001_create_orders.sql    ← Performer #2 (编号冲突!)
```

### 6.2 解决方案

```typescript
// Migration 文件使用时间戳 + 随机后缀
function generateMigrationFileName(description: string): string {
  const timestamp = new Date().toISOString()
    .replace(/[-:T.Z]/g, '')
    .slice(0, 14);  // YYYYMMDDHHmmss
  
  const randomSuffix = crypto.randomBytes(4).toString('hex');
  const sanitized = description.replace(/\s+/g, '_').toLowerCase();
  
  return `${timestamp}_${randomSuffix}_${sanitized}.sql`;
}

// 结果:
// migrations/
// ├── 20240115143022_a1b2c3d4_create_users.sql
// └── 20240115143025_e5f6g7h8_create_orders.sql
```

### 6.3 Migration 序列化执行

```yaml
# 数据库 migration 必须串行
file_scope:
  includes:
    - prisma/migrations/**
  
# 这类任务自动设为串行
constraints:
  - type: serialize
    reason: database_migration
```

---

## 7. 配置参考

```yaml
# .kallax/config.yml
isolation:
  # 强制 worktree 隔离
  enforce_worktree: true
  
  # worktree 目录
  worktree_dir: ".worktrees"
  
  # 文件范围检查
  file_scope_check: true
  
  # 严格模式 (违规时报错)
  strict_mode: false
  
  # 最大并行 Performer 数
  max_parallel_performers: 5
  
  # 共享资源配置文件
  shared_resources_file: "confluence/memory/shared-resources.yaml"
  
  # 自动清理完成的 worktree
  auto_cleanup: true
  cleanup_delay: 3600  # 合并后 1 小时清理

# 冲突检测配置
conflict_detection:
  # 派发前检查
  pre_dispatch_check: true
  
  # 运行时监控
  runtime_monitoring: true
  
  # 合并前验证
  pre_merge_check: true
```

---

## 8. 最佳实践

### 8.1 任务拆分原则

```
✅ 好的拆分:
- 每个任务有清晰的文件边界
- 共享资源修改独立成任务
- 依赖关系显式声明

❌ 坏的拆分:
- 多个任务修改同一文件
- 隐式依赖
- 范围过大无法并行
```

### 8.2 Conductor 检查清单

```markdown
## 派发前检查

- [ ] 文件范围无重叠
- [ ] 共享资源协调已安排
- [ ] 依赖顺序正确
- [ ] 数据库 migration 已串行安排
- [ ] Worktree 资源充足 (< max_parallel_performers)
```

### 8.3 Performer 规范

```markdown
## 执行规范

- [ ] 只在分配的 worktree 中工作
- [ ] 只修改声明范围内的文件
- [ ] 定期 rebase 保持与 main 同步
- [ ] 共享资源修改前申请协调
- [ ] 完成后及时提交 PR 释放资源
```
