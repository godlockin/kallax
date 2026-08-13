# Batch 8 EPIC 收口 Lessons (2026-08-11/12, 24h Sprint)

> **Source**: `confluence/decisions/retrospective-batch-8-EPIC-2026-08-12.md`
> **范围**: 1 master 24h 内关掉 8 EPIC, 24 PR, 0 跨 Sprint 累积.

## 核心 5 lessons

### 1. docs-only 批模式 4-branch 稳定

- **现象**: 8 docs-only EPIC 走同一 worktree 模式, 平均 7 分钟/EPIC 走完 4 个 PR.
- **根因**: docs-only 触及 `.claude/rules/*.md` + CLAUDE.md + 1 test, 不动 source code, Rule 35 "0 source code change" 豁免拆分.
- **修复**: 跳过 4 sub-roles review, 走 Rule 37 auto-approve + master 自审 + 主公拍板.
- **防范**: 未来 docs-only 批量收口直接走此模式, 不细化 plan, 省 master 时间.

### 2. CLAUDE.md §6.4 子段化避免 merge conflict

- **现象**: 8 EPIC 全在 §6.4 加段, 每次 PR-1 merge testing 都跟之前合并的 EPIC 段冲突 (3-way merge, 6 次).
- **根因**: 共享段累积 EPIC 引用, 任何新加都冲突.
- **修复**: `git checkout --ours CLAUDE.md` (本 EPIC 段必含).
- **防范**: 修订 CLAUDE.md §6.4 用子段 (e.g. `§6.4.1 EPIC-XXX`), 同 README "Why KALLAX" 段结构.

### 3. bypass check-decorative-claim 是误诊 — 真因是新写段自带 jargon (EPIC-252 纠正)

> **本条已被 EPIC-252 纠正**. 原结论 "check-decorative-claim.sh 缺 baseline 豁免" 是错的.

- **原假设 (错)**: check-decorative 扫全 `confluence/decisions/` + `CHANGELOG.md` 198 处历史 jargon, 每次 merge commit 都拦, 需仿 check-jargon.sh 加 `is_historical_file()`.
- **实测 (对, EPIC-252 复现)**:
  1. `check-decorative-claim.sh:88-100` 已有 `KALLAX_STAGED_ONLY` 模式, 只扫 `git diff --cached` 新增行 (EPIC-110-C 引入, EPIC-114 设计历史行 grandfathered)
  2. `scripts/hooks/pre-commit:270` 已传 `KALLAX_STAGED_ONLY=1` (EPIC-232 强制)
  3. 复现: `KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh` → `no staged files, skip`, exit 0
- **真因**: 6 次 merge commit 的 staged diff 含 master 新写的 CLAUDE.md 段, 段里自带黑名单词, hook fail-closed 是**正确行为**.
- **修复 (EPIC-252)**: 0 改 immutable. 改写段习惯 (避开黑名单词) 且加 `tests/integration/immutable-staged-only.test.sh` (10 case) 锚定行为.
- **防范**: 写 CLAUDE.md / CHANGELOG / decisions 段时先查 `jira/tickets/.jargon-blacklist.json`, 直接避开. 不用 bypass.
- **元教训**: 遇 hook 拦截先跑 `KALLAX_STAGED_ONLY=1 <script>` 确认是新内容还是历史内容, 再判断是否真需改 hook. **Rule 34 独立复现适用于 hook 诊断, 不只 bugfix**.

### 4. 5 次主公 override = 实战 Rule 37 模式

- **现象**: 8 EPIC 批量收口, 主公 5 次拍板 (合并/A/同意/trim/继续), 全部 override EPIC-207 §1 "0 容忍 auto-merge" 且 EPIC-225 "0 容忍 bypass".
- **根因**: Rule 37 auto-approve 阈值不严格 (估时 < 8h 实际 < 1h), docs-only 模式 4 sub-roles review 价值低.
- **修复**: 主公拍板 override 5 次, 实际运行 Rule 37 模式.
- **防范**: 未来 docs-only 批量收口显式声明 Rule 37 auto-approve + master 自审 + 主公拍板, 省 70% 时间. 累计 override ≥ 10 次后, 启动 retrospective 决定是否固化 Rule.

### 5. 0 改 source code / 0 增 Rule / 0 增 immutable script

- **现象**: 8 EPIC 全部 docs-only 治理级, 0 source code 改动.
- **根因**: docs-only 不需 Node/Rust build, 跳过 vitest sentinel, 0 regression 风险.
- **修复**: 0 (同 v2.4.1 Rule 合并反思).
- **防范**: 保持 v3.34.6+ 治理债清理模式, 0 增 Rule 且 0 增 immutable script.

## 联动 EPIC

- **EPIC-159**: CLAUDE.md 治理 2.0 入口
- **EPIC-157**: jira/ticket-binding module (缺 test → EPIC-251 已修)
- **EPIC-160/170/171/172/158**: 8 EPIC 走 4-branch 全程
- **EPIC-174**: Smoke Retention 测试 9 个全跑 (`bash tests/integration/smoke-retention.test.sh` → exit 0)
- **EPIC-208/240**: bypass 备案模式
- **EPIC-224**: hook 体系健康
- **EPIC-225**: jargon 黑名单
- **EPIC-228**: 14 ticket 定性 (EPIC-158 在 "10 归档 done")
- **EPIC-251**: 修 EPIC-157 sentinel debt
- **EPIC-252**: 纠正本文件 L3 误诊
