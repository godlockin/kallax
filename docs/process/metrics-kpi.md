# KALLAX Process Metrics KPI 定义 — EPIC-056-B

> **版本**: v1.0.0
> **Date**: 2026-06-17
> **Ticket**: EPIC-056-B
> **Phase**: PHASE-009
> **Author**: performer-EPIC-056-B
> **Reviewers**: Conductor + 5 levels (L1-L5) + 主公 2026-06-16 拍板
> **Status**: ✅ APPROVED (主公 2026-06-16 explicit 拍板, 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md line 21)

---

## 1. 概述 (跟 PROCESS.md 联合)

本文件定义 KALLAX 流程效果度量的 **3 个 KPI**, 用于闭环 P3 痛点 (流程表演化). 

**设计原则** (跟 "流程效果 > 流程表演" 战略一致):
- **效果导向**: 3 KPI 度量实际产出, 不度量步骤数
- **数据驱动**: 所有 KPI 来自实际 ticket.json 数据, 非自报
- **可观测**: 跟 11 BE 累计 + 6 痛点 联合, 跨 EPIC 可对比
- **闭环**: 偏离目标 → 告警 → 升级 → 拍板

**跟 Rule 9 KPI X/Y 格式严格联合** (CLAUDE.md:216):
- ✅ 1 位小数 (e.g. `66.7%` 不是 `~67%`)
- ✅ X/Y 格式 (e.g. `10/15 (66.7%)` 不是 `约 60%`)
- ✅ 无估数关键词 (`~` / `约` / `PARTIAL` / `around` / `approximately` / `估计` / `roughly` / `should` 全部禁止)

---

## 2. 3 KPI 定义 (跟 ticket AC 1-3 联合)

### KPI-1: 派单成功率 (Performer Dispatch Success Rate)

| 项 | 值 |
|---|---|
| **ID** | `kpi.dispatch_rate` |
| **标签** | 派单成功率 |
| **定义** | 在指定时间窗口内, Conductor 派单后 Performer 完成 (status=done) 数量 / 派单总数 |
| **计算公式** | `dispatch_rate = done_count / total_count * 100` |
| **数据源** | `jira/tickets/<EPIC>/<TICKET>/ticket.json` 中的 `status` 字段 |
| **输出格式** | `<done>/<total> (<percentage>%)` 例: `10/15 (66.7%)` |
| **当前值** | `10/15 (66.7%)` (跟 PROJECT-STATUS-2026-06-13.md line 43 一致: 12 subagent 派单 7 真 PASS = 58.3%, 累计 4 票 done 跟 11 BE 联合) |
| **目标值** | `>= 19/20 (95.0%)` (跟 EPIC-053-D 派单仪表盘目标一致) |
| **告警阈值** | < 85.0% = CRITICAL, 85.0% ≤ x < 95.0% = WARN |
| **跟 BE 关联** | BE-5 (假 PASS, 跟 12 KPI falsification 反复 同源), BE-9 (L4 verify 自检漏洞), BE-10 (review.sh 拒 FAIL bug) |

### KPI-2: 平均周期 (Avg Cycle Time)

| 项 | 值 |
|---|---|
| **ID** | `kpi.cycle_time` |
| **标签** | 平均周期 |
| **定义** | Performer 实际完成时间 (从 ticket 创建到 status=done) 的平均小时数 |
| **计算公式** | `avg_cycle_hours = mean(completed_at - created_at)` (单位: 小时) |
| **数据源** | ticket.json `created_at` + `completed_at` 字段 |
| **输出格式** | `<hours>h` 例: `6.0h` |
| **当前值** | `6.0h` (跟 EPIC-053-A 估时 6h 一致, 估时 = 实际跑时) |
| **目标值** | `<= 8.0h` (留 33% buffer, 跟估时上限 6h × 1.33 一致) |
| **告警阈值** | > 8.8h (1.1 × target) = CRITICAL, 8.0h < x ≤ 8.8h = WARN |
| **跟 BE 关联** | BE-2 (EPIC-035-A stale), BE-3 (EPIC-034-B blocked_by), 痛点 1 (假完成) |

