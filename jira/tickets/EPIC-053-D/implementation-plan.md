# EPIC-053-D Implementation Plan

> Performer 派单成功率仪表盘 (58.3% → 95%+, 跟 Rule 9 KPI 联动, 跟 H1/H6 治根)
> P1 | 8h | branch: feature/EPIC-053-D-dispatch-dashboard
> Performer: performer-EPIC-053-D | base SHA: eefa1d3 (after EPIC-053-F merge)
> EPIC-053 最后 1 票 — 闭环 KPI falsification 系统

---

## 1. 目标 (跟 AC 1:1 对齐)

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `node/src/core/dispatch-dashboard.ts` 实现 — 实时追踪 Performer 派单成功率 (X/Y 格式, 跟 Rule 9 精确一致) | `node --experimental-vm-modules` import + 5/5 test |
| AC2 | `scripts/dashboard/dispatch-dashboard.sh` CLI 仪表盘 — 输出每 EPIC 派单成功率 + 越界事件 + 假 PASS 计数 | `bash scripts/dashboard/dispatch-dashboard.sh` raw output |
| AC3 | `web/src/dashboard/dispatch/` Web 仪表盘 — 图表显示历史趋势, 跟 web/ 框架一致 | 跟 web/styles.css dark theme 一致 + vanilla JS (zero deps, 跟 web/app.js 一致) |
| AC4 | Performer 派单成功率从 58.3% (PROJECT-STATUS line 43) → 95%+ 目标 | KPI 公式 + 历史 baseline (line 43) |
| AC5 | H1 治根 — KPI falsification 反复 实时可视化, 跟 EPIC-053-B 4-Level 证据链联动 | `detectFakePasses()` 函数 + `kpi-evidence-chain.sh` exit code 解析 |
| AC6 | H6 治根 — 越界事件 (BE-1/BE-6/BE-11) 实时告警, 跟 Rule 15 联动 | `detectBoundaryViolations()` 函数 + `check-scope-creep.sh` exit code 解析 |
| AC7 | `tests/integration/dispatch-dashboard-test.sh` 5/5 PASS (3 数据源 mock + 2 case: 派单成功 + 派单失败) | `bash tests/integration/dispatch-dashboard-test.sh` raw output |
| AC8 | Rule 9 KPI 精确 X/Y 格式 — 5/5 PASS = 100.0% | test output 含 `5/5 PASS (100.0%)` |

---

## 2. 设计 (跟 EPIC-053-A/B/C/E/F 联动)

### 2.1 架构 (3 数据源 → 1 核心 → 3 输出)

