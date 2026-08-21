# Agent Note: ADR Lifecycle Path Proposal (DSH Path A 借鉴)

> **Status**: proposed
> **Date**: 2026-08-21
> **Author**: KALLAX Performer B (Path A)
> **References**: DSH report §4 Path A + §5.1 建议 1; EPIC-225 (check-jargon 同型 admission 模式)

## 1. Problem (背景)

DSH Path A 报告 §4 + §5.1 指出 DeepSeek-Harness 的 Agent Note 体系用 lifecycle + class 双轴归档 (`proposed/implemented/rejected` × 6 class), KALLAX `confluence/decisions/*.md` 是平面文件夹, 缺 lifecycle, 缺 class 索引, 决策上下文跟普通文件混在一起. 这跟 EPIC 治理的"9-immutable gate 不可改"形成对比 — 治理门硬, 但 ADR 归档是软的, 导致 EPIC-225 后还要继续拍板".

DSH 落地的核心是"path 自带 lineage": 看路径就知 status + class, 不依赖 frontmatter, 不依赖 grep. KALLAX 现状是 `EPIC-XXX-slug.md` 平面命名, 跟 git log diff 难定位 status 转换.

## 2. Decision (提案)

提议 KALLAX 把 `confluence/decisions/*.md` 改成 lifecycle + class 双轴路径:

```
confluence/decisions/
  proposed/                  # 提案阶段 (主公未拍板)
    feature/                 # 新功能提案
    bug-fix/                 # 修 bug
    architecture/            # 架构/技术栈
    process/                 # 流程/治理
    testing/                 # 测试策略
    simplification/          # 简化/重构
  implemented/               # 主公拍板通过
    feature/
    bug-fix/
    ...
  rejected/                  # 拍板拒绝 (保留作 lineage)
    feature/
    ...
```

Header 三行标准 (跟 DSH `.agents/notes` 同型):

```markdown
# Agent Note: <title>
Status: <proposed|implemented|rejected>
Class: <feature|bug-fix|architecture|process|testing|simplification>

(problem / decision / alternatives / consequences 4 段标准)
```

跟 DSH 区别: DSH 提案阶段直接落 `proposed/`, 拍板后 `git mv` 到 `implemented/`. KALLAX 建议同模式, 但用 frontmatter (`Status:`) 避免 git mv history 丢失 (跟 EPIC-225 admission 流程同型).

## 3. Alternatives Considered

### 3.1 维持现状 (flat `confluence/decisions/*.md`)

