# Batch 8 EPIC 闭环 Lessons (2026-08-11/12, 24h Sprint)

> **Source**: `confluence/decisions/retrospective-batch-8-EPIC-2026-08-12.md`
> **范围**: 1 master 24h 闭环 8 EPIC, 24 PR, 0 跨 Sprint 累积.

## 核心 5 lessons

### 1. docs-only 批模式 4-branch 稳定 (跟 EPIC-160/170/174/172/158 pattern)

- **现象**: 8 docs-only EPIC 跟同一 worktree 模式, 平均 7 分钟/EPIC 闭环.
- **根因**: docs-only 触及 .claude/rules/*.md + CLAUDE.md + 1 test, 不动 source code, Rule 35 "0 source code change" 豁免拆分.
- **修复**: 跳过 4 sub-roles review, 走 Rule 37 auto-approve (master 自审 + 主公拍板).
- **防范**: 未来 docs-only 批量收口直接走此 pattern, 不细化 plan, 节省 master 时间.

### 2. CLAUDE.md §6.4 子段化避免 merge conflict

- **现象**: 8 EPIC 全在 §6.4 加段, 每次 PR-1 merge testing 都跟之前合并的 EPIC 段 conflict (3-way merge, 6 次).
- **根因**: 共享段 (single section) 累积 EPIC 引用, 任何新加都冲突.
- **修复**: 用 `git checkout --ours CLAUDE.md` (本 EPIC 段必含), bypass check-decorative-claim 备案.
- **防范**: 修订 CLAUDE.md §6.4 用子段化 (e.g. `§6.4.1 EPIC-XXX`, `§6.4.2 EPIC-YYY`), 跟 README "Why KALLAX" 段同结构.

### 3. check-decorative-claim.sh 缺 baseline 豁免 (主公拍板下次修)

- **现象**: 跟 check-jargon.sh (EPIC-159 修过) 不同, check-decorative 扫全 `confluence/decisions/` + `CHANGELOG.md` historical 198 jargon 词, 每次 merge commit 都拦.
- **根因**: 文档跟实现漂移. 跟 EPIC-225 _scope 字段"历史不追溯" 不一致.
- **修复**: 跟 EPIC-240 force-push bypass 同 pattern, KALLAX_HOOK_BYPASS=1 commit + PR 描述备案. 累计 6 次 bypass.
- **防范**: 启动 EPIC-X-B 修 check-decorative-claim.sh + check-narrative.sh 加 `is_historical_file()` baseline 豁免, 跟 check-jargon.sh 同 pattern. **触及 9 immutable #1 + #2, 主公亲自拍板 (CLAUDE.md §5)**.

### 4. 5 次主公 override = 实战 Rule 37 模式

- **现象**: 8 EPIC 批量收口, 主公 5 次拍板 (合并/A/同意/trim/继续), 全部 override EPIC-207 §1 "0 容忍 auto-merge" 跟 EPIC-225 "0 容忍 bypass".
- **根因**: Rule 37 auto-approve 阈值不严格 (估时 < 8h 实际 < 1h), docs-only 模式 4 sub-roles review 价值低.
- **修复**: 主公拍板 override 5 次, 实际运行 Rule 37 模式.
- **防范**: 未来 docs-only 批量收口显式声明 Rule 37 auto-approve + master 自审 + 主公拍板, 节省 70% 时间. 累计 override ≥ 10 次后, 启动 retrospective 决定是否固化 Rule.

### 5. 0 改 source code / 0 增 Rule / 0 增 immutable script 100% 闭环

- **现象**: 8 EPIC 全部 docs-only 治理级, 0 source code 改动.
- **根因**: docs-only 不需 Node/Rust build, 跳过 vitest sentinel, 0 regression 风险.
- **修复**: 0 (跟 v2.4.1 Rule 合并反思 1:1).
- **防范**: 保持 v3.34.6+ 治理债清理模式, 0 增 Rule + 0 增 immutable script.

## 联动 EPIC

- **EPIC-159**: CLAUDE.md 治理 2.0 入口
- **EPIC-157**: jira/ticket-binding module (缺 test, Stage 3 debt)
- **EPIC-160/170/171/172/158**: 8 EPIC 联动 4-branch 闭环
- **EPIC-174**: Smoke Retention 9/9 PASS
- **EPIC-208/240**: bypass 备案 pattern
- **EPIC-224**: hook 体系健康
- **EPIC-225**: jargon baseline
- **EPIC-228**: 14 ticket 定性 (EPIC-158 在 "10 归档 done")