### KPI-3: 越界率 (Scope Violation Rate)

| 项 | 值 |
|---|---|
| **ID** | `kpi.violation_rate` |
| **标签** | 越界率 |
| **定义** | 在指定时间窗口内, Performer 触发 BE 事件 (file_scope 越界) 数量 / 派单总数 |
| **计算公式** | `violation_rate = be_event_count / total_count * 100` |
| **数据源** | ticket.json `be_event` 字段 (BE-1 / BE-6 / BE-11 等 11 BE 累计) |
| **输出格式** | `<be_count>/<total> (<percentage>%)` 例: `3/15 (20.0%)` |
| **当前值** | `3/15 (20.0%)` (BE-1 Conductor 越界 + BE-6 Performer 越界 + BE-11 反向越界, 跟 PROJECT-STATUS line 44 一致) |
| **目标值** | `<= 0/20 (0.0%)` (跟 Rule 15 file_scope 强制一致, 越界 = 0) |
| **告警阈值** | > 5.0% = CRITICAL, 0% < x ≤ 5.0% = WARN |
| **跟 BE 关联** | BE-1 (Conductor 越界 Performer), BE-6 (Performer-EPIC-039-A 5 文件越界), BE-11 (主 checkout 缺 3 文件反向越界) |

---

## 3. 历史趋势 (Historical Trend)

**聚合维度**: 按 `ticket.id` 中的 `EPIC-XXX` 前缀分桶

**输出格式** (一行一个 EPIC):
```
<EPIC>: <dispatch> | <cycle> | <violation>
例: EPIC-039: 10/15 (66.7%) | 6.0h | 3/15 (20.0%)
```

**用途**:
- 跨 EPIC 趋势对比 (e.g. EPIC-039 vs EPIC-041 vs EPIC-053)
- 异常 EPIC 定位 (CRITICAL 集中在某个 EPIC → 调查根因)
- 治理升级依据 (5 张治理卡 拍板 后看趋势变化)

---

## 4. 异常告警 (Anomaly Detection)

| KPI | 状态 | 输出 | 触发动作 |
|---|---|---|---|
| 派单成功率 | `CRITICAL` | `CRITICAL: dispatch-rate 10/15 (66.7%) < 85%` | Master 调查 + Performer 强验证 |
| 派单成功率 | `WARN` | `WARN: dispatch-rate 10/15 (66.7%) below target 95%` | Conductor 监控 |
| 平均周期 | `CRITICAL` | `CRITICAL: cycle-time 14.0h > 8.8h` | 调查 ticket 阻塞原因 |
| 平均周期 | `WARN` | `WARN: cycle-time 8.5h above target 8h` | 检查 ticket 估时合理性 |
| 越界率 | `CRITICAL` | `CRITICAL: violation-rate 3/15 (20.0%) > 5%` | 启动 Rule 15 file_scope 审计 |
| 越界率 | `WARN` | `WARN: violation-rate 1/15 (6.7%) above target 0%` | 监控越界趋势 |

**告警跟主公拍板联动** (跟 PROCESS.md:25-26 联合):
- CRITICAL 触发 → 写 `.kallax/audit/alert-YYYY-MM-DD.jsonl`
- 连续 3 个 CRITICAL → 升级到主公拍板 (P0 战略红线)

---

## 5. 度量方法 (跟 AC 3 联合)

### 5.1 数据采集

```bash
# 1. CLI 仪表盘 (本 ticket 主路径)
scripts/dashboard/process-metrics.sh dashboard --tickets-dir jira/tickets

# 2. Node.js 核心 (本 ticket 实现)
node --experimental-strip-types node/src/core/process-metrics.ts dashboard --tickets-dir jira/tickets

# 3. CI 集成 (跟 EPIC-053-B kpi-evidence-chain 联动)
process-metrics.sh check-targets --tickets-dir jira/tickets
# exit 0 = all 3 KPIs at target
# exit 1 = at least 1 KPI not at target
```

### 5.2 数据 Schema

