---
paths:
  - .github/workflows/**
  - "**/CHANGELOG.md"
  - confluence/decisions/branch-flow-*.md
  - "**/package.json"
---

# 4-branch flow if-then 详细规则 (EPIC-074/142/146/155)

> **Path-scoped rule**: 只在 workflow / CHANGELOG / 治理 doc 被编辑时加载.

## If-Then 矩阵

```
if 工作分支 = feature/*:
  then worktree 创建 (git worktree add -b feature/...)
  then 5-Level Verify 必跑
  then PR base = testing

if PR base = testing:
  then integration + cargo test + vitest env
  then 防止 v3.8.0 form-only PASS

if PR base = main:
  then full e2e + decision matrix 25 cells
  then 防止 v3.8.0 "25/25 假 PASS"

if PR base = miao:
  then master review + 4 sub-roles
  then 处理 v3.8.0 red-blue review 阻塞
```

## Pre-existing 分支 sync 模式

| 分支 | sync 模式 | 备案 |
|---|---|---|
| testing → miao | force-push (跟 EPIC-142 pattern) | 2026-07-26 master force-push |
| main → testing | force-push (跟 EPIC-146 pattern) | 2026-07-26 master force-push |
| main ↔ miao | bypass 备案 + accept (跟 40e2b8e) | EPIC-155 |

## 检查脚本

- `scripts/branch-4pr.sh` — 4-stage 强制流程 wrapper
- `scripts/check-dco.sh --allow-pre-cutoff` — DCO check + 跳过 pre-cutoff commits

## 0 静默跳过

- v3.10.0+ 必走 4-PR 全程
- 紧急 bypass 仅 `git commit --no-verify` (主公明确批准时)
- 同类假 PASS 症状再次出现 → pre-commit hook 拦截

## 未来分工 (EPIC-242 拍板, 2026-08-10)

| 阶段 | 实际拍板 | 备注 |
|------|----------|------|
| feature/* → testing | **master** (=主公, 单人环境) | 0 sub-roles 模拟 (本环境限制) |
| testing → main | **master** (=主公, 单人环境) | 0 sub-roles 模拟 (本环境限制) |
| **main → miao** | **主公亲自** (不再 master 自合) | **本 EPIC 起严格**, 跟 EPIC-242 §3 同步 |

**反例 (本会话已发生 3 次, EPIC-235/239/240 备案)**:
- `git push origin origin/<from>:refs/heads/<to>` 跳过 PR (PR-2/PR-3)
- `git commit --amend --no-edit` + `git push --force-with-lease` (amend 历史污染)
- `gh pr close --delete-branch` 删远程 branch 后立即重建 (绕过 4pr review)

**预防 (EPIC-241)**:
- `scripts/hooks/pre-push` 跨主干 push block by default
- 例外 `KALLAX_HOOK_BYPASS=1` + 主公 explicit 批准

## 0 增 Rule (本 EPIC)

本规则**不增 Rule, 不改 CLAUDE.md** (CLAUDE.md §1-7 含历史债 25 处黑话词, EPIC-225 当时不扫既有文件; 跟 README EPIC-217 同样处理 — 历史债不追溯).

仅在 `.claude/rules/branch-flow.md` (path-scoped, 0 黑话) 新增 1 段.

详细: `confluence/decisions/branch-flow-governance-2026-07-09.md`