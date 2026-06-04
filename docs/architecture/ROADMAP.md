# KALLAX Roadmap

> 对齐愿景：让人机协作、AI Agent 协作像专业人类开发团队一样稳定高质量高效率地交付。

## 愿景回顾

KALLAX 的核心价值：
- **平等协作**：人类和 AI Agent 是平等的 coworkers，使用相同协议
- **框架驱动**：框架自主完成分析→拆解→分配→调度，人类从微管理者变为质量守门人
- **协议约束**：用协议而非信任来约束 AI 输出，解决幻觉、记忆、假死问题
- **全链路追溯**：每一步决策留痕留档，可审查可复盘

## Phase 1: 协议层 — 多 Agent 协作基础 (v2.1, 2-3 月)

**目标**：单 Conductor + 2-3 Performer 实战可用，新人 1 小时入门。

| 模块 | 内容 | 对应愿景 |
|------|------|---------|
| Multi-Session Protocol | Conductor/Performer 间通过 API Server 的状态同步协议 | 平等协作 |
| Heartbeat + Dead Detection | Agent 假死自动检测 + 任务重分配 | 解决假死问题 |
| Session Resume | Performer 崩溃后恢复到上次检查点 | 解决记忆问题 |
| Claim Queue | 任务池 + 自动分配 + 优先级排序 | 框架驱动 |
| Trace Log | 每次操作记录：谁、何时、做了什么、证据链接 | 全链路追溯 |

## Phase 2: 智能层 — 自主分析与调度 (v2.2, 3-6 月)

**目标**：框架开始"理解"任务，自主做出调度决策。

| 模块 | 内容 | 对应愿景 |
|------|------|---------|
| Auto-Decompose | 从需求描述自动生成 DAG (依赖图) | 框架驱动 |
| Expert Matching | 按任务特征匹配最优 Agent profile | 框架驱动 |
| Adaptive Schedule | 根据 Agent 历史表现调整分配策略 | 框架驱动 |
| Context Budget | 每个 Agent session 的上下文预算管理 | 解决记忆问题 |
| Quality Trend | 跟踪每个 Agent 的交付质量趋势 | 全链路追溯 |

## Phase 3: 自治层 — Agent 农场 (v3.0, 6-12 月)

**目标**：KALLAX 作为自托管服务运行，持续协调 N 个 Agent。

| 模块 | 内容 | 对应愿景 |
|------|------|---------|
| Agent Farm Server | 常驻服务，管理 Performer 池 | 框架驱动 |
| Auto-Scaling | 根据任务队列动态增减 Performer | 框架驱动 |
| Cross-Project Pool | 多个项目共享同一个 Performer 池 | 工业级交付 |
| Self-Evolution | KALLAX 用自身管理自身开发 | 完整闭环 |
| Enterprise Audit | 合规审计日志 + 权限管理 | 全链路追溯 |

## Phase 4: 生态层 — 社区与标准化 (v4.0, 12-24 月)

| 模块 | 内容 |
|------|------|
| Agent Protocol Standard | 开放协议，第三方 Agent 接入 |
| Plugin Marketplace | 社区贡献 Hook / Expert / Template |
| Benchmark Suite | 标准化 Agent 协作性能测试 |
| Certification | KALLAX Certified Performer 认证 |

## 当前优先级 (v2.0-beta → v2.1)

按紧急度和愿景对齐排序：

| 优先级 | 事项 | 原因 |
|--------|------|------|
| P0 | Multi-session protocol 稳定 | 多窗口协作是核心价值，当前仅测试验证 |
| P0 | Heartbeat + Dead Detection | 假死问题不解决，Agent 协作不可信 |
| P1 | Session Resume + Trace Log | 崩溃恢复和全程追溯是协议约束的基础 |
| P1 | Claim Queue | 让 Conductor 不再需要手动分配 |
| P2 | Auto-Decompose prototype | 演示框架驱动分析的价值 |
| P2 | Expert Matching | 让合适的 Agent 做合适的事 |

---

> KALLAX 不追求代码量。它追求让每一次人机协作都像专业团队一样可信赖。
