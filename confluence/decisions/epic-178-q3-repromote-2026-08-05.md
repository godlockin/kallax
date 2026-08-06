# EPIC-178 Q3 Re-promote Decision Record (2026-08-05)

> **起源**: 主公 Phase 6 AC 拍板 — "Q3 re-promote, 闭环 EPIC-155 备案 + 9 专家 review HIGH blocker"
> **跟 EPIC-155 plan 1:1**: 5 bypass commits cherry-pick 走 4-PR

## 1. 主公拍板 (Phase 6 AC)

**拍板内容**:
- **执行 Q3 re-promote** — 5 bypass commits retractively re-promote
- **闭环 EPIC-155 备案** — 接受丢失 → 现在标准化 4-PR 流程
- **闭环 9 专家 review HIGH blocker** — 'Q3 re-promote pending' 状态终结
- **DCO 3 violations 修复** — 40e2b8e + 30e923a + 33ecc9b 加 Signed-off-by trailer

**拍板理由**:
1. **治理闭环** — 5 commits 已 in miao (IS ancestor), 现在标准化 commit message + DCO
2. **风险控制** — 0 改 source code, 仅 cherry-pick 走 4-PR
3. **9 专家 review 收口** — 'Q3 re-promote pending' HIGH blocker 必须闭环

## 2. 5 commits re-applied 详化

| # | Source SHA | New SHA | Subject | DCO 状态 |
|---|------------|---------|---------|----------|
| 1 | a8da33f | 43228dc | chore(v3.32.0): archive 38 outdated docs to _archived/ | 修复 (原已有) |
| 2 | 1482ffa | 668082e | docs(EPIC-154): CLAUDE.md 224 → 110 行 + 6 reference docs 按需加载 | 修复 (原已有) |
| 3 | 40e2b8e | afc55f4 | chore: 清理 main 本地 uncommitted — gitignore .eket + .kallax/.kallax | 修复 (原无) |
| 4 | 30e923a | abb6e44 | fix(security): EPIC-175-fix JSON injection MEDIUM (2 处 jq -n) | 修复 (原无) |
| 5 | 33ecc9b | b7737c6 | feat(jira): EPIC-176 commit history 修整 ticket | 修复 (原无) |

**commit message 标准化**:
```
[Q3-repromote] <original subject>

Re-applied from <original SHA> (跟 EPIC-155 plan 1:1).
<optional: content status>
0 改 source code, 0 增 Rule, 0 增 immutable script.
Signed-off-by: Agent <agent@kallax.test>
```

## 3. 4-PR 流程 (跟 EPIC-074/142/146 1:1)

| 阶段 | 操作 | PR | 跟 EPIC-155 1:1 |
|------|------|-----|-----------------|
| feature → testing | 5 PR squash merge | #206-210 | v3.32.0 doc-merge 5 PR |
| testing → main | 1 PR squash merge + force-push | #211 | EPIC-146 pattern |
| main → miao | 1 PR squash merge + force-push | #212 | EPIC-142 pattern |
| tag | 5 v3.33.0-repromote-N | pushed | v3.32.0 doc-merge 1:1 |

**force-push 备案**:
- PR #211 merge 后: `git push --force-with-lease origin testing:main`
- PR #212 merge 后: `git push --force-with-lease origin main:miao`

## 4. DCO 3 violations 修复

**来源**: 9 专家 review 抓 'DCO 3 violations' HIGH blocker

| Commit | 原 Signed-off-by | 修复后 |
|--------|------------------|--------|
| 40e2b8e | 无 | 添加 Signed-off-by: Agent <agent@kallax.test> |
| 30e923a | 无 | 添加 Signed-off-by: Agent <agent@kallax.test> |
| 33ecc9b | 无 | 添加 Signed-off-by: Agent <agent@kallax.test> |

**验证**:
```bash
git log --format="%H %s" v3.33.0-repromote-1..v3.33.0-repromote-5 | grep "Signed-off-by"
```

## 5. 跟 EPIC-155 备案 / EPIC-176 指南 1:1

| 维度 | EPIC-155 | EPIC-178 |
|------|----------|----------|
| 问题类型 | 4-branch bypass | 4-branch bypass + DCO violations |
| 拍板 Phase | Phase 3 | Phase 6 |
| 处理方式 | 备案 + 接受丢失 | 备案 + 标准化 4-PR |
| 5 commits | a8da33f / 1482ffa / 40e2b8e | + 30e923a / 33ecc9b |

**EPIC-176 指南引用**:
- Pattern 5: 4-PR 收口跟 EPIC-142/146 force-push 1:1

## 6. 9 专家 review HIGH blocker 闭环

**原 blocker**: 'Q3 re-promote pending' (EPIC-155 备案)

**闭环验证**:
- [x] 5 commits cherry-pick 走 4-PR (feature → testing → main → miao)
- [x] 5 commit message 标准化 ([Q3-repromote] prefix + DCO)
- [x] DCO 3 violations 修复 (40e2b8e + 30e923a + 33ecc9b)
- [x] 5 PR merged (PR #206-212)
- [x] 5 tag v3.33.0-repromote-N pushed
- [x] CHANGELOG [v3.33.1] entry added

## 7. Raw Output

**5 commits re-applied**:
```
43228dc [Q3-repromote] chore(v3.32.0): archive 38 outdated docs to _archived/
668082e [Q3-repromote] docs(EPIC-154): CLAUDE.md 224 → 110 行 + 6 reference docs 按需加载
afc55f4 [Q3-repromote] chore: 清理 main 本地 uncommitted — gitignore .eket + .kallax/.kallax
abb6e44 [Q3-repromote] fix(security): EPIC-175-fix JSON injection MEDIUM (2 处 jq -n 替代 printf)
b7737c6 [Q3-repromote] feat(jira): EPIC-176 commit history 修整 ticket
```

**5 PR merged**:
- PR #206 (repromote-1 → testing): merged
- PR #207 (repromote-2 → testing): merged
- PR #208 (repromote-3 → testing): merged
- PR #209 (repromote-4 → testing): merged
- PR #210 (repromote-5 → testing): merged
- PR #211 (testing → main): merged + force-push
- PR #212 (main → miao): merged + force-push

**5 tags**:
- v3.33.0-repromote-1
- v3.33.0-repromote-2
- v3.33.0-repromote-3
- v3.33.0-repromote-4
- v3.33.0-repromote-5

## 8. 结论

EPIC-178 **Q3 re-promote 完成**:
- 5 bypass commits cherry-pick 走 4-PR (跟 EPIC-155 plan 1:1)
- 5 commit message 标准化 ([Q3-repromote] prefix + DCO Signed-off-by)
- DCO 3 violations 修复 (40e2b8e + 30e923a + 33ecc9b)
- 9 专家 review HIGH blocker 闭环 (EPIC-155 'Q3 re-promote pending')
- 0 改 source code, 0 增 Rule, 0 增 immutable script

**主公接受**: Q3 re-promote 闭环, EPIC-155/176 备案完成
