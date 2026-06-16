# EPIC-053-C Implementation Plan

> Tool self-check 系统级治根 — review.sh / check-kpi-precision.sh 工具自检 (4 维度), 治 BE-10 模式 + bash 5.x 数组模式兼容性
> P0 紧急 | 6h | branch: feature/EPIC-053-C-tool-self-check
> Performer: performer-EPIC-053-C | base SHA: eefa1d3 | blocked_by: EPIC-053-B (done)

---

## 1. 目标 (跟 AC 1:1 对齐)

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `scripts/verify/tool-self-check.sh` 实现 — 跑 review.sh + check-kpi-precision.sh 自身 4 维度自检 (语法 + patterns 兼容 + 真 PASS 判 PASS + 真 FAIL 判 FAIL) | 跑 `tests/integration/tool-self-check-test.sh` |
| AC2 | BE-10 (review.sh 拒 FAIL bug) 治根 | review.sh + check-kpi-precision.sh 自检 PASS, 真 FAIL 不再被拒判 |
| AC3 | `tests/integration/tool-self-check-test.sh` 8/8 PASS (4 工具 × 2 case: 真 PASS + 真 FAIL) | 跑 test |
| AC4 | `scripts/conductor/review.sh` 修 — patterns 改用 bash 5.x 兼容 (`\s` 替代 `[[:space:]]` 数组内模式) | 自检 PASS + 真 PASS/FAIL case |
| AC5 | `scripts/verify/check-kpi-precision.sh` 修 — 跟 review.sh 同步 patterns 升级 | 自检 PASS |
| AC6 | Rule 9 KPI 精确 X/Y 格式 — 8/8 PASS = 100.0% | test 输出 8/8 = 100.0% |
| AC7 | 跟 EPIC-053-B 联动 — 证据链工具本身也是被检查对象, 形成元级闭环 | tool-self-check.sh 被 kpi-evidence-chain.sh L3 检查 |

---

## 2. 设计 (跟 Rule 8 + Rule 9 + BE-10 + EPIC-053-B 联合)

### 2.1 核心语义 — 4 维度工具自检

```
+---------------------------------------------------+
| D1: Syntax (bash -n 编译通过)                       |
|     - 0 stderr from bash -n                         |
|     - exit 0                                         |
+---------------------------------------------------+
| D2: Pattern compatibility (bash 5.x 数组模式兼容)   |
|     - 0 instances of [[:space:]] in array elements  |
|     - 所有 array patterns 用 \s (bash 5.x regex)    |
+---------------------------------------------------+
| D3: True PASS detection (真 PASS → 工具判 PASS)     |
|     - 用合法输入跑工具, 必须 exit 0                  |
|     - 防 BE-10 (拒 FAIL bug 反向: 拒 PASS bug)      |
+---------------------------------------------------+
| D4: True FAIL detection (真 FAIL → 工具判 FAIL)     |
|     - 用非法输入跑工具, 必须 exit non-zero            |
|     - 治 BE-10 (review.sh 拒 FAIL bug)              |
+---------------------------------------------------+
```

### 2.2 4 工具 × 2 case 矩阵

| 工具 | 真 PASS 输入 | 真 FAIL 输入 | 验证方法 |
|------|------------|------------|----------|
| review.sh | clean commit (无 estimate pattern) | commit msg 含 `~70%` (kpi-precision FAIL) | 跑 `review.sh` 检查 exit code |
| check-kpi-precision.sh | commit msg: `M1: 8/8 = 100.0%` | commit msg: `M1: ~70%` | 跑 `check-kpi-precision.sh HEAD` |
| check-test-case-isolation.sh | experts 干净 (50 真实 test case 不在 trigger) | mock expert file 注入 test case | 跑 `check-test-case-isolation.sh` |
| check-scope-creep.sh | commit 在 scope 内 | commit 改 src/ 但 ticket scope 不含 src/ | 跑 `check-scope-creep.sh <ticket>` |

**总: 4 工具 × 2 case = 8 test case (8/8 = 100.0%, Rule 9 精确 X/Y)**

### 2.3 元级闭环 (跟 EPIC-053-B 联动)

```
EPIC-053-B kpi-evidence-chain.sh L3 检查 5 扩展组
    → security-tool-bypass: check-scope-creep + check-kpi-precision
    → process-engineering: check-fact-forcing-preflight + l3-l4-consistency
    → auditor: auditor-checkpoint + subagent-pass-gate
    → compliance: check-test-case-isolation
    → decision-gate: review-checkpoint + rule-19-checkpoint

EPIC-053-C tool-self-check.sh
    → 检查对象: review.sh, check-kpi-precision.sh, check-test-case-isolation.sh, check-scope-creep.sh
    → 这 4 工具 正好是 kpi-evidence-chain L3 的核心 tools
    → tool-self-check.sh 本身也接入 L3 (process-engineering 扩展)
    → 元级闭环: 检查工具的工具, 自己也被检查
```

### 2.4 跟 BE-10 模式联合

BE-10 模式: `review.sh` 之前用 `[[:space:]]` 数组模式 (bash 5.x 不兼容), 导致真 FAIL 也会被判 PASS (因为 array indexing 出错, 永远走空 pattern). Master 修了 check-kpi-precision.sh patterns.

治根: 不只修一处, 而是建 **system-level 自检机制** — 任何工具未来回归 `[[:space:]]` 数组模式, 立刻被 tool-self-check.sh 拦截. 跟 EPIC-048 tool-bypass-audit 模式 一致 (meta-tool 守住 framework 不退化).

---

