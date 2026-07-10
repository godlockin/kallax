# EKET 借鉴总进度表

> **目的**: EKET 5 视角对比报告 P0/P1/P2 26 项借鉴落地进度追踪
> **日期**: 2026-06-11
> **来源**: PHASE-005 升级 4 (2026-06-11 决定补落地)
> **作者**: master (Phase 5 review)
> **状态**: ACTIVE

---

## §1 EKET 借鉴总览

### 1.1 5 视角对比报告来源

| 视角 | 借鉴来源 | EPIC |
|---|---|---|
| Conductor | Conductor §5.1 (TrustScore/scoring_trace) + §5.3 (waiting) | EPIC-030 / EPIC-031 |
| Performer | Performer §5.1 (Brief Inference) + §5.4 (Hook Profile) + §5.5 (PR Size) | EPIC-030 |
| UX | UX §5.2 (system:doctor JSON) | EPIC-030 |
| Security | Security §5.2 (AuditMiddleware) | EPIC-030 |
| Architect | EPIC-021 §3.1 (persona 字段) | EPIC-030 |

### 1.2 EPIC-021 12 共识超越点

EPIC-021 5 专家 panel 分析 EKET, 12 共识点:
1. KALLAX 7 expert 体系 vs EKET 强
2. 2-Group review vs EKET 自审
3. 5-Level Fact-Forcing vs EKET 2-Level
4. heartbeat 机制 vs EKET 定时
5. file-scope 隔离 vs EKET workspace
6. TrustScore 派发 vs EKET 轮询
7. 降级链 (Redis→SQLite→file) vs EKET Redis-only
8. A+B review 互补 vs EKET 单视角
9. 症状决策树 vs EKET keyword match
10. output_format 4 节 vs EKET 2 节
11. anatomy10 项校验 vs EKET 7 项
12. M1 co-evolution vs EKET 静态

---

## §2 26 项借鉴进度表

### 2.1 P0 9 项 (全部完成 ✅)

| # | 借鉴项 | 来源 |落地 EPIC | 落地时间 | commit | 状态 |
|---|---|---|---|---|---|---|
| 1 | TrustScore 三层匹配 + 向量 cosine | Conductor §5.1 | EPIC-030-A | 2026-06-11 | miao `3364556` | ✅ done |
| 2 | scoring_trace.jsonl 每日轮转 | Conductor §5.1 | EPIC-030-B | 2026-06-11 | miao `3364556` | ✅ done |
| 3 | waiting-for-expert 自动降级 | Conductor §5.3 | EPIC-030-C | 2026-06-11 | miao `3364556` | ✅ done |
| 4 | Hook Profile 三档 minimal/standard/strict | Performer §5.4 | EPIC-030-D | 2026-06-11 | miao `3364556` | ✅ done |
| 5 | PR Size self-test fixture | Performer §5.5 | EPIC-030-E | 2026-06-11 | miao `3364556` | ✅ done |
| 6 | system:doctor JSON 结构化 | UX §5.2 | EPIC-030-F | 2026-06-11 | miao `3364556` | ✅ done |
| 7 | AuditMiddleware audit_log 新 SQLite | Security §5.2 | EPIC-030-G | 2026-06-11 | miao `3364556` | ✅ done |
| 8 | KALLAX persona 5 字段 (7 default) | EPIC-021 §3.1 | EPIC-030-H | 2026-06-11 | miao `3364556` | ✅ done |
| 9 | Brief Inference 任务理解强制 | Performer §5.1 | EPIC-030-I | 2026-06-11 | miao `3364556` | ✅ done |

**P0 总结**: 9/9 done ✅,全部落地 EPIC-030, miao `3364556`

### 2.2 P1 8 项 (1/8 完成 ⚠️)

| # | 借鉴项 | 来源 | 落地 EPIC | 落地时间 | commit | 状态 |
|---|---|---|---|---|---|---|
| 10 | M1 co-evolution 50 test case | Product 视角 | — | — | — | ⏳ pending |
| 11 | TrustScore 派发权让渡 (60% AI + 40% 人工) | EPIC-021 超越点6 | EPIC-031 | 2026-06-11 | miao `8314956` | ✅ done |
| 12 | Ekalax Token Plan 升级 (5h → 8h) | Conductor 容量 | — | — | — | ⏳ pending |
| 13 | 3 模式决策权 (ai-auto/ai-copilot/manual) | EPIC-029 A1 | EPIC-029 |2026-06-09~15 | EPIC-029 active | ⏳ in progress |
| 14 | Performer 5 阶段协商 (stage-gate) | Performer §2.2 | EPIC-029 | 2026-06-09~15 | EPIC-029 active | ⏳ in progress |
| 15 | 危险操作统一检查 (decision-gate) | Security §4 | EPIC-029 | 2026-06-09~15 | EPIC-029 active | ⏳ in progress |
| 16 | worktree_role 强制绑定 | EPIC-021 治理 | — | — | — | ⏳ pending |
| 17 | 2-Group review 强制 (A+B) | EPIC-021 治理 | — | — | — | ⏳ pending |

**P1 总结**: 1/8 done (TrustScore 派发权让渡), 7/8 pending/in-progress

### 2.3 P2 8 项 (0/8 完成, 推迟)

