# KALLAX 框架白皮书

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor
> 
> Version 1.0.0 | 生产级多智能体协作框架

---

## 1. 设计理念

### 1.1 核心哲学

KALLAX 基于以下核心信念构建：

1. **信任但验证 (Trust but Verify)**: AI Agent 能力强大但易产生幻觉，所有产出必须可验证
2. **隔离即安全 (Isolation is Safety)**: 并行执行必须物理隔离，避免状态污染
3. **优雅降级 (Graceful Degradation)**: 系统故障不应阻断工作流，降级应透明可观测
4. **单一职责 (Single Responsibility)**: Conductor 协调不执行，Performer 执行不决策

### 1.2 设计目标

| 目标 | 指标 | 实现方式 |
|-----|------|---------|
| **高可用** | 99.9% 可用性 | 三级降级架构 |
| **低延迟** | P99 < 100ms | Rust 核心层 |
| **可扩展** | 1-50 Performer | DAG 调度 + 隔离 |
| **可观测** | 全链路追踪 | 结构化日志 + Metrics |
| **类型安全** | 0 any | 编译时检查 |

---

## 2. Conductor-Performer 模型

### 2.1 角色分工

```
┌─────────────────────────────────────────────────────────────┐
│                        Human Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Product Owner / Tech Lead / QA Lead                 │   │
│  │  - 需求输入 (inbox/human_input.md)                   │   │
│  │  - 最终验收                                          │   │
│  │  - 阻塞决策                                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Conductor Layer                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Conductor Instance (Claude Code / Gemini / Copilot) │   │
│  │                                                       │   │
│  │  职责:                                                │   │
│  │  ✓ 需求分析与任务拆解                                │   │
│  │  ✓ 任务派发与进度追踪                                │   │
│  │  ✓ PR 审核 (4-Level Fact-Forcing)                    │   │
│  │  ✓ 合并到 main 分支                                  │   │
│  │  ✓ 知识库维护                                        │   │
│  │                                                       │   │
│  │  禁止:                                                │   │
│  │  ✗ 编写生产代码                                      │   │
│  │  ✗ 自我领取任务                                      │   │
│  │  ✗ 无 CI 绿灯合并                                    │   │
│  │  ✗ 自我审查 PR                                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Performer #1  │    │ Performer #2  │    │ Performer #N  │
│ (Frontend)    │    │ (Backend)     │    │ (Test)        │
│               │    │               │    │               │
│ Worktree:     │    │ Worktree:     │    │ Worktree:     │
│ .worktrees/   │    │ .worktrees/   │    │ .worktrees/   │
│ TASK-001/     │    │ TASK-002/     │    │ TASK-003/     │
│               │    │               │    │               │
│ File Scope:   │    │ File Scope:   │    │ File Scope:   │
│ src/ui/**     │    │ src/api/**    │    │ tests/**      │
└───────────────┘    └───────────────┘    └───────────────┘
```

### 2.2 职责边界

| 操作 | Conductor | Performer |
|-----|-----------|-----------|
| 分析需求 | ✓ | ✗ |
| 拆解任务 | ✓ | ✗ |
| 派发任务 | ✓ | ✗ |
| 领取任务 | ✗ | ✓ |
| 编写代码 | ✗ | ✓ |
| 编写测试 | ✗ | ✓ |
| 提交 PR | ✗ | ✓ |
| 审核 PR | ✓ | ✗ |
| 合并代码 | ✓ | ✗ |
| 操作 main 分支 | ✓ | ✗ |
| 操作 feature 分支 | ✗ | ✓ |

### 2.3 架构对比

| 问题 | 旧方案 | 设计原则 | KALLAX 改进 |
|-----|----------|----------|------------|
| 命名 | Master/Performer | 敏感词汇 | Conductor/Performer |
| 并行隔离 | 可选 worktree | 文件冲突频发 | 强制 worktree + 文件范围 |
| 验证机制 | 信任 Agent 报告 | 幻觉产出 | 4-Level Fact-Forcing |
| 错误处理 | `expect()`/`panic!()` | 生产崩溃 | 强制 `Result<T, E>` |

