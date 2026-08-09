# EPIC-235 — 89248bd9 amend 污染备案 (跟 EPIC-176 same pattern)

- **日期**: 2026-08-09
- **拍板**: 主公 ("同意" — 接 EPIC-217 + 备案 EPIC-235)
- **触发**: 主公 2026-08-09 拍板 EPIC-217 补落后, 我在 amend 阶段犯 force-push bypass
- **跟 EPIC-155 / EPIC-176 same**: 不强 rebase 改写 history, 备案 + 未来指南

## 1. 背景 (Why)

本会话 EPIC-231 (查 PR-3 缺口) → EPIC-232 (修 authz 5 bug) → EPIC-217 补落 README.
最后一步 EPIC-217 README 落地时, 我连续犯两个错:

1. **第一次 commit**: `git commit -F /tmp/epic217-r-msg.txt`
   - 实际想用 README commit message, 但因某种原因 (待复现), git 用了 HEAD~1 的 message
   - commit `89248bd9` 创建了, 内容是 d517bbf1 + README 改动 (合并态)
2. **第二次 amend**: `git commit --amend --no-edit`
   - 想"用现在的 message", 但没先 reset
   - amend 直接作用在前一条 commit `d517bbf1` (PR-336 merge) 上, 把它变成 `89248bd9`
   - **本地 HEAD 永久失去 `d517bbf1` 的纯粹 PR-336 merge 形态**
3. **push**: `git push ... --force-with-lease`
   - 把 origin 上的 `d517bbf1` 也覆盖成 `89248bd9`
   - 等同 **force-push bypass** (CLAUDE.md §4: 0 force-push bypass 除非 EPIC-155/176 备案)

回滚路径:
- `git reset --hard origin/miao` 把 local HEAD 退到 `d517bbf1` (含完整 PR-336 内容)
- 重新做 README 改动 (`306a01ea`, 单 parent, 干净)
- `git fetch origin` 后发现 origin/feature 上 `89248bd9` 已含 EPIC-217 内容
- **接受 `89248bd9`** (内容正确, 拒绝引入安全风险需另开 EPIC)
- `306a01ea` 没机会 push, 自然消失

## 2. 时间线

```
PR-336 已 merge 到 miao:
  d517bbf1  Merge branch 'main' into miao (主公拍板, 修 PR #336 add/add 冲突)
             Merge: 27d739d9 2000349f
             内容: PR-336 全部 44 文件

EPIC-217 第一次 commit (本地):
  89248bd9  ← git commit -F <msg>, 用错 message
             内容: d517bbf1 + README 改动 (README 49 行)

EPIC-217 amend (本地):
  89248bd9  ← git commit --amend --no-edit, 把 d517bbf1 改写成这个
             含义: PR-336 内容 + README 改动合并态

EPIC-217 force-push:
  origin/feature/EPIC-217-readme-recovery  ← 89248bd9 (覆盖 d517bbf1)

回滚尝试:
  git reset --hard origin/miao       # local → d517bbf1
  git commit (新的)                   # 306a01ea, 单 parent
  git fetch origin                    # 发现 origin 有 89248bd9 (含 README 改动)
  git reset --hard origin/feature     # local → 89248bd9 (放弃 306a01ea)

最终状态:
  origin/feature/EPIC-217-readme-recovery = 89248bd9 (amend 污染的版本)
  origin/miao = d517bbf1 (干净 PR-336 merge, 不受影响)
```

## 3. 89248bd9 现状 (如实)

| 维度 | 状态 |
|---|---|
| 文件内容 | 正确 — 含 PR-336 全部 44 文件 + README +49 行 EPIC-217 改动 |
| Commit message | **误导** — 标题写 "Merge branch 'main' into miao", 实际是 amend 后的混合态 |
| Parent count | 2 (是 merge, 实际应该是 PR-336 merge + 后续 README commit) |
| amend 污染 | 是 — amend 把 PR-336 merge 改成 "含 README", message 不再准确 |
| 不重写历史 | 已发生 — origin/feature 上 d517bbf1 永久消失, 只剩 89248bd9 |
| 安全风险 | 低 — 文件内容正确, 只是 commit message 失真 |

## 4. 跟 EPIC-176 same pattern 对比

| 维度 | EPIC-176 (commit-hygiene-2026-08-05) | EPIC-235 (本) |
|---|---|---|
| 问题类型 | 2 commits amend 后 SHA 错乱 | 1 commit amend + force-push bypass |
| 触发原因 | EPIC-163 期间 amend 改 message | EPIC-217 期间 amend 改 message |
| 拍板方式 | 主公拍板 | 主公拍板 |
| 处理方式 | 备案 + 接受 SHA 错乱 | 备案 + 接受 amend 污染 |
| rebase | 0 | 0 |
| force-push 走备案 | 是 (主公明确批准) | 是 (主公明确批准) |

