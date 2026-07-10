# PHASE-XXX Review — 经验升级完整完成

> **何时触发**: 完成 3-5 个 EPIC, 或阶段目标达成, master 召集.
> **流程**: Phase 1 Architect 全局扫 → Phase 2 5 专家并行 → Phase 3 Master 仲裁升级 → Phase 4 决策者审批.
> **产出**: 本文件 + CLAUDE.md 修订 + (可选) confluence/architecture/ 新文档.
> **路径**: `confluence/decisions/PHASE-XXX-REVIEW-YYYYMMDD.md`

**Date**: YYYY-MM-DD
**Phase 范围**: EPIC-XXX 到 EPIC-YYY (X 个 EPIC)
**Status**: REVIEW IN PROGRESS / APPROVED
**Author**: master_xxx (仲裁)
**Reviewers**: 5 专家 panel + 决策者

---

## 0. 触发与背景

**触发原因**: [完成 N 个 EPIC / 阶段目标达成 / 用户决策]

**Phase 范围**:
- EPIC-XXX (YYYY-MM-DD ~ YYYY-MM-DD, Z tickets)
- EPIC-YYY (YYYY-MM-DD ~ YYYY-MM-DD, Z tickets)
- ...

**关键决策** (本 phase 累积):
- [决策 1]: [一句话]
- [决策 2]: [一句话]

---

## 1. Phase 1 — Architect 全局扫描

### 1.1 EPIC 汇总

| EPIC | Tickets Done | 时间 | 关键产出 | 目标达成 |
|---|---|---|---|---|
| EPIC-XXX | X/Y | YYYY-MM-DD | [产物] | Z% |
| EPIC-YYY | X/Y | YYYY-MM-DD | [产物] | Z% |
| **合计** | **X/Y** | **N 天** | [产物列表] | **Z%** |

### 1.2 经验教训分类

- **技术 (Tech)**: [N 条, 跨 EPIC 出现 K 次]
- **流程 (Process)**: [N 条, K 次]
- **治理 (Governance)**: [N 条, K 次]
- **人员 (People)**: [N 条, K 次]
- **工具 (Tooling)**: [N 条, K 次]

### 1.3 Architect 跨 EPIC 观察

- [跨 EPIC 模式 1]: [现象, 涉及 EPIC, 共性]
- [跨 EPIC 模式 2]: [同上]

---

## 2. Phase 2 — 5 专家并行 (各 600 tokens 视角)

### 2.1 🏗️ Architect

**观察**:
- [Architect 视角的洞见]
- [架构层面累积 / 漂移 / 债务]

**建议**:
- [建议 1]
- [建议 2]

### 2.2 💻 Backend

**观察**:
- [后端层面累积]
- [性能 / 稳定性 / 兼容性]

**建议**:
- [建议 1]
- [建议 2]

### 2.3 🎨 Frontend

**观察**:
- [前端 / UI / 触点累积]
- [DX 改进 / 摩擦点]

**建议**:
- [建议 1]
- [建议 2]

### 2.4 🖌️ UX

**观察**:
- [用户体验累积]
- [决策树 / 引导 / 文档化]

**建议**:
- [建议 1]
- [建议 2]

### 2.5 📋 Product

**观察**:
- [产品 / 价值 / 路线图]
- [北极星指标 / 转化漏斗]

**建议**:
- [建议 1]
- [建议 2]

---

## 3. Phase 3 — Master 仲裁 (查漏补缺 / 纠错 / 合并 / 升级)

### 3.1 查漏补缺

| 缺失项 | 原因 | 补 EPIC / 文档 |
|---|---|---|
| [缺 1] | [原因] | EPIC-XXX |
| [缺 2] | [原因] | confluence/architecture/yyy.md |

### 3.2 纠错

| 错误经验教训 | EPIC | 修正 |
|---|---|---|
| [错 1] | EPIC-XXX | [修正内容] |
| [错 2] | EPIC-YYY | [修正内容] |

### 3.3 归纳合并 (跨 EPIC 相似 lessons)

