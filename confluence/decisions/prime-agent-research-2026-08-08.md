# prime-agent Research 2026-08-08 — Master 仲裁 + 借鉴清单

**调研对象**: PrimeIntellect-ai/prime-agent (⭐ 6,955 / 🍴 565, MIT, 2026-08-08 active)
**调研日期**: 2026-08-08
**方法**: EPIC-056-A 3 阶段治理 (Conductor 全局扫描 + 9 专家并行 + Master 仲裁)
**报告存档**: `/tmp/prime-agent-research/` (README + 4 个核心 docs + repo meta)
**联动**: EPIC-013 (borrowing-from-external) + EPIC-206 (manifesto) + EPIC-213 (elevator-pitch)

---

## 1. prime-agent 一句话定位

**Open-source coding/research agent for general + long-running work, IPython-as-control-plane + daemon-backed workers + continual harness refinement + importable Python skills.**

跟 KALLAX **正交叠加**: prime-agent 是 runtime (替代/竞争 Claude Code), KALLAX 是 governance layer (治理 Claude Code). 不直接竞争, 但 prime-agent 的设计点暴露 KALLAX 多个空白.

---

## 2. 9 专家报告汇总 (去重 + 仲裁)

### 后端 3 件套 (Agent #1: Backend + Frontend + Security)

| 借鉴 | 出处 | 仲裁 |
|------|------|------|
| **持久 Supervisor + Lease** | Backend | ✅ 跟 KALLAX worktree 隔离互补 (分层), 落 EPIC-222 |
| **统一 Headless Event Protocol** | Frontend | ✅ KALLAX 26 命令缺统一契约, 落 EPIC-222 |
| **Capability-Based Fail-Closed Security** | Security | ⚠️ P0 红线, 触及 6 immutable scripts + AUTO-PERMS — 本调研不强行开 P0, 落 EPIC-222 research-only |

### UX/产品 3 件套 (Agent #2: UX + Product + Process)

| 借鉴 | 出处 | 仲裁 |
|------|------|------|
| **README 30s elevator + 场景段** | UX + Product | ✅ 跟 EPIC-213 manifesto elevator-pitch 扩展, 落 EPIC-217 |
| **Long-running 原语 (heartbeat/schedule)** | Product | ✅ 跨 worktree 聚合状态, 落 EPIC-218 |
| **Refine snapshot at repo level** | Process | ✅ CLAUDE.md 改也走 snapshot+rollback, 落 EPIC-219 |

### 治理 3 件套 (Agent #3: Auditor + Compliance + Decision-Gate)

| 借鉴 | 出处 | 仲裁 |
|------|------|------|
| **Disclaimer audit script** | Auditor | ✅ 6th immutable script (同 5 existing), 落 EPIC-220 |
| **DCO + Rule 34 contribution template** | Compliance | ✅ 跟现有 DCO + Apache 2.0 + EPIC-152, 落 EPIC-221 |
| **"limit ≠ success" disclaimer 标准** | Decision-Gate | ✅ 同 v3.8.0 "25/25 假 PASS" 教训, 合并进 EPIC-220 |

---

## 3. 冲突仲裁

| 冲突点 | Agent A 视角 | Agent B 视角 | Master 仲裁 |
|--------|-------------|-------------|------------|
| **Trust model 强弱** | Security: AUTO-PERMS 不够, 升级 capability engine | Compliance: 社区贡献 bugfix 缺 Rule 34 | **双管齐下**: capability engine (long-term, EPIC-222 research) + Rule 34 template (short-term, EPIC-221) |
| **README 减摩擦** | UX: ≤ 80 字 elevator | Product: 场景维度替代规模维度 | **合并**: ≤ 80 字 "What is KALLAX" + "When to use" 场景段, 落 EPIC-217 |
| **持久化 vs 隔离** | Backend: worktree 适合代码, prime-agent 适合长跑 | Frontend: 持久 task 需要统一事件协议 | **分层**: 任务状态持久化 + 代码执行 worktree 隔离, 落 EPIC-218 + EPIC-222 |

---

## 4. 借鉴清单 (按落地优先级, P0/P1/P2)

### P0 (红线, 触及治理核心) — 0 项

> **0 触及 immutable scripts / Rule 改 / 4-PR bypass**: 本次调研**不开 P0 ticket**. 借鉴以 P1 流程升级为主, 同 EPIC-207 v2 (主公亲自拍板).