| # | 借鉴项 | 来源 | 落地 EPIC | 落地时间 | commit | 状态 |
|---|---|---|---|---|---|---|
| 18 | 3 anti-fab self-test (test-case-isolation / kpi-precision / scope-creep) | Performer §5.4 | — | — | — | ⏳ postponed |
| 19 | 3 模式 6 衍生 (Auditor mode / Readonly mode / 模式 + 工作流) | EPIC-029 衍生 | — | — | — | ⏳ postponed |
| 20 | M1 co-evolution 扩 200+ test case (data + legal 场景) | Product 视角 | — | — | — | ⏳ postponed |
| 21 | 90 extended expert persona 完善 | EPIC-021 §3.1 | — | — | — | ⏳ postponed |
| 22 | Redis-less降级链 (SQLite → file only) | Architect | — | — | — | ⏳ postponed |
| 23 | cross-repo migration plan | Security | — | — | — | ⏳ postponed |
| 24 | audit append-only 实现 | Security | — | — | — | ⏳ postponed |
| 25 | workspace isolation v2 (immutable record) | EPIC-022 | — | — | — | ⏳ postponed |
| 26 | cross-role audit (F5) | EPIC-022 | — | — | — | ⏳ postponed |

**P2 总结**: 0/8 done, 全部推迟到长期规划

---

## §3 跨 EPIC 经验沉淀

### 3.1 5 主题 lessons (综合主题来源)

| 主题 | EPIC | 关键教训 |
|---|---|---|
| three-modes-decision-authority | EPIC-029 | 派发权让渡 = 算法骨架 + 人工拍板 |
| security-hardening-iterations | EPIC-029/030 | 安全审查 3 轮叠加 (20 issue) |
| token-plan-cap-incident | EPIC-029 | Token Plan 限撞墙 + 容量 |
| performer-kpi-falsification-pattern | EPIC-031 | KPI falsification 4 次演化 |
| cross-epic-kpi-falsification-evolution | PHASE-005 | 综合 4 主题, 单一入口 |

### 3.2 Phase 5 review产出

| 产出 | 描述 | 关联 |
|---|---|---|
| PHASE-005-REVIEW-2026-06-11.md | Phase 5 完整完成 review | §1-§16 |
| cross-epic-kpi-falsification-evolution.md | 综合主题 | 整合 4 主题 |
| EKET-BORROW-PROGRESS-2026-06-11.md | 借鉴进度表 | 本文件 |

---

## §4 下一步 (待决策)

### 4.1 P1 7剩项处理

| # | 剩项 | 建议 EPIC | 估时 | 优先级 |
|---|---|---|---|---|
| 10 | M1 co-evolution 50 test case | EPIC-032 | 1d | P0 |
| 12 | Ekalax Token Plan 升级 | 长期规划 | TBD | P1 |
| 14 | Performer 5 阶段协商 | EPIC-029 收口 | 0.5d | P0 |
| 15 | 危险操作统一检查 | EPIC-029 收口 | 0.5d | P0 |
| 16 | worktree_role 强制绑定 | 新 EPIC |0.5d | P1 |
| 17 | 2-Group review 强制 | Rule 升级 | 0.25d | P0 |

**建议**: 拆 EPIC-033/034, 跟飞轮"迭代"阶段衔接

### 4.2 P2 8 项处理

| # | P2 项 | 建议 |
|---|---|---|
| 18 | 3 anti-fab self-test | 推迟, 跟 Rule 9d 一起 |
| 19 | 3 模式 6 衍生 | 推迟, EPIC-032 |
| 20 | M1 扩 200+ test case | 推迟, Phase 6 |
| 21 | 90 extended expert | 推迟, 用到时再完善 |
| 22 | Redis-less降级链 | 推迟, 长期规划 |
| 23 | cross-repo migration | 推迟, Security review |
| 24 | audit append-only | 推迟, EPIC-022 |
| 25-26 | workspace isolation v2 / cross-role audit | 推迟, EPIC-022 |

**建议**: P2 8 项全推迟到长期规划, 不进飞轮"迭代"

### 4.3 决策点

| 决策点 | 选项 |
|---|---|
| P1 7 剩项何时落地 | A. EPIC-033/034 串行; B. 配合 EPIC-032 并行; C. 推迟 |
| P2 8 项处理 | A. 全推迟; B. 部分提前; C. 长期规划 |

---

## §5 进度统计

### 5.1 总体进度

| 类别 | 总数 | 完成 | 进行中 | 待处理 | 完成率 |
|---|---|---|---|---|---|
| P0 | 9 | 9 | 0 | 0 | **100%** ✅ |
| P1 | 8 | 1 | 3 | 4 | **12.5%** ⚠️ |
| P2 | 8 | 0 | 0 | 8 | **0%** ⏳ |
| **合计** | **26** | **10** | **3** | **13** | **38.5%** |

**进度摘要**: P0 9/9 done ✅ | P1 1/8 done ⚠️ | P2 0/8 ⏳

### 5.2 进度可视化

```
P0: [████████████████████] 9/9 100% ✅
P1: [██░░░░░░░░░░░░░░░░] 1/8 12.5% ⚠️
P2: [░░░░░░░░░░░░░░░░░░] 0/8 0% ⏳
```

---

## §6 关联文档

| 文档 | 描述 |
|---|---|
| `confluence/decisions/PHASE-005-REVIEW-2026-06-11.md` | Phase 5 review (本进度表来源) |
| `jira/epics/EPIC-030/epic.json` | EPIC-030 EKET P0 借鉴 9 项 |
| `jira/epics/EPIC-031/epic.json` | EPIC-031 TrustScore 落地 |
| `jira/epics/EPIC-029/epic.json` | EPIC-029 3 模式决策权 |
| `jira/epics/EPIC-021/epic.json` | EPIC-021 战略 12 超越点 |
| `docs/superpowers/plans/2026-06-11-kallax-eket-borrow-p0.md` | EKET P0 实施计划 |
| `confluence/memory/lessons/cross-epic-kpi-falsification-evolution.md` | 综合主题 lessons |

---

**维护者**: master (2026-06-11 确认)
**最后更新**: 2026-06-11
**下次 review**: Phase 6 (新 EPIC 启动后)