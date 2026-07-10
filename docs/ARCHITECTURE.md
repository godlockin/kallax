# KALLAX v3.0.0 架构

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor
>
> v3.6.0 (跟 v3.7.0 准备) | 生产级多智能体协作框架 | 6 武器 + 4 根本 价值 + 5 immutable scripts + 集成测试 25/25 PASS
>
> **对照验证**: `bash scripts/permission/decision-matrix.sh --self-test` (25/25 PASS) + `bash tests/integration/6-weapons-e2e-test.sh` (6/6 PASS)

---

## 1. What — KALLAX v3.0.0 是什么

KALLAX 是一个**生产级多智能体协作框架**, 借鉴 [eket](https://github.com/godlockin/eket) 极简哲学, 在其基础上补齐 6 个空白处 (6 武器), 形成""的差异化定位。KALLAX = Conductor + Performer (1+4 sub-roles) + 6 武器 + Q18 决策模型 (5 levels × 4 roles = 25 cells), 1 binary 整合 (5 Rust crates), 3 层降级 (Rust ~5ms → Node.js → Shell), 冷启动 3.3KB CLAUDE.md + lazy load docs。

---

## 2. Why — 为什么需要 KALLAX (历史背景, 6 武器 从根源修复)

KALLAX 解决 6 个 eket 跟历史项目 未覆盖的反模式, 形成 6 武器 (W1-W6):

| 武器 | 从根源修复反模式 | KALLAX 实施 | eket 状态 |
|------|-----------|-------------|----------|
| **W1** Hash-Chain Audit Log | SEC-002 (audit log 无 hash chain) | SHA256 chain + `audit:verify` CLI | 无 |
| **W2** 5-Level Fact-Forcing | 4-Level/6 维度重叠 (跟 Rule 8 联合) | L1-L5 5 独立脚本 (`scripts/verify/level-{1..5}.sh`) | 名字 only |
| **W3** Sub-Role Dispatch | Performer 产能 Gap 40% | 4 sub-roles (coder/reviewer/tester/docs) | 无 (单 role) |
| **W4** EPIC 4 件套 | PROD-001 (EPIC 交付缺失) | A+B review + readme + lessons + signoff | 无 |
| **W5** Hook Server 回放 + Audit | 多 AI 工具协同缺口 | `/hooks/replay` + `/hooks/audit` endpoints | 无 |
| **W6** Web Dashboard | FE-001 XSS | 1 page ≤ 500 LOC (textContent + escape) | 无 |

**6 武器 对照验证** (跟 README §"6 武器 对照验证" 联合):

| 武器 | 实施位置 | 验证命令 |
|------|---------|----------|
| W1 | `scripts/verify/hash-chain.sh` | `bash scripts/verify/hash-chain.sh` |
| W2 | `scripts/verify/level-{1..5}.sh` | `kallax verify all TICKET-XXX` |
| W3 | `scripts/conductor/dispatch.sh --sub-role=X` | `bash tests/integration/sub-role-test.sh` |
| W4 | `scripts/verify/check-epic-4-piece.sh` + `epic:close` | `bash tests/integration/epic-4-piece-test.sh` |
| W5 | `node/src/hooks/hook-events-store.ts` + `/hooks/replay` | `bash tests/integration/hooks-test.sh` |
| W6 | `node/src/web/dashboard.tsx` (≤ 500 LOC) | `bash tests/integration/dashboard-test.sh` |

---

## 3. How — 架构图 + 5 levels + 4 roles + Q18 决策模型

### 3.1 顶层架构图

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
│  W1 Hash-Chain Audit | W2 5-Level Fact-Forcing              │
│  W3 Sub-Role Dispatch | W4 EPIC 4 件套                      │
│  W5 Hook Server 回放 + Audit | W6 Dashboard 1 page          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            Rust Core (Level 1, ~5ms startup)                │
│  Event Bus | DAG Scheduler | Ticket Engine | Agent Pool     │
│  Mailbox | Hook Server | Axum HTTP API (:9877)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (fallback)
┌─────────────────────────────────────────────────────────────┐
│           Node.js Layer (Level 2, ~400ms startup)           │
│  Web Dashboard | Hook Events Store | 5-Level Scripts        │
│  Decision Matrix | Sub-Role Dispatcher | EPIC 4-Piece       │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 5 levels (跟 `docs/5-levels.md` 联合)

| Level | 名称 | 验证 | 命令 | 反模式 |
|-------|------|------|------|--------|
| **L1** | 存在性 | git log SHA 真变 | `git log --oneline -1` | Amend SHA 没变 |
| **L2** | 实质性 | test stdout 真实 | `cargo test 2>&1 \| tee /tmp/stdout.log` | "should work" 估数 |
| **L3** | 接线正确 | 4-expert 评审 | `kallax expert:run {arch,backend,frontend,security}` | 自审 |
| **L4** | 独立见证 | independent witness 重跑 | `kallax witness:spawn TICKET --independent` | 瞒报 |
| **L5** | 边界 | boundary input/异常/并发 | `kallax test:boundary/exception/concurrent` | happy path only |

**实施**: `bash scripts/verify/level-{1..5}.sh TICKET-XXX` + `kallax verify all TICKET-XXX`

### 3.3 4 roles + 4 sub-roles (跟 `docs/4-roles.md` 联合)

**2 主角色** + **4 sub-roles** (1+4 容量):

- **Conductor**: 分析/拆解/审核/合并/发布 (1 instance, 主 session)
- **Performer** (4 sub-roles):
  - **coder**: 写代码 + commit (Rule 5/8 + Rule of 500 + PR ~100 行)
  - **reviewer**: A/B review + 跨 PR 验证 (Rule 8 5-Level + Rule 18 KPI)
  - **tester**: 写测试 + raw stdout (Rule 9 anti-fab + L2/L4 强制 stdout)
  - **docs**: 写 .md + cheatsheet 对照验证 (Rule 5 DRY + Rule 19 标签 SOP)

### 3.4 Q18 决策模型 (跟 `docs/process/q18-decision-model.md` 联合)

**25 cells** = 5 levels × 4 roles (Conductor + Performer×3, 实际是 5 roles 但 docs 合并 Conductor + Performer 成 4 行主表): 自主 12 + 推荐 8 + **主公拍 5** (L4 全部 4 sub-roles + L4 Conductor 跨 subagent 独立).

**3 模式 × 4 维度** (跟 Rule 12 联合):
- `ai-auto` (AI 自主) / `ai-copilot` (默认) / `manual` (主公确认每阶段)
- Block 5 类 + Danger 3 类: 3 模式都停下问主公 (不可 AI 自主决定)

---

## 4. 跟 eket 关系 (Q11 实施: 互取所长 互补)

> **独立项目, 互取所长**: KALLAX 实做 5 levels + 6 武器, eket 借 multi-agent 概念

| 维度 | KALLAX v3.0.0 | eket | 关系 |
|------|---------------|------|------|
| **架构** | Rust + Node.js + Shell (3 层降级) | Node.js ≥20 (单层) | KALLAX 更深 |
| **Multi-agent** | Conductor + Performer + 4 sub-roles (1+4) | Master + Slaver | 概念同源, 命名不同 |
| **Fact-Forcing** | 5-Level (L1-L5 实做, 5 独立脚本) | 9 Hard Rules (规则 only) | KALLAX 实做 |
| **决策模型** | Q18 (5×4=25 cells, 25/25 PASS) | decision-gate (block/danger 触发) | 互补 |
| **Cargo workspace** | 2.7.6 (跟 npm 对齐) | 无 (Node.js only) | KALLAX 多语言 |
| **极简** | CLAUDE.md 3.3KB + 5KB cold start | CLAUDE.md 精简 | 一致 |
| **术语** | 0 术语 (cheatsheet + lazy load) | 0 术语 | 一致 |
| **Audit** | Hash-Chain SHA256 | 无 | KALLAX 独有 |
| **Dashboard** | 1 page ≤ 500 LOC (XSS 从根源修复) | 无 | KALLAX 独有 |

**Q11 实施总结**: 6 武器 KALLAX 胜 (W1-W6 全部 KALLAX 独有), eket 借 multi-agent 概念, 跟 eket MASTER-RULES.md §6 联合 ("借方法论 不借代码").

---

## 5. 6 武器 详细 (跟 eket 对比)

### W1: Hash-Chain Audit Log

**目的**: audit log 不可篡改, SHA256 chain 验证

**实施**:
```bash
# 写入 audit log (SHA256 chain)
bash scripts/verify/hash-chain.sh write "TICKET-001: complete"

# 验证 hash chain
bash scripts/verify/hash-chain.sh verify
# → PASS: 1234 entries, hash chain intact

# CLI 命令
kallax audit:show --last 10
kallax audit:verify  # exit 0 = chain intact, exit 1 = broken
```

**跟 eket 对比**: eket 无 audit log hash chain, KALLAX W1 从根源修复 SEC-002.

### W2: 5-Level Fact-Forcing

**目的**: 反 "Amend SHA 没变" + "should work" 估数 + 自审 + 瞒报 + happy path only

**实施**: 5 独立脚本 (`scripts/verify/level-{1..5}.sh`) + CLI wrapper (`kallax verify {l1..l5|all}`).

**跟 eket 对比**: eket 5 levels 是命名空间, KALLAX 5 levels 是 实施框架 (5 独立脚本 + CLI).

### W3: Sub-Role Dispatch

**目的**: Performer 产能 Gap 40% (跟主公 Q4 报告 联合)

**实施**:
```bash
# 派单时指定 sub-role
kallax performer:claim TICKET-001 --sub-role=coder
kallax performer:claim TICKET-002 --sub-role=reviewer
kallax performer:claim TICKET-003 --sub-role=tester
kallax performer:claim TICKET-004 --sub-role=docs

# 内部: dispatch.sh 强制校验 sub-role enum
bash scripts/conductor/dispatch.sh --sub-role=coder TICKET-001 accept
```

**跟 eket 对比**: eket 1 role (Slaver), KALLAX 4 sub-roles (1+4 容量).

### W4: EPIC 4 件套

**目的**: 反 EPIC 交付缺失 (PROD-001)

**4 件套**: A+B review + README + LESSONS-LEARNED + signoff (跟 `docs/process/fact-forcing.md` §"EPIC 4 件套" 联合)

**实施**: `scripts/verify/check-epic-4-piece.sh` + `kallax epic:close EPIC-XXX` (强制 4 件套通过才能 close).

**跟 eket 对比**: eket 无 4 件套 (文档散落), KALLAX W4 强制结构化 EPIC 交付.

### W5: Hook Server 回放 + Audit

**目的**: 多 AI 工具 (Claude Code / Copilot / Gemini) 协同缺口

**实施**:
- `node/src/hooks/hook-events-store.ts`: 持久化 hook events
- `POST /hooks/replay`: 重放历史 events (跟 Conductor 决策 联合)
- `GET /hooks/audit`: 审计 trail (跟 W1 联合)

**跟 eket 对比**: eket 单 AI 工具, KALLAX W5 多 AI 工具集成.

### W6: Web Dashboard

**目的**: 实时状态可视化 + 从根源修复 FE-001 XSS

**实施**: `node/src/web/dashboard.tsx` (1 page, ≤ 500 LOC, `textContent` + escape 强制, 0 innerHTML)

**跟 eket 对比**: eket 无 dashboard, KALLAX W6 实时可视化 (1 page 极简).

---

## 6. 5 levels 验证 (跟 README §"5 Levels 验证" 联合)

**实施位置**: `scripts/verify/level-{1..5}.sh` (5 独立脚本, 跟 W2 联合)

**L1 (存在性)**: `git log --oneline -1` 看 HEAD SHA + `git diff HEAD~1 --stat` 看变更文件 ≥ 1.
**L2 (实质性)**: `cargo test --all --no-fail-fast 2>&1 | tee /tmp/stdout.log` + grep `test result:` 行.
**L3 (接线正确)**: `kallax expert:run {architect,backend,frontend,security} --ticket TICKET-XXX` 4 expert 全输出 review.
**L4 (独立见证)**: `kallax witness:spawn TICKET-XXX --independent` 新 session 重跑 L1-L3.
**L5 (边界)**: `kallax test:boundary --input empty|max|unicode` + `test:exception --error-network|permission` + `test:concurrent --workers 4`.

**PASS 标准**: 5/5 PASS = ticket 可 close (跟 `decision-matrix.sh --self-test` 对照验证).

---

## 7. 4 roles + 4 sub-roles (跟 README §"4 Roles" + `docs/4-roles.md` 联合)

**2 主角色**:
- **Conductor**: 分析/拆解/审核/合并/发布, 写代码 ❌ (Rule 13 红线)
- **Performer**: 领取/开发/测试/提交 PR, 写代码 ✅ (worktree 隔离, Rule 14)

**4 sub-roles** (Performer 内部):
- **coder** (默认): 写代码 + commit, Rule 5/8 + Rule of 500 + PR ~100 行
- **reviewer**: A/B review + 跨 PR 验证, Rule 8 5-Level + Rule 18 KPI
- **tester**: 写测试 + 集成测试 + raw stdout, Rule 9 anti-fab + L2/L4 stdout
- **docs**: 写 .md + cheatsheet 对照验证, Rule 5 DRY + Rule 19 标签 SOP

**分支权限**:

| 分支 | 谁能写 | 谁能 merge | 谁能 review |
|------|--------|------------|-------------|
| miao | ❌ (git hook 保护) | Conductor (promote) | Conductor (只读分析) |
| testing | ❌ | Conductor (merge feature→testing) | Conductor |
| feature/* | Performer (worktree) | Conductor (merge→testing) | Conductor + Performer/reviewer |

**1+4 容量**: 1 master 横向管 4 sub-roles (5 个并发 subagent), worktree 隔离 (Rule 1).

---

## 8. Q18 决策模型 (5 levels × 4 roles = 25 cells)

> **详细 SOP**: [docs/process/q18-decision-model.md](process/q18-decision-model.md) (543 行)
> **对照验证**: `bash scripts/permission/decision-matrix.sh --self-test` → 25/25 PASS

### 8.1 决策模式 三档

- **自主** (12 cells): AI 自主决定, Performer self-attest
- **推荐** (8 cells): Conductor 派 expert 评审, AI 跟
- **主公拍** (5 cells): 不可 AI 自主, 必须主公拍 (L4 全部 4 Performer sub-roles + L4 Conductor)

### 8.2 决策矩阵 (5×4 = 20 cells in master table, 实际 25 cells 跨 5 roles)

| Role \ Level | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |
|--------------|--------|-----------|-------------|----------------|-------------|
| **Conductor** | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |
| **Performer/coder** | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |
| **Performer/reviewer** | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| **Performer/tester** | 自主 | 自主 | 自主 | **主公拍** | 推荐 |
| **Performer/docs** | 自主 | 自主 | 推荐 | **主公拍** | 推荐 |

### 8.3 Block (5 类) + Danger (3 类) — 全部停下问主公

**5 类 Block** (3 模式都触发):
1. `block.ambiguous_options` — 多选项无最优 (AC 模糊 / 选型争议)
2. `block.performer_failure` — Performer 失败 × 3 / 30min 超时
3. `block.rule_exception` — 规则冲突 / Exception 请求 (Rule 5/7/19 冲突)
4. `block.epic_critical` — EPIC close / PHASE review / Rule 升级
5. `block.high_impact` — 跨 PHASE / 跨项目 / 升级 CLAUDE.md

**3 类 Danger** (立即 stop):
1. `danger.miao_modify` — 写 miao branch (Rule 14 红线)
2. `danger.security_failing` — pre-commit FAIL / 凭据变动 / XSS
3. `danger.data_destruction` — rm -rf / reset --hard / push --force / db drop

### 8.4 3 模式 (跟 Rule 12 联合)

| 模式 | 行为 | 触发 |
|------|------|------|
| `ai-auto` | AI 全自主, block/danger 停下问 | AI 高信任 |
| `ai-copilot` (默认) | 简单自主 + 复杂协商 | 普通场景 |
| `manual` | 主公确认每阶段 | 高风险 / 监管场景 |

---

## 9. 3 层降级架构 (跟 `docs/architecture/degradation-strategy.md` 联合)

**3 层降级** (跟 README §"三级降级架构" 联合):

| Level | 实施 | 启动时间 | 能力 | Fallback 触发 |
|-------|------|----------|------|---------------|
| **L1 Rust Core** | 1 binary (5 crates) | ~5ms | Event Bus / DAG / Ticket / Agent Pool / Mailbox / Hook Server / Axum HTTP API | rust_binary_missing / startup_timeout 5s / crash × 3 |
| **L2 Node.js** | 0.16+ | ~400ms | Web Dashboard / Hook Events Store / 5-Level Scripts / Decision Matrix / Sub-Role Dispatcher / EPIC 4-Piece | node_not_found / npm_modules_missing / startup_timeout 10s / crash × 5 |
| **L3 Shell** | bash + git | ~50ms | 心跳检查 / 文件队列 / git commit+push / ticket 状态读取 | (无 fallback, 不可降级) |

**显式降级日志** (跟 `degradation-strategy.md` §"KALLAX 改进" 联合): `logger.warn({event: 'degradation_triggered', from, to, reason, timestamp})` + `metrics.increment('kallax.degradation', {from, to})`.

---

## 10. 冷启动路径 (CLAUDE.md 3.3KB + lazy load docs)

**CLAUDE.md** (3.3KB, 16.4x 缩减 跟 v2.7.6 联合) — cold start 入口, 必读.

**Lazy load docs** (按需打开, 不在 CLAUDE.md 必读):

| 文档 | 行数 | 用途 |
|------|------|------|
| `docs/CHEATSHEET.md` | 27 | 30 命令速查 + 5 levels + 4 roles + 6 武器 + Q18 + KALLAX vs eket |
| `docs/5-levels.md` | 143 | L1-L5 实做 + 验证命令 + FAIL 模式 |
| `docs/4-roles.md` | 181 | Conductor + Performer (coder/reviewer/tester/docs) + 分支权限 + 1+4 容量 |
| `docs/process/q18-decision-model.md` | 543 | Q18 决策模型完整 SOP (5 block + 3 danger + 25 cells) |

**冷启动路径**:
```
CLAUDE.md (3.3KB, 必读)
  ↓
kallax status (运行时)
  ↓
按需 docs/CHEATSHEET.md → 5-levels.md / 4-roles.md / q18-decision-model.md
```

---

## 11. 集成测试路径 (6 武器 端到端 + decision-matrix 25 cells)

**对照验证** (跟 README §"集成测试 25/25 PASS" 联合):

```bash
# 6 武器 端到端 (跟 W1-W6 1:1)
bash tests/integration/6-weapons-e2e-test.sh
# → 6/6 PASS

# 决策矩阵 25 cells (跟 Q18 1:1)
bash tests/integration/decision-matrix-test.sh
# → 25/25 cells PASS

# 5 levels 验证
bash tests/integration/5-levels-test.sh
# → PASS

# Lazy load 验证
bash tests/integration/lazy-load-test.sh
# → PASS

# Sub-role dispatch 验证
bash tests/integration/sub-role-test.sh
# → PASS (4 sub-roles)

# EPIC 4 件套 验证
bash tests/integration/epic-4-piece-test.sh
# → PASS (A+B review + readme + lessons + signoff)
```

**KPI 累计** (跟 README §"KPI" 联合):

| 指标 | v2.7.6 | v3.0.0 | 变化 |
|------|--------|--------|------|
| CLAUDE.md size | 54KB | 3.3KB | **16.4x 缩减** |
| 术语数 | 35 | 0 (cheatsheet + lazy load) | 100% 砍 |
| Rule 数 | 21 | 0 硬编码 (5 levels + 4 roles 替代) | 100% 替代 |
| Rust crates | 8 | 5 | 整合 3 |
| 冷启动 | ~8ms | ~5ms | 1.6x 加速 |
| 6 武器 | 0/6 | 6/6 | 100% done |
| 集成测试 | - | 25/25 cells PASS | 100% pass |
| Binary 数 | 2 | 1 (kallax) | 50% 整合 |

---

## 13. eket ioredis 实战 (跟 v3.5.0 实战 配合, v3.7.0 L2 cache +1)

**v3.5.0 实战 evidence 落地** (`docs/evidence/v3.5.0/ioredis-parity-check.md`):

- ioredis version `^5.4.0` 跟 eket 0.5+ 兼容 (跟 eket 配合, 跟"诚实修正" 联合 0 假装)
- 跟 eket 分布式锁 (SETNX) + 分布式队列 (Pub/Sub) 对照验证
- 跟 v3.0.0 master-election.ts 三级选举 (Redis SETNX + SQLite + File) 对照验证

**v3.7.0 L2 cache 实战 evidence 落地** (`docs/evidence/v3.7.0/l2-cache-parity-check.md`):

- L1 moka + L2 Redis 二级 cache (跟 eket architecture 借鉴, 实战比例 20% → 30%)
- L2 cache TTL 300s (跟 eket `cache-default-ttl` 300s 1:1)
- evidence byte-different 跟 dry-run (跟 V350-B P-002 配合)

---

## 14. 文化 + 法律 配合 (跟 v3.6.0 配合, 跟 Q12 战略 + 假 PASS 症状复发 从根源修复)

**文化** (跟 V350-B P-001 配合 从根源修复 "装饰反讽"):
- 0 装饰 引用 (跟 V350-B P-001 配合 从根源修复)
- 0 估数 (跟 V350-B P-005 配合 从根源修复 "1.5-2x / 100% parity")
- 0 narrative 包装 (跟 V350-B P-002 配合 从根源修复)
- 0 反讽 fake theatre (跟 V350-B P-002 配合, v3.7.0 +1 immutable script)

**价值观** (跟 CLAUDE.md §3 配合, 跟 Q12 战略 配合):
- 小步迭代 + 彻底完成 (假 PASS 症状复发 从根源修复)
- 诚实修正 (1.5-2x → 0.92x, 100% parity → 30%)
- 复用同类症状,从根源修复 从根源修复 (5 release 累计 → v3.7.0 6 release 累计)

**不可更改法律** (immutable scripts, v3.6.0 4 → v3.7.0 5):
1. `check-decorative-claim.sh` (0 装饰 引用)
2. `check-narrative.sh` (0 narrative 包装)
3. `check-fail-closed.sh` (0 fail-open)
4. `check-self-heal.sh` (self-heal pattern)
5. `check-evidence-fake.sh` (v3.7.0 新增, 0 fake theatre, 跟 V350-B P-002 配合)

**KALLAX_DESIGN_MODE=1 master token** (跟 V350-B P-002 配合):
- 5 scripts 全 run as guards
- master token 显式 接受 violations
- 0 假装 100% PASS

---

## 12. 参考资料 (跟 docs/ 内其他文档 互链)

### 12.1 主文档 (CLAUDE.md + 4 lazy load)

- [CLAUDE.md](../CLAUDE.md) — 3.3KB cold start (必读)
- [docs/CHEATSHEET.md](CHEATSHEET.md) — 1 页 cheatsheet (27 行)
- [docs/5-levels.md](5-levels.md) — 5 levels 实做 (143 行)
- [docs/4-roles.md](4-roles.md) — 4 roles (181 行)
- [docs/process/q18-decision-model.md](process/q18-decision-model.md) — Q18 决策模型 (543 行)

### 12.2 docs/architecture/ 子文档 (11 个, 见 `_index.md`)

| 文档 | 状态 | 章节引用 |
|------|------|---------|
| `docs/architecture/degradation-strategy.md` | 引用 | §9 (3 层降级) |
| `docs/architecture/agent-protocol.md` | 引用 | §7 (4 roles) |
| `docs/architecture/dag-scheduler.md` | 引用 | §3.1 (顶层架构图, W3 sub-role) |
| `docs/architecture/election-system.md` | 引用 | (Iter 3 整合, 主公拍板) |
| `docs/architecture/heartbeat-observability.md` | 引用 | §8 (Q18 决策模型 + heartbeat) |
| `docs/architecture/hook-pipeline.md` | 引用 | §5 (W5 Hook Server) |
| `docs/architecture/isolation-strategy.md` | 引用 | §7 (worktree 隔离, Iter 1) |
| `docs/architecture/recommender-system.md` | 引用 | §4 (跟 eket 对比) |
| `docs/architecture/roadmap.md` | 引用 | (v3.0.0 + v3.1.0 候选) |
| `docs/architecture/3-MODES.md` | 引用 | §8.4 (3 模式) |
| `docs/architecture/framework.md` | **DEPRECATED** | 指向本文档 (v2.7.6 旧版) |
| `docs/architecture/three-repo-architecture.md` | **DEPRECATED** | 跟本文档重复, 整合到 §3.1 |
| `docs/architecture/workflow-engine.md` | **DEPRECATED** | 跟本文档重复, 整合到 §5 |
| `docs/architecture/verification-protocol.md` | **DEPRECATED** | 跟本文档重复, 整合到 §6 |

### 12.3 知识库 + 任务管理

- [README.md](../README.md) — 333 行 (跟 eket 对比表)
- [confluence/decisions/](https://github.com/godlockin/kallax/tree/miao/confluence/decisions) — EPIC + PHASE + RELEASE 决策记录
- [jira/](https://github.com/godlockin/kallax/tree/miao/jira) — EPIC + Ticket 管理

### 12.4 Release + CHANGELOG

- [KALLAX v3.0.0 Release Notes](https://github.com/godlockin/kallax/blob/miao/confluence/decisions/RELEASE-v3.0.0-2026-06-29.md)
- [CHANGELOG.md](../CHANGELOG.md)

---

**Source**: Iter 11 (集成测试 6 武器 端到端) + Iter 12 (v3.0.0 release) + Q11 实施 (跟 eket 互补).
**验证**: `bash tests/integration/6-weapons-e2e-test.sh` (6/6) + `bash tests/integration/decision-matrix-test.sh` (25/25) + `bash scripts/permission/decision-matrix.sh --self-test`.
**对照验证**: README.md (333 行) × CHEATSHEET.md (27 行) × 5-levels.md (143 行) × 4-roles.md (181 行) × q18-decision-model.md (543 行) × 6 武器 (6) × 25 cells (5×4) × 9 KPIs (KPI 表).