- 优点: 0 迁移成本, 现有 ~30 文件不动
- 缺点: status/class 不可索引, EPIC-225 后还要继续拍板", 跟 DSH 治理方法论差距持续放大
- 判定: 否 (跟 EPIC-023-C 北极星 #1 治理自觉冲突)

### 3.2 只加 frontmatter 不改 path

- 优点: 0 改 path, 工具可 grep frontmatter 索引
- 缺点: path 仍平面, DSH 核心价值"path 自带 lineage"拿不到, 跟 EPIC-225 check-jargon `fail-closed` 体系无法对齐
- 判定: 否

### 3.3 双轴 path (本提案)

- 优点: 跟 DSH 1对1, 跟 EPIC-225 admission 模式同型, lifecycle + class 自带 lineage
- 缺点: 现有 ~30 文件需迁移, 1 次主公拍板事件 + PR 实施
- 判定: 是

## 4. Consequences

### 4.1 正面

- 跟 DSH 治理方法论对齐 (Appendix A 概念映射 row "Agent Note (lifecycle+class) | confluence/decisions 平面" 升级)
- EPIC 治理 9-immutable + ADR lifecycle 双层落地, 决策上下文不再散落平面
- 跟 EPIC-225 check-jargon 同型 admission 流程: 新文件 status = `proposed` 才能落 `confluence/decisions/proposed/`, 主公拍板后由 Conductor `git mv` 到 `implemented/`, verify-agent-note-format.sh 拦截 path/status 不对应

### 4.2 负面

- 现有 ~30 `confluence/decisions/*.md` 文件需手工迁移 (估算 4h, 跟 DSH 5.3 建议 1 effort 1 day 1对1)
- `verify-agent-note-format.sh` 必跑 (跟 check-doc-budgets.sh 同模式, 接 pre-commit hook)
- 跟 `confluence/research/` (L4 research 层) 边界需明确: research 是探索, decision 是治理产物 (本提案在 research/ 不在 decisions/)

### 4.3 跟现有 Rule 协同

- Rule 5 (DRY): 跟现有 `confluence/decisions/` 不重复, 升级结构
- Rule 13 (3 模式 decision-gate): status 转换触发 ASK (`proposed → implemented` 必主公拍板)
- Rule 35 (Sprint 时间盒): 0 跨 Sprint 累积, ADR admission 必当前 Sprint 完成
- EPIC-225 (黑话): 跟 check-jargon.sh 同 fail-closed 模式
- EPIC-159 (CLAUDE.md ≤200 行): 6 class 闭集在 manifest 集中, 决策类定义 0 分散

## 5. Migration Estimate

现有 `confluence/decisions/*.md` 文件清单 (估算 30):

| 范围 | 数量 | status 推断 |
|------|------|------------|
| `EPIC-235-244-*` 2026-08-09/10 | 10 | `implemented/process` (历史 EPIC 治理) |
| `prime-agent-research-2026-08-08.md` | 1 | `implemented/research` (应迁 research/) |
| `retrospective-v3.X.X-*` | 6 | `implemented/process` |
| `kallax-lessons-best-practices-2026-08-07.md` | 1 | `implemented/architecture` |
| `workflow-8step-2026-08-07.md` | 1 | `implemented/process` |
| `release-automation-2026-07-20.md` | 1 | `implemented/process` |
| `runbook-2026-08-17-sprint-closure.md` | 1 | `implemented/process` |
| `TODO-backlog-2026-07-19.md` | 1 | `proposed/process` (待办, 拍板中) |
| `kallax-timeline-2026-08-07.md` | 1 | `implemented/architecture` |
| `epic-numbering-strategy-2026-08-17.md` | 1 | `proposed/process` (策略待拍板) |
| `retrospective-2026-08-18-exec-task-log-deletion.md` | 1 | `implemented/process` |
| `index.md` | 1 | 不迁 (索引) |

迁移总工时估算:
- `git mv` + frontmatter 加 3 行 = 30 文件 × 5 min = 2.5h
- verify-agent-note-format.sh 开发 + hook 接入 = 2h
- PR review (master + 4 sub-roles) = 1h
- 主公拍板 1 事件 (跟 EPIC-225 同模式)
- **总计**: ~6h, 1 Sprint 内可完成, 跟 DSH 5.1 建议 1 估算 1 day 相同

## 6. 跟 EPIC-279 协同报

本提案 (Path A) 跟同批 EPIC-279 Path C (Doc Budgets) 同批报:

| 路径 | 文档 | 状态 |
|------|------|------|
| Path C (本批已落) | `scripts/check-doc-budgets.sh` + `budgets.manifest.json` | 落地, 接入 hook |
| Path A (本 paper) | Agent Note ADR lifecycle | **proposed, 待主公拍板** |

跟 EPIC-225 check-jargon 接入流程 1对1:
1. EPIC-279 Path C 已接入 pre-commit hook (verify exit 0)
2. Path A admission: 主公拍板 → 实施迁移 → verify-agent-note-format.sh 接入 → 9-immutable 数字 9→10 admission 走 §3 流程

## 7. Open Questions (待主公拍板)

1. **6 class 闭集**: 是否采纳 (feature/bug-fix/architecture/process/testing/simplification), 还是有自定义?
2. **path 模式**: `confluence/decisions/{lifecycle}/{class}/<date>-slug.md` 还是 `confluence/decisions/{lifecycle}/<class>-<date>-slug.md`? 前者跟 DSH 1对1, 后者 grep 友好
3. **迁移 30 文件**: 一次迁移还是分批 (按时间/类)? 一次 6h 可完成, 分批 0.5 EPIC × 3
4. **verify-agent-note-format.sh**: 跟 check-doc-budgets.sh 同 hook 链 (advisory) 还是 fail-closed 硬拦?
5. **9-immutable admission**: 验证脚本算不算 immutable? 跟 `check-ticket-schema.sh` 同型 (在 `scripts/verify/` 但 fail-closed) 应算; 跟 EPIC-225 check-jargon 同型已证实 fail-closed 不算"治理 fail-closed 脚本" (因为改动只需 PR review)

## 8. References

- DSH Report §4 Path A (`/tmp/kallax-vs-deepseek-harness-report.md:67-78`)
- DSH Report §5.1 建议 1 (`/tmp/kallax-vs-deepseek-harness-report.md:103-107`)
- EPIC-225 (`scripts/verify/check-jargon.sh` + `jira/tickets/.jargon-blacklist.json`) — admission 模式同型
- EPIC-159 — path-scoped lazy load, 类比 6 class 闭集可放 manifest
- EPIC-223 — `.archive-baseline.json` 划线历史, 跟"老文件不追溯" 1对1
- DSH 报告 附录 A 概念映射 row 4: "Agent Note (lifecycle+class) | confluence/decisions 平面"

---

> **Paper 状态**: proposed (待主公拍板 5 个 open question)
> **优先级**: 中 (DSH 报告 4/5/6 都列, 跟 Path C 同批, 不阻塞)
> **落地**: 拍板后单独建 EPIC-280 (或下个 batch) 实施 6h migration
