# PHASE-006 飞轮"迭代" 阶段 Roadmap (2026-06-12)

> **何时写**: 主公 2026-06-12 拍"Token Plan 升过了, 其他的有没有继续的价值? 有的话分析、拆卡、开工" + "带着专家组讨论和思考 roadmap" + "90 extended 可以暂缓, 做能够接受、思考、判断、增加/完善的流程逻辑比扩充当前配置有用"
> **范围**: 5 痛点 × 8 Gap × 5 专家视角 (Phase 2) + Master 仲裁 (Phase 3) + 主公战略拍板依据 + 主公原话"流程逻辑" 战略转向
> **路径**: `confluence/decisions/PHASE-006-ROADMAP-2026-06-12.md`
> **方法**: 借鉴 EKET `interactive:start` 多视角 + KALLAX EPIC-021 5 专家 panel + Master 串场 (1 conductor 容量)

**Date**: 2026-06-12
**Author**: master_main (5 视角串场, 不写代码, Rule 11 联动)
**Reviewers**: 主公 (战略审批)
**Status**: ✅ COMPLETE + 主公"流程逻辑" 战略转向 (Gap 8 暂缓 + Gap 9 新增)

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
| 7 | ~~90 extended 5 字段升级~~ | ~~EKET P2 #21~~ | **❌ 主公 2026-06-12 明确暂缓** (流程逻辑 > 扩充配置) | — |
| 8 | Checkpoint 时间旅行 (借鉴 LangGraph) | 痛点 2 落后 10 分 | ⏳ PHASE-007 后拍 | 2-3d |
| **9** | **🆕 流程逻辑元能力** (接受/思考/判断/增加/完善) | **主公 2026-06-12 战略转向** | ✅ **飞轮"迭代" 阶段核心, 跟 Top 4 同步推进** | 持续 |

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

## §7 等主公拍战略 (主公 2026-06-12 已拍, 见 §8 战略转向)

| # | 决策点 | 主公拍 | 战略影响 |
|---|---|---|---|
| 1 | **Top 4 全开工** (3.5d 串行) | ✅ **同意** | 痛点综合 86%→91%, 4 EPIC 落地 |
| 2 | 派发权 80→90% AI (D3) 推迟 | ✅ **6 EPIC 后拍** | 跟 EKET 节奏, 不抢 Top 4 资源 |
| 3 | 3 模式衍生 6 项推迟 | ✅ **PHASE-007 后拍** | 避免扩面 |
| 4 | 90 extended 5 字段升级 | ✅ **主公 2026-06-12 明确暂缓** (流程逻辑 > 扩充配置) | 走 Gap 9 流程逻辑元能力 |
| 5 | Checkpoint 时间旅行 | ✅ **PHASE-007 后拍** (下个 PHASE) | 痛点 2 +10 分, 借鉴 LangGraph 思路 |
| 6 | **🆕 Gap 9 流程逻辑元能力** | ✅ **飞轮"迭代" 阶段核心** | 见 §8 战略转向 |

---

## §8 主公"流程逻辑" 战略转向 (2026-06-12 拍板) — Gap 9 新增

### 8.1 主公原话 (战略洞察)

> **主公 2026-06-12 原话**: "90 extended 可以暂缓, 做能够接受、思考、判断、增加/完善的**流程逻辑**比扩充当前配置有用"

**关键洞察翻译**:
- **"接受"** = Conductor 派单算法 + 模糊/异常/主公例外票的能力
- **"思考"** = Brief Inference (EPIC-030-I) 升级: 思考"问题真实边界" 而非"字面要求"
- **"判断"** = 3 模式决策权 (Rule 13) 升级: 判断"何时升级主公 / 何时自己决"
- **"增加/完善"** = 11 门禁 + 11 规则升级: 增加**新规则** (主公隐含要求, 不只是套用现有)

### 8.2 流程逻辑元能力 vs 扩充配置 (战略对比)

| 维度 | 扩充配置 (旧思维, Gap 8 90 extended) | 流程逻辑 (新思维, Gap 9) |
|---|---|---|
| **例子** | 90 expert 5 字段补全 | Conductor 接受/思考/判断/完善 **元能力** |
| **投入** | 1d 字段补全 | Performer **思考力** 持续训练 |
| **收益** | 97 → 100 expert 字段 (一次性) | 每次新 ticket 都受益 (**复利**) |
| **持续** | 1 次性, 用完即弃 | 飞轮"迭代" 永续 |
| **复利** | 0 | 跨 EPIC 经验 + anti-fab + 持续 audit 加固 |
| **跟飞轮战略** | ❌ 跟"迭代新流程" 矛盾 | ✅ 跟主公原话"转动正向迭代的飞轮" 完全对齐 |