---

## 3. 三级降级架构

### 3.1 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│  Level 3: Rust Core (Production)                            │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  启动时间: ~8ms    内存占用: ~12MB                    │ │
│  │                                                        │ │
│  │  组件:                                                 │ │
│  │  • Event Bus (tokio channels)                         │ │
│  │  • DAG Scheduler (关键路径分析)                       │ │
│  │  • Knowledge Base (FTS + TF-IDF)                      │ │
│  │  • Ticket Engine (CRUD + 状态机)                      │ │
│  │  • Agent Pool (Performer 管理)                        │ │
│  │  • Mailbox (异步消息传递)                             │ │
│  │  • HTTP API (Axum, :9877)                             │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────┘
                          │ (Rust 不可用时降级)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Level 2: Node.js Layer (Degraded)                          │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  启动时间: ~400ms    内存占用: ~120MB                 │ │
│  │                                                        │ │
│  │  组件:                                                 │ │
│  │  • Message Queue (Redis/File 回退)                    │ │
│  │  • SQLite Manager (本地持久化)                        │ │
│  │  • Cache Layer (LRU + TTL)                            │ │
│  │  • Web Dashboard (Express + React)                    │ │
│  │  • WebSocket (实时状态推送)                           │ │
│  │  • Skills System (40+ 命令)                           │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────┘
                          │ (Node.js 不可用时降级)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Level 1: Shell Layer (Emergency)                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  启动时间: ~50ms    依赖: bash + git                  │ │
│  │                                                        │ │
│  │  能力:                                                 │ │
│  │  • 基础心跳检查                                        │ │
│  │  • 文件队列消息传递                                    │ │
│  │  • Git 操作 (commit/push/PR)                          │ │
│  │  • 票据状态读取                                        │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 降级触发条件

```yaml
# .kallax/config.yml
degradation:
  # 自动降级触发
  triggers:
    rust_to_node:
      - rust_binary_missing
      - rust_startup_timeout: 5000  # ms
      - rust_crash_count: 3         # 3次崩溃后降级
      
    node_to_shell:
      - node_not_found
      - npm_modules_missing
      - node_startup_timeout: 10000  # ms
      - node_crash_count: 5
      
    redis_to_file:
      - redis_connection_timeout: 5000
      - redis_error_rate: 0.5        # 50% 错误率
      
  # 恢复策略
  recovery:
    check_interval: 60000   # 1分钟检查一次
    recovery_threshold: 3   # 连续3次成功后恢复
```

### 3.3 KALLAX 改进: 显式日志与指标

设计原则: 降级静默发生，运维人员无法感知

```typescript
// ❌ 旧: 静默降级
if (!redisAvailable) {
  queue = new FileQueue();  // 无日志
}

// ✅ KALLAX: 显式降级
if (!redisAvailable) {
  logger.warn({
    event: 'degradation_triggered',
    from: 'redis',
    to: 'file_queue',
    reason: 'redis_connection_timeout',
    timestamp: Date.now()
  }, 'Queue degraded from Redis to FileQueue');
  
  metrics.increment('kallax.degradation', { 
    from: 'redis', 
    to: 'file' 
  });
  
  queue = new FileQueue();
}
```

---

## 4. 三仓库分离

### 4.1 仓库职责

