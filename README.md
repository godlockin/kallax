# KALLAX

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor

**v1.0.0** | Multi-Agent Collaboration Framework for AI-Driven Development

---

## 概述

KALLAX 是一个**生产级多智能体协作框架**，专为 AI 驱动的软件开发设计。基于 Conductor-Performer 协作模型，支持 1-5 个人类管理者 + N 个 AI 智能体高效协作。

### 核心特性

- **三级降级架构**: Rust (8ms) → Node.js (400ms) → Shell (基础)
- **三仓库分离**: Confluence (知识) + Jira (任务) + Code (代码)
- **Conductor-Performer 模型**: 统一协议，支持多实例并发
- **专家组系统**: 默认 5 人核心专家 + 50+ 扩展角色
- **DAG 调度器**: 关键路径分析 + 多任务并行
- **防幻觉机制**: Fact-Forcing + 4-Level 验证
- **并行隔离强制**: Worktree + 文件范围预分配

---

## 与 KALLAX 的区别

KALLAX 基于 KALLAX 的经验教训进行了关键重构：

| 问题领域 | KALLAX 教训 | KALLAX 改进 |
|---------|----------|------------|
| **并行隔离** | worktree 冲突 | 强制 git worktree + 文件范围预划分 |
| **错误处理** | `expect()`/`panic!()` | 生产代码禁用，强制 `Result<T, E>` |
| **Agent 验证** | background 模式幻觉 | foreground 强制 + Conductor 核查 |
| **资源管理** | 无 TTL 内存泄漏 | 所有缓存/连接必配 TTL |
| **类型安全** | 46 处 `any` 类型 | CI 禁用 `any`/`@ts-ignore` |
| **测试质量** | 内联复制 82 个测试 | mutation testing 验证 |
| **命名** | Master/Slaver | Conductor/Performer (避免敏感词) |

---

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Human-AI Coordination Layer                   │
│  ┌───────────────┐  ┌──────────────┐  ┌───────────────────────┐│
│  │  Conductor UI │  │  Skills Hub  │  │  Expert Panel Control ││
│  │  (Claude Code)│  │  (50+ roles) │  │  (5-phase workflow)   ││
│  └───────────────┘  └──────────────┘  └───────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                               │
                   ┌───────────┼───────────┐
                   ▼           ▼           ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Conductor    │ │ Performer #1 │ │ Performer #N │
│ Instance     │ │ (frontend)   │ │ (backend)    │
│              │ │              │ │              │
│ • Heartbeat  │ │ • claim      │ │ • claim      │
│ • Decompose  │ │ • develop    │ │ • develop    │
│ • PR Review  │ │ • test       │ │ • test       │
│ • Merge      │ │ • PR submit  │ │ • PR submit  │
└──────────────┘ └──────────────┘ └──────────────┘
       │                 │               │
       │   ┌─────────────┼───────────────┘
       │   │
       ▼   ▼
   ┌────────────────────────────────────────┐
   │    Rust Core (Level 1)                 │
   │  ┌──────────────────────────────────┐  │
   │  │ Event Bus | DAG Scheduler        │  │
   │  │ Knowledge Base | Ticket Engine   │  │
   │  │ Agent Pool | Mailbox             │  │
   │  │ Axum HTTP API (:9877)            │  │
   │  └──────────────────────────────────┘  │
   │           ~8ms startup                 │
   │           ~12MB memory                │
   └────────────────────────────────────────┘
       ↓ (fallback)
   ┌────────────────────────────────────────┐
   │    Node.js Layer (Level 2)             │
   │  ┌──────────────────────────────────┐  │
   │  │ Message Queue (Redis/File)       │  │
   │  │ SQLite Manager | Cache Layer     │  │
   │  │ Web Dashboard | WebSocket        │  │
   │  │ Skills System | Type Safety      │  │
   │  └──────────────────────────────────┘  │
   │           ~400ms startup              │
   │           ~120MB memory               │
   └────────────────────────────────────────┘
       ↓ (fallback)
   ┌────────────────────────────────────────┐
   │    Shell Layer (Level 0)               │
   │  ┌──────────────────────────────────┐  │
   │  │ Pure Bash + File Queue           │  │
   │  │ Basic heartbeat + message passing│  │
   │  └──────────────────────────────────┘  │
   └────────────────────────────────────────┘
