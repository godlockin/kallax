# confluence/_archived Index

> **历史决策归档**: 30+ file (decision 跟 pitfalls), 占 confluence 总数 50%, 归档原理:
> 1. 跟 `docs/_archived/README.md` 一致 — past 时代决策不污染 active reading
> 2. **每个 EPIC 还在 git log 里** — 不丢 audit trail
> 3. active 决策走 `confluence/decisions/index.md` (本仓 v3.31.0 时剩 3 篇 ADR + 2 篇战略)

## 归档策略

| 决策类型 | 留存条件 |
|---|---|
| **架构 ADR** (永久, .architect-decision-records.md 风格) | 永久 -- 跨 EPIC 不变 |
| **项目重大决策** (branch flow governance / DCO / 等) | 永久 -- 项目级契约 |
| **借鉴策略 doc** (borrow-from-cindy / eket-borrow-methodology) | 永久 -- 跨 release reference |
| **EPIC retrospective** (v3.22-v3.27 era 或 v3.28 era lessons) | **归档** -- 跟 release history 进 archived/, lessons 进 confluence/research/ 或 confluence/memory/ 永久区 |
| **Branch / process transient** (branch-recovery / branch-sync / release-automation 7月) | **归档** -- 一次性 use case, replaced by EPIC-142 (testing sync) + EPIC-146 (main sync) + 4-branch governance in CLAUDE.md |
| **TODO backlog** (`TODO-backlog-2026-07-19.md`) | **归档** -- 已 closeout |
| **Pitfalls** (6 v3.0-v3.7 era) | **归档** -- 7 release stable, 新 lessons 在 confluence/decisions/ |

## Active Index

跟 `confluence/decisions/index.md` 同步 (这是 active 决策的真实 SoT)

| Active file | 用于 |
|---|---|
| confluence/decisions/index.md | 总索引 + 链接各 active ADR |
| confluence/decisions/adr-016-a-mcp-lazy-loading-2026-06-06.md | L1 init 性能 ADR |
| confluence/decisions/adr-016-b-skill-metadata-discovery-2026-06-06.md | L1 init 性能 ADR |
| confluence/decisions/borrow-from-cindy-2026-07-26.md | v3.29.0 借鉴决策 + L2 候选 |
| confluence/decisions/eket-borrow-progress-2026-06-11.md | eket 借鉴进展记录 |
| confluence/decisions/fact-forcing-independent-repro-2026-07-26.md | Rule 34 + 6 case 教训 |
| confluence/decisions/branch-flow-governance-2026-07-09.md | **已 archive by v3.31 trim — but doc 仍 readable** |
| confluence/decisions/index.md (主索引) | **SoT for decisions, hit this first** |

## 归档历史索引

| 段 | 文件 | Era |
|---|---|---|
| retrospective | retrospective-sprint-4-7-epic-101-2026-07-09.md | v3.29 era |
| retrospective | retrospective-v3.22.0 / -v3.23.0 / -v3.24.0 / -v3.26.0 / -v3.27.0 | v3.22-v3.27 era (5 files) |
| v3.28 era | epic-130-to-133-journey + epic-131-ts-strict + epic-133-worktree + epic-135-a-guided-research | 4 files |
| 7.9-20 transient | branch-flow-governance + branch-recovery + branch-sync + release-automation + TODO-backlog | 5 files |
| EPIC retros | EPIC-113-A-and-EPIC-114 + EPIC-114-vitest-scan + EPIC-115-lint-audit + EPIC-117-simplicity + EPIC-118-expertise + EPIC-119-tool-orchestration + EPIC-120-eval + EPIC-121-sandboxed + EPIC-122-E + EPIC-124 | 10 files |
| pitfalls | async-test-leak + conductor-single-point-failure + context-explosion + epic-016-postmortem + hallucination-deviation-log + review-016-postresult-hang | 6 files (v3.0-v3.7 era) |

## Use Cases

- **未来 reader**: 看 `confluence/decisions/index.md` 找 active doc; 想挖历史可以看本 `confluence/_archived/index.md` + git log
- **未来 master (主公)**: 不再 reset/rewrite 历史, 归档即"可追溯 but 不污染"

## 不动 guard

- **本目录所有 file** 同样是 `git mv` 不编辑 (跟 docs/_archived 一致)
- 每 file 仍可 `git log -p -- FILE` 查原 commit line
