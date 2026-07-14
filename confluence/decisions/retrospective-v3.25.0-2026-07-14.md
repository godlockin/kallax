# Retrospective v3.25.0 — EPIC-119 Tool Orchestration

> Date: 2026-07-14 | 3 tickets, ~30min total

## Summary

v3.25.0 将 OpenAI Building Agents 3-class tool taxonomy 落地：
- **Data**: retrieve context, read-only (7 commands)
- **Action**: execute operations, write state (16 commands)
- **Orchestration**: agent as tool for other agents (7 commands)

## 教训 #1: Testing/Miao 分支 drift 成常态

**问题**: 每次 EPIC，testing 和 miao 都因历史原因 diverge，导致 merge conflict 成了标准流程。

**根因**: v3.8.1-3.9.2 5 release 跳过了 testing/main，累积了 baseline drift。

**Fix**: 后续所有 EPIC 都走 feature → testing → miao 全程，testing 在 PR merge 后立即推 miao，避免再次 drift。

## 教训 #2: Python 替代 bash 3.2 限制

**问题**: classify-tools 写 bash 时，macOS bash 3.2 不支持 `declare -A` (associative array)。

**根因**: bash 3.2 限制。

**Fix**: 用 Python 重写 (scripts/tools/classify-tools.sh 实际是 python3 脚本)，保持 shebang `#!/usr/bin/env python3`。

## 指标

| 指标 | 值 |
|------|-----|
| Total tickets | 3 (A/B/C) |
| Total commits | 4 |
| Merge conflicts resolved | 1 (task-assigner.ts) |
| Duration | ~30min |
| Release | v3.25.0 |