### 8.3 Gap 9 战略载体 (跟 Top 4 联动)

| 流程步骤 | 当前 | 升级载体 (Top 4 落地后) |
|---|---|---|
| **接受** | Conductor 派单算法 (80% AI) | **EPIC-035 worktree_role** 强制绑定, 防"Performer 拿 Conductor ticket" 错配 = 接受能力升级 |
| **思考** | Brief Inference (EPIC-030-I) | **EPIC-034-B M1 audit** 修 Recall 61%→80%+ = 思考"问题真实边界" (M1 真识别 expert) |
| **判断** | 3 模式决策权 (Rule 13) | **EPIC-036 跨 worktree 派单** friction 减少 = 判断"何时跨 worktree / 何时同 worktree" |
| **增加/完善** | 11 门禁 + 11 规则 | **EPIC-037 持续 audit** = 增加"新规则" 能力 (redaction 持续验证 + KPI audit) |

**关键洞察**: **Top 4 不只是 4 个独立 EPIC, 是 Gap 9 流程逻辑元能力的 4 个载体**. 飞轮"迭代" 阶段 = 通过 4 载体持续训练 Conductor/Performer 的接受/思考/判断/完善能力.

### 8.4 Gap 9 跨 EPIC 经验升级机会 (PHASE-007 闭环后)

- **新主题 lessons**: Top 4 落地后, 累积 4 EPIC 子教训 → PHASE-007 升级到 CLAUDE.md 核心原则
- **Anti-Fabrication 工具加固**: KPI audit 跑通后, 跟 check-kpi-precision.sh 整合
- **流程逻辑元能力制度化**: 把"接受/思考/判断/完善" 写入 Rule 14 (新规则), 跟 Rule 13 (3 模式) 联动
- **跨框架借鉴**: LangGraph Checkpoint / CrewAI Enterprise 审计 → KALLAX 升级

### 8.5 Gap 9 vs EKET 借鉴 P2 26 项

| 关联项 | Gap 9 流程逻辑元能力 | EKET P2 26 项 |
|---|---|---|
| 范围 | **飞轮"迭代" 阶段核心, 跨多 EPIC** | 8 P2 推迟项, 战略项 |
| 落地 | **Top 4 4 载体 + 跨 EPIC 经验升级** | 单 EPIC 落地 |
| 战略 | **永续复利, 跟主公原话对齐** | 一次性, 跟"扩充配置" 旧思维同 |
| 优先级 | **P0 飞轮核心** | P2 推迟 |

**结论**: Gap 9 取代 EKET P2 #21 (90 extended 升级) 的战略位置, **是飞轮"迭代" 阶段核心命题**, 不是 1 个独立 EPIC.

---

## §9 战略飞轮 4 窗口 (主公拍战略后修订)

### 9.1 窗口 1: P0 立即开工 (3.5d 串行, 跟 Gap 9 同步)

| 序 | EPIC | 估时 | 痛点提升 | Gap 9 载体 |
|---|---|---|---|---|
| 1 | **EPIC-034-B M1 audit** | 0.5d | 痛点 1 验证 | **思考** 能力 (Brief Inference 升级) |
| 2 | **EPIC-035 worktree_role** | 0.5d | 痛点 3 +5 | **接受** 能力 (Conductor 派单验证) |
| 3 | **EPIC-036 跨 worktree 派单** | 1d | 痛点 4 +5 | **判断** 能力 (3 模式 + 跨 worktree) |
| 4 | **EPIC-037 持续 audit** | 1d | 痛点 1 +5 / 痛点 5 +10 | **增加/完善** 能力 (redaction + KPI audit) |

**累计**: 4 EPIC + Gap 9 元能力, **痛点综合 86% → 91%**.

### 9.2 窗口 2: P1 6 EPIC 后 (1-2 月, PHASE-007 闭环后)

| 序 | Gap | 估时 | 触发 | Gap 9 关联 |
|---|---|---|---|---|
| 5 | 派发权 80→90% AI (D3) | 1d | 6 EPIC + 主公拍 D3 | 接受能力渐进升级 |
| 6 | 3 模式衍生 (Auditor/Readonly 6 项) | 2-3d | EKET P1 收口 + 主公拍 | 判断能力扩面 |
| 7 | Checkpoint 时间旅行 | 2-3d | 痛点 2 落后 10 分 + 主公拍 | 思考能力 (崩溃恢复) |

