# KALLAX 三仓库架构

> 关注点分离: 知识、任务、代码各司其职

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────────────┐
│                         KALLAX 三仓库架构                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │
│  │   Confluence    │   │      Jira       │   │      Code       │   │
│  │   (知识库)       │   │   (任务管理)     │   │   (代码仓库)     │   │
│  │                 │   │                 │   │                 │   │
│  │  ./confluence/  │   │    ./jira/      │   │      ./         │   │
│  │                 │   │                 │   │                 │   │
│  │  • 长期记忆      │   │  • EPIC 管理    │   │  • 源代码        │   │
│  │  • 架构决策      │   │  • Ticket 管理  │   │  • 配置文件      │   │
│  │  • 模式库        │   │  • 状态追踪     │   │  • 测试代码      │   │
│  │  • 术语表        │   │  • 优先级管理   │   │  • 构建脚本      │   │
│  │  • 复盘文档      │   │  • 工作量估算   │   │  • CI/CD        │   │
│  │                 │   │                 │   │                 │   │
│  │  读: 全员        │   │  读: 全员        │   │  读: 全员        │   │
│  │  写: Conductor  │   │  写: Conductor  │   │  写: Performer  │   │
│  └─────────────────┘   └─────────────────┘   └─────────────────┘   │
│           │                     │                     │            │
│           └─────────────────────┼─────────────────────┘            │
│                                 ▼                                   │
│                    ┌─────────────────────┐                         │
│                    │   数据流协调中心     │                         │
│                    │   (KALLAX Core)     │                         │
│                    └─────────────────────┘                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Confluence 仓库 (知识库)

### 2.1 职责

- **长期记忆**: 项目知识、技术栈选型理由
- **架构决策**: ADR (Architecture Decision Records)
- **设计模式**: 项目中使用的模式及其变体
- **术语表**: 统一项目词汇
- **复盘文档**: 每个 Sprint/EPIC 的经验教训

### 2.2 目录结构

```
confluence/
├── memory/                      # 长期记忆
│   ├── project/                 # 项目知识
│   │   ├── overview.md          # 项目概述
│   │   ├── tech-stack.md        # 技术栈及选型理由
│   │   ├── architecture.md      # 架构文档
│   │   └── dependencies.md      # 依赖关系
│   │
│   ├── patterns/                # 设计模式
│   │   ├── error-handling.md    # 错误处理模式
│   │   ├── caching.md           # 缓存策略
│   │   └── api-design.md        # API 设计规范
│   │
│   ├── glossary/                # 术语表
│   │   └── terms.md             # 统一术语定义
│   │
│   └── memory-index.md          # 记忆索引
│
├── decisions/                   # 架构决策记录
│   ├── ADR-001-rust-core.md     # 选择 Rust 作为核心
│   ├── ADR-002-dag-scheduler.md # DAG 调度设计 (跟 docs/architecture/DAG-SCHEDULER.md 联合)
│   └── ADR-template.md          # ADR 模板
│
├── runbooks/                    # 运维手册
│   ├── deployment.md            # 部署流程
│   ├── incident-res级处理
│
└── retrospectives/              # 复盘文档
    ├── EPIC-001-review.md       # EPIC 复盘
    └── template.md              # 复盘模板
```

### 2.3 访问权限

| 角色 | 读取 | 写入 |
|-----|------|------|
| Human | ✓ | ✓ |
| Conductor | ✓ | ✓ |
| Performer | ✓ | ✗ |

### 2.4 同步机制

```yaml
# PR 合并后自动触发知识更新
on:
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  update_confluence:
    if: github.event.pull_request.merged == true
    steps:
      - name: Extract Knowledge
        run: kallax knowledge:extract --pr ${{ github.event.pull_request.number }}
        
      - name: Update Confluence
        run: kallax knowledge:update --auto-commit
```

---

## 3. Jira 仓库 (任务管理)

### 3.1 职责

- **EPIC 管理**: 大型功能需求
- **Ticket 管理**: 可执行的原子任务
- **状态追踪**: 任务生命周期管理
- **优先级管理**: P0-P3 优先级分类
- **工作量估算**: 预估与实际对比

### 3.2 目录结构