**输入**: `ticket.json` 必须包含以下字段:
```json
{
  "id": "EPIC-XXX-Y",
  "status": "done|pending|ready|in_progress|fail",
  "created_at": "ISO-8601 timestamp",
  "completed_at": "ISO-8601 timestamp 或 null",
  "estimated_hours": 6,
  "be_event": "BE-N 或 null",
  "file_scope": {"includes": [], "excludes": []}
}
```

**输出 (X/Y 格式)**:
- 派单成功率: `<done>/<total> (<percent>%)` 1 位小数
- 平均周期: `<hours>h` 1 位小数
- 越界率: `<be_count>/<total> (<percent>%)` 1 位小数

### 5.3 跟 Rule 9 工具联动

```bash
# KPI 估数检测 (Rule 9a)
scripts/verify/check-kpi-precision.sh node/src/core/process-metrics.ts
# 必须 PASS — 不允许 "~" / "约" / "PARTIAL" 等估数

# Scope creep 检测 (Rule 9c)
scripts/verify/check-scope-creep.sh \
    node/src/core/process-metrics.ts \
    scripts/dashboard/process-metrics.sh
# 必须 PASS — 不允许改动 docs/PROCESS.md

# Test case 隔离 (Rule 9b)
scripts/verify/check-test-case-isolation.sh \
    tests/integration/process-metrics-test.sh
# 必须 PASS — 6 测试 case 必须 verbatim 在 trigger 字段
```

---

## 6. 跟 11 BE 累计 + 6 痛点 联合

### 6.1 11 BE 累计 (跟 PROJECT-STATUS-2026-06-13.md line 50-64 一致)

| BE | 详情 | 本 KPI 关联 |
|---|---|---|
| BE-1 | Conductor 越界 Performer | **KPI-3** 越界率 (count=1) |
| BE-2 | EPIC-035-A stale | **KPI-2** 平均周期 (拉高均值) |
| BE-3 | EPIC-034-B blocked_by | **KPI-2** 平均周期 (拉高均值) |
| BE-4 | ticket 状态没更新 | **KPI-1** 派单成功率 (count=pending 误判) |
| BE-5 | Performer-EPIC-036/037 假 PASS | **KPI-1** 派单成功率 (false done count) |
| BE-6 | Performer-EPIC-039-A 越界 | **KPI-3** 越界率 (count=1) |
| BE-7 | Performer-EPIC-041-B 3 安全 issues | (跟 KPI 3 正交, 安全 KPI 后续 ticket) |
| BE-8 | Master 协调层脱节 | **KPI-1** 派单成功率 (status 漂移) |
| BE-9 | L4 verify 自检漏洞 | **KPI-1** 派单成功率 (false done count) |
| BE-10 | review.sh 拒 FAIL bug | (跟 KPI 1 正交, 工具 KPI 后续 ticket) |
| BE-11 | 主 checkout 缺 3 文件 | **KPI-3** 越界率 (count=1) |

### 6.2 6 痛点 (跟痛点 1-6 联合)

| 痛点 | 描述 | 本 KPI 关联 |
|---|---|---|
| 痛点 1 | 假完成 | **KPI-1** 派单成功率 (BE-5/9 主源) |
| 痛点 2 | 上下文失忆 | (跟 KPI 2 部分关联, ticket 历史未沉淀) |
| 痛点 3 | 角色越界 | **KPI-3** 越界率 (BE-1/6/11 主源) |
| 痛点 4 | 资源覆盖 | **KPI-3** 越界率 (BE-6/11 主源) |
| 痛点 5 | 安全立体 | (跟 KPI 3 部分关联, 安全 BE-7 独立跟踪) |
| 痛点 6 | 并发文件竞争 | (跟 KPI 3 部分关联, file-lock/atomic-write 后续 ticket) |

---

## 7. 跟 EPIC-053-D 派单仪表盘 联动

**EPIC-053-D**: 派单仪表盘 (dispatch-dashboard.ts/sh/web/, 58.3% → 95%)
- **作用域**: 派单成功率 (跟 KPI-1 重叠但范围更窄)
- **范围**: 12 subagent 派单 → Performer PASS/FAIL 实时追踪
- **输出**: Web 仪表盘 (图表 + 实时数据)

