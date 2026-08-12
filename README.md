# KALLAX v3.34.6

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor

**Claude Code 配套治理框架** | 借鉴 [eket](https://github.com/godlockin/eket) 极简哲学 | 详见 .claude/rules/recent-epics.md | 0 跳流程, 0 估数字, 0 装饰性宣称

---

## What is KALLAX? (30 秒电梯, EPIC-217 补落)

> **Claude Code 写代码, KALLAX 管代码怎么进 prod** — 不替代 Claude Code, 不写代码, 只做**审计 / 验证 / 治理**. 定位是 **CI/CD for AI agents**.

**不是**: Claude Code runtime / 替代 agent 框架 / IDE 插件 / 写代码的工具.

**是**: Claude Code 之外的一套**治理 gate** — 4-PR chain + 5-Level Verify + 9 immutable scripts + 4 北极星指标 + 9 专家并行评审, AI 写的代码进 prod 之前必走的关卡.

## When to use KALLAX? (场景维度, 替代规模维度, EPIC-217 补落)

| 场景 | 推荐 | 理由 |
|------|------|------|
| **governance-heavy multi-agent** (≥3 sub-agent 并行, 跨 worktree) | **必须** | 4-PR 强制 + worktree 隔离 + 9 专家并行, 防止 sub-agent 漂移 (BE-14 教训) |
| **regulated team** (金融 / 医疗 / 政企, 需 audit trail) | **必须** | 5-Level Verify + Hash-Chain Audit + DCO + Apache 2.0 |
| **Claude Code customization 重度用户** (大量 skills / subagents / CLAUDE.md 治理) | **强烈推荐** | snapshot-claude-md (EPIC-219) + heartbeat-conductor (EPIC-218) + capability-policy (EPIC-222 research) |
| **单人开发, 简单脚本** | Claude Code 直用 | governance overhead > value, KALLAX 不适用 |

**Trigger Signals** (任一命中, 立刻用 KALLAX):

- "上次 prod 假 PASS" → 5-Level Verify + check-claim-evidence (EPIC-069-D, EPIC-220 disclaimer gate)
- "team ≥3 sub-agent 并行, 分不清谁做了什么" → 4-PR + 9 专家并行 (EPIC-056-A)
- "PR 经常 skip review" → 4-PR master review 强制 (EPIC-074 + EPIC-207)
- "bug 修过 3 次复发" → Rule 34 独立复现 3 字段 (EPIC-152)
- "CLAUDE.md 改坏, 只能 git log 救" → snapshot-claude-md (EPIC-219)

---

## Why KALLAX?

> Claude Code 解决 "AI 怎么写代码", **KALLAX 解决 "AI 写的代码怎么进 prod"**. 是 AI 工程界的 **"CI/CD for AI agents"**:

- **4-PR 工作流** (feature → testing → main → miao, 4 阶段 master review 强制, EPIC-074 + EPIC-207)
- **5-Level Verify** (L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary, EPIC-069-D 防假 PASS)
- **37 Rule + 9 immutable scripts** (fail-closed, EPIC-069-D + EPIC-131/132 + EPIC-174 + EPIC-224/225)
- **4 北极星指标** (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch, EPIC-194 + EPIC-204 docs-only)
- **9 专家 3 阶段治理** (Conductor + 4 default + 5 extended, EPIC-056-A)

## Why KALLAX vs Claude Code?

| 维度 | Claude Code | KALLAX | 关系 |
|------|-------------|--------|------|
| **职责** | AI Runtime (代码生成/补全) | Governance Layer (审计/验证/治理) | **正交叠加** |
| **sub-agent** | 单 session | 多 worktree 隔离 | KALLAX 并行 |
| **PR 流程** | 无 (单角色) | 4-PR Chain (feature→testing→main→miao) | KALLAX 强制 |
| **失败追溯** | session 关闭即丢失 | run-history emit + Hash-Chain Audit | KALLAX 持久 |
| **Verify** | 无 | 5-Level Fact-Forcing (L1-L5 独立) | KALLAX 防假 PASS |

**3 句使用判断**:

| 场景 | 推荐 | 理由 |
|------|------|------|
| **单人开发, 简单脚本** | Claude Code | overhead > value, 直接够用 |
| **team ≥ 3 人, 长期项目** | KALLAX | 5-Level Verify + 4-PR Chain 价值最大化 |
| **Enterprise, 合规审计** | KALLAX 必须 | Audit trail + self-heal 满足合规 |

**Trigger Signals** (出现任一则推荐 KALLAX):
- "上次 prod 假 PASS"
- "team 多人在做, 分不清谁做了什么"
- "PR 经常 skip review"
- "bug 修过 3 次复发"
- "Claude Code session 关了上下文丢"

**3 视角 raw_output 引用** (per EPIC-069-D check-claim-evidence):
- **PR 视角**: 4-PR 链 + master + 4 sub-roles review (参考 EPIC-074, 跟随 EPIC-207)
- **CTO 视角**: 5-Level Verify + Audit Chain + self-heal (参考 EPIC-069-D, 跟随 EPIC-110)
- **Marketing 视角**: positioning doc 公开化 + 公开化协同 (参考 EPIC-169, 跟随 EPIC-172)

完整定位: [confluence/research/kallax-positioning-2026-08-05.md](confluence/research/kallax-positioning-2026-08-05.md) (EPIC-171, 3 视角: PR + CTO + Marketing)

## 快速入口

- 📋 [CLAUDE.md](./CLAUDE.md) — cold start 入口 (188 行, 36 Rule 必读)
- 🎯 [00-elevator-pitch.md](./confluence/manifesto/00-elevator-pitch.md) — 一句话介绍 (EPIC-213, 中英)
- 🏛️ [01-top-design.md](./confluence/manifesto/01-top-design.md) — 4 子系统 + 顶层架构 (EPIC-206)
- 🎯 [02-scope-mission-vision.md](./confluence/manifesto/02-scope-mission-vision.md) — Scope/Mission/Vision/5 价值观 (EPIC-206)
- ⏱️ [03-timeline.md](./confluence/manifesto/03-timeline.md) — 累计 EPIC 时间线 (EPIC-206, 见 .claude/rules/recent-epics.md 详情)
- 📚 [04-lessons.md](./confluence/manifesto/04-lessons.md) — 5 类经验教训 (EPIC-206)
- ✨ [05-best-practices.md](./confluence/manifesto/05-best-practices.md) — 8 类最佳实践 (EPIC-206)
- 🔁 [EPIC-203 retrospective](./confluence/decisions/EPIC-203-audit-retrospective-2026-08-08.md) — Sprint 收尾审计
- 🛡️ [EPIC-207 4-PR governance](./confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md) — master review 强制

## 安装

```bash
git clone https://github.com/godlockin/kallax.git
cd kallax
bash install.sh  # 全栈 deploy 95 files (依据 EPIC-160 install.sh Omnibus)
```

## 文档结构 (依据 EPIC-197/199/200/201 SoT 归并)

```
confluence/
  decisions/     # 67 EPIC 拍板记录 (v3.32.2 → v3.34.6, 依据 EPIC-209 跑批)
  memory/        # L1 SoT 决策 + L2 lessons + L3 patterns + L4 research
  research/      # 沉淀文档 (EPIC-171 positioning + EPIC-172 growth loop)
  manifesto/     # 6 文件顶层 (EPIC-206 + EPIC-213 elevator pitch)
docs/
  process/       # 流程治理 (post-process / doc-audit / smoke-retention / projection-sink)
  reference/     # 24 reference docs (lazy load, 依据 EPIC-209)
  evidence/      # 5-Level Verify raw output (依据 EPIC-069-D)
  _archived/     # 23 DEPRECATED 文件 (依据 EPIC-206 ARCHITECTURE.md)
  process/doc-audit-flow.md  # 5-Phase audit flow (EPIC-196/197/199/200/201)
scripts/         # 95 files deploy 入口 (依据 EPIC-160)
.claude/         # Claude Code 配置
  rules/         # 6 path-scoped lazy load (依据 EPIC-159, 含 recent-epics.md)
```

## 累计统计 (依据 EPIC-205 retrospective 跑批)

| 维度 | 数据 | 来源 |
|------|------|------|
| **总 EPIC** | 详见 .claude/rules/recent-epics.md | EPIC-209 trim |
| **总 release** | 8 (v3.32.2 → v3.34.6+) | EPIC-205 retrospective (manifesto/03-timeline.md) |
| **CLAUDE.md 行数** | 188 行 (≤ 200 OK) | EPIC-209 trim |
| **Immutable scripts** | 9 (5 verify + 1 hook + 1 smoke retention + 2 docs/ticket schema) | EPIC-069-D + EPIC-174 + EPIC-220/223/224/225 |
| **DEPRECATED 文件** | 23 (依据 ARCHITECTURE.md) | EPIC-206 + EPIC-209 |
| **Test TC** | 8 + 17 + 6 = 31 PASS (docs-only EPIC 累计) | EPIC-204/205 验证 |
| **force-push bypass** | 9 commits (5 EPIC-155/176 + 4 EPIC-208) | EPIC-207 + EPIC-208 |

## 4-PR 工作流 (依据 EPIC-074 + EPIC-207 v2)

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (FF)  →  miao (主公亲自 review)
   PR-1 master review      PR-2 FF + comment    PR-3 主公拍板
   worktree 隔离            integration + cargo test  full e2e + 4-sub-role review
```

| 阶段 | Master Review | 必跑 |
|------|---------------|------|
| feature → testing | master + 4 sub-roles (Architect/Backend/Frontend/Security) | integration + cargo test --workspace |
| testing → main | master + 4 sub-roles + comment 验证 (FF 关系无独立 PR) | full e2e + decision matrix |
| main → miao | **master 仲裁 + 主公亲自拍板** | conflict check + smoke retention |

## 5-Level Verify (依据 EPIC-069-D + Rule 2)

| Level | 验证命令 | 失败症状 |
|-------|---------|---------|
| **L1 git** | `git log --oneline -1` + `git diff HEAD~1 --stat` | Amend SHA 没变 |
| **L2 stdout** | `cargo test --workspace --release 2>&1 \| tee /tmp/stdout.log` | "should work" 估数 |
| **L3 4-expert** | `kallax expert:run {architect,backend,frontend,security}` | 自审 |
| **L4 independent** | `kallax witness:spawn TICKET --independent` | 瞒报 |
| **L5 boundary** | `kallax test:boundary/exception/concurrent` | happy path only |

## 9 专家 3 阶段治理 (依据 EPIC-056-A)

```
Phase 1: Conductor 全局扫描 (1 份报告, 0 协调开销)
   ↓
Phase 2: 4 default (Backend/Frontend/UX/Product) + 5 extended (security/process/auditor/compliance/decision-gate) = 9 专家
   ↓
Phase 3: Master 仲裁 + 主公拍板 (P0/P1/P2)
```

## 4 北极星指标 (依据 Rule 36 + EPIC-204)

```bash
bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX
# 1. expert_activation_rate ≥ 5 distinct experts
# 2. cross_epic_reuse_rate ≥ 60% 跨 EPIC 复用
# 3. ab_hit_rate (mismatch) < 15% 2-Group review 吻合率
# 4. mis_dispatch_rate < 10% Performer 派单错率
# docs-only EPIC: --docs-only flag + exit 3 DOCS_ONLY_SKIP
```

Exit codes: 0=PASS / 1=FAIL / 2=NO_DATA / 3=DOCS_ONLY_SKIP

## 贡献

参考 [CLAUDE.md](./CLAUDE.md) (188 行, 36 Rule 必读) + [.claude/rules/](./.claude/rules/) (path-scoped lazy load). 任何 PR 必走 4-PR 流程 + 5-Level Verify, 依据 EPIC-074 + EPIC-207 v2.

详细贡献指南: [CONTRIBUTING.md](./CONTRIBUTING.md) | DCO + Apache 2.0: [docs/reference/dco-and-licensing.md](./docs/reference/dco-and-licensing.md)

## 许可

MIT License - 详见 [LICENSE](./LICENSE)

## 致谢

- 借鉴 [eket](https://github.com/godlockin/eket) 极简哲学 (依据 EPIC-171)
- 30 EPIC 累计 (v3.32.2 → v3.34.6, 主公拍板)
- 0 估数字 + 0 装饰性宣称 + 0 元层自嘲 (8 release 累计)