```
┌─────────────────────────────────────────────────────────────┐
│  Confluence (知识库)                                        │
│  路径: ./confluence/                                        │
│                                                              │
│  内容:                                                       │
│  ├── memory/           # 长期记忆                           │
│  │   ├── project/      # 项目知识                           │
│  │   ├── patterns/     # 设计模式                           │
│  │   └── glossary/     # 术语表                             │
│  ├── decisions/        # 架构决策记录 (ADR)                 │
│  ├── runbooks/         # 运维手册                           │
│  └── retrospectives/   # 复盘文档                           │
│                                                              │
│  同步: 每次 PR 合并后自动更新                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Jira (任务管理)                                            │
│  路径: ./jira/                                              │
│                                                              │
│  内容:                                                       │
│  ├── epics/            # 史诗级需求                         │
│  ├── tickets/          # 可执行票据                         │
│  ├── schemas/          # 票据模板                           │
│  └── workflows/        # 状态机定义                         │
│                                                              │
│  状态机: TODO → IN_PROGRESS → REVIEW → DONE                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Code (代码仓库)                                            │
│  路径: ./                                                   │
│                                                              │
│  分支策略:                                                   │
│  ├── main              # 生产分支 (仅 Conductor 可操作)      │
│  ├── feature/*         # 功能分支 (Performer 工作区)         │
│  └── hotfix/*          # 紧急修复                           │
│                                                              │
│  保护规则:                                                   │
│  • main: 禁止直接推送, 需 PR + CI 绿灯 + Conductor 审核     │
│  • feature/*: Performer 可自由操作                          │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 数据流

```
Human 输入需求
      │
      ▼
┌─────────────┐
│   inbox/    │  ← 原始需求
└─────────────┘
      │
      ▼ Conductor 分析
┌─────────────┐
│ confluence/ │  ← 查询历史知识
└─────────────┘
      │
      ▼ Conductor 拆解
┌─────────────┐
│   jira/     │  ← 创建 Tickets
└─────────────┘
      │
      ▼ Performer 领取
┌─────────────┐
│   code/     │  ← 实现代码
└─────────────┘
      │
      ▼ PR 合并
┌─────────────┐
│ confluence/ │  ← 更新知识库
└─────────────┘
```

---

## 5. DAG 调度

### 5.1 任务依赖图

```
EPIC-001: 用户认证系统
│
├── TASK-001: 数据库 Schema (无依赖)
│   └── Performer: backend
│   └── 预估: 2h
│
├── TASK-002: API 接口 (依赖 TASK-001)
│   └── Performer: backend
│   └── 预估: 4h
│
├── TASK-003: UI 组件 (无依赖)
│   └── Performer: frontend
│   └── 预估: 3h
│
└── TASK-004: 集成测试 (依赖 TASK-002, TASK-003)
    └── Performer: test
    └── 预估: 2h

关键路径: TASK-001 → TASK-002 → TASK-004 = 8h
并行路径: TASK-003 (3h) 与 TASK-001+002 并行
总耗时: 8h (非关键路径 TASK-003 在关键路径内完成)
```

### 5.2 调度算法

```rust
pub struct DagScheduler {
    tasks: HashMap<TaskId, Task>,
    dependencies: HashMap<TaskId, Vec<TaskId>>,
    ready_queue: PriorityQueue<TaskId, Priority>,
}

impl DagScheduler {
    /// 计算关键路径
    pub fn critical_path(&self) -> Vec<TaskId> {
        // 拓扑排序 + 最长路径
        let sorted = self.topological_sort();
        let mut earliest_start = HashMap::new();
        let mut earliest_finish = HashMap::new();
        
        for task_id in &sorted {
            let deps = self.dependencies.get(task_id).unwrap_or(&vec![]);
            let es = deps.iter()
                .map(|d| earliest_finish.get(d).unwrap_or(&0))
                .max()
                .unwrap_or(&0);
            let ef = es + self.tasks[task_id].estimate;
            
            earliest_start.insert(task_id.clone(), *es);
            earliest_finish.insert(task_id.clone(), ef);
        }
        
        // 回溯找关键路径
        self.backtrack_critical_path(&earliest_start, &earliest_finish)
    }
    
    /// 获取可并行执行的任务
    pub fn ready_tasks(&self) -> Vec<TaskId> {
        self.tasks.iter()
            .filter(|(id, task)| {
                task.status == Status::Todo &&
                self.dependencies_satisfied(id)
            })
            .map(|(id, _)| id.clone())
            .collect()
    }
}
```

### 5.3 负载均衡

```yaml
# Performer 能力声明
performers:
  - id: performer_frontend_001
    specialty: frontend
    capacity: 2          # 同时处理任务数
    skills: [react, css, typescript]
    
  - id: performer_backend_001
    specialty: backend
    capacity: 3
    skills: [rust, sqlite, redis]

