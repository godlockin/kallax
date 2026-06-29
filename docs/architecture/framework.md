# KALLAX 框架白皮书 (跟 v3.x 1:1 同步, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **v3.2.0 重写** (主公 2026-06-30 拍 C explicit 拍板, 跟 v3.1.0 U-002 留待 联合, 跟"翻篇&精进" 战略 矛盾 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致)
>
> **跟 docs/ARCHITECTURE.md 联合**: 本文档是 v3.x 1:1 同步版, 跟主文档 `docs/ARCHITECTURE.md` §3.1 (顶层架构图) + §9 (3 层降级) 互为 互补. **不删** (跟主公拍 C 一致, "重写就是重写" 诚实).

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor
>
> Version 3.2.0 | 多智能体协作框架 (跟 eket 6 武器 + binary 整合 + 5-Level 联合)

---

## 1. v3.x 核心变化 (跟 v2.7.6 联合, 跟"反讽" 联合)

### 1.1 v2.7.6 → v3.x 演化路径 (跟"诚实修正" 联合)

| Release | 关键变化 | 跟"反讽" 联合 |
|---------|---------|------------|
| v2.7.6 | 5 expert 拍板, 经验教训升级/合并/归档/删除 | (基础) |
| v3.0.0 | 6 武器 + Iter 1-12 (跟 eket 对齐) | ✅ 跟"反哺框架" 战略 一致 |
| v3.1.0 | A+B Review hotfix 16 commits (4 P0 + 12 P1) | ✅ 跟 v3.1.0 P-005 治根 联合 |
| v3.2.0 | rtk + caveman 整合 KALLAX (跟 6 武器 互为 互补) | ✅ 跟"翻篇&精进" 战略 一致 |

### 1.2 v3.x 核心哲学 (跟 v2.7.6 联合, 跟"诚实修正" 联合)

1. **信任但验证 (Trust but Verify)**: 跟 v2.7.6 一致, **但 v3.x 落地 5-Level Fact-Forcing** (跟 v3.0.0 武器 2 联合, 跟 v3.1.0 P-003 lazy load 联合)
2. **隔离即安全 (Isolation is Safety)**: 跟 v2.7.6 一致, **但 v3.x 落地 worktree 4→1 统一** (跟 EPIC-054-A 联合)
3. **优雅降级 (Graceful Degradation)**: 跟 v2.7.6 一致, **但 v3.x 落地 1 binary 整合** (跟 v3.1.0 Iter 3 联合, 跟 eket 6 武器 联合)
4. **单一职责 (Single Responsibility)**: 跟 v2.7.6 一致, **但 v3.x 加 Performer sub-role schema** (跟 EPIC-038-A 联合: coder/reviewer/tester/docs)
5. **反讽闭环**: v3.x 新增, 跟 KALLAX-GLOSSARY §1.1 反讽 联合 0 隐藏 反复

### 1.3 v3.x 设计目标 (跟 v2.7.6 联合, 跟"反讽" 联合)

| 目标 | v2.7.6 指标 | v3.x 指标 (跟"独立" 拍板 联合) | 跟"反讽" 联合 |
|------|------------|------------------------------|------------|
| **高可用** | 99.9% 可用性 | 99.9% + 1 binary 整合 (跟 eket parity) | ✅ |
| **低延迟** | P99 < 100ms | P99 < 50ms (Rust 核心层 + binary 整合) | ✅ |
| **可扩展** | 1-50 Performer | 1+4 Performer (master + 4 sub-roles) | ✅ |
| **可观测** | 全链路追踪 | 5-Level Fact-Forcing (L1-L5 实做) | ✅ |
| **类型安全** | 0 any | 0 any + 0 @ts-ignore (strict casting 模式) | ✅ |

---

## 2. v3.x Conductor-Performer 模型 (跟 6 武器 联合)

