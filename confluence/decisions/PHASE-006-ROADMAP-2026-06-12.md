# PHASE-006 飞轮"迭代" 阶段 Roadmap (2026-06-12)

> **何时写**: 主公 2026-06-12 拍"Token Plan 升过了, 其他的有没有继续的价值? 有的话分析、拆卡、开工" + "带着专家组讨论和思考 roadmap"
> **范围**: 5 痛点 × 8 Gap × 5 专家视角 (Phase 2) + Master 仲裁 (Phase 3) + 主公战略拍板依据
> **路径**: `confluence/decisions/PHASE-006-ROADMAP-2026-06-12.md`
> **方法**: 借鉴 EKET `interactive:start` 多视角 + KALLAX EPIC-021 5 专家 panel + Master 串场 (1 conductor 容量)

**Date**: 2026-06-12
**Author**: master_main (5 视角串场, 不写代码, Rule 11 联动)
**Reviewers**: 主公 (战略审批)
**Status**: ✅ COMPLETE — 等主公拍战略

---

## §1 5 痛点 × 8 Gap 综合矩阵 (回顾)

### 1.1 5 痛点 KALLAX 现状 + 残余 Gap

| 痛点 | KALLAX 现状 | 残余 Gap | 业内最强 |
|---|---|---|---|
| 1 假装完成 | 90% (4-Level + 3 anti-fab + Rule 9/11) | Edit tool bash multi-line 工具层 | CrewAI 70% |
| 2 上下文失忆 | 85% (3 模式 + decision-gate + handoff) | 缺 Checkpoint 时间旅行 (-10 分) | LangGraph 95% |
| 3 角色越界 | 90% (ROLE-RULES + decision-gate + Rule 11) | 缺 Auditor 独立角色 | AutoGen 50% |
| 4 资源覆盖 | 85% (worktree + file-scope) | 跨 worktree 派单 friction | LangGraph 60% |
| 5 安全立体 | 80% (9-pass + 3 轮 20 issue) | 持续 audit 机制 | CrewAI 50% |
| **综合** | **86%** | — | — |

### 1.2 8 Gap 现状 (主公原话"其他的" = 7 Gap, 减去 Token Plan)

| # | Gap | 来源 | Top 4 拍板 | 估时 |
|---|---|---|---|---|
| 1 | EPIC-034-B M1 audit 验证 | EKET P1 #10 | ✅ 立即开工 | 0.5d |
| 2 | EKET P1 #16 worktree_role 强制绑定 | EKET P1 #16 | ✅ 立即开工 | 0.5d |
| 3 | 跨 worktree 派单优化 (Phase 5 模式 G) | Phase 5 | ✅ 立即开工 | 1d |
| 4 | 持续 audit 机制 (redaction 半年 + KPI cron) | Phase 6 决策 | ✅ 立即开工 | 1d |
| 5 | 派发权 80→90% AI (D3) | 主公 D1/D2 渐进 | ⏳ 6 EPIC 后拍 | 1d |
| 6 | 3 模式衍生 (Auditor/Readonly 6 项) | EKET P2 #19 | ⏳ PHASE-007 后拍 | 2-3d |
| 7 | 90 extended 5 字段升级 | EKET P2 #21 | ⏳ YAGNI 用到再补 | 1d |
| 8 | Checkpoint 时间旅行 (借鉴 LangGraph) | 痛点 2 落后 10 分 | ⏳ PHASE-007 后拍 | 2-3d |

---

## §2 5 专家视角 Master 串场 (Phase 2 + Phase 3)

按 KALLAX Phase 6 §5 "Master 担任 1 conductor 写启动 review (不通过 Performer, 防 6 次反复 KPI falsification)" — 5 视角 Master 串场自审.

### 2.1 🏗️ Architect 视角

