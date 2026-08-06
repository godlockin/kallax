# Commit Hygiene Pattern (EPIC-176)

> **起源**: EPIC-176 hygiene 备案后, 主公要求写未来指南防止复发
> **跟 loopx AGENTS.md 1:1**: 5 条 pattern 覆盖 commit history hygiene 问题

## 5 条 Commit Hygiene Pattern

### Pattern 1: 不用 amend 改 commit message

**问题场景**: EPIC-163 amend 后 SHA 错乱 (b672998 vs f8e6fa4)

**错误做法**:
```bash
# ❌ amend 已 push 的 commit
git commit --amend -m "new message"
git push --force
# 结果: SHA 变化, history 错乱
```

**正确做法**:
```bash
# ✅ create new commit
git commit -m "fix: correct commit message (follow-up to SHA xyz)"
git push
# 结果: SHA 稳定, history 可追溯
```

**何时例外**: worktree 内本地 commit 未 push 时可用 amend

## Pattern 2: 不用 reset --hard 改 history

**问题场景**: reset --hard 会丢失 worktree 内未合并的工作

**错误做法**:
```bash
# ❌ reset --hard 改 history
git reset --hard HEAD~1
git push --force
# 结果: 可能丢失未 stash 的工作
```

**正确做法**:
```bash
# ✅ 用 revert 或新 commit
git revert HEAD
git commit -m "revert: undo previous commit (see SHA xyz)"
git push
# 结果: history 保留, 协作安全
```

**何时例外**: worktree 内本地修改需 discard 时 (确认无未 stash 工作)

## Pattern 3: worktree ticket 永远走 main repo force-add

**问题场景**: EPIC-167 ticket 误路径 (`.claude/worktrees/.../jira/...`)

**错误做法**:
```bash
# ❌ worktree 内 git add .
cd .claude/worktrees/agent-epic-xxx
git add .  # 会把 .claude/worktrees/agent-epic-xxx/jira/ 也 add 进去
# 结果: ticket 路径错误
```

**正确做法**:
```bash
# ✅ 永远从 main repo force-add
cd /path/to/main-repo
git add -f jira/tickets/EPIC-xxx/ticket.json
git add -f jira/tickets/EPIC-xxx/ticket.md
git commit -m "feat(jira): EPIC-xxx ticket"
git push
# 结果: ticket 路径正确
```

**配套规则**: `cfbac7a fix(gitignore): allow jira/ tracked inside worktrees`

## Pattern 4: merge conflict 优先 ours + 手工加新 entries

**问题场景**: EPIC-168-BG 跟 EPIC-170 3-way conflict

**错误做法**:
```bash
# ❌ 自动 merge
git merge feature/xxx
# 结果: CLAUDE.md / CHANGELOG 段重复 + 顺序错
```

**正确做法**:
```bash
# ✅ 优先 ours + 手工加新 entries
git checkout --ours CLAUDE.md CHANGELOG.md
# 编辑: 手工加新 EPIC entry 到正确位置
git add CLAUDE.md CHANGELOG.md
git commit -m "merge: EPIC-xxx with conflict resolved (ours + manual entries)"
```

**CLAUDE.md merge 模板**:
```markdown
<!-- CLAUDE.md Section 6 EPIC entry 模板 -->
| EPIC-XXX | v3.XX.Y | <title> | <files> |
```

## Pattern 5: 4-PR 收口跟 EPIC-142/146 force-push 1:1

**问题场景**: 4-PR 收口时 testing/main 分支需 force-push sync

**流程**:
```bash
# 1. testing → main PR merge 后, sync main → testing
git checkout testing
git fetch origin
git reset --hard origin/main
git push --force origin testing

# 2. main → miao PR merge 后, sync miao → main
git checkout main
git fetch origin
git reset --hard origin/miao
git push --force origin main
```

**force-push 备案**:
- 5 commits bypass documented (a8da33f / 1482ffa / 40e2b8e / 30e923a / 33ecc9b)
- EPIC-142 (testing) + EPIC-146 (main) force-push pattern 1:1
- Q3 2026 考虑 retractively re-promote (可选)

## 跟 EPIC-155 备案 1:1

| 维度 | EPIC-155 | EPIC-176 |
|------|----------|----------|
| 问题类型 | 4-branch bypass | commit history hygiene |
| 拍板 Phase | Phase 3 | Phase 5 A |
| 处理方式 | 备案 + 接受丢失 | 备案 + 未来指南 |
| 未来指南 | 0 | 5 条 pattern |

## 违反 Pattern 的 3 类问题

| 问题 | 违反 Pattern | 修复措施 |
|------|-------------|----------|
| EPIC-163 amend SHA 错乱 | Pattern 1 | 不用 amend 改 commit message |
| EPIC-167 ticket 误路径 | Pattern 3 | worktree ticket 永远走 main repo force-add |
| EPIC-168-BG 3-way conflict | Pattern 4 | merge conflict 优先 ours + 手工加新 entries |

## Raw Output

**commit history hygiene check**:
```bash
# 检查 amend commit
git log --oneline --all | grep -E "amend|fixup|squash"

# 检查 ticket path
git log --oneline --all | grep "feat(jira):" | head -10
```

**force-push 备案 check**:
```bash
# 5 bypass commits
git log --oneline a8da33f..33ecc9b --ancestry-path
```

## 结论

5 条 Commit Hygiene Pattern 覆盖:
1. 不用 amend 改 commit message → 防止 SHA 错乱
2. 不用 reset --hard 改 history → 防止丢失工作
3. worktree ticket 永远走 main repo force-add → 防止路径错误
4. merge conflict 优先 ours + 手工加新 entries → 防止段重复
5. 4-PR 收口跟 EPIC-142/146 force-push 1:1 → 防止 bypass 复发
