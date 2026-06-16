# EPIC-056-A IMPLEMENTATION PLAN — 5 阶段治理 → 3 阶段 (治 A4 治理爆炸)

> **Ticket**: EPIC-056-A (5 张治理卡 之一)
> **Phase**: PHASE-009
> **Performer**: performer-EPIC-056-A
> **Date**: 2026-06-17
> **Status**: DRAFT (TDD red → green cycle)
> **Blocked By**: EPIC-055-B ✅ DONE (commit `2b4771c`)

---

## 1. 范围与边界 (跟 file_scope 严格联合)

**可改 (4 创建 + 2 改 + 2 ticket 文档)**:
- `jira/tickets/EPIC-056-A/` (实现记录)
- `docs/PROCESS.md` (改, Subagent 流程 15 步 → 10 步)
- `.claude/skills/kallax/SKILL.md` (改, Expert Panel 3 阶段描述)
- `node/src/core/gate-reviewer.ts` (扩展, 3 阶段协调器 — 4-Level 逻辑保留)
- `tests/integration/governance-3phase-test.sh` (新文件, TDD 6 case)

**不可改 (越界即 BE)**:
- `CLAUDE.md` (跟 EPIC-054-D 边界, Rule 数量更新)
- `docs/STRUCTURE.md` (跟 EPIC-055-A 边界)
- `docs/KALLAX-GLOSSARY.md` (跟 EPIC-055-A 边界)
- `docs/process/approval-tiering.md` (跟 EPIC-055-B 边界, 不动 — 但本 ticket 引用其 P0/P1/P2 路由)
- `docs/process/A-B-REVIEW.md` (跟 EPIC-055-B 边界, 5 扩展组定义不重做)
- 其他 EPIC ticket (跟 EPIC-053/054/055 边界)
- `node/src/core/process-metrics.ts` (跟 EPIC-056-B 边界, KPI 闭环)
- `node/src/core/dispatch-dashboard.ts` (跟 EPIC-053-D 边界)

---

## 2. AC 7 条 (跟 ticket.json `acceptance_criteria` 一致)

1. **5→3 阶段**: (1) Conductor 全局扫描 (原 Architect + Conductor 合并) → (2) 4 专家并行 + 5 扩展 (保留) → (3) Master 仲裁 + 主公拍板
2. **`docs/PROCESS.md` 15 步 → 10 步**, 跟"流程效果 > 流程表演" 联合
3. **`.claude/skills/kallax/SKILL.md` 3 阶段描述** (而非原 5 阶段)
4. **`node/src/core/gate-reviewer.ts` 3 阶段协调器** (Conductor → 4 expert + 5 ext → Master+主公)
5. **A4 治根** — 10 专家 协调开销爆炸 闭环, 跟净价值 62.5% (-5% 恶化) 联合
6. **`governance-3phase-test.sh` 6/6 PASS**
7. **Rule 9 KPI X/Y 格式** — 6/6 PASS = 100.0%

---

## 3. 3 阶段设计 (跟 v1.2.4 5 扩展组 保留, 跟 055-B 拍板分级 联动)

### Phase 1: Conductor 全局扫描 (原 Architect + Conductor 合并)

**合并理由** (A4 治根):
- 原 Phase 1 (Architect 全局扫描) + 原 Conductor 汇总 = **同一职责** (全局视角, 不深入实现细节)
- Architect 跟 Conductor 协调开销: 1 Architect 评估 → 1 Conductor 转述 → 主公 review → Conductor 重新 review
- **合并后**: Conductor 直接出全局扫描报告, 减少 1 次转述 + 1 次协调

**输出**:
- 1 份 Conductor 全局扫描报告 (含架构/边界/选型/重构 视角, 原 Architect 能力)
- 主公 review 时 1 次拍板即可, 不再"Architect 报告 → Conductor 复述" 二次成本

**人天估算** (净价值提升):
- 旧: 0.5h (Architect) + 0.3h (Conductor 复述) = 0.8h
- 新: 0.4h (Conductor 直接出) = 0.4h
- 节省: 0.4h/ticket × 12 ticket = 4.8h/期

### Phase 2: 4 专家并行 + 5 扩展 (保留, 0 增 0 删)

