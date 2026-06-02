# KALLAX 术语表

## 核心概念

### KALLAX
**K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor

知识增强的杠杆学习智能体执行器。一个生产级多智能体协作框架。

### Conductor (指挥者)
协调全局的角色，负责：
- 需求分析和任务拆解Performer (执行者)
执行具体任务的角色，负责：
- 领取和开发任务
- 编写测试
- 提交 PR
- 处理 Review 反馈

**对应 KALLAX**: Slaver

### Ticket (票据)
工作单元的规范化描述，存储在 `jira/tickets/` 目录。

格式: `TASK-{NNN}.md`

包含:
- Frontmatter (id, title, type, priority, status, file_scope)
- 需求描述
- 接受标准 (AC)
- 实现记录

### EPIC
功能集合，由多个 Ticket 组成。

格式: `EPIC-{ID}.md`

存储在 `jira/epics/` 目录。

### Worktree (工作树)
Git worktree，用于隔离并行 Performer 的工作空间。

KALLAX 强制要求每个 Performer 在独立 worktree 中工作，解决 KALLAX 的并行冲突问题。

### File Scope (文件范围)
Ticket 中声明的文件修改范围，用于：
- 并行任务冲突检测
- Performer 权限控制
- 变更审计

## 三仓库架构

### Confluence
知识库仓库，存储：
- 架构设计文档
- 技术决策记录 (ADR)
- 研究笔记
- 最佳实践

路径: `./confluence/`

### Jira
任务管理仓库，存储：
- Ticket 文件
- EPIC 文件
- 归档任务

路径: `./jira/`

### Code
代码仓库，即项目本身。

分支策略:
- `feature/*` - 功能分支 (Performer)
- `testing` - 集成测试分支
- `main` - 主分支 (稳定)

## 三级架构

### Level 0: Shell
纯 Bash 实现，零依赖。

用于极度受限环境（CI/CD、容器）。

### Level 1: Rust
高性能核心，启动时间 ~8ms。

用于关键路径操作（task:claim, DAG 调度）。

### Level 2: Node.js
功能丰富层，启动时间 ~400ms。

用于复杂操作（Web Dashboard, Skills 系统）。

## 工作流术语

### Heartbeat (心跳)
Conductor 定期执行的检查循环，包含 5 个问题：
1. 任务优先级
2. Performer 状态
3. 项目进度
4. 阻塞决策
5. 消息队列

### Gate Review (门卡审查)
任务执行前的质量检查，确保：
- Ticket 完整性
- 接受标准明确
- 依赖就绪
- 文件范围声明

### Fact-Forcing (事实强制)
4-Level 验证协议：
1. 存在性 - 文件存在于 diff
2. 实质性 - 真实逻辑，非 stub
3. 接线正确 - 正确 import/export
4. 数据流动 - 集成测试验证

### Saga
事务性操作模式，保证多步操作的原子性。

task:complete 使用 Saga 5步：
1. 验证票据
2. 更新状态
3. 追加结果
4. 记录检查点
5. 发布事件

### Circuit Breaker (断路器)
容错模式，防止级联失败。

状态: CLOSED → OPEN → HALF_OPEN

## Expert Panel (专家组)

### Core Experts (核心专家 5 人)
1. 🏗️ Architect - 架构师
2. 💻 Backend - 后端工程师
3. 🎨 Frontend - 前端工程师
4. 🖌️ UX - UX 研究员
5. 📋 Product - 产品经理

### Extended Experts (扩展专家 50+)
按领域分类：
- AI/ML
- Business/Finance
- Consulting
- Design
- HR
- Knowledge
- Marketing
- Ops
- PR
- Tech
- Training

## 改进术语 (KALLAX vs KALLAX)

| KALLAX 术语 | KALLAX 术语 | 改进说明 |
|----------|------------|---------|
| Master | Conductor | 避免敏感词，更准确表达协调角色 |
| Slaver | Performer | 避免敏感词，强调执行能力 |
| kallax | kallax | 新品牌 |
| expect/unwrap | Result | 错误处理改进 |
| any 类型 | unknown + 类型守卫 | 类型安全改进 |
| 无 TTL 缓存 | LRU + TTL | 资源管理改进 |
| 静默降级 | 显式降级 + 日志 | 可观测性改进 |