# 调度策略
scheduling:
  algorithm: weighted_round_robin
  weights:
    skill_match: 0.4      # 技能匹配度
    current_load: 0.3     # 当前负载
    historical: 0.3       # 历史完成率
```

---

## 6. 并行隔离策略 (KALLAX 新增)

### 6.1 问题背景

设计原则: 多 Agent 并行修改同一文件导致:
- Git 合并冲突
- 代码相互覆盖
- 测试互相干扰

### 6.2 强制 Worktree 隔离

```bash
# Performer 领取任务时自动创建 worktree
kallax task:claim TASK-001

# 内部执行:
# 1. git worktree add .worktrees/TASK-001 -b feature/TASK-001
# 2. cd .worktrees/TASK-001
# 3. 所有操作在隔离目录中进行
```

```
项目根目录/
├── .worktrees/
│   ├── TASK-001/        # Performer #1 工作区
│   │   ├── src/
│   │   └── ...
│   ├── TASK-002/        # Performer #2 工作区
│   │   ├── src/
│   │   └── ...
│   └── TASK-003/        # Performer #3 工作区
├── src/                  # main 分支 (只读参考)
└── ...
```

### 6.3 文件范围声明

每个 Ticket 必须声明文件范围:

```yaml
# jira/tickets/TASK-001.yaml
id: TASK-001
title: 实现登录组件
file_scope:
  includes:
    - src/components/Login/**
    - src/hooks/useAuth.ts
    - src/styles/login.css
  excludes:
    - src/components/shared/**  # 共享组件,需协调
```

### 6.4 冲突预防

```typescript
// Conductor 派发前检查
async function checkFileOverlap(
  task1: Ticket, 
  task2: Ticket
): Promise<ConflictReport> {
  const scope1 = expandGlob(task1.fileScope.includes);
  const scope2 = expandGlob(task2.fileScope.includes);
  
  const overlap = scope1.filter(f => scope2.includes(f));
  
  if (overlap.length > 0) {
    return {
      hasConflict: true,
      files: overlap,
      resolution: 'serialize_tasks'  // 或 split_scope
    };
  }
  
  return { hasConflict: false };
}
```

---

## 7. 验证机制 (KALLAX 新增)

### 7.1 问题背景

设计原则: Background Agent 报告"任务完成"但:
- 文件未创建
- 代码为 stub
- 测试未实际运行

### 7.2 4-Level Fact-Forcing

```
┌─────────────────────────────────────────────────────────────┐
│  Level 1: 存在性验证 (Existence)                            │
│                                                              │
│  检查:                                                       │
│  ✓ 文件是否存在于 git diff                                  │
│  ✓ 所有声明的文件都已创建                                   │
│  ✓ 无幻觉引用 (引用不存在的模块)                            │
│                                                              │
│  命令:                                                       │
│  $ git diff --name-only HEAD~1                              │
│  $ ls -la src/components/Login/                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Level 2: 实质性验证 (Substance)                            │
│                                                              │
│  检查:                                                       │
│  ✓ 代码为真实逻辑,非 stub/TODO                              │
│  ✓ 关键路径有实现                                           │
│  ✓ 错误处理存在                                             │
│                                                              │
│  命令:                                                       │
│  $ grep -r "TODO\|FIXME\|stub" src/                         │
│  $ git show HEAD -- src/components/Login/index.tsx          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Level 3: 接线验证 (Wiring)                                 │
│                                                              │
│  检查:                                                       │
│  ✓ Import/Export 正确                                       │
│  ✓ 类型兼容                                                 │
│  ✓ 编译通过                                                 │
│                                                              │
│  命令:                                                       │
│  $ npm run build                                            │
│  $ tsc --noEmit                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Level 4: 数据流验证 (Data Flow)                            │
│                                                              │
│  检查:                                                       │
│  ✓ 单元测试通过                                             │
│  ✓ 集成测试通过                                             │
│  ✓ E2E 关键路径覆盖                                         │
│                                                              │
│  命令:                                                       │
│  $ npm test -- --coverage                                   │
│  $ npm run test:e2e                                         │
└─────────────────────────────────────────────────────────────┘
```

### 7.3 证据要求

```yaml
# PR Review 必须包含以下证据

evidence_required:
  # ✅ 接受的证据
  accepted:
    - 具体代码行号引用 (如: "src/Login.tsx:42-58")
    - 命令执行 stdout/stderr
    - 测试执行结果截图或日志
    - git diff 实际输出
    
  # ❌ 拒绝的证据
  rejected:
    - "应该可以工作"
    - "看起来正确"
    - "我检查过了"
    - 无输出的命令执行
    - Mock 测试结果用于集成验证
```

---

## 8. 专家组系统

### 8.1 核心专家 (5 人)

| 角色 | 职责 | 触发条件 |
|-----|------|---------|
| **系统架构师** | 技术决策、架构评审 | 新功能设计、重构提案 |
| **安全专家** | 安全审计、漏洞分析 | 认证/授权变更、敏感数据处理 |
| **性能专家** | 性能优化、负载评估 | 关键路径变更、大数据处理 |
| **测试专家** | 测试策略、质量保证 | 测试覆盖不足、复杂边界条件 |
| **领域专家** | 业务逻辑、领域建模 | 业务规则变更、新领域引入 |

### 8.2 工作流程

```
1. 触发条件满足
       │
       ▼
2. Conductor 召集专家组
       │
       ▼
3. 专家独立评审 (并行)
       │
       ▼
4. 意见汇总
       │
       ├── 一致同意 → 继续
       │
       └── 存在分歧 → 讨论 → 投票 → 决策记录
```

---

## 9. 监控与可观测性

### 9.1 指标体系

```typescript
// 核心指标
const metrics = {
  // 任务指标
  'kallax.task.created': Counter,
  'kallax.task.claimed': Counter,
  'kallax.task.completed': Counter,
  'kallax.task.duration': Histogram,
  
  // Performer 指标
  'kallax.performer.active': Gauge,
  'kallax.performer.timeout': Counter,
  'kallax.performer.error': Counter,
  
  // 降级指标
  'kallax.degradation.triggered': Counter,
  'kallax.degradation.recovered': Counter,
  
  // 验证指标
  'kallax.verification.passed': Counter,
  'kallax.verification.failed': Counter,
  'kallax.verification.level': Histogram,
};
```

### 9.2 告警规则

```yaml
alerts:
  - name: PerformerTimeout
    condition: kallax.performer.timeout > 3 in 10m
    severity: warning
    action: notify_conductor
    
  - name: DegradationTriggered
    condition: kallax.degradation.triggered > 0
    severity: warning
    action: notify_ops
    
  - name: VerificationFailureSpike
    condition: rate(kallax.verification.failed) > 0.3
    severity: critical
    action: pause_merge
```

---

## 10. 未来路线图

### Phase 1 (Current): 基础框架
- [x] Conductor-Performer 协议
- [x] 三级降级架构
- [x] 基础验证机制
- [x] Worktree 隔离

### Phase 2: 智能增强
- [ ] ML 驱动的任务估算
- [ ] 自动冲突检测
- [ ] 智能 Performer 匹配
- [ ] 知识图谱

### Phase 3: 企业级
- [ ] 多租户支持
- [ ] SSO 集成
- [ ] 审计日志
- [ ] SLA 管理

---

## 附录

### A. 术语表

参见 [confluence/memory/glossary/terms.md](../../confluence/memory/glossary/terms.md)

### B. 相关文档

- [降级策略详解](DEGRADATION-STRATEGY.md)
- [三仓库架构](THREE_REPO_ARCHITECTURE.md)
- [隔离策略](ISOLATION-STRATEGY.md)
- [验证协议](VERIFICATION-PROTOCOL.md)
