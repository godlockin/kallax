# EPIC-202-B: 流程治理修 — 拍板记录 (2026-08-07)

> **起源**: Process 专家 (ad978b7f51da6f84e) 对抗式 review EPIC-197/199/200/201 后挑刺 7 项 CRITICAL/MAJOR。
> **对抗 review**: Process 专家 round 2 验证本 EPIC 修复, 0 CRITICAL 才进 4-PR。

## 修复清单

| # | Severity | 问题 | 修法 | 状态 |
|---|----------|------|------|------|
| 1 | CRITICAL | Step 7 retrospective 缺 × 3 (EPIC-197/200/201) | 补 3 个 retrospective 文件 | ✅ |
| 2 | CRITICAL | Step 8 缺 — 4 feature branches 未删 | push origin --delete × 4 | ✅ |
| 3 | CRITICAL | Rule 36 Sprint 北极星 NO_DATA | 文档化 (docs-only EPIC 不会触发 ticket workflow, NO_DATA 是 expected) | ✅ |
| 4 | MAJOR | EPIC-199 commit SHA 重复 53828135 | 已 merge 进 miao, 不能改历史 (跟 EPIC-155/176 1:1 forward-only 模式) | ⏸️ deferred |
| 5 | MAJOR | check-body 12/15 PR 失败 | docs-only PR body template 必填 7-class risk schema (待 EPIC-202-C 修, 跟 EPIC-069-D check-claim-evidence 1:1) | ⏸️ deferred |
| 6 | MAJOR | Rule-of-500 violation (3 commit 超 500 行) | 跟 EPIC-198 docs-only exempt 1:1 模式 (docs-only EPIC 允许超 500 行, source code EPIC 严守) | ⏸️ deferred (documented) |
| 7 | NIT | EPIC-197 e9a4cf39 / 6ce4abeb 两个 commit 近重复 | 已 merge, 不能 amend (跟 EPIC-155/176 历史债 1:1 pattern) | ⏸️ deferred |

## 拍板决定

主公拍板(2026-08-07):
1. **Forward-only fix**: 已 merge 的 commit 不 amend, 跟 EPIC-155/176 Q3 2026 re-promote 模式 1:1 (主公 Phase 3+5 A 拍接受丢失)
2. **Docs-only EPIC Rule-of-500 exempt**: docs-only EPIC 允许单 commit > 500 行 (避免拆 commit 破坏 git rename detection). source code EPIC 严守 ≤ 500 行.
3. **NO_DATA 是 docs-only EPIC 的 expected state**: docs-only EPIC 不触发 ticket workflow (EPIC-021-F expert_invocations + ticket.json binding), metrics 必然 NO_DATA. Rule 36 silent PASS 禁的是 "假装有数据", docs-only NO_DATA 是诚实.

## 4 Lessons

### 1. 8-step 流程是 EPIC 闭环强制
**教训**: EPIC-197/200/201 当时只跑 step 1-5 (publish + 4-PR), 跳了 step 6 (整理) 跟 step 7 (retro). 导致 3 EPIC 缺 retro, Process 专家挑刺.
**应用**: future EPIC 必走 8-step, 不能跳. Step 7 retro 必写 (哪怕 "无新教训" 也是 retrospective).

### 2. Rule-of-500 跟 docs-only 互不冲突
**教训**: docs-only EPIC 单 commit > 500 行是 acceptable (避免拆 commit 破坏 git rename), 但 source code EPIC 严守.
**应用**: future docs-only EPIC 在 commit message 注明 "docs-only, Rule-of-500 exempt per EPIC-198 + EPIC-202-B".

### 3. Step 8 feature branch 删除必须
**教训**: 4 feature branches merged 后未删, 占 remote 列表, 让 future reader 困惑 (哪个 branch active).
**应用**: 4-PR 完成 + merge 后必 `git push origin --delete feature/X`. 跟 install.sh Omnibus 1:1.

### 4. Sprint metrics NO_DATA 透明化
**教训**: 4 个 docs-only EPIC 跑 sprint-metrics.sh → ALL_NO_DATA. 看着像 silent PASS 违规, 实际是 docs-only EPIC 不触发 ticket workflow 的 expected 状态.
**应用**: docs-only EPIC 拍板记录必注明 "docs-only, sprint-metrics NO_DATA expected".

## 验证

- `bash scripts/metrics/sprint-metrics.sh --epic EPIC-197` → ALL_NO_DATA (expected, docs-only)
- `git branch -r --merged origin/miao | grep feature/EPIC` → 不含 4 deleted branches

## 联动

- EPIC-198 (docs-only CI exempt) + EPIC-202-B: docs-only EPIC 全套 governance 一致
- EPIC-069-D check-claim-evidence (12 PR CI 失败): 待 EPIC-202-C 修 PR body template

---

Co-Authored-By: Claude <noreply@anthropic.com>