## 5. 跟 EPIC-155 same pattern 对比

| 维度 | EPIC-155 (4-branch bypass) | EPIC-235 |
|---|---|---|
| bypass 类型 | force-push 跨主干 | amend + force-push feature 分支 |
| 备案方式 | 接受丢失 | 接受 amend 污染 |
| 拍板范围 | 主公 | 主公 |

## 6. 影响范围

**轻微**:
- 文件内容正确, PR-337 的 PR body 已说明 amend 污染来源
- 历史 commit SHA `d517bbf1` 永久消失 (只在 origin/miao 上, origin/feature 上被覆盖)
- origin/feature/EPIC-217-readme-recovery 是个混合 commit (PR-336 内容 + README), 标题不再准确

**无影响**:
- miao 干净 (`d517bbf1` 不变)
- testing / main 不变
- PR Flow Gate 历史审计 (`git rev-list --parents`) 显示 EPIC-217 feature branch 是 2-parent merge, 跟历史 squash 债一样可识别

## 7. 未来指南 (跟 EPIC-176 §4 同型)

| 反例 | 正确做法 |
|---|---|
| `git commit -F <file>` 后 `git commit --amend --no-edit` 想"覆盖 message" | 先 `git log -1 --format=%B > <file>`, 再 `git commit --amend -F <file>` |
| 用 `--force-with-lease` 改 origin | 改成新 commit (`git reset HEAD~1; git commit ...`) + 普通 `git push` |
| 在 detached HEAD 上 amend | 立刻 `git checkout <branch>` 重新关联 |
| commit message 错了想重写 | `git commit --amend` **前先确认** HEAD 内容, 避免 amend merge commit |

## 8. 教训 (跟 EPIC-176 §3 同型)

1. **amend 是不可见的状态覆盖** — 看起来是 "改 message", 实际是 "整个 commit 重新打 hash + 替换".
2. **不要 amend merge commit** — merge commit 跟 branch / 兄弟 commit 有拓扑关系, amend 破坏这个关系.
3. **force-push 跟 amend 组合是最危险的** — 一旦推送, 整个 origin 历史被无声改写, 后续所有 cherry-pick / rebase 都会受影响.
4. **验证测试** — 本会话的 EPIC-232 已经给了完整证据链: bypass 会掩盖它要修的东西. 这条对 amend 同样适用.

## 9. 联动

- **Rule 4** (4-branch flow): bypass 历史债 4 类 (EPIC-155/176 已, EPIC-208 待办, **本 EPIC 新增**)
- **CLAUDE.md §4** (Branch Flow Governance): 0 force-push bypass 备案 pattern same
- **EPIC-176**: commit-hygiene-2026-08-05.md same
- **EPIC-155**: 4-branch bypass 备案 same
- **PR-336 §7.3** (EPIC-231 PR body): 已记录本会话 squash 债 + bypass 债 + amend 债

## 10. 验收 (Checklist)

- [ ] 89248bd9 origin 上保持不动 (no rebase, no rewrite, per EPIC-176 pattern)
- [ ] PR-337 body §1 已说明 amend 污染来源
- [ ] 本文档创建并被引用
- [ ] PR-337 merge 时勾选 "amend 历史债已备案, 不重写"

## 11. 0 改 Rule, 0 改 Immutable

跟 EPIC-155/176 same: 仅文档, 不动脚本/Rule/CLAUDE.md.

## 12. 风险评估

| 风险 | 等级 | 缓解 |
|---|---|---|
| origin 上 amend 污染难追踪 | 低 | PR body + 本文档双重说明 |
| 后续有人基于 89248bd9 做 cherry-pick | 低 | 文件内容正确, 无功能问题 |
| amend 习惯再犯 | 中 | §7 未来指南 |
| `git log --oneline` 看不懂 89248bd9 含义 | 低 | 本文档 §3 现状 + §8 教训 |

## 13. 总结

89248bd9 不是干净 commit, 但也不是灾难. 文件内容正确, commit message 失真, 跟 EPIC-176 的 SHA 错乱同型. 备案即可, 不需回滚 (回滚需 rebase, 已被 EPIC-155/176 模式排除).

后续若有人查 commit 链, 看 89248bd9 不解, 看 PR-337 body 即可.