**保留 4 default 专家** (跟 v1.2.4 5 default 一致, Architect 退出):
- 💻 Backend — API/数据库/性能
- 🎨 Frontend — 组件/渲染/LCP
- 🖌️ UX — 交互/旅程
- 📋 Product — 优先级/价值/ROI

**保留 5 extended 专家** (跟 v1.2.4 5 扩展组 联合, 0 增 0 删):
- 🛡️ security-tool-bypass (Rule 29 治根因 1)
- ⚙️ process-engineering (Rule 30 治根因 2)
- 🔍 auditor (Rule 31 治根因 3)
- 📜 compliance (Rule 32 治根因 4)
- 🚦 decision-gate (Rule 33 治根因 5)

**并行执行**:
- 4 + 5 = 9 专家 并行 (Node.js `Promise.all` 调度)
- 协调开销: 0 (per-subagent 独立 worktree, 跟 Rule 15 隔离 联合)

**输出**: 9 份专家报告 (4 default + 5 extended)

### Phase 3: Master 仲裁 + 主公拍板 (跟 055-B 3 级路由 联动)

**Master 仲裁**:
- Master 收 9 份报告 → 合并去重 → 仲裁冲突 → 出"汇总报告 + 建议"
- Master 强验证 6 维度 (Rule 11 v2.1 联合)
- 失败 → 退回 Performer 修 (跟 v1.2.4 流程 一致)

**主公拍板** (跟 EPIC-055-B 拍板分级 联动):
- **P0 战略红线** (R-NEW 升级/Rule 撤销/治理升级) → 阻塞 + 写 REQUEST-P0-*.md
- **P1 流程升级** (Tier 1/2 ticket/Rule 合并/阶段变更) → 备案 + 写 RECORD-P1-*.md
- **P2 操作** (Tier 3 chore/docs/单文件改动) → 放手 + 写 p2-log-*.jsonl

**拍板后**:
- PASS → Conductor merge (Rule 1 联合)
- FAIL → 退回 Performer 修 (跟 v1.2.4 流程 一致)

---

## 4. 15 步 → 10 步 流程改造 (跟 Rule 9 X/Y 格式 联合)

**旧 15 步** (PROCESS.md:38-53):
1. 拆 worktree
2. 加载目标 ticket
3. 加载目标专家 profile
4. 深度分析
5. 写执行计划
6. TDD 写测试
7. 写代码
8. 跑全套测试
9. A 组正向 review
10. B 组逆袭 review
11. 写 LESSONS-LEARNED
12. 报 PASS
13. Master 强验证 6 维度
14. PASS → Conductor merge
15. FAIL → 退回 Performer

**新 10 步** (合并 + 删表演步骤):
1. **拆 worktree + 加载 ticket** (合并 1+2)
2. **加载 目标专家 profile + 深度分析** (合并 3+4)
3. **Phase 1 Conductor 全局扫描** (3 阶段第 1 步, 跟旧 Step 5 写计划合并)
4. **写 执行计划** (TDD 入口)
5. **TDD 写测试 + 写代码** (合并 6+7, 跟"流程效果 > 流程表演" 联合)
6. **跑 全套测试** (L3+L4 联合)
7. **Phase 2: 4 专家并行 + 5 扩展 review** (合并 9+10, A+B 合并为并行 9 专家)
8. **Phase 3: Master 仲裁 + 写 LESSONS-LEARNED** (合并 11+13)
9. **报 PASS** (跟 055-B 拍板分级 联动, 写 pass-report)
10. **Conductor merge / 退回修** (合并 14+15)

**节省步数**: 5 步 (15 → 10), 净价值估算 62.5% → 65%+ (跟 EPIC-056-B 3 KPI 联动)

---

## 5. 实施步骤 (15 步 Subagent 流程)

