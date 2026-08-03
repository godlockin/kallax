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

详细: `confluence/decisions/branch-flow-governance-2026-07-09.md`