## 3. 步骤 (15 步中我的子集, Step 1-8, 11-12)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 验证 worktree (Master 已建, 我验证) | ✓ |
| 2 | 加载 ticket 描述 | ✓ |
| 3 | 加载 expert profile (backend) | ✓ |
| 4 | 深度分析 (review.sh + check-kpi-precision + check-test-case-isolation + check-scope-creep + kpi-evidence-chain + tool-bypass-audit + BE-10 历史) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 (8 case) | 待执行 |
| 7 | 写实现 (tool-self-check.sh + review.sh 加 guard + check-kpi-precision.sh 加 guard) | 待执行 |
| 8 | 跑 8/8 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-C.json) | 待执行 |
| 13-15 | Master 强验证 / merge (Master/Conductor 责任) | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建**:
- `scripts/verify/tool-self-check.sh` — 4 维度工具自检核心
- `tests/integration/tool-self-check-test.sh` — TDD 8 case
- `jira/tickets/EPIC-053-C/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-C/LESSONS-LEARNED.md` — 教训沉淀

**修改** (跟 file_scope includes):
- `scripts/conductor/review.sh` — 加 bash 5.x pattern guard header (防 BE-10 复发)
- `scripts/verify/check-kpi-precision.sh` — 加 bash 5.x pattern guard header (同步)

**不动** (边界 — 跟其他 EPIC-053 ticket 边界):
- `scripts/verify/l3-l4-consistency.sh` (EPIC-053-A 边界)
- `scripts/verify/kpi-evidence-chain.sh` (EPIC-053-B 边界)
- `tests/integration/l3-l4-*` (EPIC-053-A/E 边界)
- `scripts/verify/check-scope-creep.sh` (EPIC-053-F 刚修的)
- `scripts/verify/tool-bypass-audit.sh` (EPIC-048 已有)
- docs/, confluence/, node/, web/, rust/

---

## 5. 测试设计 (AC3 8 case)

| # | 工具 | 场景 | 期望 exit | 期望 X/Y |
|---|------|------|-----------|----------|
| 1 | review.sh | clean commit (无 estimate) | 0 (PASS) | 1/1 |
| 2 | review.sh | commit msg 含 `~70%` | 1 (FAIL — kpi-precision 拒) | 2/2 |
| 3 | check-kpi-precision.sh | msg: `M1: 8/8 = 100.0%` | 0 (PASS) | 3/3 |
| 4 | check-kpi-precision.sh | msg: `M1: ~70%` | 1 (FAIL) | 4/4 |
| 5 | check-test-case-isolation.sh | experts 干净 | 0 (PASS) | 5/5 |
| 6 | check-test-case-isolation.sh | 注入 test case 到 expert | 1 (FAIL) | 6/6 |
| 7 | check-scope-creep.sh | commit 在 scope | 0 (PASS) | 7/7 |
| 8 | check-scope-creep.sh | commit 改 src/ 但 ticket scope 不含 | 1 (FAIL) | 8/8 |

**最终: 8/8 PASS (100.0%) — Rule 9 精确 X/Y 格式**

**测试隔离**:
- 用 temp dir 做每个 case 的 setup/teardown
- test case 5/6 用 KALLAX_TEST_EXPERT_DIR env override 隔离
- test case 7/8 用 test branch + ticket.json 隔离
- 不污染 .kallax/experts/default 实际数据

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| tool-self-check.sh 自己也有 BE-10 模式 | 自检也跑 4 维度, 自检运行测试 case 1-8 |
| 4 维度定义不清 | D1 语法 (bash -n) + D2 patterns (no [[:space:]] in array) + D3/D4 (真 PASS/FAIL) 显式 |
| 越界 file_scope | 用 `check-scope-creep.sh EPIC-053-C` 验证 |
| KPI falsification 反复 | commit message 用 X/Y 精确格式 (8/8 = 100.0%) |
| 自审 | A/B review 跳过 (不在 Performer 责任) |
| 跑测试不报 PASS | pass-report 含 raw test_output (8/8 PASS = 100.0%) |
| 简化 4 维度 | 严格 4 维度, 缺 1 算 FAIL, 不允许降级 |
| 修改边界外文件 | file_scope includes/excludes 严格, check-scope-creep.sh 验证 |

---

## 7. 联动清单

| 联动 | 描述 |
|------|------|
| EPIC-053-A (l3-l4-consistency) | tool-self-check 的 D3/D4 等于 EPIC-053-A 的 truth table 思想 — 真值自检 |
| EPIC-053-B (kpi-evidence-chain) | tool-self-check.sh 的检查对象 (4 工具) 正好是 kpi-evidence-chain L3 的核心 tools |
| EPIC-053-F (check-scope-creep glob) | check-scope-creep.sh 是自检对象之一, 跟 EPIC-053-F 闭环 |
| EPIC-048 (tool-bypass-audit) | 元级自检模式 — tool-bypass-audit 检查 bypass vector, tool-self-check 检查工具自身 4 维度 |
| BE-10 (review.sh 拒 FAIL bug) | 直接治根 — 4 维度 D2 (pattern compat) 拦截 `[[:space:]]` 数组模式 |
| Rule 8 (4-Level Fact-Forcing) | D1=existence, D2=substance, D3/D4=data flow (跟 Rule 8 对齐) |
| Rule 9 (KPI 精确 X/Y) | 8/8 PASS = 100.0% |
| Rule 18 (KPI falsification 黑名单) | 不报伪 PASS, 缺 1 维度算 FAIL |
| Rule 30/31 (独立见证) | tool-self-check 跑测试时输出 raw stdout (跟 BE-5 修复模式一致) |
| BE-7 (umask 077 修复) | tool-self-check 写 audit log 时遵守 BE-7 |