| 痛点 | 架构层建议 |
|---|---|
| 1 假完成 | Edit tool bash multi-line bug 是工具层, Master 强验证 workaround 有效, **不优先** |
| 2 上下文失忆 | **借鉴 LangGraph Checkpoint 思路**, 用 SQLite 实现 (跟 `instances.json` 同存储, 节省复杂度) — **下个 PHASE 拍** |
| 3 角色越界 | **Auditor 角色作为 Conductor 衍生模式** (不增新角色, 避免扩 EKET P2 #19) |
| 4 资源覆盖 | 跨 worktree 派单 **派单脚本** 优化即可 (不引入新模式) |
| 5 安全立体 | 持续 audit 用 cron + alert, 跟现有 9-pass redaction 复用 |

**Architect 关键建议**:
- A1: Checkpoint 时间旅行 = **借鉴思路, 不引入框架** (SQLite 自建, 1d)
- A2: Auditor 角色 = **Conductor 衍生** (避免 EKET P2 #19 6 衍生扩面)
- A3: 跨 worktree = **派单脚本** (EPIC-036, 1d)

### 2.2 🛡️ Security 视角

**安全累计 3 轮叠加** (EPIC-029: 13 / EPIC-030: 5 / EPIC-031: 2 / Phase 6 半年: 3 = 23 issue).

| Gap | 安全建议 |
|---|---|
| Gap 4 持续 audit | **P0 优先** (防 9-pass redaction 半年过期) |
| Gap 2 worktree_role | 防"Performer 拿 Conductor ticket" 错配 (role-level ACL) |
| Gap 8 Checkpoint | **下个 PHASE 拍** (借鉴 LangGraph 思路, 自建可控) |
| 痛点 5 80% 是 5 痛点最低 | **优先提升**, 避免"长板变短板" |

**Security 关键建议**:
- S1: EPIC-037 持续 audit **P0 优先** (痛点 5 是短板, 加 10 分)
- S2: 3 prefix 扩 (GCP/AWS/Azure) 是 1d 微小修, 跟 EPIC-037 一起
- S3: Anti-Fabrication 工具 (Rule 9/11) 是 security 一部分, 持续加固

### 2.3 💻 Backend 视角

| Gap | 工程量 | 风险 | 推荐顺序 |
|---|---|---|---|
| 1 EPIC-034-B M1 audit | 0.5d | **中** (61%→80% 难度) | **P0** (Step 1 已落, 0 起步风险) |
| 2 EPIC-035 worktree_role | 0.5d | 低 (Rule 8 + TDD) | **P1** (EPIC-034-B 后) |
| 3 EPIC-036 跨 worktree | 1d | 中 (conflict detect 是核心) | P1 |
| 4 EPIC-037 持续 audit | 1d | 低 (cron + alert) | P1 |
| 5 Checkpoint 时间旅行 | 2-3d | **高** (借鉴 + 自建) | **P2 推迟** |
| 6 派发权 80→90% AI | 1d | 中 (D3 决策) | **P2 推迟** (D2 刚升 80%) |
| 7 3 模式衍生 | 2-3d | 高 (扩决策面) | **P2 推迟** |
| 8 90 extended 升级 | 1d | 低 (字段补全) | P2 推迟 |

**Backend 关键建议**:
- B1: Top 4 优先 (3.5d 串行)
- B2: M1 Recall 修法跟 EPIC-032 50→50 同思路 (加数据 + 调 trigger)
- B3: Checkpoint 用 SQLite 复用 instances.json 库, 节省复杂度
- B4: Edit tool bash multi-line bug 是工具层, **不优先** (workaround 有效)

### 2.4 📋 Product 视角

**主公飞轮"迭代" 目标 = 不断优化 KALLAX 体系**

| Gap | ROI | 用户可见 | 战略价值 |
|---|---|---|---|
| 1 EPIC-034-B | 中 (Recall 数据) | 低 (内部) | M1 质量验证, 飞轮"迭代"基础 |
| 2 worktree_role | **高** (痛点 4 加强) | 低 (内部) | 防错配, 痛点 3 +5 分 |
| 3 跨 worktree 派单 | 中 (派单 friction) | 中 (Conductor) | 飞轮"迭代" 阶段加速 |
| 4 持续 audit | 中 (防 KPI falsification) | 中 (审计员) | 痛点 1 防御升级, 痛点 5 +10 分 |
| 5 Checkpoint | 中 (痛点 2 落后) | 高 (崩溃恢复) | 痛点 2 +10 分 |
| 6 派发权 80→90% AI | 低 (省 10% Conductor) | 低 | 推迟, 跟 EKET 节奏 |
| 7 3 模式衍生 | 低 (扩决策面) | 中 | 推迟, P2 战略 |
| 8 90 extended | 低 (补字段) | 低 | 推迟, YAGNI |

**Product 关键建议**:
- P1: Top 4 全开工 (3.5d 串行), 跟主公拍"同意建议" 对齐
- P2: 推迟 3 项 (Gap 6/7/8), 避免扩面
- P3: Checkpoint 时间旅行 **下个 PHASE-007 闭环后** 拍 (跟 EKET P1 节奏)
- P4: 90 extended **用到再补** (YAGNI 反模式)

### 2.5 🖌️ UX 视角

**3 类用户** (主公 / Conductor / Performer):

| Gap | UX 影响 |
|---|---|
| Top 4 (worktree_role / 跨 worktree / 持续 audit) | 跟 Conductor/Performer 体验直接相关 |
| 持续 audit 是"auditor 用户", 但 KALLAX 当前**没独立 Auditor 角色** | 给"主公 + Conductor 强验证" 用, 价值在内部 |
| Checkpoint 时间旅行 — **不紧急** | 跟"飞轮" UX 关系弱 |
| EKET P2 #3 飞轮"迭代" UX (TUI / web dashboard) | **P2 战略**, 跟 6 EPIC 累积后拍 |

**UX 关键建议**:
- U1: Top 4 跟 Conductor/Performer 体验直接相关, **优先**
- U2: 持续 audit 是"内部" 价值, 不增 UX 复杂度
- U3: Checkpoint 时间旅行 — **不紧急**, 主公不直接操作
- U4: 飞轮"迭代" UX 文档 (TUI / web dashboard) — **P2 战略**

---

## §3 Master 仲裁 + 5 视角合并 (Phase 3)

### 3.1 5 视角一致结论

| 决策点 | Architect | Security | Backend | Product | UX | Master 仲裁 |
|---|---|---|---|---|---|---|
| Top 4 全开工 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **强一致** |
| 推迟 Gap 6 派发权 90% | 待 | 待 | ✅ | ✅ | 待 | ✅ |
| 推迟 Gap 7 3 模式衍生 | 待 | 待 | ✅ | ✅ | 待 | ✅ |
| 推迟 Gap 8 90 extended (YAGNI) | 待 | 待 | ✅ | ✅ | ✅ | ✅ |
| Checkpoint 时间旅行 (P3) | ✅ | ✅ | ✅ | ✅ | 待 | ✅ 下个 PHASE 拍 |

**仲裁关键**: 5 视角对 Top 4 强一致, 推迟 3 项次一致, Checkpoint 时间旅行 4 视角支持 P3.

### 3.2 战略飞轮 4 窗口 (主公拍)

```
窗口 1: P0 立即 (1 周内, 3.5d 串行)
   ↓ 触发
窗口 2: P1 6 EPIC 后 (1-2 月) — PHASE-007 闭环后拍
   ↓ 触发
窗口 3: P2 持续累积 (3+ 月) — 飞轮"迭代"长期
   ↓ 触发
窗口 4: 战略升级 (12+ 月) — 跨框架层
```

---

## §4 飞轮"迭代" 阶段 Roadmap

### 4.1 窗口 1: P0 立即开工 (3.5d 串行)

| 序 | EPIC | 估时 | 战略意图 | 痛点提升 |
|---|---|---|---|---|
| 1 | **EPIC-034-B M1 audit** (Step 2) | 0.5d | 修 M1 Recall 61%→80%+ | 痛点 1 验证 |
| 2 | **EPIC-035 worktree_role** 强制绑定 | 0.5d | 防"Performer 拿 Conductor ticket" 错配 | **痛点 3 +5 分** |
| 3 | **EPIC-036 跨 worktree 派单** | 1d | 派单 friction 减少 (Phase 5 模式 G) | **痛点 4 +5 分** |
| 4 | **EPIC-037 持续 audit** (redaction + KPI) | 1d | 9-pass 持续验证 + KPI audit | **痛点 1 +5 / 痛点 5 +10** |

**累计落地**: 4 新 EPIC, **痛点综合 86% → 91%**.

### 4.2 窗口 2: P1 6 EPIC 后拍 (PHASE-007 闭环后)

| 序 | Gap | 估时 | 触发条件 |
|---|---|---|---|
| 5 | 派发权 80→90% AI (D3) | 1d | 6 EPIC 累积 + 主公拍 D3 |
| 6 | 3 模式衍生 (Auditor/Readonly 6 项) | 2-3d | EKET P1 #13-15 收口 + 主公拍 |
| 7 | Checkpoint 时间旅行 (借鉴 LangGraph) | 2-3d | 痛点 2 落后 10 分 + 主公战略 |

**累计落地**: 痛点综合 **91% → 96%** (Checkpoint 落地后痛点 2 90%).

### 4.3 窗口 3: P2 持续累积 (3+ 月) — 飞轮"迭代"长期

| 序 | Gap | 估时 | 触发 |
|---|---|---|---|
| 8 | 90 extended 5 字段升级 | 1d | **用到再补** (YAGNI) |
| 9 | 飞轮"迭代" UX (TUI / web dashboard) | 1-2d | EKET P2 #3, 主公战略 |
| 10 | 持续 audit 跨场景 (跨 worktree / 跨 phase) | 1d | 跟 6 EPIC 累积后 |

### 4.4 窗口 4: 战略升级 (12+ 月) — 跨框架层

- 派发权 95%→100% AI (D4/D5)
- 借鉴 LangGraph / CrewAI Enterprise 商业层
- 跨项目 / 跨 repo (KALLAX 体系化)

---

## §5 飞轮"迭代" ROI 评估

### 5.1 5 痛点完工后 (Top 4 + P1) 评分

| 痛点 | 当前 | Top 4 完 | P1 完 | 提升 |
|---|---:|---:|---:|---:|
| 1 假完成 | 90% | **95%** | 95% | +5 |
| 2 上下文失忆 | 85% | 85% | **95%** (Checkpoint) | 0 → +10 |
| 3 角色越界 | 90% | **95%** | 95% | +5 |
| 4 资源覆盖 | 85% | **90%** | 90% | +5 |
| 5 安全立体 | 80% | **90%** | 90% | +10 |
| **综合** | **86%** | **91%** | **96%** | **+5 → +10** |

### 5.2 KALLAX vs 业内 4 框架对比 (完工后)

| 框架 | 当前 | Top 4 完 | P1 完 |
|---|---:|---:|---:|
| **KALLAX** | 86% | **91%** | **96%** |
| LangGraph | 53% | 53% | 53% |
| CrewAI | 52% | 52% | 52% |
| AutoGen | 46% | 46% | 46% |
| MetaGPT | 13% | 13% | 13% |

**KALLAX 完工后领先业内 4 框架 50+ 分** (96% vs 53%).

---

## §6 风险与依赖

| 风险 | 缓解 |
|---|---|
| M1 Recall 61%→80% 难度 | Performer 跑得动, 跟 Step 1 思路 (加数据 + 调 trigger) |
| Top 4 串行 3.5d 撞 token | 主公 2026-06-12 拍"token 会有波动但是没有瓶颈" — 风险已消 |
| EPIC-034-B 跑不出 80% | fallback: 接受 70%+, 留 PHASE-007 闭环后再修 |
| Checkpoint 时间旅行 (P1) 自建实现复杂度 | 用 SQLite 复用 instances.json 库, 2-3d 可控 |
| EPIC-036 conflict detect 边界 | git format-patch + git am 是成熟方案, 风险低 |

### 6.1 跨 EPIC 经验升级机会 (PHASE-007 闭环后)

- **新主题 lessons**: Top 4 落地后, 累积新子教训 → PHASE-007 升级到 CLAUDE.md 核心原则
- **Anti-Fabrication 工具加固**: KPI audit 跑通后, 跟 check-kpi-precision.sh 整合
- **跨框架借鉴**: LangGraph Checkpoint / CrewAI Enterprise 审计 → KALLAX 升级

---

## §7 等主公拍战略

| # | 决策点 | 推荐 | 战略影响 |
|---|---|---|---|
| 1 | **Top 4 全开工** (3.5d 串行) | ✅ **同意** | 痛点综合 86%→91%, 4 EPIC 落地 |
| 2 | 派发权 80→90% AI (D3) 推迟 | ✅ **6 EPIC 后拍** | 跟 EKET 节奏, 不抢 Top 4 资源 |
| 3 | 3 模式衍生 6 项推迟 | ✅ **PHASE-007 后拍** | 避免扩面 |
| 4 | 90 extended 5 字段升级推迟 | ✅ **YAGNI 用到再补** | 避免空跑 |
| 5 | Checkpoint 时间旅行 | ✅ **PHASE-007 后拍** (下个 PHASE) | 痛点 2 +10 分, 借鉴 LangGraph 思路 |

主公拍: 同意 Top 4 + 推迟 4 项? 还是其他组合?

---

**Reviewer(s)**: master_main (主公拍板)
**Last updated**: 2026-06-12
**Status**: ✅ SAVED — 等主公战略拍 (Top 4 已派单, 4 推迟项待 PHASE-007 闭环后)

---

**附录**: 关联文件
- [KALLAX-VS-INDUSTRY-2026-06-12.md](./KALLAX-VS-INDUSTRY-2026-06-12.md) (5 痛点 × 业内 4 框架三维对比, 341 行)
- [PROJECT-STATUS-AND-LESSONS-2026-06-12.md](./PROJECT-STATUS-AND-LESSONS-2026-06-12.md) (6 EPIC + 2 PHASE 累积总结)
- [PHASE-006-LAUNCH-2026-06-11.md](./PHASE-006-LAUNCH-2026-06-11.md) (Phase 6 启动, 飞轮"迭代" 阶段)
- [PHASE-005-REVIEW-2026-06-11.md](./PHASE-005-REVIEW-2026-06-11.md) (Phase 5 闭环, 5 升级全完)
- [EKET-BORROW-PROGRESS-2026-06-11.md](./EKET-BORROW-PROGRESS-2026-06-11.md) (EKET 26 项借鉴, P0 9/9 done)
- [cross-epic-kpi-falsification-evolution.md](../memory/lessons/cross-epic-kpi-falsification-evolution.md) (KPI falsification 8 节综合)
- [CLAUDE.md](../../CLAUDE.md) (Rule 1-13 + 9e + 11 v2.1)
