---
paths:
  - CLAUDE.md
  - confluence/decisions/EPIC-216-*.md
---

# Rule 37 — 小 effort auto-approve (EPIC-216, 2026-08-08)

> **Path-scoped rule**: 只在 CLAUDE.md / EPIC-216 decision doc 修改时加载.
> **来源**: 主公 2026-08-08 拍板"effort 比较小的直接 auto-approve".

## 1. 起因

主公 2026-08-08 拍板"effort 比较小的直接 auto-approve", 跟 EPIC-207 §1 "0 容忍 auto-merge" 矛盾, 主公拍板 override.

## 2. Rule (强制)

### 2.1 小 effort 阈值 (master auto-approve PR-3)

EPIC 同时满足以下**全部** → master auto-approve PR-3 (miao merge), 不等主公:

- **0 改 source code** (跟 EPIC-198 docs-only exempt 1:1)
- **≤ 100 行 diff** (跟 Rule 8 Rule-of-500 联合, 100 是 500 的 1/5 更严 threshold)
- **仅 1 个 commit** (跟 Rule 35 ≤ 10 commits/EPIC 联合)
- **决策 doc 含 ≥ 1 段 "联动 + Reviewer"** (跟 EPIC-197 1:1 联合)

### 2.2 PR-1 + PR-2 仍走 master review

- **PR-1 (feature → testing)**: master + 4 sub-roles (Architect/Backend/Frontend/Security)
- **PR-2 (testing → main)**: FF push + master review comment (跟 EPIC-207 v2 §5.1 1:1)
- **PR-3 (main → miao)**: master review comment + `[auto-approve-Rule37]` tag + 4 项 checklist + 直接 merge (本 Rule 简化)

### 2.3 PR-3 master review checklist 必填

PR-3 comment 含 `[auto-approve-Rule37]` tag + 4 项验证:

1. **文件 diff stat** (`git diff --stat origin/miao..HEAD`)
2. **0 source code change 验证** (`git diff --stat | grep -E "\.(ts|rs|js|sh)$"` 为空)
3. **≤ 100 行 diff 验证** (`git diff --shortstat`)
4. **单 commit 验证** (`git log --oneline origin/miao..HEAD | wc -l = 1`)

### 2.4 master auto-approve 动作

满足 4 项 checklist → master 直接 `gh pr merge --merge`, **不等主公亲自 approve**.

## 3. 例外 (主公亲自拍板 0 跳过)

| 类别 | 原因 |
|------|------|
| 任何改 Rule / immutable script / public-facing file (README/CHANGELOG/SKILL.md/CLAUDE.md) | Rule 改必主公拍板 (跟 EPIC-207 0 容忍 1:1) |
| 任何 source code change (.ts/.rs/.js/.sh 改动) | source code 风险需主公亲自审 |
| 任何 4-PR bypass | 跟 EPIC-208 §5.2 备案债 1:1 |
| 任何 sprint-metrics 改动 | Rule 36 + EPIC-194/204 联合 |
| 任何 commit > 100 行 | 跟 Rule 8 联合 |
| 任何 EPIC 是 "EPIC-XXX 备案债" / "force-push 修复" 类 | 跟 EPIC-155/176/208 1:1 |

## 4. 跟现有 Rule 联合 (0 增冲突)

- **Rule 4 (4-branch flow)**: PR-1 + PR-2 + PR-3 仍 4 阶段, 仅 PR-3 跳过主公
- **Rule 5 (DRY)**: master auto-approve 不代表 0 验证, 4 项 checklist 必填
- **Rule 8 (Rule-of-500)**: ≤ 100 行是 Rule 8 ≤ 500 行的更严 threshold
- **Rule 35 (Sprint 时间盒)**: 单 commit 跟 ≤ 10 commits 联合
- **Rule 36 (4 北极星)**: sprint-metrics 改动例外, 必主公亲自
- **EPIC-069-D (5-Level Verify)**: docs-only EPIC 仍走 L1-L3
- **EPIC-074 + EPIC-207 (4-PR + master review)**: 仅 PR-3 跳过, PR-1 + PR-2 仍 master + 4 sub-roles

## 5. 0 改 source code / 0 增 Rule 数 (Rule 37 是新 Rule, +1)

注: 这是 v3.34.6 + 1 新 Rule (Rule 37), 跟 EPIC-157 (Rule 36) 增量一致. 总 Rule 数 36 → 37.

## 6. 4-PR 流程 (本 EPIC-216, 严格 EPIC-207 v2 + Rule 37 适用)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-216-rule-37 (worktree) | CLAUDE.md §6.4 + .claude/rules/rule-37.md |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | FF push + master review comment |
| Step 4 | PR-3: main → miao | master auto-approve (本 Rule 适用, 不等主公) |

## 7. Reviewer

- 主公 (拍板"小 effort 直接 auto-approve")
- master (执行)
- EPIC-207 (4-PR governance 源, 本 Rule 是 override)
- EPIC-198 (docs-only exempt 源)