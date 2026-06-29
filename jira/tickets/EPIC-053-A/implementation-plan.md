# EPIC-053-A Implementation Plan

> L3 集成测试 vs L4 verify 一致性检查 (治 H2 / BE-9)
> P0 紧急 | 6h | branch: feature/EPIC-053-A-l3-l4-consistency
> Performer: performer-EPIC-053-A | base SHA: fa4db08

---

## 1. 目标 (跟 AC 1:1 对齐)

实现 L3 (集成测试) ↔ L4 (verify 脚本) 一致性强制约束 — 不许矛盾. 防御体系自检漏洞 (BE-9) 治根闭环.

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `l3-l4-consistency.sh` 实现 — L3 pass ⇒ L4 pass | 单元 + 集成测试 |
| AC2 | 4 case 全 PASS | 跑 `tests/integration/l3-l4-consistency-test.sh` |
| AC3 | BE-9 治根闭环 | 一致性强制: 矛盾 ⇒ 退出非零 |
| AC4 | Rule 8 5-Level Fact-Forcing 强约束 | L3 + L4 必须并行跑, 不可单边报 |
| AC5 | 跟 preflight 联动 | `check-fact-forcing-preflight.sh` 调用 l3-l4-consistency |
| AC6 | KPI X/Y 格式 (4/4 = 100.0%) | 测试报告 X/Y 格式精确数字 |

---

## 2. 设计 (跟 Rule 8 + Rule 18 联合)

### 2.1 核心语义

```
       L3 pass   L3 fail
L4 pass  OK        ERROR  ← 矛盾 = BE-9
L4 fail  ERROR     OK
```

L3 L4 不许矛盾 — 矛盾意味着防御体系自检漏洞, 报 ERROR exit=1.

### 2.2 接口

```bash
# scripts/verify/l3-l4-consistency.sh
# Usage: l3-l4-consistency.sh --l3-status=PASS|FAIL --l4-status=PASS|FAIL
# Exit 0: consistent
# Exit 1: contradiction detected (ERROR)
# Exit 2: invalid args
```

### 2.3 实现策略

- **L3 input**: 集成测试退出码 (0=PASS, 非零=FAIL)
- **L4 input**: verify 脚本退出码 (0=PASS, 非零=FAIL)
- **逻辑**: XOR-like 判定 — 同状态 ⇒ OK; 异状态 ⇒ ERROR

### 2.4 与 preflight 联动

`check-fact-forcing-preflight.sh` 跑 l3-l4-consistency 作为 pre-gate, 同时跑 4 个 anti-fab 工具 (check-test-case-isolation, check-kpi-precision, check-scope-creep, check-fact-forcing-preflight-self). 任一失败 ⇒ preflight FAIL ⇒ ticket REJECT.

---

## 3. 步骤 (15 步中我的子集, Step 1-8, 11-12)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 拆 worktree (Master 已建, 我验证) | ✓ |
| 2 | 加载 ticket 描述 | ✓ |
| 3 | 加载 expert profile (backend) | ✓ |
| 4 | 深度分析 (3 anti-fab 工具 + l4-self-check + 2 test 模板) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 (4 case) | 待执行 |
| 7 | 写实现 l3-l4-consistency.sh | 待执行 |
| 8 | 跑 4/4 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-A.json) | 待执行 |
| 13-15 | Master 强验证 / merge (Master/Conductor 责任) | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建**:
- `scripts/verify/l3-l4-consistency.sh` — 核心检查器
- `tests/integration/l3-l4-consistency-test.sh` — TDD 4 case
- `scripts/verify/check-fact-forcing-preflight.sh` — preflight 联动 (新建, file_scope 包含)
- `jira/tickets/EPIC-053-A/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-A/LESSONS-LEARNED.md` — 教训沉淀

**不动** (边界):
- docs/, confluence/, scripts/conductor/, scripts/audit/, scripts/hooks/, node/, rust/, web/

---

## 5. 测试设计 (AC2 4 case)

| Case | L3 | L4 | 期望 |
|------|----|----|------|
| 1 | PASS | FAIL | ERROR (矛盾) |
| 2 | FAIL | PASS | ERROR (矛盾) |
| 3 | PASS | PASS | OK (一致) |
| 4 | FAIL | FAIL | OK (一致, 都没撒谎) |

**子检查**: AC6 — 4/4 = 100.0% (精确 X/Y, no estimate).

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| L3 L4 信号难定义 (什么算 L3 / L4) | 走最小化定义: 集成测试退出码 + verify 脚本退出码 |
| 复制其他 3 anti-fab 工具 | 只参考命名/风格, 实现从零写 |
| boundary 越界 | 用 `check-scope-creep.sh EPIC-053-A` 验证 |
| KPI falsification 反复 | commit message 用 X/Y 精确格式 (4/4 = 100.0%) |
| 自审 | A/B review 跳过 (本 ticket 范围内不在 Performer 责任) |
| 跑测试不报 PASS | pass-report 含 raw test_output |
