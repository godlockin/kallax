# Retrospective v3.24.0 — EPIC-118 Expertise-aware Dispatch

> Date: 2026-07-14 | 3 tickets, ~45min total

## Summary

v3.24.0 将 Anthropic Claude Code Research 关键洞察落地:
- **abandonment_rate metric** — performer 失联率, target <10%
- **mastery_level schema** — L1/L2/L3 expertise 分层
- **expertise-aware checkpoints** — assignTask 时动态设 checkpoint_interval

## Anthropic Research 原文数据

| Metric | Novice | Expert | KALLAX Target |
|--------|--------|--------|----------------|
| Abandonment rate | 19% | 5-7% | <10% |
| Verified success | 15% | 28-33% | — |

## 教训 #1: Testing 分支 drift 导致 conflict 反复

**问题**: gate-reviewer.ts + check-checkin-points.sh 在 3 次 merge (feature←testing←miao) 中反复冲突。

**根因**: testing 和 miao 在 EPIC-115/116/117/118 期间各自演进, testing 有 EPIC-117 但无 EPIC-118-C, miao 有 backlog fix 但无 EPIC-117。

**Fix**: 后续 EPIC 先完整 commit 到 feature, merge 前先 rebase 到 testing tip, 减少三方 diff。

## 教训 #2: EPIC-118-C 在 merge 中丢失

**问题**: merge testing→miao 时, task-assigner.ts 的 EPIC-118-C 部分被 testing 版本覆盖(测试分支没有 C commit)。

**根因**: feature branch push 先于 merge, 导致 testing 基于旧 feature 创建。

**Fix**: 所有 5 ticket commits 先 commit 到 feature, 再 push + PR, 不提前 push。

## 教训 #3: Shell 冲突用 python3 解决更可靠

**问题**: Edit tool 无法处理 conflict marker 嵌套 (<<<<<< HEAD / ======= / >>>>>>>)。

**根因**: Edit tool 要求精确 string match, conflict block 多行难以精确匹配。

**Fix**: `python3` 脚本逐行处理, 跳过冲突区域更可靠。

## 指标

| 指标 | 值 |
|------|-----|
| Total tickets | 3 (A/B/C) |
| Total PRs | 2 (feature→testing + testing→miao) |
| Merge conflicts | 2 files × 3 次 = 6 次 resolved |
| Duration | ~45min |
| Release | v3.24.0 |