### 2.1 v3.x 角色分工 (跟 EPIC-038-A sub-role 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────┐
│                        Human Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  主公 (Product Owner / Tech Lead / QA Lead)         │   │
│  │  - explicit 拍板 (跟独立 战略 联合)                    │   │
│  │  - 阻塞决策 (inbox/human_feedback.md)                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Conductor Layer (v3.x)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Conductor Instance (Claude Code / opencode / ...)   │   │
│  │                                                       │   │
│  │  v3.x 职责 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合):     │   │
│  │  ✓ 需求分析与任务拆解 (跟 /kallax-panel 9 专家 联合) │   │
│  │  ✓ 任务派发与进度追踪 (跟 5-Level L1 联合)           │   │
│  │  ✓ PR 审核 (跟 v3.1.0 A+B Review 联合)               │   │
│  │  ✓ 合并到 miao 分支 (跟 v3.0.0 6 武器 联合)          │   │
│  │  ✓ 知识库维护 (跟 EPIC-059-H L0-L4 联合)              │   │
│  │  ✓ 5-Level Fact-Forcing 验证 (跟 v3.0.0 武器 2 联合)  │   │
│  │                                                       │   │
│  │  v3.x 禁止 (跟 v2.7.6 联合 + 新增):                   │   │
│  │  ✗ 编写生产代码 (跟 Rule 10 Master 禁写 联合)          │   │
│  │  ✗ 自我领取任务 (跟 v2.7.6 联合)                       │   │
│  │  ✗ 无 5-Level 验证 合并 (跟 v3.0.0 武器 2 联合)       │   │
│  │  ✗ 自我审查 PR (跟 v2.7.6 联合)                       │   │
│  │  ✗ 越界 Performer 实施 (跟 Rule 13 联合)              │   │
│  │  ✗ 改 binary/Rust 源码 (跟 v3.0.0 Iter 3 联合)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Performer     │    │ Performer     │    │ Performer     │
│ sub-role:     │    │ sub-role:     │    │ sub-role:     │
│ coder         │    │ reviewer      │    │ tester/docs   │
│               │    │               │    │               │
│ (跟 EPIC-038-A 联合: 4 sub-roles 互为 互补)              │
│ (跟 v3.0.0 武器 3 Performer Sub-Role Dispatch 联合)       │
│ Worktree:     │    │ Worktree:     │    │ Worktree:     │
│ 4→1 统一      │    │ 4→1 统一      │    │ 4→1 统一      │
│ (跟 EPIC-054-A 联合)                                       │
└───────────────┘    └───────────────┘    └───────────────┘
```

### 2.2 v3.x 职责边界 (跟 v2.7.6 联合, 跟"反讽" 联合)

| 操作 | Conductor | Performer (coder/reviewer/tester/docs) | 跟"反讽" 联合 |
|-----|-----------|---------------------------------------|------------|
| 分析需求 | ✓ | ✗ | ✅ |
| 拆解任务 | ✓ | ✗ | ✅ |
| 派发任务 | ✓ | ✗ | ✅ |
| 领取任务 | ✗ | ✓ | ✅ |
| 编写代码 | ✗ | ✓ (coder) | ✅ |
| 编写测试 | ✗ | ✓ (tester) | ✅ 跟 v3.0.0 武器 2 联合 |
| 提交 PR | ✗ | ✓ (coder) | ✅ |
| 审核 PR | ✓ | ✓ (reviewer) | ✅ 跟 v3.1.0 A+B Review 联合 |
| 合并代码 | ✓ | ✗ | ✅ 跟 v3.1.0 武器 4 联合 |
| 操作 miao 分支 | ✓ | ✗ | ✅ 跟 v2.7.6 联合 |
| 操作 feature 分支 | ✗ | ✓ | ✅ 跟 v2.7.6 联合 |
| 5-Level 验证 | ✓ | ✓ (self) | ✅ 跟 v3.0.0 武器 2 联合 |

### 2.3 v3.x 架构对比 (跟 v2.7.6 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

| 问题 | v2.7.6 旧方案 | v3.x 设计原则 (跟"反讽" 联合) | KALLAX v3.x 改进 (跟"诚实修正" 联合) |
|-----|--------------|--------------------------------|-------------------------------------|
| 命名 | Master/Performer | 敏感词汇 | Conductor/Performer (跟 v2.7.6 一致) |
| 并行隔离 | 可选 worktree | 文件冲突频发 | **强制 worktree + 4→1 统一** (跟 EPIC-054-A 联合) |
| 验证机制 | 4-Level Fact-Forcing | 幻觉产出 | **5-Level Fact-Forcing (L5 boundary)** (跟 v3.0.0 武器 2 联合) |
| 错误处理 | `expect()`/`panic!()` | 生产崩溃 | 强制 `Result<T, E>` (跟 v2.7.6 一致) |
| Rust binary | 多 crate 3 unreachable | 资源浪费 | **1 binary 整合** (跟 v3.0.0 Iter 3 联合) |
| 6 武器 | 0 | 空白 | **武器 1-6 落地** (跟 v3.0.0 联合, 跟 eket 联合 0 装饰) |
| 子角色 | 0 | 0 sub-role | **4 sub-roles** (coder/reviewer/tester/docs, 跟 EPIC-038-A 联合) |
| 记忆分层 | L0 累积 | 1 GB+ 风险 | **L0-L4 分层** (跟 EPIC-059-H 联合) |
| RTK 整合 | 0 | 0 token 优化 | **rtk 13 命令** (跟 v3.2.0 联合, 75% token 节省) |
| caveman | 0 | 0 压缩 | **caveman 模式** (跟 v3.2.0 联合, 75% token 节省) |

---

## 3. v3.x 三级降级架构 (跟 v3.0.0 Iter 3 binary 整合 联合, 跟"反讽" 联合)

### 3.1 v3.x 架构概览 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合)

```
┌─────────────────────────────────────────────────────────────┐
│  Level 3: Binary Integrated (v3.0.0+)                       │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  1 binary 整合 (kallax, 跟 v2.7.6 多 crate 反讽)       │ │
│  │                                                        │ │
│  │  v3.x 组件 (跟 6 武器 联合):                            │ │
│  │  • 武器 1: Hash-Chain Audit Log (SHA256 chain)         │ │
│  │  • 武器 2: 5-Level Fact-Forcing (L1-L5 实做)           │ │
│  │  • 武器 3: Performer Sub-Role (coder/reviewer/...)    │ │
│  │  • 武器 4: EPIC 4 件套 (A+B review + readme + ...)     │ │
│  │  • 武器 5: Hook Server 回放 + Audit (多 AI 工具)      │ │
│  │  • 武器 6: Dashboard 1 page (1 binary 整合)            │ │
│  │  • 启动时间: ~8ms (跟 v2.7.6 Rust 持平)                │ │
│  │  • 内存占用: ~12MB (跟 v2.7.6 持平)                    │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────┘
                          │ (binary 不可用时降级)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Level 2: Node.js Layer (跟 v2.7.6 联合, 跟 v3.1.0 联合)   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  • Web Dashboard (跟 v2.7.6 联合)                       │ │
