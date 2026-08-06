# Commit Hygiene 备案 (EPIC-176)

> **起源**: 主公 2026-08-05 Phase 5 A 拍板 — "commit history 时间顺序修整, 跟 EPIC-155 1:1 pattern"
> **跟 EPIC-155 备案 1:1**: 不强 rebase 改写 history, 改为 hygiene 备案 + 未来指南

## 1. 主公拍板 (跟 EPIC-155 1:1)

**拍板内容**:
- **接受 hygiene issue documented** — commit history 存在 3 类问题(详见 Section 2)
- **不强 rebase 改写 history** — 保留原始 commit 链, 不做 interactive rebase
- **改为写 hygiene 备案 + 未来指南** — 新增 `confluence/decisions/commit-hygiene-2026-08-05.md` + `docs/reference/commit-hygiene-pattern-2026-08-05.md`

**拍板理由 (Phase 5 A)**:
1. **风险控制** — rebase 会改写 SHA, 影响已发布的 tag (v3.32.0~22)
2. **成本收益** — hygiene issue 已通过 force-push 同步分支 (EPIC-142/146), 再 rebase 收益有限
3. **备案价值** — 记录问题 + 未来指南 > 改写 history

**跟 EPIC-155 1:1 pattern**:
| 维度 | EPIC-155 | EPIC-176 |
|------|----------|----------|
| 问题类型 | 4-branch bypass | commit history hygiene |
| 拍板 Phase | Phase 3 | Phase 5 A |
| 处理方式 | 备案 + 接受丢失 | 备案 + 未来指南 |
| rebase | 0 | 0 |

## 2. 3 类问题详化

### 2.1 EPIC-163 amend 后 SHA 错乱

**问题描述**: EPIC-163 merge commit 被 amend 两次, 导致 SHA 错乱

**时间线**:
```
原始:
f8e6fa4 merge: EPIC-163 public/private boundary (v3.32.7)  ← 原始 merge

第一次 amend:
4d999d0 feat(EPIC-163): Public/Private Boundary + check-private-context.sh  ← amend 后新 commit

第二次 amend:
b672998 merge: EPIC-163 public/private boundary (v3.32.8)  ← 再次 amend
  └─ Merge: c1cb0e6 319063f
  └─ 实际内容: EPIC-163 + EPIC-167 ticket (SHA 319063f)
```

**影响**:
- SHA `f8e6fa4` (v3.32.7) vs `b672998` (v3.32.8) 时间顺序混乱
- `b672998` merge message 声称 v3.32.8, 但包含 EPIC-167 ticket (应该在 v3.32.12)
- 跟后续 6 EPIC (164/165/166/167/168/169) merge 顺序无法对应版本号

**根本原因**:
- 用 `git commit --amend` 修改已 push 的 merge commit
- amend 后 SHA 变化, 但 merge message 未同步更新

**修复措施** (EPIC-176 不采用 rebase):
- 备案问题 (本文档)
- 未来指南: 不用 amend 改 commit message (见 Section 4)

### 2.2 EPIC-167 ticket 误路径

**问题描述**: 早期 worktree 内部 add 时 force-add 误写 `.claude/worktrees/.../jira/...` 路径

**证据**:
```
commit 319063f
Author: Agent <agent@kallax.test>
Date:   Wed Aug 5 03:26:00 2026 +0800

    docs(jira): EPIC-167 AC1 sync branch=miao (跟 .gitmodules 实现一致)

    跟 EPIC-162 1:1 merge conflict 已解 (CLAUDE.md table + Section 7 Security Rules).
    0 增 Rule, 0 增 immutable script, 0 改 source code.
```

**影响**:
- ticket.json 路径错误: `.claude/worktrees/.../jira/tickets/EPIC-167/ticket.json`
- 应该路径: `jira/tickets/EPIC-167/ticket.json`

**根本原因**:
- worktree 内部 `git add .` 时未排除 `.claude/worktrees/` 路径
- EPIC-162 的 gitignore fix 后才解决 (`cfbac7a fix(gitignore): allow jira/ tracked inside worktrees`)

**修复措施** (EPIC-176 不采用 rebase):
- 备案问题 (本文档)
- 未来指南: worktree ticket 永远走 main repo force-add (见 Section 4.3)

### 2.3 EPIC-168-BG 跟 EPIC-170 3-way conflict

**问题描述**: 多次 merge 后 CLAUDE.md / CHANGELOG 段重复 + 顺序错

**时间线**:
```
EPIC-168-BG merge (fb8a203):
merge: EPIC-168-BG daemon 3 bug 修复 + 北极星 dashboard (v3.32.14)
  └─ CLAUDE.md Section 6 新增 EPIC-168-BG entry

EPIC-170 merge (e041400):
merge: EPIC-170 完整 plugin 化 (v3.32.16)
  └─ CLAUDE.md Section 6 新增 EPIC-170 entry

3-way conflict 点:
  └─ CLAUDE.md Section 4 (4-branch bypass 段) — EPIC-155 vs EPIC-176 两次修改
  └─ CHANGELOG.md — v3.32.14 vs v3.32.16 entry 顺序
```

**影响**:
- CLAUDE.md Section 4 存在重复 entry (EPIC-155 已有 3 commits, EPIC-176 扩展 2 commits)
- CHANGELOG entry 顺序跟版本号不对应