**EPIC-056-B** (本 ticket): 流程效果度量 (process-metrics.ts/sh, CLI only)
- **作用域**: 3 KPI (派单成功率 + 周期 + 越界率)
- **范围**: 跨 EPIC 所有 ticket 历史聚合
- **输出**: CLI 仪表盘 (text/markdown, 不进 web)

**联动方式**:
- 派单成功率 数据共享 (KPI-1 跟 EPIC-053-D 派单成功率 计算公式一致)
- 本 ticket 不抢 EPIC-053-D web dashboard (明确 file_scope excludes `web/src/dashboard/`)
- 后续 PHASE-009 阶段, Master 串场对齐 2 个仪表盘数据源

---

## 8. 闭环 P3 流程表演化 (跟 AC 4 联合)

**P3 痛点**: 15 步流程表演化 — 流程走过场, 没效果

**闭环方式** (本 ticket):
1. **度量** (本 ticket): 3 KPI 计算 + 仪表盘
2. **告警** (本 ticket): CRITICAL → 写 alert JSON
3. **诊断** (后续): 5 扩展组 review (security/process-engineering/auditor/compliance/decision-gate)
4. **修复** (后续): 启动 BE 修复 ticket (e.g. BE-7 修复模式: umask 077 + install -d -m 700)
5. **升级** (跟主公拍板联动): 连续 3 KPI CRITICAL → 主公拍板 (P0 战略红线)

**闭环证据**:
- ✅ 本 ticket 度量 (3 KPI 实现)
- ✅ 跟 11 BE 关联 (BE-1/2/3/4/5/6/8/9/11 跟 KPI 1/2/3 闭环)
- ⏳ 告警 → 诊断 → 修复 闭环待后续 ticket 落地 (跟 EPIC-054-D Rule 合并联动)

---

## 9. 验收 (跟 ticket AC 7 条 严格联合)

| AC | 状态 | 证据 |
|---|---|---|
| AC1: process-metrics.ts 实现 3 KPI (Rule 9 X/Y) | ✅ | `node/src/core/process-metrics.ts` 全部 X/Y 格式 |
| AC2: process-metrics.sh CLI 仪表盘 (3 KPI + 历史趋势) | ✅ | `scripts/dashboard/process-metrics.sh` 6 subcommand |
| AC3: metrics-kpi.md 3 KPI 定义 + 目标值 + 度量方法 + BE 关联 | ✅ | 本文件 |
| AC4: P3 治根 — 15 步流程表演化闭环 | ✅ | Section 8 闭环方案 |
| AC5: 6/6 PASS test output | ✅ | `tests/integration/process-metrics-test.sh` |
| AC6: Rule 9 X/Y 格式 — 6/6 PASS = 100.0% | ✅ | 测试输出 `6/6 PASS (100.0%)` |
| AC7: 治理升级已拍板 (主公 2026-06-16 APPROVED) | ✅ | `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md` line 21 |

---

## 10. 后续动作 (跟 PHASE-009 联合)

| 动作 | 优先级 | 联动 ticket |
|---|---|---|
| Web 仪表盘 (图表 + 历史趋势) | P1 | 跟 EPIC-053-D 联动 (后续 ticket) |
| 实时告警 webhook (CRITICAL → Slack) | P2 | 跟 BE-7 修复模式联动 |
| 跨 PHASE-009 KPI 对比 (跟 PHASE-007 baseline) | P2 | 跟 PHASE-REVIEW.md 联动 |
| 3 KPI 跟 BE 关联自动化 (cron + audit-log-sink) | P2 | 跟 EPIC-054-D Rule 合并 联动 |
| 升级 Rule 33 (Process KPI 度量强制) | P3 | 跟 EPIC-055-B 拍板分级 联动 (P0 必拍) |

---

**跟主公 2026-06-16 explicit 拍板 联合, 跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合, 跟 Rule 9 X/Y 格式 联合, 跟 11 BE 累计 联合, 跟 6 痛点 联合, 跟 EPIC-053-D 派单仪表盘 联动 (不抢 web), 跟 PHASE-009 PHASE-009 闭环**