│  │  • Hook Server (v3.0.0 武器 5 整合)                     │ │
│  │  • 30+ 斜杠命令 (跟 v2.3.0 install.sh 联合)             │ │
│  │  • 启动时间: ~400ms                                     │ │
│  │  • 内存占用: ~120MB                                    │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────┘
                          │ (Node.js 不可用时降级)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Level 1: Shell Layer (跟 v2.7.6 联合, v3.0.0 保留)        │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  • 基础心跳检查                                        │ │
│  │  • 文件队列消息传递                                    │ │
│  │  • Git 操作 (commit/push/PR)                          │ │
│  │  • 启动时间: ~50ms                                     │ │
│  │  • 依赖: bash + git                                    │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 v3.x 降级触发条件 (跟 v2.7.6 联合, 跟 v3.0.0 联合)

```yaml
# .kallax/config.yml
degradation:
  # 自动降级触发 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合)
  triggers:
    binary_to_node:
      - binary_missing  # 跟 v2.7.6 rust_to_node 联合 0 装饰
      - binary_startup_timeout: 5000  # ms
      - binary_crash_count: 3         # 3次崩溃后降级

    node_to_shell:
      - node_not_found
      - npm_modules_missing
      - node_startup_timeout: 10000  # ms
      - node_crash_count: 5

  # 恢复策略 (跟 v2.7.6 联合)
  recovery:
    check_interval: 60000   # 1分钟检查一次
    recovery_threshold: 3   # 连续3次成功后恢复

  # v3.x 新增: 6 武器 fallback (跟 v3.0.0 联合)
  weapons_fallback:
    weapon_1_hash_chain: "audit-chain.sh 替代 SHA256 chain"
    weapon_2_5_level: "level-1.sh level-2.sh level-3.sh level-4.sh level-5.sh"
    weapon_3_sub_role: "ticket.json performer_sub_role 字段"
    weapon_4_epic_4piece: "check-epic-4-piece.sh"
    weapon_5_hook_replay: "hooks/hook-replay.sh"
    weapon_6_dashboard: "dashboard/dashboard.html 1 page"
```

### 3.3 v3.x 改进: 6 武器 显式降级 (跟 v2.7.6 联合, 跟"反讽" 联合)

```typescript
// ❌ v2.7.6 旧: 静默降级 (跟"反讽" 联合 治根)
if (!redisAvailable) {
  queue = new FileQueue();  // 无日志
}

// ✅ v3.x: 显式降级 + 6 武器 落地
if (!binaryAvailable) {
  logger.warn({
    event: 'degradation_triggered',
    from: 'binary',
    to: 'node',
    reason: 'binary_crash_count_3',
    timestamp: Date.now(),
    weapons_affected: ['weapon_1_hash_chain', 'weapon_2_5_level']
  }, 'Binary degraded to Node.js');

  metrics.increment('kallax.degradation', {
    from: 'binary',
    to: 'node'
  });

  // v3.0.0 武器 2: 5-Level 强制跑
  await runLevel1to5Fallback();
}
```

