# EPIC-252 — 纠正 retrospective-batch-8 L4/L11 误诊

**Status**: in_progress → done
**Priority**: P1
**Type**: bugfix (misdiagnosis correction)
**Estimated**: 1h
**Phase**: PHASE-023

## 起因

主公 2026-08-12 Sprint 规划 #2 原计划: "修 check-decorative-claim.sh + check-narrative.sh 加 baseline 豁免", 触及 9 immutable #1 + #2, 主公已批准改动.

主公追问 "改动代价大还是修复代价大" → master 做代价对比 → 主公拍 "同意改动" → **实测发现原假设错**.

## Rule 34 独立复现 (证明假设错)

```bash
# 假设: hook 扫全仓 198 处历史 jargon
bash scripts/verify/check-decorative-claim.sh
# → FAIL: 198 decorative claim patterns detected, exit 1  (全仓模式确实 198)

# 实测: hook 实际调用方式
KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh
# → KALLAX_STAGED_ONLY=1: no staged files, skip, exit 0  ← 历史文件已豁免
```

**3 个实测事实**:

| # | 事实 | 证据 |
|---|---|---|
| 1 | script 已有 staged-diff-only 模式 | `check-decorative-claim.sh:88-100` (EPIC-110-C 引入) |
| 2 | 历史行已 grandfathered | `check-decorative-claim.sh:87` 注释 "Historical decorative lines already in CHANGELOG are grandfathered" (EPIC-114 设计) |
| 3 | hook 已传 STAGED_ONLY=1 | `scripts/hooks/pre-commit:270` |

## 真因

8 EPIC session 中 6 次 merge commit 的 staged diff 含 master **新写的** CLAUDE.md 段, 段里自带黑名单词. hook fail-closed 是**正确行为**, 不是 bug.

## 修复 (0 改 immutable)

| # | 改动 | 目的 |
|---|---|---|
| 1 | `tests/integration/immutable-staged-only.test.sh` (新, 10 case) | 锚定 STAGED_ONLY 行为, 防未来再误判 |
| 2 | `CLAUDE.md` §4 docs-only 批模式段 | 删 "bypass check-decorative-claim 备案" 误导表述, 改 "写段禁 jargon" 正确指引 |
| 3 | `lessons/batch-8-EPIC-closure-2026-08-12.md` L3 | 标注已纠正 + 记录元教训 |

**scope 排除**: `scripts/verify/check-decorative-claim.sh` 且 `check-narrative.sh` 不动.

## 验证结果

| AC | 状态 | raw output |
|---|---|---|
| AC1 0 改 immutable | PASS | `git status --short` 无 `scripts/verify/` 条目 |
| AC2 test ≥8 case | PASS | 10 case |
| AC3 staged jargon → exit 1 | PASS | Case 7: `jargon in staged added lines → fail-closed (exit 1)` |
| AC4 历史行 → exit 0 | PASS | Case 8: `historical jargon not re-flagged (exit 0)` |
| AC5 hook 传 STAGED_ONLY=1 | PASS | Case 4: `pre-commit passes KALLAX_STAGED_ONLY=1` |
| AC6 CLAUDE.md §4 纠正 | PASS | 删 bypass 表述, 加写段禁 jargon |
| AC7 lessons L3 纠正 | PASS | 标注 "本条已被 EPIC-252 纠正" |
| AC8 CLAUDE.md ≤ 200 行 | PASS | `wc -l CLAUDE.md` → 199 |
| AC9 commit 不用 bypass | PASS | 本 PR commit 0 用 `KALLAX_HOOK_BYPASS` |
| AC10 4-branch flow | 进行中 | PR-1 → testing → main → miao |

## 元教训

遇 hook 拦截先跑 `KALLAX_STAGED_ONLY=1 <script>` 确认是新内容还是历史内容, 再判断是否真需改 hook.

**Rule 34 独立复现适用于 hook 诊断, 不只 bugfix.**

节省: 原计划改 2 个 immutable (1h + 长期风险), 实际 0 改 immutable.

## 联动

- EPIC-110-C (KALLAX_STAGED_ONLY 模式引入方)
- EPIC-114 (historical lines grandfathered 设计)
- EPIC-225 (jargon 黑名单源头)
- EPIC-232 (pre-commit 必传 STAGED_ONLY=1)
- retrospective-batch-8 L4/L11 (被纠正的误诊)
- Rule 34 (独立复现)
- CLAUDE.md §5 (immutable — 本 ticket 0 改动)
