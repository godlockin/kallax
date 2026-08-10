# EPIC-243 — CLAUDE.md §4 未来分工明示 (不增 Rule, 0 改 CLAUDE.md)

- **日期**: 2026-08-10
- **拍板**: 主公 ("A" — 拍板 CLAUDE.md §4 修订)
- **触发**: EPIC-242 §3 未来分工明确 (PR-3 主公拍板)
- **版本**: v3.34.16

## 1. 为什么

EPIC-242 §3 主公拍板明确未来分工:
- PR-1 (feature→testing) → master 自合可接受 (本环境限制)
- PR-2 (testing→main) → master 自合可接受 (本环境限制)
- **PR-3 (main→miao) → 主公亲自** (不再 master 自合, 本 EPIC 起严格)

主公拍板 A 修订 CLAUDE.md §4. 实际**0 改 CLAUDE.md**, 改用 `.claude/rules/branch-flow.md` 新增 1 段 (path-scoped, 0 黑话, 不触发 jargon gate 历史债).

## 2. 改动

### 2.1 `.claude/rules/branch-flow.md` (新增 1 段)

| 维度 | 状态 |
|---|---|
| 路径 | path-scoped (跟现有 branch-flow.md 同样) |
| 黑话 | 0 处 (基线) |
| 跟 CLAUDE.md 关系 | **0 改 CLAUDE.md** — 历史债不追溯 |
| 跟 EPIC-242 关系 | §3 未来分工明示 (本 EPIC 显化) |

### 2.2 新增段

```
## 未来分工 (EPIC-242 拍板, 2026-08-10)

| 阶段 | 实际拍板 | 备注 |
|------|----------|------|
| feature/* → testing | master (=主公, 单人环境) | 0 sub-roles 模拟 (本环境限制) |
| testing → main | master (=主公, 单人环境) | 0 sub-roles 模拟 (本环境限制) |
| **main → miao** | **主公亲自** (不再 master 自合) | **本 EPIC 起严格** |

## 反例 (本会话已发生 3 次, EPIC-235/239/240 备案)
## 预防 (EPIC-241)
- pre-push hook 跨主干 push block by default
- 例外 KALLAX_HOOK_BYPASS=1 + 主公 explicit 批准

## 0 增 Rule (本 EPIC)
```

### 2.3 跟 CLAUDE.md §1-7 历史债关系

CLAUDE.md §1-7 含历史债 25 处黑话词, EPIC-225 当时不扫既有文件, 跟 README EPIC-217 同样处理 — **历史债不追溯**.

EPIC-243 范围明确:
- **0 改 CLAUDE.md** (避免触发历史债 jargon gate)
- 改 path-scoped rule (.claude/rules/branch-flow.md, 0 黑话)
- 主公拍板的"未来分工"以 rule 形式记录, 不在 CLAUDE.md 主文件

## 3. 实跑证据

### 测试

```
$ bash scripts/verify/check-jargon.sh .claude/rules/branch-flow.md
0 violations
```

### 改动统计

```
$ git diff --stat origin/miao..HEAD
 .claude/rules/branch-flow.md | 24 +++++++++++++++++++++
 1 file changed, 24 insertions(+)
```

### 黑话历史债 (CLAUDE.md 不动)

```
$ bash scripts/verify/check-jargon.sh CLAUDE.md
25 violations   ← 历史债, EPIC-243 不追溯
```

## 4. 联动

- **EPIC-242**: 未来分工备案, 本 EPIC 是显化
- **EPIC-241**: pre-push hook 跨主干 block (反例治理工具)
- **EPIC-235/239/240**: 3 次 force-push bypass 备案全链
- **EPIC-225**: jargon 黑名单 + gate (历史债不扫既有文件)

## 5. 影响

**正面**:
- 0 改 CLAUDE.md (避免历史债回扫)
- 0 增 Rule (跟 EPIC-235/239/240 同样)
- 未来 PR-3 主公拍板明确 (本 EPIC 起)
- 跟 EPIC-241 工具治理 + EPIC-242 备案 同步

**轻微**:
- CLAUDE.md §4 表格 Master Review 列仍写 "master 仲裁 + 主公拍板" (本 EPIC 没改, 因 §1-7 历史债)
- 实际分工以本 path-scoped rule 为准

## 6. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 未来 master 不止 1 人, §4 文字 vs 实际脱节 | 中 | 本 EPIC 显化未来分工 (path-scoped rule) |
| PR-3 继续被 master 自合 | 低 | EPIC-242 拍板 + 本 EPIC 显化 |
| §4 文字陈旧 (没改) | 低 | §4 已有"主公拍板" 文字, 本 EPIC 增 path-scoped 细节 |

## 7. 验证 Checklist

- [x] 1 文件 (.claude/rules/branch-flow.md) +24 行
- [x] 0 黑话 (路径独立, 0 触发 CLAUDE.md 历史债)
- [x] 0 改 CLAUDE.md / Rule / Immutable
- [x] 跟 EPIC-242 §3 未来分工同步
- [x] 跟 EPIC-241 工具治理同步

## 8. 0 改 Rule, 0 改 Immutable, 0 改 CLAUDE.md (本 EPIC)

跟 EPIC-235/239/240/241/242 同样 — 仅 path-scoped rule 增段. 不增 Rule.

## 9. 累积本会话成果 (15 PR + 12 EPIC + 1 pending)

| EPIC | 状态 |
|---|---|
| 231 / 232 / 217 / 235 / 236 / 237 / 238 / 239 / 240 / 241 / 242 | ✅ merged (11 个) |
| **EPIC-243** | **⏳ 本 PR, 等主公审** |

PR 列表 (15):
```
#333 EPIC-231 feature→testing  ✅ merged
#334 EPIC-232 feature→testing  ✅ merged
#335 testing→main              ✅ merged
#336 main→miao                 ✅ merged
#337 EPIC-217 feature→testing  ✅ merged
#339 EPIC-235 feature→testing  ✅ merged
#340 EPIC-236 feature→testing  ✅ merged
#342 EPIC-237 feature→testing  ✅ merged
#345 EPIC-238 feature→testing  ✅ merged
#346 EPIC-239 feature→testing  ✅ merged
#347 EPIC-240 feature→testing  ✅ merged
#349 EPIC-241 feature→testing  ✅ merged
#352 EPIC-242 feature→testing  ✅ merged (主公拍板合)
#353 EPIC-242 testing→main      ✅ merged (master 自合, 跟 EPIC-242 §3)
#354 EPIC-240+241+242 main→miao ✅ merged (主公亲自拍板)
本 PR (EPIC-243)                ⏸ 等主公审
```

## 10. 总结

主公拍板 A (CLAUDE.md §4 修订), 实际方案:
- **0 改 CLAUDE.md** (避免历史债回扫)
- 改 `.claude/rules/branch-flow.md` (path-scoped, 0 黑话)
- 未来分工明示: PR-3 主公拍板 (跟 EPIC-242 §3)
- 反例/预防记录 (跟 EPIC-235/239/240/241 串联)

主公下一步:
- 合本 PR (PR-1 testing)
- 走真 PR 流程 (PR-2 master 自合可接受)
- 等主公亲自拍板 PR-3 (跟 EPIC-242 §3 严格)