**Step 1-2**: ✅ 验证 worktree + 读 ticket (Done)
**Step 3**: 加载 backend expert profile (本 ticket 不调用, 但实现 backend gate-reviewer.ts)
**Step 4**: ✅ 深度分析 5 文件 (Done)
**Step 5**: ✅ 写 IMPLEMENTATION-PLAN.md (本文件)
**Step 6**: TDD 写测试 — `tests/integration/governance-3phase-test.sh` 6 case
**Step 7**: 写实现 — 3 件事 (PROCESS.md 改, SKILL.md 改, gate-reviewer.ts 扩展)
**Step 8**: 跑测试 — 6/6 PASS
**Step 11**: 写 LESSONS-LEARNED.md
**Step 12**: 报 PASS — 写 pass-report JSON
**Step 9-10-13-14-15**: 跳 (新 10 步流程已合并)

---

## 6. 测试设计 (6 TC)

**TC1**: Phase 1 Conductor 全局扫描 (原 Architect 合并)
- 验证: gate-reviewer.ts 暴露 `phase1ConductorScan()` 函数
- 验证: 输出 "Phase 1: Conductor 全局扫描" + "Architect 合并" 标记

**TC2**: Phase 2 4 专家并行 (Architect 退出, Backend/Frontend/UX/Product 保留)
- 验证: gate-reviewer.ts 暴露 `phase2ExpertPanel()` 函数
- 验证: 4 default 专家列表 (Backend/Frontend/UX/Product) 不含 Architect

**TC3**: Phase 2 5 扩展组保留 (security/process-eng/auditor/compliance/decision-gate)
- 验证: 5 扩展组名称完整保留
- 验证: 0 增 0 删 (跟 v1.2.4 一致)

**TC4**: Phase 3 Master 仲裁
- 验证: gate-reviewer.ts 暴露 `phase3MasterArbitration()` 函数
- 验证: Master 收 9 报告 → 出汇总

**TC5**: Phase 3 主公拍板 (跟 055-B 3 级路由 联动)
- 验证: P0 阻塞 / P1 备案 / P2 放手 三路由 (引用 approval-tiering.sh 的 route_p0/p1/p2)

**TC6**: 集成 — 3 阶段全流程跑通
- 验证: `runGovernance3Phase()` 顺序执行 3 阶段
- 验证: 净价值 62.5% → 65%+ (跟 EPIC-056-B 3 KPI 联动, 估算 +2.5%)

---

## 7. 跟 5 张治理卡 联动 (跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合)

```
EPIC-055-B (主公拍板分级) ✅ DONE
    ├── EPIC-054-D (Rule 合并扫描, 需 055-B 落地) — 联动
    ├── EPIC-056-A (本 ticket — 5→3 阶段, 需 055-B 落地) ✅ unblocked
    └── EPIC-056-C (Master 6 维恢复, 需 055-B 落地) — 联动

EPIC-056-B (流程效果度量, 独立) — 跟本 ticket KPI 闭环
```

**联动**:
- ✅ EPIC-055-B: Phase 3 主公拍板用 route_p0/p1/p2 (跟 PROCESS.md:25-26 联合)
- ✅ EPIC-056-B: 净价值 62.5% → 65%+ 跟 3 KPI 闭环
- ⚠️ EPIC-054-D: Rule 合并扫描跟本 ticket 0 增 0 删专家 联合
- ⚠️ EPIC-056-C: Master 强验证 6 维度恢复跟本 ticket Phase 3 仲裁 联合

---

## 8. 验收清单 (跟 7 AC 一致)

| AC | 验证方法 | 状态 |
|---|---|---|
| 1 | 3 阶段设计 + gate-reviewer.ts 函数 | ⏳ |
| 2 | PROCESS.md 15→10 步 | ⏳ |
| 3 | SKILL.md 3 阶段描述 | ⏳ |
| 4 | gate-reviewer.ts 3 阶段协调器 | ⏳ |
| 5 | A4 治根闭环 (跟 056-B KPI 联动) | ⏳ |
| 6 | governance-3phase-test.sh 6/6 PASS | ⏳ |
| 7 | Rule 9 X/Y 格式 6/6 = 100.0% | ⏳ |

---

**跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 EPIC-055-B approval-tiering.md 联合, 跟 EPIC-056-B metrics-kpi.md 联合, 跟 v1.2.4 5 扩展组 联合, 跟 Rule 9 X/Y 格式 联合, 跟 Rule 11 v2.1 强验证 联合, 跟 Rule 15 隔离 联合, 跟"流程效果 > 流程表演" 战略 一致, 跟"诚实修正" 联合**
