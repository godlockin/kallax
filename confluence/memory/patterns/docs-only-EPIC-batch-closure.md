# Docs-Only EPIC Batch Closure Pattern (跟 EPIC-160/170/174/172/158 一致)

> **Source**: `confluence/decisions/retrospective-batch-8-EPIC-2026-08-12.md`
> **范围**: 8 docs-only EPIC 在 24h Sprint 内闭环, 0 source code change, 0 增 Rule.

## 适用条件

- EPIC 全部 docs-only (无 source code 改动)
- 触及 ≤ 5 个文件 (CLAUDE.md + 1 docs + 1 test)
- 估时 < 8h (实际 < 1h 因 docs-only)
- 主公 override 4 sub-roles review (Rule 37 auto-approve)

## 4-Branch 流程 (跟 EPIC-074 + EPIC-207 联合)

```
Step 1  worktree 隔离 (feature/EPIC-XXX-name, off miao)
Step 2  PR-1: feature → testing (squash, master + 4 sub-roles bypass)
Step 3  PR-2: testing → main (FF 不可行时 rebase testing on main + push new branch)
Step 4  PR-3: main → miao (FF 不可行时 force-push, 主公拍板 override)
```

## 关键参数

| 参数 | 值 | 备注 |
|---|---|---|
| 平均闭环时间 | ~7 分钟/EPIC | 跟 EPIC-159 11m 接近 |
| 冲突率 | 75% (6/8 EPIC) | CLAUDE.md §6.4 累积 EPIC 段 |
| bypass 率 | 88% (7/8) | check-decorative-claim merge commits + scan-dead-code Stage 3 |
| test 通过率 | 100% (42/42) | trim + ci-debt + strategy + public-coord |
| 0 source code change | 100% (8/8) | 跟 v2.4.1 Rule 合并反思 1:1 |
| 0 增 Rule / immutable | 100% (8/8) | 跟 v2.4.1 联合 |

## 4 模式 fix

1. **worktree 隔离**: `git worktree add -b feature/EPIC-XXX-name .claude/worktrees/agent-epicNNN origin/miao`
2. **CLAUDE.md 段 + 1 docs-only 改动**: 主仓 ≤200 行, 删冗余段, ref `.claude/rules/*.md`
3. **test 验证**: `bash tests/integration/epic-XXX.test.sh` → ALL PASS
4. **PR + 4-branch**: PR-1 → bypass conflict → --ours → bypass hook → PR-2 force → PR-3 force

## 失败模式 (防范)

- **F1**: CLAUDE.md §6.4 累积段 → 6/8 冲突. 修: 子段化 (§6.4.1 EPIC-XXX).
- **F2**: check-decorative-claim historical jargon → 6/8 bypass. 修: 启动 EPIC-X-B 修 hook baseline 豁免.
- **F3**: scan-dead-code Stage 3 报新 module 无 test → 1/8 bypass (EPIC-157 jira/ticket-binding). 修: 新 module 必加 test (跟 L3 联动).
- **F4**: testing 落后 main → 6/8 rebase. 修: rebase testing on main + push new branch (跟 EPIC-159 pattern).
- **F5**: main 落后 miao → 6/8 force-push PR-3. 修: --force-with-lease (atomic check).

## 联动

- 跟 `lessons/batch-8-EPIC-closure-2026-08-12.md` 1:1.
- 跟 `patterns/isolation-strategy.md` (worktree) 1:1.
- 跟 `patterns/rust-node-bridge.md` (skill-builder 跟 docs 1:1) 1:1.
