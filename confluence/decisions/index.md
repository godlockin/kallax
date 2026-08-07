# Architecture Decision Records (ADRs) + Decision Documents Index

> **决策文档统一索引**. 分类组织,所有引用经 EPIC-196 (2026-08-07) 治理验证全 EXIST。
> **路径**: `confluence/decisions/`
> **归档**: `confluence/decisions/ARCHIVED/` (永久只读,详见 ARCHIVED/README.md)
> **更新规则**: 任何新决策文档创建时, 同步加链接到这里。

---

## 1. ADR (架构决策记录)

| ADR | 状态 | 主题 |
|---|---|---|
| [ADR-016-A: MCP Server Lazy Loading](./adr-016-a-mcp-lazy-loading-2026-06-06.md) | Accepted | MCP server 按需加载 |
| [ADR-016-B: Skill Metadata On-Demand Discovery](./adr-016-b-skill-metadata-discovery-2026-06-06.md) | Accepted | Skill metadata 按需发现 |

## 2. 治理规则 (Branch + Commit + Release)

| 文档 | 日期 | 主题 |
|---|---|---|
| [Branch Flow Governance](./branch-flow-governance-2026-07-09.md) | 2026-07-09 | 4-PR flow (feature → testing → main → miao) |
| [Branch 4-way Sync EPIC-129](./branch-sync-2026-07-20.md) | 2026-07-20 | main/miao/testing 同步实操 |
| [Branch Recovery](./branch-recovery-2026-07-20.md) | 2026-07-20 | main 远端被删重建 |
| [Commit Hygiene](./commit-hygiene-2026-08-05.md) | 2026-08-05 | commit history 备案 + 未来指南 (跟 EPIC-155 1:1) |
| [Release Automation EPIC-128](./release-automation-2026-07-20.md) | 2026-07-20 | release archive + symlink UX |

## 3. 借鉴 / 调研

| 文档 | 日期 | 主题 |
|---|---|---|
| [EKET Borrow Progress](./eket-borrow-progress-2026-06-11.md) | 2026-08-07 refresh | EKET 26 项 P0/P1/P2 借鉴进度 |
| [Borrow from cindy](./borrow-from-cindy-2026-07-26.md) | 2026-07-26 | makecindy/cindy 工程治理借鉴 |

## 4. EPIC 实施复盘 / 教训

### 4.1 Sprint 复盘

| 文档 | 日期 | 范围 |
|---|---|---|
| [Sprint 4-7 + EPIC-101](./retrospective-sprint-4-7-epic-101-2026-07-09.md) | 2026-07-09 | v3.8.1-v3.11.0 + EPIC-101 验证 |

### 4.2 EPIC 实施教训

| 文档 | 日期 | 范围 |
|---|---|---|
| [EPIC-113-A + EPIC-114](./EPIC-113-A-and-EPIC-114-lessons-2026-07-11.md) | 2026-07-11 | 4-PR flow 首次全程真跑 + CI 债务 |
| [EPIC-114 Vitest Scan](./EPIC-114-vitest-scan-2026-07-12.md) | 2026-07-12 | node/tests 45 files 扫描结果 |
| [EPIC-115 Lint Audit](./EPIC-115-lint-audit-2026-07-13.md) | 2026-07-13 | 633 lint errors / 108 files 切 6 ticket |
| [EPIC-130→133 Journey](./epic-130-to-133-journey.md) | 2026-07-20 | 33 commits + 11 lessons |
| [EPIC-131 TS Strict Lessons](./epic-131-ts-strict-lessons-2026-07-20.md) | 2026-07-20 | 33 strict errors 扫除 |
| [EPIC-133 Worktree Fix](./epic-133-worktree-fix.md) | 2026-07-20 | callback/Promise mismatch 根因 |
| [EPIC-135-A Guided Research](./epic-135-a-guided-research.md) | 2026-07-20 | /kallax-research 引导式 |

## 5. EPIC 拍板记录 (2026-08-05 Phase 5)

| EPIC | 文档 | 主题 |
|---|---|---|
| EPIC-166 | [epic-166-daemon-runtime-verification-2026-08-05.md](./epic-166-daemon-runtime-verification-2026-08-05.md) | daemon 真跑抓 3 bug |
| EPIC-168-BG | [epic-168-bg-2026-08-05.md](./epic-168-bg-2026-08-05.md) | 北极星 dashboard 闭环 |
| EPIC-169 | [epic-169-public-path-2026-08-05.md](./epic-169-public-path-2026-08-05.md) | 公开化路径 |
| EPIC-170 | [epic-170-complete-plugin-2026-08-05.md](./epic-170-complete-plugin-2026-08-05.md) | Expert plugin complete |
| EPIC-171 | [epic-171-strategy-deposit-2026-08-05.md](./epic-171-strategy-deposit-2026-08-05.md) | 3 视角战略沉淀 |
| EPIC-172 | [epic-172-public-coord-2026-08-05.md](./epic-172-public-coord-2026-08-05.md) | 公开化协同 |
| EPIC-174 | [epic-174-smoke-retention-2026-08-05.md](./epic-174-smoke-retention-2026-08-05.md) | smoke retention policy |
| EPIC-175-fix | [epic-175-fix-json-injection-2026-08-05.md](./epic-175-fix-json-injection-2026-08-05.md) | JSON injection 修复 |
| EPIC-175 | [epic-175-security-extended-2026-08-05.md](./epic-175-security-extended-2026-08-05.md) | Security rules 强化 |
| EPIC-177-G | [epic-177-g-northstar-emit-2026-08-05.md](./epic-177-g-northstar-emit-2026-08-05.md) | run-history emit integration |
| EPIC-178 | [epic-178-q3-repromote-2026-08-05.md](./epic-178-q3-repromote-2026-08-05.md) | Q3 re-promote 备案 |

## 6. 设计阶段 / 待实施

| 文档 | 状态 | 备注 |
|---|---|---|
| [EPIC-122-E: events.jsonl per EPIC](./EPIC-122-E-design-2026-07-18.md) | ⚠️ SUPERSEDED-BY EPIC-177-G | 设计未落地, run-history emit 替代 |
| [EPIC-124: KALLAX MCP Bridge](./EPIC-124-design-2026-07-18.md) | ⚠️ PENDING | 设计未落地, 见 `confluence/research/mcp-bridge-backlog.md` |
| [EPIC-119: Tool Orchestration](./EPIC-119-tool-orchestration-2026-07-14.md) | ✅ Accepted | OpenAI 借鉴, 已实施 |

## 7. Backlog / 数据快照

| 文档 | 日期 | 内容 |
|---|---|---|
| [TODO/FIXME Backlog](./TODO-backlog-2026-07-19.md) | 2026-08-07 refresh | 当前 grep 实质 TODO 清单 |

## 8. 已归档 (永久只读)

详见 [ARCHIVED/README.md](./ARCHIVED/README.md) — 9 篇文档因内容重叠/数据过期归档。

---

## 9. 维护规则

- **新文档创建时**: 立刻加链接到对应分类
- **新 EPIC 完成后**: 24h 内写 LESSONS-LEARNED + 加链接
- **过期文档**: 经 EPIC 决策后 git mv → ARCHIVED/, 同步更新 index + README
- **季度审计**: master 跑一次 cross-reference 完整性检查

---

**Reviewer(s)**: master_main
**Last updated**: 2026-08-07 (EPIC-196)
**Status**: ✅ 治理完成,34 顶层 + 9 归档, 0 MISSING 引用