| 合并主题 | 涉及 EPIC | 出现频次 | 合并后表述 |
|---|---|---|---|
| [主题 1] | EPIC-A, B, C | 3 次 | [通用表述] |
| [主题 2] | EPIC-D, E | 2 次 | [通用表述] |

### 3.4 升级到 CLAUDE.md / architecture/

#### 3.4.1 升级项清单 (待 Phase 4 审批)

| 编号 | 类型 | 来源 (跨 EPIC 合并) | 建议位置 | 优先级 |
|---|---|---|---|---|
| UP-1 | 新规则 | 并行冲突 × 3 | CLAUDE.md 核心原则 #X | P0 |
| UP-2 | 新模板 | review 模板缺失 × 2 | confluence/templates/ | P1 |
| UP-3 | 修订现有 | Rule 6 文档更新范围扩大 | CLAUDE.md Rule 6 | P1 |
| UP-4 | 新决策 | 安全 attack surface 累积 | confluence/architecture/security-*.md | P0 |

#### 3.4.2 升级项详细说明

**UP-1: 新规则 [标题]**

- **背景**: 跨 EPIC 出现 K 次, 涉及 [EPIC-A, B, C]
- **建议规则**: [具体规则内容]
- **代价**: [实施成本 / 学习曲线]
- **不升级的风险**: [不升级会怎样]

**UP-2: 新模板 [标题]**
...

---

## 4. Phase 4 — 决策者审批 (升级项决策)

### 4.1 决策者决策点

| 编号 | 决策问题 | 决策者答复 | 决策日期 |
|---|---|---|---|
| UP-1 | 是否升级 [规则名]? | YES/NO/修订 | YYYY-MM-DD |
| UP-2 | 是否新增 [模板名]? | YES/NO/修订 | YYYY-MM-DD |
| UP-3 | 是否修订 [现有规则]? | YES/NO/修订 | YYYY-MM-DD |
| UP-4 | 是否新建 [架构文档]? | YES/NO/修订 | YYYY-MM-DD |

### 4.2 升级实施记录

| 编号 | 实施 commit | 文件 | 实施者 |
|---|---|---|---|
| UP-1 | [commit SHA] | CLAUDE.md | master |
| UP-2 | [commit SHA] | confluence/templates/xxx.md | master |
| ... | | | |

---

## 5. 下 Phase 路线图 (决策者决策)

### 5.1 下 Phase 候选 EPIC

| EPIC | 标题 | 估时 | 优先级 | 阻塞 |
|---|---|---|---|---|
| EPIC-AAA | [title] | Xh | P0 | 无 |
| EPIC-BBB | [title] | Xh | P1 | EPIC-AAA |
| EPIC-CCC | [title] | Xh | P2 | 无 |

### 5.2 阶段目标

[本 phase 想达成什么, 跟北极星指标如何挂钩]

### 5.3 资源 / 角色配置

- Performer 数量: N
- Conductor: M
- Master: 1

---

## 6. 经验沉淀机制效果评估

### 6.1 跨 Phase 对比 (本 phase vs 上 phase)

| 指标 | 上 phase | 本 phase | 改进 |
|---|---|---|---|
| EPIC 平均完成时间 | X 天 | Y 天 | Z% |
| A+B review 修复数 | X | Y | Z |
| 重复教训数 | X | Y | Z (越少越好) |
| 升级到 CLAUDE.md 项数 | X | Y | Z |

### 6.2 沉淀机制本身评估

- ✅ 跨 EPIC 模式识别 (合并)
- ✅ 漏洞补全 (查漏)
- ✅ 决策者审批 (升级有 gate)
- ❌ [不足 1]: 描述, 改进建议
- ❌ [不足 2]: 描述, 改进建议

---

**Reviewer(s)**: 5 专家 panel + master 仲裁 + 决策者审批
**Last updated**: YYYY-MM-DD
**Status**: ✅ APPROVED — 升级项已实施, 下 Phase 路线图已确认

---

**附录**: 关联文件
- [EPIC-XXX LESSONS-LEARNED.md](...)
- [EPIC-YYY LESSONS-LEARNED.md](...)
- [CLAUDE.md 升级 commit](...)
- [新模板/新架构文档 commit](...)
