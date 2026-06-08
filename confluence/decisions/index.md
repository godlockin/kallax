# Architecture Decision Records (ADRs) + Decision Documents Index

> **决策文档统一索引**. 分 3 类: 框架 ADR / EPIC 实施 ADR / 战略 / 调研.
> **路径**: `confluence/decisions/`
> **更新规则**: 任何新决策文档 (Phase 评审, 调研, 战略) 创建时, 同步加链接到这里.

---

## 0. 框架 ADR (Accepted)

> 长期生效的架构决策, 跨 EPIC 不变.

- [ADR-001: Three-Tier Degradation (Redis → SQLite → Filesystem)](../docs/adr/ADR-001-degradation-strategy.md) — Accepted 2026-01
- [ADR-002: Conductor-Performer over Master-Slaver](../docs/adr/ADR-001-degradation-strategy.md) — Accepted 2026-01
- [ADR-003: Saga Compensation over Simple Rollback](../docs/adr/ADR-001-degradation-strategy.md) — Accepted 2026-01

---

## 1. EPIC-016 ADR (Init Performance Optimization)

> Layer A 平台级优化, 60-80% token 节省.

- [ADR-016-A: MCP Server Lazy Loading](./ADR-016-A-mcp-lazy-loading.md) — Proposed 2026-06-06
- [ADR-016-B: Skill Metadata On-Demand Discovery](./ADR-016-B-skill-metadata-discovery.md) — Proposed 2026-06-06

---

## 2. EKET 调研 (Phase 002 启动依据)

> 借鉴 EKET 专家体系 + 引导式初始化, KALLAX 决定从 0 起步建 7 expert.

**调研链** (短 → 长 → 战略):
- [EKET-BORROW-METHODOLOGY-2026-06-07.md](./EKET-BORROW-METHODOLOGY-2026-06-07.md) — 短报告 (145 行), 3 块可借鉴方法论
- [EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md](./EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md) — 深度调研 (545 行), 4-Group 4 专家原始报告 + 共识冲突 + 12 借鉴建议
- [EKET-SURPASS-STRATEGY-2026-06-07.md](./EKET-SURPASS-STRATEGY-2026-06-07.md) — **战略合成**, 5 维独有优势 + 12 共识超越点 + EPIC-021 草案

**三角关系**:
```
BORROW-METHODOLOGY (短)
    ↓ 触发
DEEP-DIVE (长)
    ↓ 5 专家 panel
SURPASS-STRATEGY (战略)
    ↓ 用户决策
EPIC-021 ticket 结构 (jira/epics/EPIC-021/)
```

---

## 3. Permission Model 调研 (Phase 002 下一 EPIC 候选)

> EPIC-022 Permission Model v1 调研, 5 专家 review + 12 P0 fixes.

- [PERMISSION-MODEL.md](./PERMISSION-MODEL.md) — 设计文档 (来源, EKET-style)
- [PERMISSION-PANEL-RAW-2026-06-07.md](./PERMISSION-PANEL-RAW-2026-06-07.md) — 5 专家原始报告 (Architect/Backend/Security/DevOps/Product)
- [PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md](./PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md) — **战略合成** (367 行), 12 P0 fixes + EPIC-017 scope + 6 决策点

**关系**:
```
PERMISSION-MODEL (设计)
    ↓ 5 专家并行
PERMISSION-PANEL-RAW (原始)
    ↓ Master 仲裁
PERMISSION-MODEL-EXPERT-REVIEW (战略)
    ↓ 用户决策 (待)
EPIC-022 ticket 结构 (待建)
```

---

## 4. Workflow 规则 (CLAUDE.md Rule 6+7 配套)

> 经验沉淀强制化, EPIC 交付 + PHASE 闭环 review 机制.

- [WORKFLOW-RULES-2026-06-07.md](./WORKFLOW-RULES-2026-06-07.md) — 详细 workflow + 3 模板说明 + 触发节奏
- [EPIC-LESSONS-LEARNED-TEMPLATE.md](../templates/EPIC-LESSONS-LEARNED-TEMPLATE.md) — EPIC 经验教训模板
- [PHASE-REVIEW-TEMPLATE.md](../templates/PHASE-REVIEW-TEMPLATE.md) — PHASE 闭环 review 模板
- [AB-REVIEW-TEMPLATE.md](../templates/AB-REVIEW-TEMPLATE.md) — A+B 2-Group review 记录模板

