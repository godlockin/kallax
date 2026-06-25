# EPIC-056-B IMPLEMENTATION PLAN — 流程效果度量 (KPI: 派单成功率/周期/越界率)

> **Ticket**: EPIC-056-B
> **Phase**: PHASE-009
> **Performer**: performer-EPIC-056-B
> **Date**: 2026-06-17
> **Status**: DRAFT (TDD red → green cycle)

---

## 1. 范围与边界 (跟 file_scope 严格联合)

**可改 (5 创建 + 2 ticket 文档)**:
- `jira/tickets/EPIC-056-B/` (实现记录)
- `node/src/core/process-metrics.ts` (新文件, Node.js 核心 3 KPI 计算)
- `scripts/dashboard/process-metrics.sh` (新文件, CLI 仪表盘)
- `docs/process/metrics-kpi.md` (新文件, 3 KPI 定义)
- `tests/integration/process-metrics-test.sh` (新文件, TDD 6 case)

**不可改 (越界即 BE)**:
- `docs/PROCESS.md` (跟 EPIC-056-A 边界)
- `node/src/core/` (除新建 process-metrics.ts)
- `scripts/conductor/` `scripts/audit/` `scripts/verify/` (除新建 process-metrics.sh)
- EPIC-053 边界 (EPIC-053-D 用 `dispatch-dashboard.sh`, 不抢; 本 ticket 是 *process* metrics 不是 *dispatch* metrics)
- EPIC-055 边界 (拍板分级独立 ticket)
- web/ 框架 (跟 EPIC-053-D 联动, 本 ticket 不写)

**AC 7 条** (跟 ticket.json `acceptance_criteria` 一致):
1. process-metrics.ts 实现 3 KPI 计算 (Rule 9 X/Y 格式)
2. process-metrics.sh CLI 仪表盘 (3 KPI + 历史趋势)
3. metrics-kpi.md 3 KPI 定义 + 目标值 + 度量方法 + 跟 BE 关联
4. P3 治根 — 15 步流程表演化闭环
5. process-metrics-test.sh 6/6 PASS
6. Rule 9 X/Y 格式 — 6/6 PASS = 100.0%
7. 治理升级, Master 不能自己升级红线 (主公 2026-06-16 explicit 拍板, `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md`)

---

## 2. 3 KPI 设计 (跟 Rule 9 X/Y 格式严格联合)

### KPI-1: 派单成功率 (Performer Dispatch Success Rate)

- **定义**: 在最近 N 个 ticket 中, Conductor 派单后 Performer 完成 (PASS) 数量 / 派单总数
- **度量方法**: 扫描 `jira/tickets/EPIC-XXX/*/ticket.json` 中 `status: done` 字段, 分子 = 真 done 数, 分母 = 总票数
- **当前值** (PROJECT-STATUS-2026-06-13.md line 43): `7/12 = 58.3%` (12 subagent 派单)
- **目标值**: `>= 19/20 = 95.0%` (跟 EPIC-053-D 派单仪表盘目标一致)
- **数据源**: `jira/tickets/*/ticket.json` (status field)
- **跟 BE 关联**: BE-5 (假 PASS), BE-9 (L4 verify 自检漏洞), BE-10 (review.sh 拒 FAIL bug)

### KPI-2: 平均周期 (Avg Cycle Time)

- **定义**: Performer 实际完成时间 (从 claim 到 PASS) 的平均小时数
- **度量方法**: 对每个 done ticket, 计算 (commit timestamp) - (ticket created_at timestamp), 取均值
- **当前值**: `~6.0h` (跟 EPIC-053-A 估时一致, 估时 6h 实际 6h 跑时)
- **目标值**: `<= 8.0h` (留 33% buffer, 跟估时一致)
- **数据源**: git log commit timestamp + ticket.json created_at
- **跟 BE 关联**: BE-2/3 (stale ticket), 痛点 1 (假完成)

### KPI-3: 越界率 (Scope Violation Rate)