---

## 4. v3.x 三仓库分离 (跟 v3.0.0 Iter 3 binary 整合 联合, 跟"反讽" 联合)

### 4.1 v3.x 仓库职责 (跟 v2.7.6 联合, 跟 v3.0.0 联合)

```
┌─────────────────────────────────────────────────────────────┐
│  Confluence (知识库) — 跟 v2.7.6 联合                       │
│  路径: ./confluence/                                        │
│                                                              │
│  v3.x 内容:                                                  │
│  ├── memory/           # L0-L4 分层 (跟 EPIC-059-H 联合)     │
│  │   ├── project/      # 项目知识                           │
│  │   ├── patterns/     # 设计模式 (v3.0.0 6 武器 模式)     │
│  │   ├── glossary/     # 35 术语 (v2.7.5 压缩, 跟反讽 联合) │
│  │   ├── lessons/      # L2 经验沉淀                        │
│  │   └── research/     # L4 深度研究                        │
│  ├── decisions/        # ADR (v3.x v3.0.0/v3.1.0/v3.2.0) │
│  ├── runbooks/         # 运维手册                            │
│  ├── memory-promote.sh # L0 → L4 升级 (跟 EPIC-059-H 联合)  │
│  └── retrospectives/   # 复盘 (v3.1.0 16 hotfix 复盘)      │
│                                                              │
│  同步: 每次 PR 合并后自动更新 (跟 v2.7.6 联合)              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Jira (任务管理) — 跟 v2.7.6 联合                           │
│  路径: ./jira/                                              │
│                                                              │
│  v3.x 内容:                                                  │
│  ├── epics/            # EPIC + 4 件套 (跟 v3.0.0 武器 4)    │
│  │   ├── EPIC-001/                                       │
│  │   ├── epic.json    # 状态机 8 转换 (跟 v2.0.4 EPIC-054) │
│  │   ├── README.md    # 实施记录                            │
│  │   └── LESSONS-LEARNED.md  # 经验沉淀 (跟 v3.0.0 武器 4)  │
│  ├── tickets/          # 票据 (跟 EPIC-038-A sub-role 联合) │
│  ├── schemas/          # Schema (跟 Rule 11 联合)          │
│  ├── workflows/        # 状态机 (跟 v2.0.4 联合)            │
│  └── inbox/            # 主公 explicit 拍板 入口            │
│                                                              │
│  v3.x 状态机 (跟 v2.0.4 EPIC-054-C 联合):                   │
│  planning → active → blocked → done → archived → closed    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Code (代码仓库) — 跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合    │
│  路径: ./                                                   │
│                                                              │
│  v3.x 分支策略 (跟 v2.7.6 联合, 跟 v3.1.0 联合):             │
│  ├── miao              # 生产 (仅 Conductor 可操作)         │
│  ├── testing           # 集成验证 (Conductor merge feature) │
│  └── feature/*         # 隔离开发 (Performer 工作区)         │
│                                                              │
│  v3.x 保护规则:                                              │
│  • miao: 禁止直接推送, 需 PR + CI 绿灯 + A+B Review (v3.1.0)│
│  • feature/*: Performer 可自由操作 (跟 EPIC-054-A 联合)     │
│  • 1 binary 整合 (跟 v3.0.0 Iter 3 联合, 跟 eket 联合 0 装饰)│
└─────────────────────────────────────────────────────────────┘
```

### 4.2 v3.x 数据流 (跟 v2.7.6 联合, 跟"反讽" 联合)

```
主公 输入需求
      │
      ▼
┌─────────────┐
│   inbox/    │  ← 原始需求 (跟 v2.7.6 联合)
└─────────────┘
      │
      ▼ Conductor 分析 (跟 v3.0.0 /kallax-panel 9 专家 联合)
┌─────────────┐
│ confluence/ │  ← L0-L4 记忆分层 (跟 EPIC-059-H 联合)
│  memory/    │     Level 1: project/overview
│             │     Level 2: patterns/error-handling
│             │     Level 3: lessons/oauth-2026-06-15
│             │     Level 4: research/6-weapons-design
└─────────────┘
      │
      ▼ Conductor 拆解 (跟 v3.0.0 武器 4 EPIC 4 件套 联合)
┌─────────────┐
│   jira/     │  ← EPIC + 4 件套 (A+B review + readme +
│   epics/    │     lessons-learned + signoff)
└─────────────┘
      │
      ▼ Performer 领取 (跟 EPIC-038-A sub-role 联合)
┌─────────────┐
│   code/     │  ← 实现代码 (1 binary 整合, 跟 v3.0.0 Iter 3)
│             │  ← 4 sub-roles (coder/reviewer/tester/docs)
└─────────────┘
      │
      ▼ PR A+B Review (跟 v3.1.0 武器 4 EPIC 4 件套 联合)
┌─────────────┐
│  testing/   │  ← A+B Review (跟 v3.1.0 16 hotfix 模式)
│  branch     │     Forward 5 维度 + Attack 16 findings
└─────────────┘
      │
      ▼ 合并到 miao
┌─────────────┐
│ confluence/ │  ← L0 → L1 → L2 → L3 → L4 升级 (EPIC-059-H)
│  memory/    │     memory-promote.sh 自动触发
└─────────────┘
```