```
┌─────────────────────────────────────────────────────────┐
│  3 数据源 (read-only, 跟 EPIC-053 5 票已有产物对齐)     │
│  S1: pass-report JSON (.kallax/queue/outbox/performer-*/│
│       pass-report-*.json) — 派单 outcome 真相          │
│  S2: check-scope-creep.sh exit (BE-1/6/11 越界)        │
│  S3: kpi-evidence-chain.sh exit (4-Level evidence)     │
└──────────────┬──────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│  核心: node/src/core/dispatch-dashboard.ts              │
│  - computeDispatchKpi(records): Result<KpiSummary>     │
│  - detectFakePasses(records): ReadonlyArray<FakePass>  │
│  - detectBoundaryViolations(records): ReadonlyArray<BE> │
│  - formatXofY(passed, total): string ("5/5 (100.0%)")  │
│  纯函数, neverthrow Result, no I/O                       │
└──────────────┬──────────────────────────────────────────┘
               ↓ (3 输出路径, 同一核心)
┌─────────────────────────────────────────────────────────┐
│  1. CLI: scripts/dashboard/dispatch-dashboard.sh       │
│     文本输出 (KPI + BE + fake PASS + trend)             │
│  2. Web: web/src/dashboard/dispatch/                   │
│     index.html + dispatch.js + dispatch.css             │
│     SVG 图表 + dark theme (跟 web/styles.css 一致)      │
│  3. Test: tests/integration/dispatch-dashboard-test.sh │
│     5/5 case, 3 数据源 mock via env var                  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 数据模型 (TypeScript strict, no `any`)

```typescript
type DispatchOutcome = 'pass' | 'fail' | 'fake_pass' | 'boundary_violation';
interface DispatchRecord {
  readonly ticketId: string;
  readonly epicId: string;
  readonly performerId: string;
  readonly commitSha: string;
  readonly outcome: DispatchOutcome;
  readonly evidenceChainPassed: boolean;  // EPIC-053-B 4-Level
  readonly scopeViolations: ReadonlyArray<string>;  // BE-1/6/11
  readonly timestamp: number;
}
interface DispatchKpiSummary {
  readonly total: number;
  readonly passed: number;
  readonly failed: number;
  readonly fakePasses: number;
  readonly boundaryViolations: number;
  readonly formatXofY: string;  // "5/5 (100.0%)" Rule 9 精确
  readonly ratePct: number;     // 0.0-100.0
  readonly byEpic: ReadonlyMap<string, EpicKpi>;
}
```

### 2.3 跟 EPIC-053 5 票联动点

| 票 | 联动方式 |
|----|----------|
| 053-A | L3↔L4 一致性 (Rule 18 同步) — 假 PASS 在 L3 检测, 仪表盘在 S3 验证 |
| 053-B | `kpi-evidence-chain.sh verify` exit code → `evidenceChainPassed` 字段 |
| 053-C | `check-scope-creep.sh` exit code → `scopeViolations` 字段 (BE-1/6/11 模式) |
| 053-E | wiring gap 治根 — 5 调用点闭环, 仪表盘不重复实现 (复用 `output-verifier.ts` 的接口) |
| 053-F | glob pattern 跟 `jira/tickets/EPIC-XXX/` 一致 — 仪表盘读取 ticket.json file_scope |

### 2.4 数据源 S1 (pass-report JSON) 格式契约

跟 EPIC-053-F / 053-A / 053-B / 053-E / 053-C 一致, 已存在. 文件结构:
```
.kallax/queue/outbox/performer-EPIC-XXX-Y/pass-report-EPIC-XXX-Y.json
{
  "ticket_id": "EPIC-XXX-Y",
  "commit_sha": "<40-char hex>",
  "kpi_x_of_y": "X/Y (100.0%)",
  "anti_fab_results": { ... },
  "be_events": [ ... ],
  "boundary_violations": 0
}
```
仪表盘解析每个 JSON: outcome='pass' if `boundary_violations=0` AND `kpi_x_of_y` matches `PASS (100.0%)`; else outcome='fail' 或 'fake_pass'.

### 2.5 数据源 S3 (kpi-evidence-chain.sh) exit 解析

调用 `bash scripts/verify/kpi-evidence-chain.sh verify <ticket> <sha> <stdout>` → exit 0 = evidence PASS, exit 1 = evidence FAIL. Parse `[L1 PASS|FAIL]` markers 验证 4-Level 一致性 (跟 output-verifier.ts:392-400 一致).

---

## 3. 步骤 (15 步子集)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 验证 worktree (eefa1d3 + branch feature/EPIC-053-D-dispatch-dashboard) | ✓ |
| 2 | 读 ticket.json (P1, blocked_by 053-C done) | ✓ |
| 3 | 加载 fullstack expert profile (Node.js + Web) | ✓ |
| 4 | 深度分析 (output-verifier.ts + claim-queue.ts + web/app.js + scope-creep-glob-test + 053-F plan) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写 `dispatch-dashboard-test.sh` 5 case (red) | 待执行 |
| 7a | 写 `node/src/core/dispatch-dashboard.ts` (核心, 绿) | 待执行 |
| 7b | 写 `scripts/dashboard/dispatch-dashboard.sh` (CLI) | 待执行 |
| 7c | 写 `web/src/dashboard/dispatch/` (Web 仪表盘) | 待执行 |
| 8 | 跑测试 5/5 PASS | 待执行 |
| 9 | 跑 7 anti-fab tools (scope-creep/kpi-precision/fact-forcing-preflight/test-case-isolation/l3-l4-consistency/kpi-evidence-chain/tool-self-check) | 待执行 |
| 10 | `git commit` (单 commit, message 跟 053 模式一致) | 待执行 |
| 11 | 写 `LESSONS-LEARNED.md` (3-5 lessons) | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-D.json) | 待执行 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**新建 (6 个)**:
- `node/src/core/dispatch-dashboard.ts` — 核心追踪逻辑 (TypeScript strict, neverthrow)
- `scripts/dashboard/dispatch-dashboard.sh` — CLI 仪表盘
- `web/src/dashboard/dispatch/index.html` — Web 仪表盘页面
- `web/src/dashboard/dispatch/dispatch.js` — Web 图表逻辑 (vanilla JS, zero deps)
- `web/src/dashboard/dispatch/dispatch.css` — 跟 web/styles.css dark theme 一致
- `tests/integration/dispatch-dashboard-test.sh` — TDD 5 case
- `jira/tickets/EPIC-053-D/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-D/LESSONS-LEARNED.md` — 教训沉淀
- `.kallax/queue/outbox/performer-EPIC-053-D/pass-report-EPIC-053-D.json` — PASS 报告

**不动 (边界)**:
- `node/src/core/output-verifier.ts` (EPIC-053-B 边界)
- `node/src/core/claim-queue.ts` (只读, 复用 enqueue/dequeue 接口)
- `scripts/verify/check-scope-creep.sh` (EPIC-053-F 边界)
- `scripts/verify/kpi-evidence-chain.sh` (EPIC-053-B 边界)
- `scripts/verify/l3-l4-consistency.sh` (EPIC-053-A 边界)
- `scripts/verify/check-fact-forcing-preflight.sh` (EPIC-053-A 边界)
- `web/app.js` `web/index.html` `web/styles.css` (框架, 不改, 仪表盘新建子目录)

---

## 5. 测试设计

### 5.1 `dispatch-dashboard-test.sh` 5 case

| Case | 场景 | 期望 |
|------|------|------|
| 1 | 3 数据源 mock 跑通 (S1 pass-report JSON + S2 scope-creep + S3 kpi-evidence-chain) | 3 source 都成功读入, 计数 = N |
| 2 | 派单成功 path (5 ticket 全 PASS) | X/Y format = "5/5 (100.0%)" rate=100.0% |
| 3 | 派单失败 path (fake PASS 检测) | fakePasses >= 1, evidenceChainPassed=false 触发 |
| 4 | 越界事件告警 (BE-1/6/11 pattern) | boundaryViolations >= 1, BE events 列表非空 |
| 5 | X/Y 格式 KPI 输出 (Rule 9 precision) | 输出含 `5/5 PASS (100.0%)` 精确字符串 |

### 5.2 Mock 数据 (via KALLAX_DASHBOARD_MOCK_DIR env)

测试用临时目录 (mktemp) 装 3 个 mock 数据源:
- `mock/outbox/performer-EPIC-X/{pass-report-EPIC-X-1..5}.json` (5 个 pass-report)
- `mock/scope-creep/{EPIC-X-1..5}.exit` (5 个 exit code 文件)
- `mock/evidence-chain/{EPIC-X-1..5}.exit` (5 个 4-Level 验证结果)

Case 3 (假 PASS): 1 个 pass-report `kpi_x_of_y="5/5 PASS"` 但 `boundary_violations=1` → outcome='fake_pass'
Case 4 (越界): 1 个 pass-report 跟 scope-creep exit=1 联动 → outcome='boundary_violation'

### 5.3 Anti-patterns 防护

- ❌ magic numbers: 用 `KpiThresholds` 常量对象 (PASS_RATE_TARGET = 95.0, baselineRatePct = 58.3)
- ❌ `any`: 全 TypeScript strict (跟 output-verifier.ts 一致)
- ❌ 简化 5/5: 强制 3 数据源 + 2 case (AC7 明确要求)
- ❌ merge to miao: 只 commit, 不 merge (Conductor 专属)
- ❌ 自审: 报 PASS 由 Conductor review

---

## 6. 风险 + 反模式 (跟 Rule 18 + Rule 19 联合)

| 风险 | 缓解 |
|------|------|
| 数据源契约漂移 (pass-report 格式变) | 类型 `PassReportSummary` 跟 EPIC-053-F 一致 + 解析失败回退 (FAIL outcome) |
| web/ framework 不兼容 | 复用 styles.css 变量 (--bg-primary 等), zero deps vanilla JS |
| 越界 file_scope | 跑 `check-scope-creep.sh EPIC-053-D` 验证 0 越界 (新文件全在 scope.includes) |
| KPI falsification 反复 | test_case 5 验证 Rule 9 精确字符串 ("5/5 PASS (100.0%)") |
| Bash 5.x 字符类 bug (BE-10) | 用 `case "$x" in "$prefix"*)` 不用 `[[:space:]]` |
| 跟 EPIC-053-A/B/C/E/F 边界冲突 | file_scope excludes 显式列出, 跑 check-scope-creep.sh 验证 |
| 自审 | 跳 A/B review, Conductor merge |

---

## 7. 联动

| Ticket | 联动点 |
|--------|--------|
| EPIC-053-A | L3↔L4 一致性 (l3-l4-consistency.sh 不动, 仪表盘在 S3 验证 4-Level) |
| EPIC-053-B | `kpi-evidence-chain.sh verify` exit → evidenceChainPassed |
| EPIC-053-C | `check-scope-creep.sh` 修复版 exit → scopeViolations (BE-10 模式联动) |
| EPIC-053-E | wiring gap 治根, 仪表盘不复用 `output-verifier.verify` 而是用 `verifyPassEvidence` (avoid 5 调用点重复) |
| EPIC-053-F | glob pattern 跟 `jira/tickets/EPIC-XXX/` 一致, ticket.json file_scope 解析 |

---

## 8. 跟 Rule 9 KPI X/Y 联合

最终 KPI: `5/5 (dispatch-dashboard-test.sh) = 5/5 PASS = 100.0%`
精确数字, no estimate (跟 EPIC-053-A 6 次 KPI 反复闭环).

历史 baseline (PROJECT-STATUS-AND-LESSONS-2026-06-13.md line 43): `7/12 真 PASS (58.3%)` → 目标 `95%+`
公式: `(passed + (fakePasses * 0)) / (total - fakePasses) * 100` (假 PASS 不算成功)
或更严格: `passed / total * 100` (含 fakePasses 在 failed 中)
本仪表盘采用更严格公式 (跟 H1 治根一致): `realPassRate = passed / (total - fakePasses) * 100`

---

## 9. 数据源 S2 (check-scope-creep.sh exit) 解析

调用 `bash scripts/verify/check-scope-creep.sh <ticket_id>` → exit 0 = scope OK, exit 1 = scope violation.
每个 ticket.json 都跑一遍 scope-creep, 把 exit code 存到 `scopeViolations: [paths...]` 数组 (空=OK, 非空=violation).
BE-1 (Conductor 越界) / BE-6 (Performer-EPIC-039-A 越界) / BE-11 (主 checkout 缺 3 文件反向越界) — 3 个 BE 模式在仪表盘告警面板上独立显示.

---

## 10. 跟 H1/H6 治根闭环

### H1 (KPI falsification 反复 12 次) 治根:
- `detectFakePasses()` 扫描所有 pass-report, 检测 "reported PASS but evidence chain FAIL" 模式
- 输出 fake_pass 列表 + 关联 ticket_id + commit_sha (跟 BE-5 联动)
- 仪表盘 H1 面板: `Fake PASS Count: N | Last 30 days trend | Top performers`

### H6 (越界事件 BE-1/6/11) 治根:
- `detectBoundaryViolations()` 扫描所有 ticket.json file_scope vs git diff changed files
- 输出 BE events 列表 + 类型 (BE-1 Conductor / BE-6 Performer / BE-11 反向) + ticket_id
- 仪表盘 H6 面板: `BE Events: N | By Type | Recent 10`

---

## 11. 验收 checklist

- [ ] 5/5 test PASS (raw output 含 `5/5 PASS (100.0%)`)
- [ ] 0 boundary violation (跑 `check-scope-creep.sh EPIC-053-D` exit=0)
- [ ] 0 KPI precision false (跑 `check-kpi-precision.sh` 验证 X/Y 格式)
- [ ] 0 test case isolation leak (跑 `check-test-case-isolation.sh`)
- [ ] 0 fact-forcing preflight gap (跑 `check-fact-forcing-preflight.sh`)
- [ ] 0 L3↔L4 inconsistency (跑 `l3-l4-consistency.sh` 联动 053-A)
- [ ] 0 KPI evidence chain gap (跑 `kpi-evidence-chain.sh verify` 联动 053-B)
- [ ] 0 tool self-check gap (跑 `tool-self-check` 联动 053-C)
- [ ] 1 git commit (single, 跟 053 模式一致)
- [ ] LESSONS-LEARNED.md 3-5 lessons
- [ ] pass-report JSON 写入 outbox
- [ ] EPIC-053 闭环 6/6 证明 (5 prior + 1 mine)
