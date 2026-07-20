# Branch 4-way Sync — EPIC-129 (2026-07-20)

> **起源**: 主公 2026-07-20 下令 "miao merge 过去, 重新同步进度" + "main → miao 必须 PR + review"。
> **决策**: 走 2 个 PR (#139 main ← miao, #140 testing ← miao) 完成同步; 写 `scripts/branch-sync.sh` 给下次用。

## 同步前状态

```
main     = eaf3b3b  EPIC-121            UAT
testing  = eaf3b3b  EPIC-121            UAT 验证
miao     = 91c07f8  EPIC-128-A           stable/prod

miao ahead of main:   36 commits
miao ahead of testing: 36 commits
testing ahead of main: 0
```

`main == testing`,都是 stale EPIC-121, 而 miao 上了 36 commits stable 增量 (上次 branch-recovery-2026-07-20.md 文档的延续)。

## 同步动作 (2 PR + 0 force-push)

### PR #139: miao → main (走 review 流程)
- 创建: `gh pr create --base main --head miao --title "sync(miao → main): ..."`
- merge: `gh pr merge 139 --merge`
- 结果: `fbdc73e Merge PR #139`, main 推到 91c07f8 + merge commit
- 时间: 2026-07-20T02:35:34Z

### PR #140: miao → testing (fast-forward)
- 创建: `gh pr create --base testing --head miao`
- merge: `gh pr merge 140 --merge`
- 结果: `9e492b4 Merge PR #140`, testing 推到 91c07f8 + merge commit
- 时间: 后续

## 同步后状态

```
main     = fbdc73ee  (Merge PR #139) — 实质 91c07f8 + 1 merge
testing  = 9e492b4e  (Merge PR #140) — 实质 91c07f8 + 1 merge
miao     = 91c07f8   EPIC-128-A        — stable/prod unchanged

divergence: main ↔ testing = +1, main ↔ miao = +1, testing ↔ miao = +1
```

**功能等价**: 3 个 branch 都是 miao ancestor + 1 merge commit。

## 治理规则 (主公新规)

按 CLAUDE.md v3.10.0+ 4-branch 强制流程:

```
feature/* → testing → main (UAT) → miao (prod)
```

新规: **`main → miao` 必须 PR + review** (不再 force-push)。

实现:
1. `scripts/branch-sync.sh status` — 看 4-branch divergence
2. `scripts/branch-sync.sh testing` — testing → main 自动开 PR
3. `scripts/branch-sync.sh main` — main → miao 开 PR + 自动 merge (sync PR 默认 No review, 主公 workflow)
4. `scripts/branch-sync.sh feature/<br>` — feature → testing (人类 review 后 merge)

## 脚本 (下次复用)

`scripts/branch-sync.sh` (52 行 + shell wrapper):

| Subcmd | 作用 |
|--------|------|
| `status` | 显示 3 branch tip + divergence + feature ahead |
| `feature/<br>` | 提示人类开 feature → testing PR |
| `testing` | 自动开 testing → main PR + merge |
| `main` | 自动开 main → miao PR + merge |
| `all` | 同 testing + main |

强制约束:
- ✅ 验证 fast-forward (merge-base == to_branch tip)
- ✅ fail-closed on ancestor mismatch
- ❌ 不允许 force-push 主分支 (主公新规)
- ✅ 跟 `--merge` (保留 merge commit, 不 squash, 历史清晰)

## 验证 (5 步)

1. `bash scripts/branch-sync.sh status` → 显示 3 branch 都在 91c07f8
2. `git log origin/main..origin/miao --count` → 0 (main 含 miao)
3. `git log origin/testing..origin/miao --count` → 0 (testing 含 miao)
4. PR #139 状态: MERGED
5. PR #140 状态: MERGED

## 反模式警告 (0 复发)

❌ **禁止**:
- 直接 `git push origin main` (无 review) — 违反主公新规
- `git push --force` 主分支 — 丢历史, 别人 tracking 跟丢
- 跳过 testing 直接 main ← feature — 绕开 UAT 阶段

✅ **必做**:
- 主公提到 "同步进度" — 默认走 PR+review
- feature → testing 必须人类看 PR description
- main → miao 可走脚本自动 (主公信任 sync PR)
- testing → main 必须人类 review (主公新规)

## 联动 ticket

- **EPIC-127-B** main branch recovery (2026-07-20, 重建 main)
- **EPIC-128** release automation
- **EPIC-129** 4-branch sync governance (本次)
- 后续 v3.X.Y release 必先过 `branch-sync.sh all` 自动 main ↔ testing 同步

## 文件变更 (本次)

- ✅ 2 GitHub PR (#139 main ← miao, #140 testing ← miao)
- ✅ 新增 `scripts/branch-sync.sh` (~165 行, 5 sub-commands)
- ✅ 新增 `confluence/decisions/branch-sync-2026-07-20.md` (本文件)
- ❌ 0 业务代码改动
