# EPIC-208 治理债闭环 (2026-08-08)

> **Decision record**: PR-2 v2 修正 doc 落地 + force-push 备案债 (4 commits) + CLAUDE.md §6 5 条 EPIC 补录.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 范围

EPIC-207 闭环后发现 3 项治理债, 闭环在 EPIC-208:
1. PR-2 架构修正 (FF 关系下独立 PR 不可行)
2. force-push 备案债 (4 commits)
3. CLAUDE.md §6 5 条 EPIC 补录

## 2. 落地

### 2.1 PR-2 架构修正 doc 落地

文件: `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md`

追加 §5.1 "PR-2 架构修正 (v2, 主公 2026-08-08 拍板)":
- testing → main FF 关系下独立 PR 不可行 (`gh pr create --base main --head testing` GraphQL: "No commits between main and testing")
- 主公拍板"FF + commit message 验证"
- 修正方案: FF push + master review comment 模式 (post-merge)
- **EPIC-207 §5 修订** (v2): PR-1 + PR-3 独立 PR, PR-2 FF push + comment 验证

### 2.2 force-push 备案债 (4 commits, 主公拍板接受丢失)

文件: `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md`

追加 §5.2 "force-push 备案债 (4 commits, 主公 2026-08-08 拍板接受)":
- EPIC-203/204/205/206 testing→main 4 次 force-push (`git push origin testing:main --force-with-lease`)
- 当时认为是合规 (跟 EPIC-142/146 pattern 1:1)
- 主公 2026-08-08 拍板: 接受丢失 (跟 EPIC-155 + EPIC-176 Phase 3/5 A 1:1 pattern)
- **EPIC-208 retroactive re-promote**: Q3 2026 跟 EPIC-155/176 一起

### 2.3 CLAUDE.md §6 5 条 EPIC 补录

文件: `CLAUDE.md §6 Recent EPICs` 表追加 5 行:

| EPIC | Version | 关键 |
|------|---------|------|
| EPIC-203 | (审计) | 4-expert 26 项审计闭环 |
| EPIC-204 | (sprint-metrics) | docs-only metrics 适配 |
| EPIC-205 | (retrospective) | retrospective-routine.sh 6 阶段 + KALLAX_ROOT fix |
| EPIC-206 | (manifesto) | 5 文件战略归一 |
| EPIC-207 | (governance) | 4-PR master review + 0 force-push |
| EPIC-208 | (governance-debt) | 治理债闭环 (本 EPIC) |

更新 "0 增 Rule, 0 增 immutable script, 0 改 source code for all 19 EPICs" → 24 EPICs.

## 3. 0 改 source code / 0 增 Rule / 0 增 immutable script

跟 EPIC-197/199/200/201/202-A/B/C 1:1 pattern, 纯 docs-only 治理债闭环.

## 4. 联动

- **EPIC-207**: 4-PR master review 强制 (本 EPIC 修正 PR-2)
- **EPIC-155 + EPIC-176**: force-push 历史债备案 (pattern 1:1)
- **EPIC-197/199/200/201**: docs-only SoT 归并 (本 EPIC 1:1)
- **EPIC-205**: retrospective-routine 跑批 (5 EPIC 累计合规)

## 5. 4-PR 流程 (本 EPIC-208 自身)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-208-governance-debt (worktree) | 3 文件 diff |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | **FF push + master review comment** (跟 EPIC-207 v2 1:1) |
| Step 4 | PR-3: main → miao | 独立 PR + master review |

## 6. Reviewer

- 主公 (拍板"修治理债")
- master (执行)
- EPIC-207 + EPIC-155 + EPIC-176 (源)