---

## 5. v3.x DAG 调度 (跟 v2.7.6 联合, 跟 EPIC-038-A sub-role 联合)

### 5.1 v3.x 任务依赖图 (跟 v2.7.6 联合, 跟"反讽" 联合)

```
EPIC-064: v3.2.0 rtk + caveman 整合
│
├── TASK-A: 装 caveman skill (跟 v3.2.0 联合)
│   └── Performer: sub-role=coder
│   └── 实际: 0.1h
│
├── TASK-B: rtk 实战 (跟 v3.2.0 联合)
│   └── Performer: sub-role=coder
│   └── 实际: 0.1h
│
├── TASK-C: caveman 实战 (跟 v3.2.0 联合)
│   └── Performer: sub-role=coder
│   └── 实际: 0.1h
│
└── TASK-D: 写整合文档 + 升 v3.2.0 (跟 v3.2.0 联合)
    └── Performer: sub-role=docs
    └── 实际: 0.5h

关键路径: TASK-A → TASK-D = 0.6h
并行路径: TASK-B, TASK-C 跟 TASK-A 并行
总耗时: 0.6h (跟 v3.2.0 实际 一致)
```

### 5.2 v3.x 调度算法 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)

```rust
pub struct DagScheduler {
    tasks: HashMap<TaskId, Task>,
    dependencies: HashMap<TaskId, Vec<TaskId>>,
    ready_queue: PriorityQueue<TaskId, Priority>,
}

impl DagScheduler {
    /// v3.x: 计算关键路径 (跟 v2.7.6 联合)
    pub fn critical_path(&self) -> Vec<TaskId> {
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

        self.backtrack_critical_path(&earliest_start, &earliest_finish)
    }

    /// v3.x: sub-role-aware 派发 (跟 EPIC-038-A 联合)
    pub fn ready_tasks_for_sub_role(&self, sub_role: SubRole) -> Vec<TaskId> {
        self.tasks.iter()
            .filter(|(id, task)| {
                task.status == Status::Todo &&
                task.sub_role == sub_role &&
                self.dependencies_satisfied(id)
            })
            .map(|(id, _)| id.clone())
            .collect()
    }
}
```

### 5.3 v3.x 负载均衡 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)

```yaml
# Performer sub-role + capacity 声明 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)
performers:
  - id: performer_coder_001
    sub_role: coder          # 跟 EPIC-038-A 联合
    capacity: 3
    skills: [rust, typescript, sql]

  - id: performer_reviewer_001
    sub_role: reviewer        # 跟 EPIC-038-A 联合
    capacity: 2
    skills: [security, performance, audit]

  - id: performer_tester_001
    sub_role: tester          # 跟 EPIC-038-A 联合
    capacity: 2
    skills: [tdd, integration, e2e]

  - id: performer_docs_001
    sub_role: docs            # 跟 EPIC-038-A 联合
    capacity: 1
    skills: [technical-writing, api-docs]

# 调度策略 (跟 v2.7.6 联合)
scheduling:
  algorithm: weighted_round_robin
  weights:
    sub_role_match: 0.5    # 跟 EPIC-038-A 联合: sub-role 匹配优先
    current_load: 0.3
    historical: 0.2
```

---

## 6. v3.x 并行隔离策略 (跟 v2.7.6 联合, 跟 EPIC-054-A 联合)

### 6.1 v3.x 问题背景 (跟 v2.7.6 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 落地 4→1 统一**:
- v2.7.6: 多 Agent 并行修改同一文件导致冲突
- v3.x: 跟 EPIC-054-A 联合, 4 worktree 根 → 1 worktree 根 (`.kallax/worktrees/`)

### 6.2 v3.x 强制 Worktree 隔离 (跟 EPIC-054-A 联合, 跟"反讽" 联合)