**根本原因**:
- 4-PR 流程中 testing/main 分支 force-push (EPIC-142/146) 导致 merge base 变化
- 多 EPIC 并行开发时 CHANGELOG merge conflict 手工解不当

**修复措施** (EPIC-176 不采用 rebase):
- 备案问题 (本文档)
- 未来指南: merge conflict 优先 ours + 手工加新 entries (见 Section 4.4)

## 3. 5 兜底 commit 备案 (跟 EPIC-155 1:1)

**来源**: 4-branch bypass 历史债 (EPIC-155 3 commits) + 本 EPIC 扩展 (EPIC-176 2 commits)

| # | Commit SHA | Message | 备案 EPIC |
|---|------------|---------|-----------|
| 1 | `a8da33f` | merge: EPIC-155 4-branch bypass 备案 (v3.31.6) | EPIC-155 |
| 2 | `1482ffa` | docs(EPIC-155): 4-branch bypass 备案 (v3.31.6) | EPIC-155 |
| 3 | `40e2b8e` | docs(EPIC-155): 4-branch bypass 备案 (v3.31.6) | EPIC-155 |
| 4 | `30e923a` | fix(security): EPIC-175-fix JSON injection MEDIUM (2 处 jq -n 替代 printf) | EPIC-176 |
| 5 | `33ecc9b` | feat(jira): EPIC-176 commit history 修整 ticket (主公 Phase 5 A, 跟 EPIC-155 1:1 pattern) | EPIC-176 |

**主公拍板**: 接受 5 commits bypass, Q3 2026 考虑 retractively re-promote (跟 EPIC-155 计划 1:1)

**raw output**:
```
git log --oneline a8da33f..33ecc9b --ancestry-path
  a8da33f → 1482ffa → 40e2b8e → 30e923a → 33ecc9b
```

## 4. 拍板理由 (Phase 5 A 备案而非 rebase)

### 4.1 风险控制

| 风险 | rebase 方案 | 备案方案 |
|------|------------|----------|
| SHA 变化 | 影响 22 个已发布 tag | 0 影响 |
| CI/CD 引用 | 需更新所有 reference | 0 更新 |
| 协作冲突 | 可能跟其他 worktree 冲突 | 0 冲突 |

### 4.2 成本收益

| 成本/收益 | rebase 方案 | 备案方案 |
|----------|------------|----------|
| 开发时间 | 4-8 小时 (interactive rebase) | 1 小时 (写文档) |
| reviewer 时间 | 2-4 小时 (rebase review) | 0.5 小时 (docs review) |
| 收益 | history 整洁 | 未来指南防复发 |

### 4.3 主公决策

主公拍板 **备案方案** (Phase 5 A):
- 接受 hygiene issue documented
- 不强 rebase 改写 history
- 写 hygiene 备案 + 未来指南
- Q3 2026 retractively re-promote (可选)

## 5. 未来指南引用

**文档**: `docs/reference/commit-hygiene-pattern-2026-08-05.md`

**5 条 pattern**:
1. 不用 amend 改 commit message (create new commit)
2. 不用 reset --hard 改 history (用 revert 或新 commit)
3. worktree ticket 永远走 main repo force-add (跟 EPIC-162 1:1)
4. merge conflict 优先 ours + 手工加新 entries (不自动 merge)
5. 4-PR 收口跟 EPIC-142/146 force-push 1:1 (跟 EPIC-155 备案)

## 6. 跟现有 EPIC 协同

| EPIC | 协同内容 | 1:1 pattern |
|------|---------|------------|
| EPIC-142 | testing 分支 force-push sync | testing → miao force-push |
| EPIC-146 | main 分支 force-push sync | main → testing force-push |
| EPIC-155 | 4-branch bypass 备案 | 3 commits bypass → 5 commits bypass |
| EPIC-162 | gitignore fix (worktree jira/ tracked) | worktree ticket path 规范 |
| EPIC-163 | amend SHA 错乱 | 本 EPIC Section 2.1 |
| EPIC-167 | ticket 误路径 | 本 EPIC Section 2.2 |
| EPIC-168-BG | 3-way conflict | 本 EPIC Section 2.3 |

## 7. Raw Output

**commit history**:
```
git log --oneline --all | head -30
  33ecc9b feat(jira): EPIC-176 commit history 修整 ticket
  30e923a fix(security): EPIC-175-fix JSON injection MEDIUM
  f178da1 merge: EPIC-175 security rules extended (v3.32.21)
  ...
  b672998 merge: EPIC-163 public/private boundary (v3.32.8)  ← amend 后 SHA
  f8e6fa4 merge: EPIC-163 public/private boundary (v3.32.7)  ← 原始 merge (被 amend 覆盖)
```

**5 bypass commits**:
```
git log --oneline a8da33f..33ecc9b --ancestry-path
  a8da33f → 1482ffa → 40e2b8e → 30e923a → 33ecc9b
```

**EPIC-163 amend 证据**:
```
git show --stat b672998
  Merge: c1cb0e6 319063f
  319063f = EPIC-167 ticket (时间顺序应在 v3.32.12)
```

## 8. 结论

EPIC-176 **hygiene 备案完成**:
- 3 类问题 documented (Section 2)
- 5 兜底 commit 备案 (Section 3)
- 拍板理由记录 (Section 4)
- 未来指南引用 (Section 5)
- 0 rebase 改写 history (跟 EPIC-155 1:1)

**主公接受**: hygiene issue documented, 不强 rebase 改写 history
