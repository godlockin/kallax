# A+B 2-Group Review 模板

> **何时用**: EPIC ticket 实施完成后, master 跑 A+B review.
> **流程**: master 派 2 个 sub-agent (A-Forward + B-Attack), 各自独立 review.
> **产出**: 本文件 (或 ticket.json 的 `review:` 字段), 含 P0/P1/P2 + CRITICAL/HIGH/MEDIUM/LOW 列表.
> **路径**: `confluence/templates/AB-REVIEW-TEMPLATE.md` (模板) / `jira/tickets/EPIC-XXX-{A,B,...}/REVIEW.md` (实际)

**Ticket**: EPIC-XXX-A (或单个 ticket)
**Commit**: <commit SHA>
**Reviewers**: A-Forward + B-Attack
**Date**: YYYY-MM-DD

---

## A 组 (Forward) — 找"是否真做对"

### AC 校验

| # | AC 描述 | 结果 | 证据 |
|---|---|---|---|
| 1 | [AC 1] | ✅/❌ | [文件:行号, 命令输出] |
| 2 | [AC 2] | ✅/❌ | [证据] |
| ... | | | |

### 4-Level Fact-Forcing

- L1 存在性: ✅/❌
- L2 实质性: ✅/❌
- L3 接线正确: ✅/❌
- L4 数据流动: ✅/❌

### Findings

| Severity | Category | File | Line | Issue | Suggestion |
|---|---|---|---|---|---|
| P0 | [cat] | [file] | [N] | [issue] | [fix] |
| P1 | [cat] | [file] | [N] | [issue] | [fix] |
| P2 | [cat] | [file] | [N] | [issue] | [fix] |

### Summary

- X/Y AC pass
- Z P0, W P1, V P2
- **Recommendation**: APPROVE / REJECT / NEEDS_FIX

---

## B 组 (Attack) — 找"会不会出问题"

### Attack Surface 分析

- 入口点: [list]
- 数据流: [list]
- 攻击向量: [list]

### Findings

| Severity | Category | File | Line | Issue | Attack Scenario | Mitigation |
|---|---|---|---|---|---|---|
| CRITICAL | [cat] | [file] | [N] | [issue] | [scenario] | [fix] |
| HIGH | [cat] | [file] | [N] | [issue] | [scenario] | [fix] |
| MEDIUM | [cat] | [file] | [N] | [issue] | [scenario] | [fix] |
| LOW | [cat] | [file] | [N] | [issue] | [scenario] | [fix] |

### 跨视角观察

- A 组漏掉的攻击面: [list]
- 跨平台 / 跨环境风险: [list]
- 时序 / 竞态 / 并发: [list]

### Summary

- X CRITICAL, Y HIGH, Z MEDIUM, W LOW
- **Recommendation**: APPROVE / REJECT / NEEDS_FIX

---

## Master 仲裁

### 综合判定

| 维度 | A 组 | B 组 | 一致性 |
|---|---|---|---|
| AC 合规 | X/Y pass | n/a | — |
| 代码质量 | Z findings | W findings | 互补 |
| 安全 / 攻击 | n/a | K findings | B 独享 |

### 修复优先级

1. **必修 (P0 / CRITICAL)**: [list]
2. **应修 (P1 / HIGH)**: [list]
3. **可缓 (P2 / MEDIUM)**: [list]
4. **可忽略 (LOW)**: [list]

### 修复记录

| Issue | Severity | Fix Commit | Status |
|---|---|---|---|
| [issue] | P0/CRITICAL | [sha] | fixed/pending/wontfix |

### 最终决定

- **APPROVE** / **REJECT** / **APPROVE with conditions**
- 条件 (if any): [list]
- Merge 目标: miao / testing / [branch]
- Merge commit: [sha] (after fix)

### 下一步

1. [Performer 需修的 issue 列表]
2. [master 需做的 follow-up]
3. [经验教训待沉淀到 LESSONS-LEARNED.md]

---

**Master 签名**: ____________
**Date**: YYYY-MM-DD
