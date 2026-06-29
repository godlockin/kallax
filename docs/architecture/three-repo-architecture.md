# KALLAX 三仓库架构 (跟 v3.x 1:1 同步, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **v3.2.0 重写** (主公 2026-06-30 拍 C explicit 拍板, 跟 v3.1.0 U-002 留待 联合, 跟"翻篇&精进" 战略 矛盾 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致)
>
> **跟 docs/ARCHITECTURE.md 联合**: 本文档是 v3.x 1:1 同步版, 跟主文档 `docs/ARCHITECTURE.md` §3.1 (顶层架构图) + §12.3 (知识库 + 任务管理) 互为 互补. **不删** (跟主公拍 C 一致, "重写就是重写" 诚实).

> 关注点分离: 知识、任务、代码各司其职 (跟 v2.7.6 联合, 跟 v3.x 1:1 同步)

---

## 1. v3.x 架构概览 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 binary 整合 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│                   KALLAX v3.x 三仓库架构 (跟 v3.0.0 Iter 3 联合)   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │
│  │   Confluence    │   │      Jira       │   │      Code       │   │
│  │   (知识库)       │   │   (任务管理)     │   │   (代码仓库)     │   │
│  │                 │   │                 │   │                 │   │
│  │  ./confluence/  │   │    ./jira/      │   │      ./         │   │
│  │                 │   │                 │   │                 │   │
│  │  v3.x 内容:     │   │  v3.x 内容:     │   │  v3.x 内容:     │   │
│  │  • L0-L4 记忆   │   │  • EPIC + 4件套 │   │  • 1 binary     │   │
│  │  • patterns      │   │  • sub-role     │   │  • 6 武器 落地   │   │
│  │  • 35 术语       │   │  • 8 状态机     │   │  • rtk + caveman │   │
│  │                 │   │                 │   │                 │   │
│  │  读: 全员        │   │  读: 全员        │   │  读: 全员        │   │
│  │  写: Conductor  │   │  写: Conductor  │   │  写: Performer  │   │
│  └─────────────────┘   └─────────────────┘   └─────────────────┘   │
│           │                     │                     │            │
│           └─────────────────────┼─────────────────────┘            │
│                                 ▼                                   │
│                    ┌─────────────────────┐                         │
│                    │  v3.x 1 binary 整合  │                         │
│                    │  (跟 eket 对齐, 跟    │                         │
│                    │   v3.0.0 Iter 3 联合) │                         │
│                    └─────────────────────┘                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. v3.x Confluence 仓库 (知识库) (跟 v2.7.6 联合, 跟 EPIC-059-H L0-L4 联合, 跟"反讽" 联合)

### 2.1 v3.x 职责 (跟 v2.7.6 联合, 跟 EPIC-059-H 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 落地 L0-L4 分层** (跟 EPIC-059-H 联合):
- **L0 (state)**: 短期状态 (`.kallax/state/`)
- **L1 (decision)**: 单 ticket 决策 (`confluence/decisions/`)
- **L2 (lesson)**: EPIC 经验 (`confluence/memory/lessons/`)
- **L3 (pattern)**: 跨 release 模式 (`confluence/memory/patterns/`)
- **L4 (research)**: 深度研究 (`confluence/memory/research/`)

### 2.2 v3.x 目录结构 (跟 v2.7.6 联合, 跟 EPIC-059-H 联合, 跟"反讽" 联合)