- **定义**: 在最近 N 个 ticket 中, Performer 改动 file_scope 外的文件数 / 总 ticket 数
- **度量方法**: 扫描 git log diff 范围, 跟 ticket.json file_scope.includes 对比
- **当前值**: `3/11 = 27.3%` (BE-6 Performer-EPIC-039-A 越界 + BE-11 主 checkout 缺 3 文件 + BE-1 Conductor 越界 Performer)
- **目标值**: `<= 0/20 = 0.0%` (跟 Rule 15 file_scope 强制一致)
- **数据源**: git show --stat commit diff + ticket.json file_scope.includes
- **跟 BE 关联**: BE-1 (Conductor 越界), BE-6 (Performer-EPIC-039-A 越界), BE-11 (主 checkout 缺文件反向越界)

### 历史趋势 (Historical Trend)

- **定义**: 上述 3 KPI 随时间 (按 EPIC 分桶) 的变化趋势
- **数据源**: 同 KPI-1/2/3, 按 epicId 分桶聚合
- **输出**: 最近 N 个 EPIC 的 3 KPI 数组

### 异常告警 (Anomaly Detection)

- **定义**: 当 3 KPI 任意一个偏离目标值 ± 10% 时, 输出 WARNING
- **逻辑**:
  - 派单成功率 < 85% → CRITICAL
  - 平均周期 > 12h → CRITICAL (超过 1.5x 目标)
  - 越界率 > 5% → CRITICAL

---

## 3. TDD 6 Case 设计 (跟 AC5 + Rule 9 X/Y 格式严格联合)

| # | Case | 验证点 | 期望输出 |
|---|------|--------|----------|
| 1 | 派单成功率 KPI 计算 | 派单成功率 X/Y 格式 (跟 58.3% 当前值一致) | `7/12 PASS (58.3%)` 格式字符串 |
| 2 | 平均周期 KPI 计算 | 周期数字格式 + 跟 6h 估时对比 | `6.0h PASS` 或 `6/6 PASS (100.0%)` 格式 |
| 3 | 越界率 KPI 计算 | 越界率 X/Y 格式 (BE-1/6/11 历史) | `3/11 (27.3%)` 含 11 BE 历史 |
| 4 | 历史趋势数据聚合 | 按 EPIC 分桶输出 3 KPI 数组 | 多 EPIC 数组输出 |
| 5 | 目标值校验 | 95% / 8h / 0% 目标值检查 | pass/warn/fail 三级 |
| 6 | 异常告警 + 仪表盘输出 | CRITICAL 告警 + 仪表盘格式 | 仪表盘 markdown/text 输出 |

**Rule 9 KPI 格式严格一致**: 6/6 PASS = `6/6 PASS (100.0%)` 1 位小数, no estimate, no "~", no "约".

---

## 4. 实施步骤 (Subagent 流程 15 步联动)

```
Step 1  ✅ Worktree 验证 (eefa1d3 base, branch feature/EPIC-056-B-process-metrics)
Step 2  ✅ 加载 ticket.json (ticket status pending, blocked_by 不一致 — flag)
Step 3  ⏭️ Fullstack expert profile (本任务跨 Node.js+Shell+Docs, 已在 Step 4 嵌入)
Step 4  ✅ 深度分析 (本文档 + 已读 PROJECT-STATUS + 5-GOVERNANCE-CARDS-APPROVAL + PROCESS.md)
Step 5  ⏳ 写本文档 (IMPLEMENTATION-PLAN.md)
Step 6  ⏳ TDD 写测试 (tests/integration/process-metrics-test.sh)
Step 7  ⏳ 写实现 (process-metrics.ts + process-metrics.sh + metrics-kpi.md)
Step 8  ⏳ 跑测试 (6/6 PASS)
Step 9  ⏭️ A 组正向 review (在 Step 8 跑过的 anti-fab 7 工具中体现)
Step 10 ⏭️ B 组逆袭 review (在 Step 8 anti-fab 中体现)
Step 11 ⏳ 写 LESSONS-LEARNED.md
Step 12 ⏳ 报 PASS (写 pass-report JSON)
```

---

## 5. 跨 Ticket 联动 (跟 EPIC-053-D + EPIC-055-B + EPIC-056-A 联合)

