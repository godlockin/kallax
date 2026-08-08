# KALLAX v3.34.6

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor

**生产级 Claude Code 治理框架** | 借鉴 [eket](https://github.com/godlockin/eket) 极简哲学 | 24 EPIC 累计 (v3.32.2 → v3.34.6) | 0 跳流程, 0 估数字, 0 装饰性宣称

## Why KALLAX?

Claude Code 解决 "AI 怎么写代码", **KALLAX 解决 "AI 写的代码怎么进 prod"**. 是 AI 工程界的 **"CI/CD for AI agents"**:

- **4-PR 工作流** (feature → testing → main → miao, 4 阶段 master review 强制)
- **5-Level Verify** (L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary, 防假 PASS)
- **36 Rule + 5 immutable scripts** (fail-closed, 0 估数 0 装饰)
- **4 北极星指标** (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch)
- **3 阶段专家治理** (Conductor + 4 default + 5 extended = 9 expert)

## 快速入口

- 📋 [CLAUDE.md](./CLAUDE.md) — cold start 入口 (3.3KB, 36 Rule 必读)
- 🏛️ [Top Design](./confluence/manifesto/01-top-design.md) — 4 子系统 + 顶层架构
- 🎯 [Scope / Mission / Vision / 价值观](./confluence/manifesto/02-scope-mission-vision.md)
- ⏱️ [Timeline](./confluence/manifesto/03-timeline.md) — 8 release 累计
- 📚 [Lessons](./confluence/manifesto/04-lessons.md) — 5 类经验教训
- ✨ [Best Practices](./confluence/manifesto/05-best-practices.md) — 8 类最佳实践

## 安装

```bash
bash install.sh  # 全栈 deploy 95 files (跟 EPIC-160 install.sh Omnibus 1:1)
```

## 文档结构 (跟 EPIC-197 SoT 归并 1:1)

```
confluence/
  decisions/     # 66 EPIC 拍板记录
  memory/        # L1 SoT 决策 + L2 lessons + L3 patterns + L4 research
  research/      # 战略沉淀 (EPIC-171 + EPIC-172 positioning + growth loop)
  manifesto/     # 5 文件顶层 (EPIC-206, 战略入口)
docs/
  process/       # 流程治理 (post-process / doc-audit / smoke-retention / projection-sink)
  reference/     # 24 reference docs (lazy load)
  evidence/      # 5-Level Verify raw output (跟 EPIC-069-D 1:1)
  _archived/     # 22 DEPRECATED 文件 (跟 EPIC-197/199/200/201 1:1)
scripts/         # 95 files deploy 入口 (跟 EPIC-160 1:1)
```

---

## Why KALLAX vs Claude Code?

> **1 句话 Elevator Pitch**: KALLAX 是 AI 工程界的 "CI/CD for AI agents" — Claude Code 解决 "AI 怎么写代码", KALLAX 解决 "AI 写的代码怎么进 prod".

### 5 维度对比表

| 维度 | Claude Code | KALLAX | 关系 |
|------|-------------|--------|------|
| **职责** | AI Runtime (代码生成/补全) | Governance Layer (审计/验证/治理) | **正交叠加** |
| **sub-agent** | 单 session | 多 worktree 隔离 | KALLAX 并行 |
| **PR 流程** | 无 (单角色) | 4-PR Chain (feature→testing→main→miao) | KALLAX 强制 |
| **失败追溯** | session 关闭即丢失 | Hash-Chain Audit + Memory L0-L4 | KALLAX 持久 |
| **Verify** | 无 | 5-Level Fact-Forcing (L1-L5 独立) | KALLAX 防假 PASS |

### 3 句使用判断

| 场景 | 推荐 | 理由 |
|------|------|------|
| **单人开发, 简单脚本** | Claude Code | overhead > value, 直接够用 |
| **team ≥ 3 人, 长期项目 (6+ 月)** | KALLAX | 5-Level Verify + 4-PR Chain 价值最大化 |
| **Enterprise, 合规审计** | KALLAX 必须 | Audit trail + self-heal 满足合规 |

### Trigger Signals (出现任一则推荐 KALLAX)

- "上次 prod 假 PASS"
- "team 多人在做, 分不清谁做了什么"
- "PR 经常 skip review"
- "bug 修过 3 次复发"
- "Claude Code session 关了上下文丢"

### 详细定位

> **KALLAX = AI Engineering Governance Platform**
> - **入口**: 解决假 PASS 痛点
> - **差异化**: 治理层 vs runtime
> - **技术 Moat**: 24 EPIC 累计 + 0 假 PASS 文化 + 4 北极星指标

**完整定位文档**: [confluence/research/kallax-positioning-2026-08-05.md](confluence/research/kallax-positioning-2026-08-05.md) (EPIC-171)

## 安装

```bash
bash install.sh  # 全栈 deploy 95 files (跟 EPIC-160 install.sh Omnibus 1:1)
```

## 文档结构 (跟 EPIC-197 SoT 归并 1:1)

```
confluence/
  decisions/     # 66 EPIC 拍板记录
  memory/        # L1 SoT 决策 + L2 lessons + L3 patterns + L4 research
  research/      # 战略沉淀 (EPIC-171 + EPIC-172 positioning + growth loop)
  manifesto/     # 5 文件顶层 (EPIC-206, 战略入口)
docs/
  process/       # 流程治理 (post-process / doc-audit / smoke-retention / projection-sink)
  reference/     # 24 reference docs (lazy load)
  evidence/      # 5-Level Verify raw output (跟 EPIC-069-D 1:1)
  _archived/     # 22 DEPRECATED 文件 (跟 EPIC-197/199/200/201 1:1)
scripts/         # 95 files deploy 入口 (跟 EPIC-160 1:1)
```

---

## Why KALLAX vs Claude Code?

> **1 句话 Elevator Pitch**: KALLAX 是 AI 工程界的 "CI/CD for AI agents" — Claude Code 解决 "AI 怎么写代码", KALLAX 解决 "AI 写的代码怎么进 prod".

### 5 维度对比表

| 维度 | Claude Code | KALLAX | 关系 |
|------|-------------|--------|------|
| **职责** | AI Runtime (代码生成/补全) | Governance Layer (审计/验证/治理) | **正交叠加** |
| **sub-agent** | 单 session | 多 worktree 隔离 | KALLAX 并行 |
| **PR 流程** | 无 (单角色) | 4-PR Chain (feature→testing→main→miao) | KALLAX 强制 |
| **失败追溯** | session 关闭即丢失 | Hash-Chain Audit + Memory L0-L4 | KALLAX 持久 |
| **Verify** | 无 | 5-Level Fact-Forcing (L1-L5 独立) | KALLAX 防假 PASS |

### 3 句使用判断

| 场景 | 推荐 | 理由 |
|------|------|------|
| **单人开发, 简单脚本** | Claude Code | overhead > value, 直接够用 |
| **team ≥ 3 人, 长期项目 (6+ 月)** | KALLAX | 5-Level Verify + 4-PR Chain 价值最大化 |
| **Enterprise, 合规审计** | KALLAX 必须 | Audit trail + self-heal 满足合规 |

### Trigger Signals (出现任一则推荐 KALLAX)

- "上次 prod 假 PASS"
- "team 多人在做, 分不清谁做了什么"
- "PR 经常 skip review"
- "bug 修过 3 次复发"
- "Claude Code session 关了上下文丢"

### 详细定位

> **KALLAX = AI Engineering Governance Platform**
> - **入口**: 解决假 PASS 痛点
> - **差异化**: 治理层 vs runtime
> - **技术 Moat**: 24 EPIC 累计 + 0 假 PASS 文化 + 4 北极星指标

**完整定位文档**: [confluence/research/kallax-positioning-2026-08-05.md](confluence/research/kallax-positioning-2026-08-05.md) (EPIC-171)

---

## 5 Levels × 4 Roles 决策矩阵 (Q18)

> **25 cells**: 自主 12 + 推荐 8 + 主公拍 5 = 25 cells (跟 decision-matrix.sh --self-test 1:1 验证)

| Role \ Level | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |
|--------------|--------|-----------|-------------|----------------|-------------|
| **Conductor** | 自主 | 自主 | 推荐 | 主公拍 | 推荐 |
| **Performer/coder** | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |
| **Performer/reviewer** | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| **Performer/tester** | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| **Performer/docs** | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |

**主公拍 cells** (5 cells, 不可 AI 自主): L4 全部 4 个 Performer sub-roles + L4 Conductor (跨 subagent 独立)

**详细 SOP**: `docs/process/q18-decision-model.md` (543 行)

---

## 5 Levels 验证

```
L1 git log SHA 真变
L2 test stdout 实质 (raw stdout, 不接受 "should work")
L3 4-expert 接线 (coder/reviewer/tester/docs)
L4 independent witness (主公拍, 跨 subagent)
L5 boundary 边界 (Conductor 推荐)
```

**实施**: `bash scripts/verify/level-{1..5}.sh TICKET-XXX` (5 独立脚本) + `kallax verify all TICKET-XXX` (wrapper)

---

## 4 Roles

```
Conductor (分析/拆解/审核/合并/发布)
Performer (coder/reviewer/tester/docs, 1+4 容量)
```

---

## 30 命令速查 (跟 eket 1:1)

**Subagent (3)**: `kallax subagent:register` · `kallax subagent:list` · `kallax subagent:deregister`

**Ticket (8)**: `kallax ticket:create` · `kallax ticket:claim` · `kallax ticket:list` · `kallax ticket:show` · `kallax ticket:complete` · `kallax ticket:assign` · `kallax ticket:transition` · `kallax ticket:history`

**EPIC (4)**: `kallax epic:create` · `kallax epic:add-ticket` · `kallax epic:close` · `kallax epic:status`

**Verify (6)**: `kallax verify l1 TICKET` · `kallax verify l2 TICKET` · `kallax verify l3 TICKET` · `kallax verify l4 TICKET` · `kallax verify l5 TICKET` · `kallax verify all TICKET`

**Audit/Export (5)**: `kallax audit:show` · `kallax audit:verify` · `kallax export:report` · `kallax export:dashboard` · `kallax system:doctor`

**Misc (4)**: `kallax mode:set` · `kallax role:switch` · `kallax worktree:create` · `kallax skill:list`

---

## 快速开始

### 安装

```bash
git clone https://github.com/godlockin/kallax.git
cd kallax
cargo build --release  # 1 binary 整合, 5 crates
```

### 基本工作流

```bash
# 1. 创建 ticket
kallax ticket:create "实现 Redis 缓存层" --type feature --priority P1

# 2. claim ticket (atomic)
kallax ticket:claim TICKET-001

# 3. 开发 + commit (in worktree, Performer sub-role=coder)
cd .worktrees/TICKET-001
# ... 写代码 + commit ...

# 4. 跑 5-Level 验证
kallax verify l1 TICKET-001  # git log SHA
kallax verify l2 TICKET-001  # raw test stdout
kallax verify l3 TICKET-001  # 4-expert 接线
kallax verify l4 TICKET-001  # 主公拍 (跨 subagent)
kallax verify l5 TICKET-001  # boundary 边界

# 5. 完成 ticket
kallax ticket:complete TICKET-001
```

---

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│              KALLAX v3.0.0 Multi-Agent Layer                │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │  Conductor   │  │ Performer    │  │ Sub-Role Dispatch  │ │
│  │  (协调/审核)  │  │ (coder/      │  │ (4 sub-roles)      │ │
│  │              │  │  reviewer/   │  │                    │ │
│  │              │  │  tester/     │  │                    │ │
│  │              │  │  docs)       │  │                    │ │
│  └──────────────┘  └──────────────┘  └────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  6 武器 Layer                                │
│  武器 1: Hash-Chain Audit Log                                │
│  武器 2: 5-Level Fact-Forcing                                │
│  武器 3: Sub-Role Dispatch                                   │
│  武器 4: EPIC 4 件套                                         │
│  武器 5: Hook Server 回放 + Audit                            │
│  武器 6: Web Dashboard 1 page ≤ 500 LOC                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            Rust Core (Level 1, ~5ms startup)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Event Bus | DAG Scheduler | Ticket Engine            │  │
│  │ Agent Pool | Mailbox | Hook Server                   │  │
│  │ Axum HTTP API (:9877)                                │  │
│  └──────────────────────────────────────────────────────┘  │
│           ~5ms startup (跟 eket 一致)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (fallback)
┌─────────────────────────────────────────────────────────────┐
│           Node.js Layer (Level 2, ~400ms startup)            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Web Dashboard | Hook Events Store                    │  │
│  │ 5-Level Scripts | Decision Matrix                    │  │
│  │ Sub-Role Dispatcher | EPIC 4-Piece Checker           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 目录结构

```
kallax/
├── rust/                    # Rust 高性能核心 (5 crates 整合)
│   ├── core/                # 类型系统 + 中间件
│   ├── engine/              # 执行引擎 + DAG
│   ├── cli/                 # CLI 入口
│   ├── server/              # HTTP API
│   └── ticket-engine/       # ticket 引擎
├── node/                    # Node.js 增强层
│   └── src/
│       ├── commands/        # 命令实现
│       ├── core/            # 消息队列、缓存
│       ├── hooks/           # Hook Server (武器 5)
│       ├── web/             # Dashboard (武器 6)
│       └── skills/          # Skills 系统
├── docs/                    # 架构文档
│   ├── CHEATSHEET.md        # 1 页 cheatsheet (30 行)
│   ├── 5-levels.md          # 5 levels 实做
│   ├── 4-roles.md           # 4 roles (Conductor + 4 sub-roles)
│   └── process/q18-decision-model.md  # Q18 决策模型 (543 行)
├── template/                # 外部项目模板
├── scripts/                 # 运维脚本
│   ├── verify/              # 5 level scripts + decision-matrix
│   ├── permission/          # decision-gate (block + danger)
│   ├── conductor/           # dispatch (sub-role)
│   └── io/                  # file-lock + atomic-write
├── confluence/              # 知识库
│   └── decisions/           # EPIC + PHASE + RELEASE
├── jira/                    # 任务管理
└── CLAUDE.md                # 3.3KB cold start (16.4x 缩减)
```

---

## 配置

### 主配置 (.kallax/config.yml)

```yaml
version: "3.0.0"
mode: "claude_code"              # claude_code | copilot | gemini

# 4 sub-roles 配置
performer_sub_roles:
  - coder
  - reviewer
  - tester
  - docs

# 5 levels 验证
fact_forcing:
  levels: 5
  hash_chain: true
  independent_witness: true

# 6 武器
weapons:
  hash_chain_audit: true
  level_scripts: true
  sub_role_dispatch: true
  epic_4_piece: true
  hook_server: true
  dashboard: true

# 决策模型
decision_model:
  type: q18
  cells: 25
  block_classes: 5
  danger_classes: 3
```

---

## KPI (跟 v2.7.6 对比)

| 指标 | v2.7.6 | v3.0.0 | 变化 |
|------|--------|--------|------|
| CLAUDE.md size | 54KB | 3.3KB | **16.4x 缩减** |
| 术语数 | 35 | 0 (cheatsheet + lazy load) | 100% 砍 |
| Rule 数 | 21 | 0 硬编码 (5 levels + 4 roles 替代) | 100% 替代 |
| Rust crates | 8 | 5 | 整合 3 |
| 冷启动 | ~8ms | ~5ms | 1.6x 加速 |
| 6 武器 | 0/6 | 6/6 | 100% done |
| 集成测试 | - | 25/25 cells PASS | 100% pass |
| Binary 数 | 2 (kallax + expert-match) | 1 (kallax) | 50% 整合 |

---

## 集成测试 (v3.8.1 EPIC-069 真相化, 跟 v3.8.0 red-blue review 1:1 联合)

> **诚实修正**: v3.8.0 README 声称 "25/25 PASS / 生产级 / 治根",但 reviewer 红蓝对抗
> 实测发现:`cargo test` 11 errors + Node hook-replay 8/19 fail + Hash-Chain 防篡改=0。
> v3.8.1 (本 release) 真测试结果如下,所有数字来自本机 `cargo test` / `vitest run` raw output:

```bash
# Rust 全 workspace (EPIC-069-A 修复后实测)
cd rust && cargo test --release
# → test result: ok. 74 passed; 0 failed (kallax-core lib)

# Node hook-replay (EPIC-069-B 修复后实测)
cd node && KALLAX_HOOK_API_KEY=test-... npx vitest run tests/hook-replay.test.ts
# → Test Files  1 passed (1) | Tests  19 passed (19)

# 6 武器端到端 (历史脚本,实测验证如下)
bash tests/integration/6-weapons-e2e-test.sh
# → 实测 6/6 PASS (raw output: /tmp/claude-tasks/kallax-tests-20260709-*.log)

# 决策矩阵 25 cells
bash tests/integration/decision-matrix-test.sh
# → 实测 25/25 PASS
```

**未覆盖项**(诚实声明,不放任 PR):
- A4 三级降级: `recovery-manager` 存在但仅观测,未接线 (EPIC-071 决定)
- A5 Rust 持久化: 全 DashMap, 重启丢票 (EPIC-071 决定)
- A1+A2+A3 Hash-Chain 锚点: 算法公开 + 全零种子 + 空文件 PASS (EPIC-072 治根)

---

## 6 Release 累计 时间线 (v3.0.0 → v3.7.0)

| Release | Commit | 关键 落地 | eket parity |
|---------|--------|-----------|-------------|
| v3.0.0 | `452ab7d` | 6 武器 + 决策模型 25 cells + 集成测试 | 0 |
| v3.1.0 | `15adbe7` | hotfix 16 (4 P0 + 12 P1, 跟 V310 A+B 1:1) | 0 |
| v3.2.0 | `6eee94b` | rtk 0.42.4 + caveman SKILL 整合 | 0 |
| v3.3.0 | `03c0e7f` | A1+A2+B+C+E 根治 + EPIC-058 5/5 closed | 0 |
| v3.4.0 | `aeeb5f6` | 21 release 累计 + graceful-exit.sh 跟 eket Level 4 1:1 | 0 |
| v3.5.0 | `096eafe` | 实战 eket ioredis + graceful-exit 1 次 + hotfix 16 | 1 (20%) |
| v3.6.0 | `668980b` | CLAUDE.md 3.3KB → 1.1KB + 删 14 sub-doc + 4 immutable scripts + KALLAX_DESIGN_MODE=1 | 1 (20%) |
| v3.7.0 | TBD | 7 候选 1:1 联合 Q12 (4 根本 价值 + 5 scripts + L2 cache) | 2 (30%) |
| v3.10.0 | `753f7c9` | Sprint 6: A4/A5 闭环 + P1 滚动 + eket 借鉴 (check-pr-size) + 4-PR 流程新规首次 | 3 (35%) |
| v3.11.0 | `92fe8be` | Sprint 7: TierRouter 端到端 (4 op) + eket 40% (debrief/count-tokens) + CSP 启用 + Perf-1 缓存 | 4 (40%) |
| v3.12.0 | `520dfee` | Sprint 8: EPIC-083 retrospective + branch-4pr.sh (本地命令更新) | 4 (40%) |
| v3.13.0 | `a1d9d99` | Sprint 9: 6 EPIC (P1-2/3/4/7 + Perf-2/3) 4-PR 全程 18 PRs | 4 (40%) |
| v3.14.0 | `4a355e7` | Sprint 10: 5 EPIC (P1-5/6/8/10 + Rust E0432) 4-PR 全程 15 PRs | 4 (40%) |
| v3.15.0 | `a811e20` | Sprint 11: 3 EPIC (TierRouter e2e + Perf-2/3 进一步优化) 4-PR 全程 9 PRs | 4 (40%) |
| v3.15.1 | `dbd8e90` | EPIC-101: Rust E0432 + 2 regression + TierRouter 端到端 (workspace 100 真验) | 4 (40%) |
| v3.16.0 | `dbd8e90` | Sprint 12: 2 EPIC (cargo test workspace + retrospective 应用) 4-PR 全程 6 PRs | 4 (40%) |
| v3.17.0 | `d1f3051` | Sprint 13: 1 EPIC (GitHub Actions CI + CHANGELOG 3-crate scope) 4-PR 全程 3 PRs | 4 (40%) |

**关键演化**:
- 0 跳 release (跟 V310-LESSONS + V350-LESSONS 1:1 联合)
- 0 估数 + 0 装饰 + 0 narrative (跟 V350-B P-001/P-002/P-005 1:1 联合; v3.8.1 起: README 数字必须来自 raw test output, 治反讽 1:1 复发)
- eket 借鉴 比例 0 → 30% (跟 eket 1:1 借鉴 极简 哲学 1:1 联合)

---

## 详细文档

- [1 页 Cheatsheet](docs/CHEATSHEET.md)
- [Q18 决策模型 (1:1 锁定 law)](scripts/permission/decision-matrix.sh)
- [CLAUDE.md (1.1KB cold start)](CLAUDE.md)
- [AGENTS.md](AGENTS.md)
- `confluence/decisions/RELEASE-v3.5.0-2026-06-29.md`
- `confluence/decisions/LESSONS-LEARNED-v3.7.0-2026-07-01.md`
- [CHANGELOG.md](CHANGELOG.md)

---

## 贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解贡献指南。

## 许可

MIT License - 详见 [LICENSE](LICENSE)