```
confluence/  (v3.x, 跟 v2.7.6 联合, 跟 EPIC-059-H 联合)
├── memory/                      # L0-L4 分层 (跟 EPIC-059-H 联合)
│   ├── project/                 # 项目知识 (L1)
│   │   ├── overview.md
│   │   ├── tech-stack.md
│   │   ├── architecture.md
│   │   └── dependencies.md
│   │
│   ├── patterns/                # 设计模式 (L3)
│   │   ├── error-handling.md
│   │   ├── caching.md
│   │   ├── api-design.md
│   │   └── 6-weapons-design.md  # v3.0.0 新增
│   │
│   ├── glossary/                # 术语表 (L1)
│   │   └── terms.md             # v2.7.5 35 术语 (跟 v3.x Iter 1 砍 35 术语 联合)
│   │
│   ├── lessons/                 # 经验沉淀 (L2)
│   │   └── epic-{ID}-{date}.md  # EPIC 完成触发
│   │
│   ├── research/                # 深度研究 (L4)
│   │   └── {topic}.md           # PHASE review 触发
│   │
│   └── memory-index.md          # 记忆索引 (跟 EPIC-059-H 联合)
│
├── decisions/                   # ADR (v3.x, 跟 v2.7.6 联合)
│   ├── ADR-001-rust-core.md
│   ├── ADR-002-dag-scheduler.md
│   ├── PHASE-013-REFLECTION-2026-06-18.md  # v2.4.1 反思
│   ├── PHASE-014-REVIEW-2026-06-18.md     # v2.5.0 跨期 review
│   ├── V310-A-REVIEW-2026-06-29.md        # v3.1.0 A 组 Forward
│   ├── V310-B-REVIEW-2026-06-29.md        # v3.1.0 B 组 Attack
│   └── archived/                # v2.7.6 30 文档归档 (跟"反讽" 联合)
│
├── runbooks/                    # 运维手册 (跟 v2.7.6 联合)
│   ├── deployment.md
│   └── incident-response.md
│
├── memory-promote.sh            # v3.0.0 L0 → L4 升级 (跟 EPIC-059-H 联合)
│
└── retrospectives/              # 复盘 (跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 复盘 联合)
    └── EPIC-{ID}-review.md
```

### 2.3 v3.x 访问权限 (跟 v2.7.6 联合, 跟"反讽" 联合)

| 角色 | 读取 | 写入 | 跟"反讽" 联合 |
|-----|------|------|------------|
| Human (主公) | ✓ | ✓ | ✅ 跟 v2.7.6 联合 |
| Conductor | ✓ | ✓ (L0 → L4) | ✅ 跟 v2.7.6 联合, 跟 EPIC-059-H 联合 |
| Performer (coder/reviewer/tester/docs) | ✓ (L0/L1) | ✓ (L1, 写自己的 ticket 决策) | ✅ 跟 v2.7.6 联合, 跟 EPIC-038-A 联合 |
| Auditor | ✓ (L0-L4) | ✗ (只读) | ✅ 跟 v3.0.0 武器 1 联合 |

### 2.4 v3.x 同步机制 (跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 联合, 跟"反讽" 联合)

```yaml
# v3.x PR 合并后自动触发 L0 → L4 升级 (跟 v2.7.6 联合, 跟 EPIC-059-H 联合)
on:
  pull_request:
    types: [closed]
    branches: [miao]

jobs:
  promote_memory:
    if: github.event.pull_request.merged == true
    steps:
      - name: L0 → L1 (ticket 完成)
        run: bash scripts/memory-promote.sh promote L0 L1

      - name: L1 → L2 (EPIC 闭环)
        run: bash scripts/memory-promote.sh promote L1 L2

      # 跟 v3.0.0 Iter 11 集成测试 6 武器 联合
      - name: 6 武器 验证
        run: |
          bash scripts/audit/audit-verify.sh    # 武器 1
          bash scripts/verify/level-1.sh         # 武器 2
          bash scripts/verify/level-2.sh
          bash scripts/verify/level-3.sh
          bash scripts/verify/level-4.sh
          bash scripts/verify/level-5.sh
          bash scripts/verify/check-epic-4-piece.sh  # 武器 4
```

---

## 3. v3.x Jira 仓库 (任务管理) (跟 v2.7.6 联合, 跟 EPIC-038-A sub-role 联合, 跟"反讽" 联合)