```bash
# v3.x: Performer 领取任务时自动创建 worktree (跟 v2.7.6 联合)
kallax task:claim TASK-001

# 内部执行 (跟 EPIC-054-A 联合):
# 1. 4→1 worktree 根统一 (跟 v2.0.4 联合)
git worktree add .kallax/worktrees/TASK-001 -b feature/TASK-001
# 2. cd .kallax/worktrees/TASK-001
# 3. 所有操作在隔离目录中进行
```

```
项目根目录/  (v3.x, 跟 v2.7.6 联合, 跟 EPIC-054-A 联合)
├── .kallax/                # v3.x 单一根 (跟 v2.0.4 联合)
│   ├── worktrees/          # 跟 v2.0.4 EPIC-054-A 联合
│   │   ├── TASK-001/       # Performer #1 工作区
│   │   ├── TASK-002/       # Performer #2 工作区
│   │   └── TASK-003/       # Performer #3 工作区
│   ├── audit/              # v3.0.0 武器 1 Hash-Chain
│   ├── inbox/              # 主公 explicit 拍板 入口
│   └── outbox/             # Performer 报告出口
├── src/                    # miao 分支 (跟 v2.7.6 联合)
└── ...
```

### 6.3 v3.x 文件范围声明 (跟 v2.7.6 联合, 跟 Rule 17 联合)

跟 v2.7.6 联合, **但 v3.x 加 sub-role 字段** (跟 EPIC-038-A 联合):

```yaml
# jira/tickets/TASK-001.yaml (v3.x 跟 EPIC-038-A 联合)
id: TASK-001
title: 实现登录组件
worktree_role: performer          # v3.0.0 EPIC-035-A 联合
performer_sub_role: coder         # v3.x EPIC-038-A 联合
handoff_depth: L1                # v3.x EPIC-038-A 联合
file_scope:
  includes:
    - src/components/Login/**
    - src/hooks/useAuth.ts
    - src/styles/login.css
  excludes:
    - src/components/shared/**  # 共享组件,需协调
```

### 6.4 v3.x 冲突预防 (跟 v2.7.6 联合, 跟"反讽" 联合)

```typescript
// v3.x: Conductor 派发前检查 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)
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
      // v3.x 新增: sub-role 协调 (跟 EPIC-038-A 联合)
      resolution: subRoleCoordination(task1.performer_sub_role, task2.performer_sub_role)
    };
  }

  return { hasConflict: false };
}
```

---

## 7. v3.x 5-Level Fact-Forcing 验证 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