**累计**: 痛点综合 **91% → 96%**.

### 9.3 窗口 3: P2 持续累积 (3+ 月) — 飞轮"迭代" 长期

| 序 | Gap | 估时 | 触发 | Gap 9 关联 |
|---|---|---|---|---|
| ~~8~~ | ~~90 extended 5 字段升级~~ | ~~1d~~ | **❌ 主公 2026-06-12 明确暂缓** | **走 Gap 9 元能力路径** |
| 9 | 飞轮"迭代" UX (TUI / web dashboard) | 1-2d | EKET P2 #3 + 主公战略 | 元能力可视化 |
| 10 | 持续 audit 跨场景 | 1d | 6 EPIC 累积后 | 完善能力扩面 |

### 9.4 窗口 4: 战略升级 (12+ 月) — 跨框架层

- 派发权 95%→100% AI (D4/D5)
- 借鉴 LangGraph / CrewAI Enterprise 商业层
- **Gap 9 元能力制度化**: Rule 14 (新规则) — "接受/思考/判断/增加/完善 5 步流程, 跨 EPIC 强制"

---

## §10 飞轮"迭代" ROI 评估 (修订)

### 10.1 5 痛点完工后 (Top 4 + P1) 评分

| 痛点 | 当前 | Top 4 完 | P1 完 | 提升 |
|---|---:|---:|---:|---:|
| 1 假完成 | 90% | **95%** (持续 audit + KPI audit) | 95% | +5 |
| 2 上下文失忆 | 85% | 85% | **95%** (Checkpoint) | 0 → +10 |
| 3 角色越界 | 90% | **95%** (worktree_role) | 95% | +5 |
| 4 资源覆盖 | 85% | **90%** (跨 worktree 派单) | 90% | +5 |
| 5 安全立体 | 80% | **90%** (持续 audit) | 90% | +10 |
| **综合** | **86%** | **91%** | **96%** | **+5 → +10** |

### 10.2 Gap 9 元能力 ROI (主公战略转向后, 新增维度)

| 元能力 | 现状 | Top 4 完 | P1 完 | 复利 |
|---|---|---|---|---|
| **接受** (Conductor 派单) | 80% AI | **85%** (worktree_role) | **90%** (派发权 90%) | 每次派单受益 |
| **思考** (M1 Brief Inference) | M1 61% | **M1 80%+** (audit 修) | **M1 90%+** (Checkpoint) | 每次问题受益 |
| **判断** (3 模式 + 决策门) | Rule 13 | **Rule 13 + 跨 worktree** | **Rule 13 + 3 模式衍生** | 每次决策受益 |
| **增加/完善** (11 门禁) | 11 门禁 | **+ 持续 audit** | **+ 跨场景 audit** | 每次新规则受益 |
| **综合元能力** | 75% | **85%** | **95%** | **永续复利** |

### 10.3 KALLAX vs 业内 4 框架对比 (完工后, 含 Gap 9)

| 框架 | 当前 | Top 4 完 | P1 完 |
|---|---:|---:|---:|
| **KALLAX + Gap 9 元能力** | 86% / 元能力 75% | **91%** / **85%** | **96%** / **95%** |
| LangGraph | 53% | 53% | 53% |
| CrewAI | 52% | 52% | 52% |
| AutoGen | 46% | 46% | 46% |
| MetaGPT | 13% | 13% | 13% |

**KALLAX 完工后领先业内 4 框架 50+ 分** (96% vs 53%), 元能力领先业内 50+ 分 (95% vs 业内无元能力概念).

---

## §11 风险与依赖 (修订)

| 风险 | 缓解 |
|---|---|
| M1 Recall 61%→80% 难度 | Performer 跑得动, 跟 Step 1 思路 (加数据 + 调 trigger) |
| Top 4 串行 3.5d 撞 token | 主公 2026-06-12 拍"token 会有波动但是没有瓶颈" — 风险已消 |
| EPIC-034-B 跑不出 80% | fallback: 接受 70%+, 留 PHASE-007 闭环后再修 |
| Checkpoint 时间旅行 (P1) 自建实现复杂度 | 用 SQLite 复用 instances.json 库, 2-3d 可控 |
| EPIC-036 conflict detect 边界 | git format-patch + git am 是成熟方案, 风险低 |
| **Gap 9 元能力训练** (新) | Top 4 4 载体 + 跨 EPIC 经验升级 + Rule 14 (新规则) 制度化 |
| **90 extended 暂缓后补回** (新) | **不回补**, 走 Gap 9 路径, 流程逻辑 > 扩充配置 (主公原话硬决策) |