```
jira/
├── epics/                       # 史诗级需求
│   ├── EPIC-001/
│   │   ├── spec.md              # 需求规格
│   │   ├── decomposition.md     # 任务拆解
│   │   └── progress.md          # 进度追踪
│   └── EPIC-002/
│       └── ...
│
├── tickets/                     # 可执行票据
│   ├── TASK-001.yaml            # 票据元数据
│   ├── TASK-002.yaml
│   └── ...
│
├── schemas/                     # 票据模板
│   ├── ticket-schema.md         # Schema 定义
│   ├── feature-template.yaml    # 功能票据模板
│   ├── bugfix-template.yaml     # 修复票据模板
│   └── refactor-template.yaml   # 重构票据模板
│
├── workflows/                   # 状态机定义
│   ├── standard.yaml            # 标准工作流
│   └── hotfix.yaml              # 紧急修复工作流
│
├── inbox/                       # 输入队列
│   ├── human_input.md           # 人类输入
│   └── human_feedback.md        # 人类反馈
│
└── backlog/                     # 待办列表
    ├── p0.md                    # P0 紧急
    ├── p1.md                    # P1 高优先
    ├── p2.md                    # P2 中优先
    └── p3.md                    # P3 低优先
```

### 3.3 Ticket 生命周期

```
                    ┌───────────────────────────────────────┐
                    │                                       │
                    ▼                                       │
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  DRAFT  │───▶│  TODO   │───▶│ IN_PROG │───▶│ REVIEW  │──┘
└─────────┘    └─────────┘    └─────────┘    └─────────┘
     │              │              │              │
     │              │              │              ▼
     │              │              │         ┌─────────┐
     │              │              │         │  DONE   │
     │              │              │         └─────────┘
     │              │              │              │
     │              │              │              ▼
     │              │              │         ┌─────────┐
     └──────────────┴──────────────┴────────▶│ CLOSED  │
                  (废弃/重复)                  └─────────┘

状态转换触发:
- DRAFT → TODO: Conductor 审核通过
- TODO → IN_PROGRESS: Performer 领取
- IN_PROGRESS → REVIEW: Performer 提交 PR
- REVIEW → IN_PROGRESS: Review 需修改
- REVIEW → DONE: Review 通过 + Merge
- DONE → CLOSED: EPIC 关闭时批量处理
```

### 3.4 访问权限

| 角色 | 读取 | 创建 | 状态变更 |
|-----|------|------|---------|
| Human | ✓ | ✓ | ✓ |
| Conductor | ✓ | ✓ | ✓ |
| Performer | ✓ | ✗ | 部分 (claim/complete) |

---

## 4. Code 仓库 (代码)

### 4.1 职责

- **源代码**: 业务逻辑实现
- **配置文件**: 环境配置、CI/CD 配置
- **测试代码**: 单元测试、集成测试、E2E 测试
- **构建脚本**: Makefile、package.json scripts
- **文档**: README、API 文档

### 4.2 分支策略

```
┌─────────────────────────────────────────────────────────────────────┐
│                           分支策略                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  main (生产分支)                                                     │
│  ════════════════════════════════════════════════════════════════   │
│      │         │              │                   │                  │
│      │    ┌────┴────┐    ┌───┴────┐         ┌────┴────┐            │
│      │    │ PR #1   │    │ PR #2  │         │ PR #N   │            │
│      │    │ merged  │    │ merged │         │ merged  │            │
│      │    └────┬────┘    └───┬────┘         └────┬────┘            │
│      │         │             │                   │                  │
│  feature/TASK-001 ──────────────────────────────                    │
│  ─────────────────          │                                       │
│      (Performer #1)         │                                       │
│                             │                                       │
│  feature/TASK-002 ──────────                                        │
│  ─────────────────                                                  │
│      (Performer #2)                                                 │
│                                                                      │
│  hotfix/critical-001                                                │
│  ───────────────────────────────────────────────                    │
│      (紧急修复, 优先合并)                                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

分支命名规范:
- feature/TASK-{NNN}     功能开发
- bugfix/TASK-{NNN}      Bug 修复
- hotfix/{description}   紧急修复
- refactor/TASK-{NNN}    重构
- docs/TASK-{NNN}        文档更新
```

### 4.3 保护规则

```yaml
# main 分支保护
protection_rules:
  main:
    required_reviews: 1
    required_reviewers:
      - conductor
    require_ci_pass: true
    allow_force_push: false
    allow_deletion: false
    
    # 允许合并的角色
    merge_allowed_by:
      - conductor
      
    # 禁止直接推送
    direct_push_allowed_by: []

# feature 分支规则
  feature/*:
    required_reviews: 0           # Performer 可自由推送
    require_ci_pass: false        # CI 在 PR 时检查
    allow_force_push: true        # 允许 rebase
    allow_deletion: true          # 合并后可删除
    
    # 只有分支所有者可推送
    push_allowed_by:
      - branch_owner
```