### 3.1 v3.x 职责 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 加 sub-role schema** (跟 EPIC-038-A 联合):
- **EPIC 管理**: 大型功能需求 (跟 v2.7.6 联合)
- **Ticket 管理**: 可执行任务 (跟 v2.7.6 联合)
- **sub-role 派发**: 4 sub-roles (coder/reviewer/tester/docs) (跟 EPIC-038-A 联合)
- **状态追踪**: 8 状态机 (planning/active/blocked/done/archived/closed) (跟 v2.0.4 EPIC-054-C 联合)
- **4 件套强制**: A+B review + readme + lessons + signoff (跟 v3.0.0 武器 4 联合)

### 3.2 v3.x 目录结构 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)

```
jira/  (v3.x, 跟 v2.7.6 联合, 跟 EPIC-038-A 联合)
├── epics/                       # EPIC + 4 件套 (跟 v3.0.0 武器 4 联合)
│   ├── EPIC-001/
│   │   ├── epic.json           # 状态机 8 转换
│   │   ├── README.md           # 实施记录
│   │   ├── LESSONS-LEARNED.md  # 经验沉淀 (跟 EPIC-059-E 联合)
│   │   └── A-B-REVIEW.md       # A+B Review (跟 v3.1.0 联合)
│   └── EPIC-002/
│       └── ...
│
├── tickets/                     # 票据 (跟 EPIC-038-A sub-role 联合)
│   ├── TASK-001/
│   │   └── ticket.json         # 含 worktree_role + performer_sub_role
│   ├── TASK-002/
│   └── ...
│
├── schemas/                     # Schema (跟 v2.7.6 联合, 跟 Rule 11 联合)
│   ├── ticket-schema.md
│   ├── feature-template.yaml
│   ├── bugfix-template.yaml
│   └── refactor-template.yaml
│
├── workflows/                   # 状态机 (跟 v2.0.4 EPIC-054-C 联合)
│   ├── standard.yaml
│   └── hotfix.yaml
│
├── inbox/                       # 主公 explicit 拍板 入口 (跟 v2.7.6 联合)
│   ├── human_input.md
│   └── human_feedback.md
│
└── backlog/                     # 待办 (跟 v2.7.6 联合)
    ├── p0.md
    ├── p1.md
    ├── p2.md
    └── p3.md
```

### 3.3 v3.x Ticket schema (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

```yaml
# jira/tickets/TASK-001/ticket.json (v3.x, 跟 EPIC-038-A 联合)
{
  "id": "TASK-001",
  "title": "实现登录组件",
  "worktree_role": "performer",        # v3.0.0 EPIC-035-A 联合
  "performer_sub_role": "coder",       # v3.x EPIC-038-A 新增
  "handoff_depth": "L1",              # v3.x EPIC-038-A 新增
  "file_scope": {
    "includes": [
      "src/components/Login/**",
      "src/hooks/useAuth.ts",
      "src/styles/login.css"
    ],
    "excludes": [
      "src/components/shared/**"
    ]
  },
  "status": "ready",
  "priority": "P1"
}
```

### 3.4 v3.x Ticket 生命周期 (跟 v2.7.6 联合, 跟 v2.0.4 EPIC-054-C 8 状态机 联合)

```
                    ┌───────────────────────────────────────┐
                    │                                       │
                    ▼                                       │
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│ PLANNING │───▶│  ACTIVE  │───▶│ BLOCKED  │───▶│   DONE   │──┘
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │              │              │              │
     │              │              │              ▼
     │              │              │         ┌──────────┐
     │              │              │         │ ARCHIVED │
     │              │              │         └──────────┘
     │              │              │              │
     │              │              │              ▼
     │              │              │         ┌──────────┐
     └──────────────┴──────────────┴────────▶│  CLOSED  │
                  (废弃/重复)                  └──────────┘

v3.x 状态转换 (跟 v2.0.4 EPIC-054-C 联合):
- PLANNING → ACTIVE: Conductor 审核通过
- ACTIVE → BLOCKED: 主公 explicit 拍板 (inbox/human_feedback.md)
- ACTIVE → IN_PROGRESS: Performer 领取 (跟 EPIC-038-A sub-role 联合)
- IN_PROGRESS → REVIEW: Performer 提交 PR (跟 v3.1.0 A+B Review 联合)
- REVIEW → IN_PROGRESS: Review 需修改
- REVIEW → DONE: A+B Review 通过 + Merge
- DONE → ARCHIVED: EPIC 关闭时批量处理
- ARCHIVED → CLOSED: 1 release 累计 后清理
```