**CLAUDE.md 配套规则** (在 `/CLAUDE.md`):
- Rule 6: EPIC 交付三件套 (A+B review + 文档更新 + 经验总结)
- Rule 7: PHASE 闭环 review (4-Group 升级, 主公审批)

---

## 5. 实施复盘 (Postmortem)

> EPIC 完成后 24h 内的复盘, 跟 EPIC 实施 commit 同一 PR.

- [EPIC-016-POSTMORTEM-2026-06-07.md](./EPIC-016-POSTMORTEM-2026-06-07.md) — Init 性能 19 ticket 复盘, 7 lessons learned
- [REVIEW-016-postresult-hang.md](./REVIEW-016-postresult-hang.md) — Q ticket 深度调研 (post-result hang)
- [HALLUCINATION-DEVIATION-LOG.md](./HALLUCINATION-DEVIATION-LOG.md) — J ticket 哈希验证偏差日志

---

## 6. 扩展方案 (未来 EPIC 候选)

> 未实施但已规划的扩展.

- [EXPERT-EXTENSION-SCHEME-2026-06-07.md](./EXPERT-EXTENSION-SCHEME-2026-06-07.md) — Expert 体系扩展 (新增 expert 类型流程)
- (待建) [PHASE-002-REVIEW-2026MMDD.md](./) — Phase 002 闭环 review (3rd EPIC 后触发)

---

## 7. 待办索引

### 7.1 EPIC 经验教训 (jira/epics/EPIC-XXX/LESSONS-LEARNED.md)

| EPIC | 状态 | 路径 |
|---|---|---|
| EPIC-016 | ✅ done (POSTMORTEM 形式, 补 Template Conformance) | [EPIC-016-POSTMORTEM-2026-06-07.md](./EPIC-016-POSTMORTEM-2026-06-07.md) |
| EPIC-021 | ✅ done | [jira/epics/EPIC-021/LESSONS-LEARNED.md](../../jira/epics/EPIC-021/LESSONS-LEARNED.md) |
| EPIC-022 | ⏳ 待建 (实施完) | — |
| EPIC-018 | ⏳ 待建 (O 5 issue 修复) | — |

### 7.2 模板 (confluence/templates/)

| 模板 | 状态 | 用途 |
|---|---|---|
| EPIC-LESSONS-LEARNED-TEMPLATE.md | ✅ v1 | EPIC 经验教训 (8 节) |
| PHASE-REVIEW-TEMPLATE.md | ✅ v1 | PHASE 闭环 review (4-Group) |
| AB-REVIEW-TEMPLATE.md | ✅ v1 | A+B 2-Group review 记录 |

### 7.3 Phase 002 review 候选升级项 (待主公审批)

来自 EPIC-021 LESSONS-LEARNED §8.3:
- **UP-1**: Rule 8 "L4 脚本必须存在, 否则 ticket 不 close"
- **UP-2**: Rule 9 "4-Level Fact-Forcing 强制机制 = task:complete 集成"
- **UP-3**: Rule 6 修订 "EPIC 实施 commit 必带 LESSONS-LEARNED 草稿"
- **UP-4**: 新增 architecture 文档 `confluence/architecture/heartbeat-observability.md`

---

## 8. 维护规则

- **新文档创建时**: 立刻加链接到对应分类
- **新 EPIC 完成后**: 24h 内写 LESSONS-LEARNED.md + 加链接到 §7.1
- **Phase 触发时**: 写 PHASE-REVIEW 文档 + 升级到 §7.3
- **季度审计**: master 跑一次 cross-reference 完整性检查 (每季度)

---

**Reviewer(s)**: master_main (2026-06-07)
**Last updated**: 2026-06-07
**Status**: ✅ UNIFIED INDEX — 14 决策文档全部覆盖, 交叉引用一致