```

---

## 快速开始

### 安装

```bash
# 克隆仓库
git clone https://github.com/your-org/kallax.git
cd kallax

# 运行安装脚本（自动检测 Rust/Node 版本）
./scripts/quick-setup.sh

# 或手动安装
npm install
cd rust && cargo build --release
```

### 初始化项目

```bash
# 在目标项目中初始化 KALLAX
kallax init

# 启动 Conductor 或 Performer
kallax start --role conductor
kallax start --role performer --specialty backend
```

### 基本工作流

```bash
# Conductor: 创建任务
kallax task:create "实现用户登录功能" --type feature --priority P1

# Performer: 领取任务
kallax task:claim TASK-001

# Performer: 完成任务
kallax task:complete TASK-001

# Conductor: 审核 PR
kallax pr:review --pr 42
```

---

## 命令索引

### 任务管理
```bash
kallax task:create "title"          # 创建票据
kallax task:claim [TASK-NNN]        # 原子领取任务
kallax task:complete TASK-NNN       # Saga 5步完成
kallax task:status TASK-NNN         # 查看状态
kallax task:progress                # DAG 进度 + 关键路径
kallax task:resume TASK-NNN         # checkpoint 恢复
```

### Conductor 操作
```bash
kallax conductor:heartbeat          # 心跳检查（5 问）
kallax conductor:poll               # 处理 Performer 上报
kallax conductor:delegate           # 委派给助理
```

### Performer 操作
```bash
kallax performer:register --role backend   # 注册 Performer
kallax performer:poll                      # 长轮询邮箱
kallax performer:resume TASK-NNN           # 恢复执行
```

### 知识库
```bash
kallax knowledge:index --dir jira/  # 构建 FTS 索引
kallax knowledge:search "keyword"   # 全文搜索
kallax recommend TASK-NNN           # TF-IDF 推荐
```

### 系统管理
```bash
kallax system:doctor                # 系统诊断
kallax team:status                  # 团队状态
kallax server --port 9877           # 启动 HTTP API
kallax web --port 3000              # Web Dashboard
```

---

## 目录结构

```
kallax/
├── rust/                    # Rust 高性能核心
│   └── crates/
│       ├── kallax-core/     # 类型系统 + 中间件
│       ├── kallax-engine/   # 执行引擎 + DAG
│       ├── kallax-cli/      # CLI 入口
│       ├── kallax-server/   # HTTP API
│       └── context-mon/     # 上下文监控
├── node/                    # Node.js 增强层
│   └── src/
│       ├── commands/        # 40+ 命令实现
│       ├── core/            # 消息队列、缓存
│       ├── api/             # HTTP/WebSocket
│       └── skills/          # Skills 系统
├── confluence/              # 知识库仓库
├── jira/                    # 任务管理仓库
├── docs/                    # 架构文档
├── template/                # 外部项目模板
├── scripts/                 # 运维脚本
└── .kallax/                 # 系统数据目录
```

---

## 配置

### 主配置 (.kallax/config.yml)

```yaml
version: "1.0.0"
mode: "claude_code"              # claude_code | copilot | gemini
profile: "standard"              # lightweight | standard | enterprise

# Conductor 白名单
conductor_emails:
  - admin@example.com

# 三仓库路径
repositories:
  confluence: "./confluence"
  jira: "./jira"
  code: "./"

# 降级策略
degradation:
  mode: auto                     # auto | rust | node | shell
  redis_timeout: 5000            # ms
  
# 并行隔离策略 (KALLAX 新增)
isolation:
  enforce_worktree: true         # 强制 worktree 隔离
  file_scope_check: true         # 文件范围检查
  max_parallel_performers: 5

# 资源管理 (KALLAX 改进)
resources:
  cache_ttl: 300000              # 5 分钟 TTL
  connection_pool_max: 10
  connection_pool_timeout: 30000
```

---

## 贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解贡献指南。

## 许可

MIT License - 详见 [LICENSE](LICENSE)