### 3.5 v3.x 访问权限 (跟 v2.7.6 联合, 跟 EPIC-038-A sub-role 联合)

| 角色 | 读取 | 创建 | 状态变更 | 跟"反讽" 联合 |
|-----|------|------|---------|------------|
| Human (主公) | ✓ | ✓ | ✓ | ✅ |
| Conductor | ✓ | ✓ | ✓ | ✅ 跟 v2.7.6 联合 |
| Performer (coder/reviewer/tester/docs) | ✓ | ✗ | 部分 (claim/complete 自己 sub-role 的) | ✅ 跟 EPIC-038-A 联合 |
| Auditor | ✓ (L0-L4) | ✗ | ✗ (只读 + 写 audit 报告) | ✅ 跟 v3.0.0 武器 1 联合 |

---

## 4. v3.x Code 仓库 (代码) (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 binary 整合 联合, 跟"反讽" 联合)

### 4.1 v3.x 职责 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 落地 1 binary 整合** (跟 v3.0.0 Iter 3 联合, 跟 eket 联合 0 装饰):
- **源代码**: 业务逻辑实现 (跟 v2.7.6 联合)
- **1 binary 整合**: kallax binary, 跟 eket 对齐 (跟 v3.0.0 Iter 3 联合)
- **6 武器落地**: Hash-Chain + 5-Level + Sub-Role + EPIC 4 件套 + Hook + Dashboard (跟 v3.0.0 联合)
- **rtk + caveman 整合**: 跟 v3.2.0 联合
- **测试代码**: 单元 + 集成 + E2E (跟 v2.7.6 联合)
- **构建脚本**: Makefile、package.json scripts (跟 v2.7.6 联合)

