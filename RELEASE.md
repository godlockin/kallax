# KALLAX v2.0.0-beta

> **让人类和 AI Agent 像专业团队一样平等协作。框架驱动质量，协议约束输出，全链路可追溯。**

2026-06-04 | 65 commits | MIT License

---

## 关于 KALLAX

KALLAX (Knowledge-Augmented Leveraged Learning Agent eXecutor) 是一个 Conductor-Performer 多 Agent 协作框架。它让 1 个 Conductor（人或 AI）协调多个 Performer Agent 在隔离的 git worktree 中并行开发，通过协议约束、Fact-Forcing 验证和全链路追溯保证交付质量。

KALLAX 不把 AI 视为工具——人类和 AI 在这里是**平等的协作者**。

## 核心能力

### 多 Agent 协作引擎
- **Conductor-Performer 模型**: 人类和 AI 平等的协作协议，共同 claim、开发、review
- **DAG 调度器**: BinaryHeap 优先级队列 + 关键路径分析，Kahn 波次并行执行
- **Worktree 隔离**: 每个 Performer 独立 git worktree，文件范围预声明，冲突自动检测
- **并发安全**: 原子 Claim（多 Agent 同时领取同一任务，恰好 1 个胜出）

### 质量保证
- **4 级 Fact-Forcing 验证**: L1 存在性→L2 实质性→L3 接线→L4 数据流，每级有可验证证据
- **Saga 补偿事务**: 5 步任务完成（测试→Lint→Commit→Push→PR），任意步失败自动回滚
- **Gate Review**: Preflight→Architecture→Security→Performance 四门禁
- **Property-Based 测试**: 核心不变量保护（幂等、原子、状态一致）

### 可靠性
- **三级降级**: Rust (8ms/12MB) → Node (400ms/120MB) → Shell (50ms 应急)
- **RecoveryManager**: 60s 探测 + 自动升级 + 崩溃计数
- **Master Election**: Redis→SQLite→filesystem 三级选举
- **心跳监控**: Agent 假死自动检测 + 任务重分配
- **检查点恢复**: DAG 执行中断后恢复，不丢进度

### 开发者体验
- **27 个 Slash Commands**: `/kallax-start`, `/kallax-claim`, `/kallax-submit-pr` 等
- **20+ CLI 命令组**: Ticket/Task/Conductor/Performer/Epic/Knowledge 全生命周期
- **API Server**: 20 REST 端点 + SSE 实时事件 + 认证 + 限流
- **Web Dashboard**: 实时状态面板（Tasks/Agents/System/Overview）
- **安装**: `bash scripts/install.sh` 一键安装，自动升级检测

### 测试覆盖
- **Node.js**: 38 测试文件 (单元 + E2E + 属性测试)
- **Rust**: 99 测试通过，零 Clippy 警告
- **多会话模拟**: 真实多进程 Conductor+Performer 协作验证

## 架构

```
Shell (L1)         Node.js (L2)        Rust (L3)
───────            ──────────          ────────
30 slash cmd       102 source files    31 source files
40 shell scripts   CLI + API server    DAG Scheduler
                   SQLite + Worker     DB persistence
                   EventBus + Hook     Webhook + Analyzer
                   RecoveryManager     Fingerprint
```

## 安装

```bash
# 克隆
git clone https://github.com/godlockin/kallax.git
cd kallax

# 安装 (自动检测环境)
bash scripts/install.sh

# 初始化项目
cd /your/project
kallax init

# 开始使用
/kallax-start
```

## 路线图

| 阶段 | 内容 |
|------|------|
| **v2.0-beta** (now) | 多 Agent 协作核心稳定，单 Conductor + 1-3 Performer 可用 |
| **v2.1** | Web Dashboard 增强，可视化监控，多项目支持 |
| **v2.2** | Rust 引擎完备，8ms 级调度，分布式 Agent Farm |
| **v3.0** | 自托管 Agent 农场，跨组织 Agent 协作，自我演进 |

## 从 EKET 迁移

KALLAX 是 EKET (Elite Knowledge & Engineering Team) 的下一代。如果你在用 EKET，参考 `docs/guides/migration-single-to-multi-agent.md`。

核心改进：
- **类型安全**: 零 `any`，零 `@ts-ignore` (vs EKET 46 处)
- **错误处理**: neverthrow Result<T,E> 全栈 (vs 混合异常)
- **安全模型**: 命令 allowlist (vs 黑名单)
- **命名**: Conductor/Performer (vs Master/Slaver)
- **代码质量**: 所有文件 <300 行 (vs 多个 500-1000+ 行文件)

## 贡献

KALLAX 使用自身管理开发 (`eat-dog-food`)。欢迎提交 Issue、PR、或通过 `/kallax-expert` 参与评审。

## License

MIT License © 2026 KALLAX Contributors
