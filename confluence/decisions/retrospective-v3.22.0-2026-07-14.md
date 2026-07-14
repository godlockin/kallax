# Retrospective v3.22.0 — EPIC-115 lint debt + EPIC-116 jargon cleanup

> Date: 2026-07-14 | 8 PRs, ~1h total

## Summary

v3.22.0 解决了两大技术债:
- **EPIC-115**: typescript-eslint@8 strictTypeChecked 引入后 633 lint errors (108 files / 25 rules), 6 专家并行修复, 19 分钟完成
- **EPIC-116**: 722 装饰性黑话词汇 (联合/治根/反讽/战略 等), 2 专家并行清理
- **Backlog fix**: check-checkin-points auto-discovery bypass + gate-reviewer security finding

## 教训 #1: 并行 subagent 依赖 epic.json 蓝图

**问题**: EPIC-115-D subagent 完成但被 pre-commit hook 拦截,因为 epic.json 不存在于 testing branch。

**根因**: 子 agent 的 worktree 基于旧 testing,而 epic.json 是新 commit 的一部分。

**Fix**: 先 push 脚手架 (epic.json + audit doc) 到 testing,再派子 agent。

**验证**: 之后 EPIC-116 无此问题。

## 教训 #2: Pre-commit hook auto-discovery 假阳性

**问题**: check-checkin-points 和 check-epic-4-piece 在 pre-commit 上下文中 auto-discover 到 EPIC-070 (文件旧注释),导致硬阻塞。

**根因**: auto-discovery 搜索 staged files 内容时匹配到 EPIC-070,不是当前分支的 EPIC-115。

**Fix**: 加 `KALLAX_PRE_COMMIT=1` 环境变量标记,pre-commit 上下文跳过 auto-discovery。

## 教训 #3: 工作目录变更在 stash drop 后丢失

**问题**: 主 repo 工作目录有 100+ 文件修改 (EPIC-115/116 的副本)。`git stash drop` 后这些修改丢失,需重新提交。

**根因**: 子 agent 的工作在 worktree 中完成,但主 repo 的工作目录也有副本。

**Fix**: 工作目录修改应先 commit 到临时分支,再 rebase 到 miao。避免 stash drop 丢失。

## 教训 #4: 硬链接假设错误

**问题**: master 和 worktree 的 `scripts/verify/*.sh` 不是硬链接 (不同 inode)。master 的编辑不自动传播到 worktree。

**根因**: git worktree 创建时文件是独立副本,不是硬链接。

**Fix**: 显式 `cp` 从 master 到 worktree。

## 教训 #5: 黑话清理 75k 规模的实际操作

**问题**: 全代码库黑话扫描显示 75k+ 出现,但实际在代码中的只有 ~722 (node/src 101 + scripts 621)。

**根因**: 大部分在 markdown 自然语言 (CLAUDE.md, CHANGELOG)。CLAUDE.md 不可改,CHANGELOG 不可改。

**Fix**: 集中清理 node/src 和 scripts,跳过不可改文件。

## 指标

| 指标 | 值 |
|------|-----|
| Total PRs | 8 (6 EPIC-115 + 2 EPIC-116) |
| Total files changed | ~200 |
| Lines added/removed | ~1,500 |
| Subagents dispatched | 8 (6 lint + 2 jargon) |
| Merge conflicts | 0 |
| Duration | ~1h |