### 4.2 v3.x 分支策略 (跟 v2.7.6 联合, 跟 v3.1.0 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     v3.x 分支策略 (跟 v2.7.6 联合)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  miao (生产分支, 仅 Conductor 可操作)                                │
│  ════════════════════════════════════════════════════════════════   │
│      │         │              │                   │                  │
│      │    ┌────┴────┐    ┌───┴────┐         ┌────┴────┐            │
│      │    │ PR #1   │    │ PR #2  │         │ PR #N   │            │
│      │    │ merged  │    │ merged │         │ merged  │            │
│      │    └────┬────┘    └───┬────┘         └────┬────┘            │
│      │         │             │                   │                  │
│  feature/TASK-001 ──────────────────────────────                    │
│  ─────────────────          │                                       │
│      (Performer #1, sub-role=coder)                                 │
│                             │                                       │
│  feature/TASK-002 ──────────                                        │
│  ─────────────────                                                  │
│      (Performer #2, sub-role=reviewer)                              │
│                                                                      │
│  testing (集成验证分支, Conductor merge feature → 这里)              │
│  ────────────────────────────────────────                          │
│      (跟 v2.0.7 联合, 跟 v3.1.0 A+B Review 联合)                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

v3.x 分支命名 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合):
- feature/TASK-{NNN}     功能开发 (sub-role=coder)
- review/TASK-{NNN}      评审 (sub-role=reviewer)
- test/TASK-{NNN}        测试 (sub-role=tester)
- docs/TASK-{NNN}        文档 (sub-role=docs)
- hotfix/{description}   紧急修复
- refactor/TASK-{NNN}    重构
```

### 4.3 v3.x 保护规则 (跟 v2.7.6 联合, 跟 v3.1.0 A+B Review 联合, 跟"反讽" 联合)

```yaml
# v3.x 分支保护 (跟 v2.7.6 联合, 跟 v3.1.0 联合)
protection_rules:
  miao:
    required_reviews: 2                       # v3.x: 2 reviewer (跟 v3.1.0 A+B 联合)
    required_reviewers:
      - conductor
      - auditor                                # v3.0.0 武器 1 联合
    require_ci_pass: true
    require_5_level: true                     # v3.x: 5-Level 强制 (跟 v3.0.0 武器 2 联合)
    allow_force_push: false
    allow_deletion: false

    # 允许合并的角色 (跟 v2.7.6 联合)
    merge_allowed_by:
      - conductor

    # 禁止直接推送 (跟 v2.7.6 联合)
    direct_push_allowed_by: []

  # feature 分支规则 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)
  feature/*:
    required_reviews: 0           # Performer 可自由推送
    require_ci_pass: false        # CI 在 PR 时检查
    allow_force_push: true        # 允许 rebase
    allow_deletion: true          # 合并后可删除

    # 只有 sub-role 匹配可推送 (跟 EPIC-038-A 联合)
    push_allowed_by:
      - branch_owner_with_sub_role
```

### 4.4 v3.x Worktree 隔离 (跟 v2.7.6 联合, 跟 EPIC-054-A 4→1 统一 联合, 跟"反讽" 联合)

```bash
# v3.x: Performer 领取任务时自动创建 worktree (跟 v2.7.6 联合, 跟 EPIC-054-A 联合)
kallax task:claim TASK-001

# 内部执行 (跟 EPIC-054-A 联合, 跟 v3.0.0 Iter 3 联合):
# 1. 4→1 worktree 根统一 (跟 v2.0.4 联合)
git worktree add .kallax/worktrees/TASK-001 -b feature/TASK-001 origin/miao
# 2. cd .kallax/worktrees/TASK-001
# 3. 所有操作在隔离目录中进行
```

```
项目根目录/  (v3.x, 跟 v2.7.6 联合, 跟 EPIC-054-A 联合, 跟 v3.0.0 Iter 3 联合)
├── .kallax/                # v3.x 单一根 (跟 v2.0.4 联合)
│   ├── worktrees/          # 跟 v2.0.4 EPIC-054-A 联合: 4→1 统一
│   │   ├── TASK-001/       # Performer #1 (sub-role=coder)
│   │   ├── TASK-002/       # Performer #2 (sub-role=reviewer)
│   │   └── TASK-003/       # Performer #3 (sub-role=tester)
│   ├── audit/              # v3.0.0 武器 1 Hash-Chain (跟 eket 联合)
│   ├── inbox/              # 主公 explicit 拍板 入口
│   ├── outbox/             # Performer 报告出口
│   └── memory/             # L0-L4 分层 (跟 EPIC-059-H 联合)
├── src/                    # miao 分支 (跟 v2.7.6 联合)
├── .claude/skills/         # v3.2.0 caveman 整合 (跟 v3.2.0 联合)
└── ...
```

---

## 5. v3.x 数据流 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1-6 联合, 跟"反讽" 联合)

### 5.1 v3.x 需求到代码 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1-6 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. 需求输入 (跟 v2.7.6 联合)                                      │
│                                                                      │
│  Human (主公) → inbox/human_input.md                                │
│  "需要实现 v3.2.0 rtk + caveman 整合"                                │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. Conductor 分析 (跟 v2.7.6 联合, 跟 v3.0.0 /kallax-panel 9 专家 联合) │
│                                                                      │
│  Conductor 读取 confluence/memory/ 查找相关知识                      │
│  ├── L0 state: 当前 task 状态                                       │
│  ├── L1 decisions: v3.0.0/v3.1.0 决策                               │
│  ├── L2 lessons: v2.7.6 经验教训                                    │
│  ├── L3 patterns: 6 武器 模式                                        │
│  └── L4 research: eket 借鉴 Phase 1                                  │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. 任务拆解 (跟 v2.7.6 联合, 跟 v3.0.0 武器 4 EPIC 4 件套 联合)        │
│                                                                      │
│  Conductor 创建 jira/epics/EPIC-064/                                │
│  └── 拆解为 (跟 EPIC-038-A sub-role 联合):                          │
│      ├── TASK-001: 装 caveman (sub-role=coder)                      │
│      ├── TASK-002: rtk 实战 (sub-role=coder)                         │
│      ├── TASK-003: caveman 实战 (sub-role=coder)                    │
│      └── TASK-004: 写整合文档 (sub-role=docs)                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. Performer 领取 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)              │
│                                                                      │
│  Performer #1 (sub-role=coder) 领取 TASK-001/002/003                 │
│  ├── git worktree add .kallax/worktrees/TASK-001 -b feature/TASK-001│
│  └── 在隔离环境中开发                                                │
│                                                                      │
│  Performer #2 (sub-role=docs) 领取 TASK-004                          │
│  └── 并行开发 (文件范围无重叠, 跟 v2.7.6 联合)                      │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. 6 武器 强制落地 (跟 v3.0.0 联合, 跟"反讽" 联合 0 装饰)          │
│                                                                      │
│  武器 1 Hash-Chain: 写 audit SHA256 chain                            │
│  武器 2 5-Level: 跑 level-1.sh 至 level-5.sh                        │
│  武器 3 Sub-Role: ticket.json sub_role 字段                         │
│  武器 4 EPIC 4 件套: A+B review + readme + lessons + signoff        │
│  武器 5 Hook: 写 hook SHA                                           │
│  武器 6 Dashboard: 1 binary 整合                                    │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. A+B Review (跟 v3.1.0 16 hotfix 联合, 跟"反讽" 联合)             │
│                                                                      │
│  A 组 Forward: 5 维度 PASS                                          │
│  B 组 Attack: 16 findings 全修                                      │
│  → 合并到 testing → 集成验证 → 合并到 miao                          │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  7. 知识沉淀 (跟 v2.7.6 联合, 跟 EPIC-059-H 联合)                    │
│                                                                      │
│  合并后自动触发 L0 → L4 升级 (跟 EPIC-059-H 联合)                    │
│  ├── L1: confluence/decisions/EPIC-064-2026-06-29.md                │
│  ├── L2: confluence/memory/lessons/epic-064-2026-06-29.md           │
│  ├── L3: confluence/memory/patterns/rtk-caveman-integration.md     │
│  └── L4: confluence/memory/research/  (跟 v3.2.0 跟 eket parity 联合) │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 v3.x 反馈循环 (跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Bug 报告 (跟 v2.7.6 联合, 跟 v3.1.0 武器 4 联合)                    │
│                                                                      │
│  Human (主公) → inbox/human_feedback.md                             │
│  "v3.2.0 整合后, rtk 在 commit 前 pre-commit hook 阻 0 error"         │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Conductor 处理 (跟 v2.7.6 联合, 跟 v3.1.0 A+B Review 联合)          │
│                                                                      │
│  1. 查找相关 EPIC: EPIC-064                                         │
│  2. 创建 bugfix ticket: TASK-005 (sub-role=coder)                    │
│  3. 关联原始 ticket: TASK-001/002/003/004                           │
│  4. A+B Review 派发 (跟 v3.1.0 联合)                                │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  修复 & 复盘 (跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 联合)              │
│                                                                      │
│  Performer 修复 → A+B Review → 合并 →                               │
│  Conductor 更新 confluence/memory/lessons/epic-064-2026-06-29.md      │
│  └── "教训: rtk 整合需先跑 pre-commit hook 测试"                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. v3.x 索引与搜索 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1 联合, 跟"反讽" 联合)

### 6.1 v3.x 全文搜索 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# 搜索知识库 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1 联合)
kallax knowledge:search "rtk + caveman" --scope confluence
# v3.x: L0-L4 分层搜索 (跟 EPIC-059-H 联合)

# 搜索任务 (跟 v2.7.6 联合)
kallax knowledge:search "登录" --scope jira

# 全局搜索 (跟 v2.7.6 联合)
kallax knowledge:search "authentication" --all
```

### 6.2 v3.x TF-IDF 推荐 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# 为新任务推荐相关知识 (跟 v2.7.6 联合, 跟 v3.0.0 武器 3 sub-role 联合)
kallax recommend TASK-005

# 输出 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合):
# Relevant knowledge for TASK-005:
# 1. [0.92] confluence/memory/patterns/6-weapons-design.md (L3)
# 2. [0.85] confluence/decisions/V310-B-REVIEW-2026-06-29.md (L1)
# 3. [0.71] jira/tickets/TASK-001/ticket.json (sub-role=coder)
```

---

## 7. v3.x 配置 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 binary 整合 联合, 跟"反讽" 联合)

```yaml
# .kallax/config.yml (v3.x, 跟 v2.7.6 联合, 跟 v3.0.0 Iter 3 联合)
repositories:
  confluence:
    path: "./confluence"
    sync_on_merge: true
    index_on_change: true
    memory_promote: true  # v3.x: L0 → L4 自动升级 (跟 EPIC-059-H 联合)

  jira:
    path: "./jira"
    ticket_prefix: "TASK"
    epic_prefix: "EPIC"
    sub_role_required: true  # v3.x: 4 sub-roles 强制 (跟 EPIC-038-A 联合)
    state_machine: 8          # v3.x: 8 状态机 (跟 v2.0.4 EPIC-054-C 联合)

  code:
    path: "./"
    worktree_dir: ".kallax/worktrees"  # v3.x: 4→1 统一 (跟 EPIC-054-A 联合)
    binary_integrated: true           # v3.x: 1 binary (跟 v3.0.0 Iter 3 联合)
    protected_branches:
      - miao
      - testing
      - release/*

  # v3.x 6 武器 配置 (跟 v3.0.0 联合)
  weapons:
    weapon_1_hash_chain: true
    weapon_2_5_level: true
    weapon_3_sub_role: true
    weapon_4_epic_4piece: true
    weapon_5_hook_replay: true
    weapon_6_dashboard: true

# 索引配置 (跟 v2.7.6 联合)
indexing:
  extensions:
    - .md
    - .yaml
    - .yml
  exclude:
    - node_modules
    - .git
    - .kallax/worktrees
  fts_language: "chinese"

# 同步配置 (跟 v2.7.6 联合, 跟 EPIC-059-H 联合)
sync:
  auto_knowledge_update: true
  update_on_pr_merge: true
  retroactive_days: 30
  memory_promote:
    L0_to_L1: "task:complete 触发"
    L1_to_L2: "EPIC 闭环触发"
    L2_to_L3: "跨 release 累计触发"
    L3_to_L4: "PHASE review 触发"
```

---

## 8. v3.x 跟 eket 借鉴对比 (跟 v2.7.6 联合, 跟 v3.0.0 Iter 11 联合, 跟"反讽" 联合)

```
v3.x KALLAX 跟 eket 对比 (跟 v3.0.0 Iter 11 集成测试 6 武器 联合):

6 胜 6 空白 (跟 v3.0.0 联合):
  武器 1 Hash-Chain Audit: KALLAX 胜 eket 0
  武器 2 5-Level Fact-Forcing: KALLAX 胜 eket 4-Level
  武器 3 Performer Sub-Role: KALLAX 胜 eket 0
  武器 4 EPIC 4 件套: KALLAX 胜 eket 0
  武器 5 Hook Server 回放 + Audit: KALLAX 胜 eket 0
  武器 6 Dashboard 1 page: KALLAX 胜 eket 0

85.5% KALLAX vs 55% eket (跟 v2.0.0 联合)
```

---

**跟主公 2026-06-30 拍 C 重写 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 v3.0.0 6 武器 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.2.0 rtk/caveman 累计 联合**