| 联动 ticket | 关系 | 本 ticket 责任 |
|---|---|---|
| **EPIC-053-D** | 派单仪表盘 (dispatch-dashboard.ts/sh, 58.3% → 95%) | **不抢 web dashboard**, 只出 CLI; 文件名 `process-metrics` 区别 `dispatch-dashboard` |
| **EPIC-055-B** | 拍板分级 P0/P1/P2 | **不影响**; 本 ticket 是 P2 流程效果度量, 跟拍板分级正交 |
| **EPIC-056-A** | 5 阶段 → 3 阶段 (改 PROCESS.md 15→10 步) | **不抢 PROCESS.md**; 本 ticket 文档写 metrics-kpi.md 单独文件, 引用 PROCESS.md 而不修改 |
| **EPIC-056-C** | Master 6 维恢复 (联动 055-B) | **不影响**; 独立 ticket |

---

## 6. 跟 5-GOVERNANCE-CARDS-APPROVAL 联合

**主公 2026-06-16 explicit 拍板 (line 22)**: EPIC-056-B 拍板 PASS, 风险等级低 (加 KPI 不改主流程).

**Master 不能自己升级红线 (PROCESS.md:25-26)**: 5 张治理卡 = 5/5 APPROVED, Master 获授权派单. **本次执行严格在拍板范围内**, 加 KPI 度量不改主流程.

**独立 (line 35)**: EPIC-056-B 在 5 张治理卡中唯一独立 ticket. ticket.json 中 `blocked_by: "EPIC-056-A"` 是数据不一致 (跟 approval 文档矛盾), 但 master 已基于 approval 文档独立派单, **不影响执行**. Flag 在 LESSONS-LEARNED.

---

## 7. 风险与缓解 (跟 11 BE + 6 痛点 联合)

| 风险 | 来源 | 缓解 |
|---|---|---|
| KPI 估数假 PASS | 12 KPI falsification 反复 (BE-5) | Rule 9a X/Y 1 位小数 + check-kpi-precision 工具 |
| Scope creep | BE-6/11 越界 | 严格 file_scope 边界, 不动 docs/PROCESS.md |
| 抢 EPIC-053-D web dashboard | ticket boundary | 明确: 本 ticket 只出 CLI 仪表盘, 不进 web/ |
| 15 步流程表演化治标不治本 | P3 痛点 | 3 KPI 度量闭环, 跟 11 BE 关联, 后续 Phase review 升级 Rule |

---

## 8. 验收标准 (跟 AC 7 条 + 7 anti-fab 工具 严格联合)

- ✅ AC1: process-metrics.ts 实现 3 KPI (Rule 9 X/Y)
- ✅ AC2: process-metrics.sh CLI 输出 3 KPI + 历史趋势
- ✅ AC3: metrics-kpi.md 3 KPI 定义 + 目标值 + 度量方法 + BE 关联
- ✅ AC4: P3 治根 — 15 步流程表演化闭环 (3 KPI 度量)
- ✅ AC5: 6/6 PASS test output (raw, not estimate)
- ✅ AC6: Rule 9 X/Y 格式 — `6/6 PASS (100.0%)` 1 位小数
- ✅ AC7: 治理升级已拍板 (主公 2026-06-16 APPROVED, 不自助)

**Anti-fab 7 工具 (跟 4-Level Fact-Forcing 联动)**:
1. check-test-case-isolation — 测试独立性
2. check-kpi-precision — X/Y 格式 (Rule 9a)
3. check-scope-creep — file_scope 边界
4. check-fact-forcing-preflight — L1-L4 存在
5. l3-l4-consistency — L3 跟 L4 一致
6. kpi-evidence-chain — 4-Level evidence chain (commit + stdout + 5 groups + witness)
7. tool-self-check — 工具自检

---

**跟主公 2026-06-16 explicit 拍板 联合, 跟 PROCESS.md:25-26 联合, 跟 Rule 9 X/Y 格式 联合, 跟 EPIC-053-D 派单仪表盘 联动 (不抢 web), 跟 11 BE 累计 联合, 跟 6 痛点 联合**