### 7.1 v3.x 问题背景 (跟 v2.7.6 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 升级 4-Level → 5-Level** (跟 v3.0.0 武器 2 联合):
- v2.7.6: 4-Level (存在性/实质性/接线/数据流)
- v3.x: 5-Level (存在性/实质性/接线/数据流/**边界**)

### 7.2 v3.x 5-Level Fact-Forcing (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)

```
┌─────────────────────────────────────────────────────────────┐
│  v3.x 5-Level Fact-Forcing (跟 v3.0.0 武器 2 联合)         │
│                                                              │
│  Level 1: 存在性验证 (Existence)                            │
│  ──────────────────────────────                             │
│  问: 声明的文件/函数/类是否真实存在?                          │
│  验证命令:                                                   │
│  $ git diff --name-only HEAD~1                              │
│  $ ls -la src/components/Login/                             │
│  $ grep -l "export.*Login" src/                             │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Level 2: 实质性验证 (Substance)                            │
│  ──────────────────────────────                             │
│  问: 代码是否为真实逻辑,而非占位符?                          │
│  验证命令:                                                   │
│  $ grep -r "TODO\|FIXME\|stub" src/                         │
│  $ git show HEAD -- src/components/Login/index.tsx          │
│  $ level-2.sh src/components/Login/                          │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Level 3: 接线验证 (Wiring)                                 │
│  ──────────────────────────                                 │
│  问: 模块之间的连接是否正确?                                 │
│  验证命令:                                                   │
│  $ npm run build                                            │
│  $ tsc --noEmit                                             │
│  $ level-3.sh --check-imports src/                          │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Level 4: 数据流验证 (Data Flow)                            │
│  ─────────────────────────────                              │
│  问: 数据是否按预期流转? 端到端是否工作?                      │
│  验证命令:                                                   │
│  $ npm test -- --coverage                                   │
│  $ level-4.sh --e2e                                        │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Level 5: 边界验证 (Boundary) — v3.x 新增 (跟 v3.0.0 联合) │
│  ─────────────────────────────                              │
│  问: 边界条件 / U-002 留待 / scope creep 是否处理?            │
│  验证命令:                                                   │
│  $ level-5.sh --check-scope-creep                           │
│  $ check-anti-patterns.sh .                                 │
│  $ U-002-DECISION-MATRIX.md (主公拍 explicit)              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

缺任一项 = PR 被 Reject (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)
```

### 7.3 v3.x 证据要求 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合)

跟 v2.7.6 联合, **但 v3.x 加 6 维度 验证** (跟 v3.1.0 A+B Review 联合):

```yaml
# v3.x PR Review 必须包含以下证据 (跟 v2.7.6 联合, 跟 v3.1.0 武器 4 联合)
evidence_required:
  # 5-Level 证据 (跟 v3.0.0 武器 2 联合)
  levels:
    level_1_existence: "git diff --name-only 真"
    level_2_substance: "raw stdout 真实"
    level_3_wiring: "build + tsc --noEmit 通过"
    level_4_dataflow: "test 8/8 PASS + coverage"
    level_5_boundary: "level-5.sh + U-002 决策"

  # A+B Review 证据 (跟 v3.1.0 联合, 跟 v3.1.0 P-005 治根 联合)
  ab_review:
    forward: "5 维度 PASS"
    attack: "16 findings 全修"

  # 6 武器 证据 (跟 v3.0.0 联合)
  weapons:
    weapon_1_hash_chain: "audit SHA256 8 字符"
    weapon_2_5_level: "L1-L5 stdout"
    weapon_3_sub_role: "ticket.json sub_role 字段"
    weapon_4_epic_4piece: "A+B review + readme + lessons + signoff"
    weapon_5_hook_replay: "hook SHA"
    weapon_6_dashboard: "dash 页面 hash"

  # ❌ 拒绝的证据 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合)
  rejected:
    - "应该可以工作" (跟 v3.1.0 P-005 装饰 pattern 治根 联合)
    - "看起来正确"
    - "我检查过了"
    - 无输出的命令执行
    - 估数 / "around" / "approximately" (跟 v3.0.0 武器 1 联合)
```

---

## 8. v3.x 6 武器专家组 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1-6 联合, 跟"反讽" 联合)

### 8.1 v3.x 6 武器 (跟 v2.7.6 5 专家 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

| # | 武器 | v2.7.6 对应 | v3.x 落地 (跟"反讽" 联合) | 跟"反讽" 闭环 |
|---|------|------------|-------------------------|------------|
| 1 | Hash-Chain Audit | 0 | SHA256 chain + 不可篡改 audit log sink | ✅ 跟 BE-7 修复模式 联合 |
| 2 | 5-Level Fact-Forcing | 4-Level (L1-L4) | **5-Level (L1-L5)** + 实做 5 个 level-*.sh | ✅ 跟 v2.7.6 升级 联合 |
| 3 | Performer Sub-Role | 0 | 4 sub-roles (coder/reviewer/tester/docs) | ✅ 跟 EPIC-038-A 联合 |
| 4 | EPIC 4 件套 | A+B review (无) | **A+B review + readme + lessons + signoff** | ✅ 跟 v3.0.0 联合 |
| 5 | Hook Server 回放 + Audit | 0 | 多 AI 工具集成 + audit replay | ✅ 跟 v3.0.0 联合 |
| 6 | Dashboard 1 page | 0 | 1 binary 整合 dashboard (跟 eket 联合) | ✅ 跟 v3.0.0 Iter 3 联合 |

### 8.2 v3.x 工作流程 (跟 v2.7.6 联合, 跟 v3.0.0 /kallax-panel 9 专家 联合)

```
1. 触发条件满足 (跟 v2.7.6 联合)
       │
       ▼
2. Conductor 召集 9 专家组 (4 default + 5 extended, 跟 v2.0.3 EPIC-056-A 联合)
       │
       ▼
3. 9 专家独立评审 (并行, 跟 v3.0.0 武器 3 sub-role 联合)
       │
       ▼
4. 6 武器 强制落地 (跟 v3.0.0 联合, 跟"反讽" 联合 0 装饰)
       │
       ▼
5. A+B Review (跟 v3.1.0 16 hotfix 联合)
       │
       ├── 一致同意 → 合并 miao
       │
       └── 存在分歧 → 修复 → 重审
```

---

## 9. v3.x 监控与可观测性 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1 联合)

### 9.1 v3.x 指标体系 (跟 v2.7.6 联合, 跟"反讽" 联合)

```typescript
// v3.x 核心指标 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1-6 联合)
const metrics = {
  // 6 武器 指标 (跟 v3.0.0 联合)
  'kallax.weapon.1.hash_chain.audit': Counter,
  'kallax.weapon.2.5_level.level_1_5': Histogram,
  'kallax.weapon.3.sub_role.dispatch': Counter,
  'kallax.weapon.4.epic_4piece.complete': Counter,
  'kallax.weapon.5.hook.replay': Counter,
  'kallax.weapon.6.dashboard.render': Histogram,

  // 任务指标 (跟 v2.7.6 联合)
  'kallax.task.created': Counter,
  'kallax.task.claimed': Counter,
  'kallax.task.completed': Counter,
  'kallax.task.duration': Histogram,

  // Performer sub-role 指标 (跟 EPIC-038-A 联合)
  'kallax.performer.sub_role.coder': Gauge,
  'kallax.performer.sub_role.reviewer': Gauge,
  'kallax.performer.sub_role.tester': Gauge,
  'kallax.performer.sub_role.docs': Gauge,

  // 降级指标 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合)
  'kallax.degradation.triggered': Counter,
  'kallax.degradation.recovered': Counter,
  'kallax.degradation.binary_to_node': Counter,

  // 验证指标 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)
  'kallax.verification.passed': Counter,
  'kallax.verification.failed': Counter,
  'kallax.verification.level_5': Histogram,  // v3.x 新增
};
```

### 9.2 v3.x 告警规则 (跟 v2.7.6 联合, 跟"反讽" 联合)

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

  # v3.x 新增: 6 武器 失败告警 (跟 v3.0.0 联合)
  - name: WeaponFailureSpike
    condition: rate(kallax.weapon.*.failed) > 0.2
    severity: critical
    action: notify_master  # 跟 Rule 11 Master 禁写 联合: Master 通知, 不写代码
```

---

## 10. v3.x 未来路线图 (跟 v2.7.6 联合, 跟"翻篇&精进" 战略 一致)

### Phase 1 (v2.7.6): 基础框架
- [x] Conductor-Performer 协议
- [x] 三级降级架构
- [x] 基础验证机制
- [x] Worktree 隔离

### Phase 2 (v3.0.0-v3.2.0): 武器化 + eket 对齐 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
- [x] 6 武器 落地 (跟 eket 联合 0 装饰)
- [x] 1 binary 整合 (跟 v3.0.0 Iter 3 联合)
- [x] A+B Review (跟 v3.1.0 16 hotfix 联合)
- [x] Performer sub-role schema (跟 EPIC-038-A 联合)
- [x] L0-L4 记忆分层 (跟 EPIC-059-H 联合)
- [x] rtk + caveman 整合 (跟 v3.2.0 联合)

### Phase 3 (未来): 企业级 (跟"翻篇&精进" 战略 一致, 不再展开)
- [ ] 多租户支持 (跟"反讽" 联合: 不拍 explicit, 暂列)
- [ ] SSO 集成 (跟"反讽" 联合: 不拍 explicit, 暂列)
- [ ] SLA 管理 (跟"反讽" 联合: 不拍 explicit, 暂列)

---

## 附录

### A. 术语表 (跟 v2.7.6 联合, 跟 v2.7.5 35 术语 联合)

参见 [docs/_archived/KALLAX-GLOSSARY.md](_archived/KALLAX-GLOSSARY.md) (v2.7.5 35 术语, 跟 v3.x Iter 1 砍 35 术语 联合).

### B. 相关文档 (跟 v2.7.6 联合, 跟 v3.x 联合)

- [主文档](../ARCHITECTURE.md) — v3.x 1:1 同步
- [三仓库架构](three-repo-architecture.md) — v3.x 1:1 同步
- [Workflow Engine](workflow-engine.md) — v3.x 1:1 同步
- [验证协议](verification-protocol.md) — v3.x 1:1 同步
- [5 levels 文档](../5-levels.md) — 跟 v3.0.0 武器 2 联合
- [4-roles 文档](../4-roles.md) — 跟 EPIC-038-A sub-role 联合

### C. v3.x release notes (跟 v2.7.6 联合, 跟"反讽" 联合)

| Release | 关键变化 | 跟"反讽" 联合 |
|---------|---------|------------|
| v2.7.6 | 5 expert 拍板, 经验教训升级/合并/归档/删除 | (基础) |
| v3.0.0 | 6 武器 + Iter 1-12 (跟 eket 对齐) | ✅ |
| v3.1.0 | A+B Review hotfix 16 commits (4 P0 + 12 P1) | ✅ |
| v3.2.0 | rtk + caveman 整合 (跟 6 武器 互为 互补) | ✅ |
| v3.3.0 (未来) | 跟"翻篇&精进" 战略 一致, 暂列 | — |

---

**跟主公 2026-06-30 拍 C 重写 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 v3.0.0 6 武器 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.2.0 rtk/caveman 累计 联合**
