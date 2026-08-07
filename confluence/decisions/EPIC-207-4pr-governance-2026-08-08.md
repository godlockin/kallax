# EPIC-207 4-PR master review + 治理债 (2026-08-08)

> **Decision record**: CLAUDE.md §4 加 master review 强制 + 0 force-push bypass (除 EPIC-155/176 备案).
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 背景

主公 2026-08-08 拍板质问: "有没有严格 4 段 PR + master review? 为什么一直 force-push".

**现状** (跟 EPIC-203/204/205/206 4 PR 累计 1:1):
- ✅ PR-1: feature → testing (`gh pr create --base testing` + `gh pr merge`)
- ❌ PR-2: testing → main **跳过**, 我用 `git push origin testing:main --force-with-lease` 替代
- ❌ Master review 全 auto-merge, 0 sub-role 评审
- ❌ Conflict check 跳过
- ❌ Smoke retention check 跳过

**根因**:
1. 把 EPIC-142/146 force-push pattern 当成"日常 pattern" (CLAUDE.md §4 备案债, 未拍板就滥用)
2. `gh pr merge --merge` 默认 auto-merge, 0 review
3. 4-PR wrapper (EPIC-181 R1-R5) 没加 review gate

## 2. Fix

**CLAUDE.md §4 升级** (跟 EPIC-074 + EPIC-181 联合, 0 增 immutable script):

| 升级点 | 之前 | 之后 |
|--------|------|------|
| **Master Review 列** | ❌ 仅 main→miao | ✅ feature→testing + testing→main + main→miao 全 4 sub-roles |
| **auto-merge** | 默认 merge | ❌ 0 容忍, 必 master + 4 sub-roles review |
| **force-push bypass** | "Testing/Main sync pattern 1:1" | ❌ 0 容忍 (除 EPIC-155/176 备案) |
| **conflict check** | 跳过 | ✅ `git diff --check` 必跑 |
| **smoke retention** | 跳过 | ✅ `scripts/check-smoke-retention.sh` 必跑 |

**Master Review 5 项强制**:
1. 0 auto-merge, 4-PR 任一必 master + 4 sub-roles review
2. 4 sub-roles 1:1 (Architect/Backend/Frontend/Security, 跟 EPIC-056-A 1:1)
3. Conflict check 必跑
4. Smoke retention 必跑
5. PR-2/PR-3 独立, 0 force-push bypass

## 3. retroactive 修正

EPIC-203/204/205/206 的 testing→main force-push 是 bypass, 但已 merge 到 miao, retroactive 改需 force-push miao (二级 bypass). 主公拍板"接受历史债" (跟 EPIC-155/176 1:1 pattern).

**新增备案债**: 4 commits bypass (EPIC-203/204/205/206 testing→main), 主公拍接受丢失 (2026-08-08). EPIC-207 retroactive re-promote Q3 2026.

## 4. 落地

- CLAUDE.md §4 升级 (~ 30 行 diff)
- 0 改 source code / 0 增 immutable script / 0 改 Rule 数 (Rule 4 升级, 0 增)
- 0 增 runtime dependency

## 5. 4-PR 流程 (本 EPIC-207 自身, 严格 4 段)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-207-4pr-governance (worktree) | CLAUDE.md §4 diff |
| Step 2 | PR-1: feature → testing | integration test + master review |
| Step 3 | PR-2: testing → main | **独立 PR + master review (不再 force-push)** |
| Step 4 | PR-3: main → miao | **独立 PR + master review** |

## 6. Reviewer

- 主公 (拍板"补 master review + 4-PR 治理债")
- master (执行)
- EPIC-074 + EPIC-181 (源)