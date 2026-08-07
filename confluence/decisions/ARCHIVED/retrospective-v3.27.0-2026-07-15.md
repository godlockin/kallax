# Retrospective v3.27.0 — EPIC-121 沙箱 Eval + Tiered Memory

> Date: 2026-07-14/15 | 2 tickets, ~40min total

## Summary

v3.27.0 落地 SWE-bench Docker 沙箱 + LangChain Tiered Memory 原理:
- **pr-eval.sh --docker**: SWE-bench 3 层容器隔离
- **performer-profile.ts + cli**: LangChain Buffer/Summary/VectorStore 分层

## 教训 #1: Squash merge 丢失后续 commit

**问题**: PR #138 squash merge 只捕获创建时的 HEAD commit，不捕获后续 commit。

**根因**: EPIC-121-A + B 在 PR 创建之后 commit + push，squash merge 没有更新。

**Fix**: PR 创建后再 commit 的文件需单独补。

## 教训 #2: Squash merge 是差量不是快照

**问题**: Squash merge 显示所有文件，容易误以为是快照。

**根因**: Squash merge 比较 base 和 HEAD 的 diff，巨大的 diff 不等于快照。

**Fix**: Squash merge 后立即验证关键文件存在。

## 指标

| 指标 | 值 |
|------|-----|
| Total tickets | 2 (A/B) |
| Lost files restored | 3 (Dockerfile.eval, performer-profile.ts, cli) |
| Squash merge artifact | 1 |
| Duration | ~40min |
| Release | v3.27.0 |