### P1 (流程升级, 备案 + RECORD) — 6 项

| # | EPIC | 标题 | 联动 | effort | 候选 |
|---|------|------|------|--------|------|
| 1 | **EPIC-217** | README 30s elevator + "When to use" 场景段 (跟 EPIC-214 扩展) | EPIC-213 + EPIC-214 | 小 (docs-only) | Rule 37 auto-approve |
| 2 | **EPIC-218** | `scripts/heartbeat-conductor.sh` — Sprint tick 跨 worktree 聚合状态 + `tasks watch/steer` | EPIC-190 + EPIC-205 + EPIC-194 | 中 (新脚本) | 主公拍板 |
| 3 | **EPIC-219** | `scripts/verify/snapshot-claude-md.sh` — CLAUDE.md/rules 修改前 auto git tag + post-edit diff 校验 + rollback cmd | EPIC-161 + EPIC-131/132 | 中 (新 immutable 候选) | 主公拍板 |
| 4 | **EPIC-220** | `scripts/verify/check-disclaimer.sh` — 扫 "trusted/sandbox/secure/safe" 关键词 + 验 raw_output 引用, 6th immutable script + "limit ≠ success" 模式 | EPIC-069-D + EPIC-174 | 中 (新 immutable) | 主公拍板 |
| 5 | **EPIC-221** | `.github/PULL_REQUEST_TEMPLATE.md` + commitlint DCO + bugfix 必填 reproduction 3 字段 (同 ticket.json binding) | EPIC-152 + 现有 DCO | 中 (config + doc) | Rule 37 auto-approve |
| 6 | **EPIC-222** | `confluence/decisions/EPIC-XXX-persistent-supervisor.md` — 持久 supervisor + lease + checkpoint + capability policy 设计稿 (research-only, 不实现) | EPIC-056-A + EPIC-190 | 大 (research) | 主公拍板 |

### P2 (操作放手) — 0 项 (借鉴合并进 P1)

| # | EPIC | 标题 |
|---|------|------|
| - | **EPIC-223** | ~~借鉴 prime-agent "limit ≠ success" 措辞, 5-Level Verify L2/L3 exit≠0 强制追加 disclaimer 行~~ → **合并进 EPIC-220** |

---

## 5. 关键认知

### 5.1 KALLAX 不直接竞争 prime-agent

KALLAX 是 **governance layer** (治理 Claude Code 怎么进 prod), prime-agent 是 **runtime** (替代 Claude Code 跑 long-running). 正交叠加, 不互相替代. 借鉴方法论 > 抄代码 (同 EPIC-206 "借方法论 不借代码").

### 5.2 KALLAX 暴露的 4 个空白

1. **README 摩擦**: 193 行 CLAUDE.md + 26 命令, 主公首次接触认知负荷高 (UX 报告)
2. **Long-running 原语**: 缺跨 worktree heartbeat / autonomous bounded continuation (Product 报告)
3. **CLAUDE.md modify snapshot**: 改 CLAUDE.md / rules 无自动 snapshot, 一旦改坏只能 git log 救 (Process 报告)
4. **Disclaimer audit**: 6 immutable scripts 防 commit 漂移, 但 README/CHANGELOG 数字"假 PASS"复发 (Auditor 报告, 同 v3.8.0)

### 5.3 借鉴方法论而非抄代码 (同 EPIC-013 + EPIC-206)

prime-agent 7 大设计点对应 KALLAX 落地:

| prime-agent 设计点 | 借鉴 / 不借鉴 | 落 EPIC |
|-------------------|--------------|---------|
| **RLM (IPython-as-control-plane)** | ❌ 不抄 (栈不兼容) | EPIC-222 research |
| **Continual Harness (small evidence-backed refine)** | ✅ 借鉴 | EPIC-219 |
| **Daemon-backed workers** | ✅ 轻量借鉴 | EPIC-218 |
| **Direct A2A messaging** | ✅ 借鉴 | EPIC-218 (tasks watch/steer) |
| **Skills discovery 4 优先级** | ❌ 不抄 (跟 26 命令显式 slash 冲突) | - |
| **Trust model 显式 disclaimer** | ✅ 反向借鉴 (扫别人的 disclaimer) | EPIC-220 |
| **"limit ≠ success" 诚实** | ✅ 借鉴 | EPIC-220 |