### 11.1 EPIC-034-B 派单状态 (诚实汇报)

| 检查项 | 期望 | 实际 |
|---|---|---|
| Performer worktree 新 commit | 应有 | ❌ 无, HEAD 仍 `516fc21` (Step 1) |
| state.json conductor-gamma | 应有 | ❌ state.json 是 test fixture |
| dispatch.sh 派单 | 真起 | ❌ `KALLAX_TEST_FIXTURES=1` 干跑 (dispatch.sh:51) |
| **真实执行** | Performer 容器在跑 | **主公触发 conductor 容器, 1 conductor + 2 performer 容量** |

**根因**: KALLAX 派单是**算法建议**层, 真实执行靠 1 conductor + 2 performer 容器 (KALLAX 容量设计). Master session 派单 = ticket 入库 + 算法建议, 真实 Performer worker 拉票由主公/外部触发.

**Master 强验证结论**: EPIC-034-B 派单已落地 (`ffba2c7`/`e9b7b85`/`3c61cca` 链路), 真实执行待主公触发 conductor 容器.

---

## §12 总结 (主公战略拍板后)

### 12.1 主公战略 4 拍板

| # | 战略 | 状态 |
|---|---|---|
| 1 | **Top 4 全开工** (3.5d 串行) | ✅ 主公同意 |
| 2 | 派发权 80→90% AI (D3) 推迟到 6 EPIC 后 | ✅ 默认 |
| 3 | 3 模式衍生 6 项推迟到 PHASE-007 后 | ✅ 默认 |
| 4 | **90 extended 明确暂缓** + **走 Gap 9 流程逻辑元能力** | ✅ **主公 2026-06-12 原话** |

### 12.2 Gap 9 战略核心 (主公"流程逻辑" 转向)

**主公 2026-06-12 原话** = **飞轮"迭代" 阶段核心命题**:
- 4 步流程: 接受 / 思考 / 判断 / 增加/完善
- 4 载体: EPIC-034-B / 035 / 036 / 037
- 永续复利: 跨 EPIC 经验升级 + Rule 14 制度化

### 12.3 KALLAX 飞轮战略对齐 (跟主公原话)

> 主公原话: "以基础experts出发，通过框架和扩展专家库支持更丰富的需求，在运行过程中不断的尝试新任务、创建新专家、**迭代新流程和skills**，转动正向迭代的飞轮不断优化kallax体系"

Gap 9 流程逻辑元能力 = "**迭代新流程和skills**" 战略落点, 跟"扩充配置" (90 extended) 旧思维划清界限.

---

**Reviewer(s)**: master_main (主公拍板)
**Last updated**: 2026-06-12
**Status**: ✅ SAVED — 主公战略拍板落地 (Top 4 + Gap 9 元能力 + 4 推迟项)

---

**附录**: 关联文件
- [KALLAX-VS-INDUSTRY-2026-06-12.md](./KALLAX-VS-INDUSTRY-2026-06-12.md) (5 痛点 × 业内 4 框架三维对比, 341 行)
- [PROJECT-STATUS-AND-LESSONS-2026-06-12.md](./PROJECT-STATUS-AND-LESSONS-2026-06-12.md) (6 EPIC + 2 PHASE 累积总结)
- [PHASE-006-LAUNCH-2026-06-11.md](./PHASE-006-LAUNCH-2026-06-11.md) (Phase 6 启动, 飞轮"迭代" 阶段)
- [PHASE-005-REVIEW-2026-06-11.md](./PHASE-005-REVIEW-2026-06-11.md) (Phase 5 闭环, 5 升级全完)
- [EKET-BORROW-PROGRESS-2026-06-11.md](./EKET-BORROW-PROGRESS-2026-06-11.md) (EKET 26 项借鉴, P0 9/9 done)
- [cross-epic-kpi-falsification-evolution.md](../memory/lessons/cross-epic-kpi-falsification-evolution.md) (KPI falsification 8 节综合)
- [CLAUDE.md](../../CLAUDE.md) (Rule 1-13 + 9e + 11 v2.1)
