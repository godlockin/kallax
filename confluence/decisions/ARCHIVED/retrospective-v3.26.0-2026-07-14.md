# Retrospective v3.26.0 — EPIC-120 Automated PR Eval Framework

> Date: 2026-07-14 | 2 tickets, ~25min total

## Summary

v3.26.0 落地 OpenAI Evals 核心原则: automated PR gate (eslint + tsc + vitest)。

## 教训 #1: Security finding 是 false positive

**问题**: pr-eval.sh 被标记 4 个 MEDIUM argument/command injection。

**分析**: FILES 变量来自 `gh api` (GitHub) 和 `git diff` (local)，KALLAX 单用户内部模型，非外部攻击面。

**结论**: Security review 有用但不是 all-or-nothing。acknowledged 但不 blocking。

## 教训 #2: Testing/Miao drift 再次发生

**问题**: task-assigner.ts 在每次 merge 都冲突 (EPIC-118 → EPIC-119 → EPIC-120)。

**根因**: testing 和 miao 在 EPIC-118-C 的 expertise-aware dispatch 实现上 diverge。

**Fix**: 后续在 master review 前 rebase feature 到 testing tip，减少三方 diff。

## 指标

| 指标 | 值 |
|------|-----|
| Total tickets | 2 (A/B) |
| Merge conflicts | 1 (task-assigner.ts) |
| Security findings | 4 (all acknowledged false positive) |
| Duration | ~25min |
| Release | v3.26.0 |