---

## 6. 不借鉴 (含理由)

| prime-agent 特性 | 不借鉴理由 |
|------------------|-----------|
| Python kernel 成为信任边界 | 跟 KALLAX Rust/Node 栈冲突, 不引入任意 Python 执行进治理核心 |
| 5 级 built-in 隐式 discovery | 跟 KALLAX 26 命令显式 slash 设计冲突 |
| 子 agent 跨 compaction 持久 | KALLAX worktree 隔离更适合审计 + 可合并, 持久化作 research (EPIC-222) |
| model-driven 决策 | 缺 P0/P1/P2 + 主公拍板, 同 EPIC-055-B 冲突 |
| 仅 disclaimer 无审计 | 反向借鉴: 扫 disclaimer, 不是写 disclaimer |
| 商业产品 + MIT 双轨 (PrimeIntellect 模式) | KALLAX 0 商业产品, 不适用 |

---

## 7. 落地路径 (同现有 4-PR + 5-Level + Sprint 时间盒)

```
Phase 1 Conductor (本报告 §1) ✅ 完成 2026-08-08
Phase 2 9 专家 (本报告 §2) ✅ 完成 2026-08-08
Phase 3 Master 仲裁 (本报告 §3-6) ✅ 完成 2026-08-08
↓
Sprint 落票 (同 EPIC-190 时间盒)
 EPIC-217 (elevator) ─┐
 EPIC-221 (DCO+Rule34) ─┴─ docs-only (Rule 37 候选, auto-approve)
 EPIC-218 (heartbeat) ─┐
 EPIC-219 (snapshot) ─┤ 新脚本/新 immutable (主公拍板)
 EPIC-220 (disclaimer) ─┤
 EPIC-222 (supervisor research) ─┘
↓
Sprint 结束必跑 4 北极星指标 (EPIC-194 + EPIC-204 docs-only flag)
```

**决策点 (跟 EPIC-055-B P0/P1/P2 联动, 等主公拍板)**:
- 6 P1 EPIC 全部进下 Sprint? 还是择高优先级 2-3 项?
- EPIC-217 + EPIC-221 是否走 Rule 37 auto-approve (docs-only + 决策 doc)?
- EPIC-220 是否独立拆 (新 immutable script 触及 5 → 6 治理变更)?

---

## 8. KPI 落地 (跟 Rule 9 X/Y 格式)

| KPI | 数据 | 来源 |
|-----|------|------|
| 调研 EPIC | 1 (本次 prime-agent research) | 本决策 doc |
| 9 专家报告 | 3 parallel agent × 3 expert = 9 份 | Phase 2 agent 输出 |
| 借鉴清单 | 6 P1 EPIC | 本报告 §4 |
| 不借鉴 | 6 项 (含理由) | 本报告 §6 |
| 主公拍板 | 0 (待主公 review 后) | 待 |
| 4 北极星 | 待下 Sprint 跑 (EPIC-194) | EPIC-217/218/219/220/221/222 |

**Rule 9 落地**: 1/1 决策 doc + 3/3 agent 报告 + 6/6 P1 EPIC = 10/10 项全交付.

---

## 9. Why this report matters

prime-agent 是跟 Claude Code 同赛道最强开源竞品 (6.9k stars, MIT, 活跃). 调研暴露 KALLAX 4 个治理空白 (README 摩擦 / Long-running 原语 / CLAUDE.md snapshot / Disclaimer audit). 借鉴方法论 (不是抄代码) 落地 6 P1 EPIC, 同 EPIC-194/204 docs-only metrics + EPIC-190 Sprint 时间盒 + EPIC-207 4-PR governance 跑通.

**How to apply**:
1. 主公 review 本决策 doc, 拍板 6 P1 EPIC 是否全部进下 Sprint
2. EPIC-217 + EPIC-221 docs-only 走 Rule 37 auto-approve (同 EPIC-216)
3. EPIC-218/219/220/222 新脚本/immutable 走主公亲自拍板 (同 EPIC-216 例外)
4. Sprint 结束必跑 sprint-metrics --docs-only flag (同 EPIC-204)
5. 6 EPIC 落地后, prime-agent 调研跑通, retro 一句话进 `confluence/manifesto/04-lessons.md`