### 4.4 Worktree 隔离

```bash
# Performer 领取任务时自动创建
kallax task:claim TASK-001

# 内部执行:
git worktree add .worktrees/TASK-001 -b feature/TASK-001 origin/main

# 目录结构:
project/
├── .worktrees/
│   ├── TASK-001/          # Performer #1 独立工作区
│   │   ├── src/
│   │   └── ...
│   ├── TASK-002/          # Performer #2 独立工作区
│   │   ├── src/
│   │   └── ...
│   └── TASK-003/
├── src/                    # main 分支 (Conductor 参考)
├── confluence/
├── jira/
└── ...
```

---

## 5. 数据流

### 5.1 需求到代码

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. 需求输入                                                         │
│                                                                      │
│  Human → inbox/human_input.md                                       │
│  "需要实现用户登录功能，包含 OAuth 支持"                              │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. Conductor 分析                                                   │
│                                                                      │
│  Conductor 读取 confluence/memory/ 查找相关知识                      │
│  ├── patterns/auth.md (已有认证模式)                                │
│  └── decisions/ADR-003-oauth.md (OAuth 选型)                        │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. 任务拆解                                                         │
│                                                                      │
│  Conductor 创建 jira/epics/EPIC-005/                                │
│  └── 拆解为:                                                         │
│      ├── TASK-015: 数据库 Schema (backend)                          │
│      ├── TASK-016: OAuth 集成 (backend)                             │
│      ├── TASK-017: 登录 UI (frontend)                               │
│      └── TASK-018: E2E 测试 (test)                                  │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. Performer 执行                                                   │
│                                                                      │
│  Performer #1 (backend) 领取 TASK-015, TASK-016                     │
│  ├── git worktree add .worktrees/TASK-015 -b feature/TASK-015      │
│  └── 在隔离环境中开发                                                │
│                                                                      │
│  Performer #2 (frontend) 领取 TASK-017                              │
│  └── 并行开发 (文件范围无重叠)                                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. PR 审核 & 合并                                                   │
│                                                                      │
│  Performer 提交 PR → Conductor 5 levels 验证 → 合并到 main           │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. 知识沉淀                                                         │
│                                                                      │
│  合并后自动更新 confluence/memory/                                   │
│  ├── 新模式: patterns/oauth-integration.md                          │
│  └── 术语更新: glossary/terms.md                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 反馈循环

```
┌─────────────────────────────────────────────────────────────────────┐
│  Bug 报告                                                            │
│                                                                      │
│  Human → inbox/human_feedback.md                                    │
│  "OAuth 登录后 token 过期无提示"                                     │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Conductor 处理                                                      │
│                                                                      │
│  1. 查找相关 EPIC: EPIC-005                                         │
│  2. 创建 bugfix ticket: TASK-019                                    │
│  3. 关联原始 ticket: TASK-016                                       │
│  4. 派发给 Performer                                                │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  修复 & 复盘                                                         │
│                                                                      │
│  Performer 修复 → PR 合并 →                                         │
│  Conductor 更新 confluence/retrospectives/EPIC-005-review.md        │
│  └── "教训: token 过期需要前端处理并提示用户"                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. 索引与搜索

### 6.1 全文搜索

```bash
# 搜索知识库
kallax knowledge:search "OAuth token" --scope confluence

# 搜索任务
kallax knowledge:search "登录" --scope jira

# 全局搜索
kallax knowledge:search "authentication" --all
```

### 6.2 TF-IDF 推荐

```bash
# 为新任务推荐相关知识
kallax recommend TASK-020

# 输出:
# Relevant knowledge for TASK-020:
# 1. [0.92] confluence/memory/patterns/oauth-integration.md
# 2. [0.85] confluence/decisions/ADR-003-oauth.md
# 3. [0.71] jira/tickets/TASK-016.yaml (相似任务)
```

---

## 7. 配置

```yaml
# .kallax/config.yml
repositories:
  confluence:
    path: "./confluence"
    sync_on_merge: true
    index_on_change: true
    
  jira:
    path: "./jira"
    ticket_prefix: "TASK"
    epic_prefix: "EPIC"
    
  code:
    path: "./"
    worktree_dir: ".worktrees"
    protected_branches:
      - main
      - release/*

# 索引配置
indexing:
  extensions:
    - .md
    - .yaml
    - .yml
  exclude:
    - node_modules
    - .git
    - .worktrees
  fts_language: "chinese"  # 中文分词

# 同步配置
sync:
  auto_knowledge_update: true
  update_on_pr_merge: true
  retroactive_days: 30
```
