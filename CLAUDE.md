# KALLAX v3.34.6

> **CLAUDE.md 治理 2.0 (EPIC-159)**: 主文件 ≤ 200 行 (Anthropic 硬阈值). 低频 / reference 内容移 `.claude/rules/*.md` path-scoped lazy load.

> 借鉴 eket 极简哲学 | 8 release 累计: 0 跳流程, 0 估数字, 0 装饰性宣称, 0 元层自嘲

## 1. CLI 执行规范 (每次工具调用, 失败成本最高)

**来源**: whisper-cpp 10 段全失败未发现 (wrapper 无 fail-fast + 未主动 grep "FAILED")

**5 条强制**:
1. **后台执行** — 所有 CLI 命令后台跑，不阻塞主会话 (`run_in_background: true` 或 `bash ~/.claude/exec-task.sh`)
2. **日志到 /tmp** — 输出重定向到 `/tmp/claude-tasks/<task>-<ts>.log`
3. **检查 exit code** — 不假设"没看到错误=成功"，必须显式 `if ! cmd; then`
4. **返回 OK/FAILED + 自动 tail** — 成功只返回一行，失败自动 tail 最后 10 行
5. **禁止监控日志** — ❌ `tail -f` / `tail -F` / `less +F` / `watch`

**⚠️ nohup & 是逃逸路径**: 可绕过 PreToolUse hook `tail -f` 拦截. 统一走 `~/.claude/exec-task.sh` wrapper. Wrapper 必须 `set -e` + `trap ERR`.

**Fail-Fast 强制** (EPIC-026-A 教训):
- ❌ 禁止 `cmd || true` 吞错误继续跑
- ✅ 必须 `if ! cmd; then echo "error"; exit 1; fi`

## 2. 5-Level Verify 新规 (EPIC-069-D 防止假 PASS 复发)

> **起源**: v3.8.0 README 用 3 个装饰性词组声称测试全过, reviewer 红蓝对抗 实测 `cargo test` 11 errors + Node 8/19 fail。

| Level | 之前 | 之后 (v3.8.1+) |
|-------|------|---------------|
| L1 git | commit + push | + raw test output 在 PR 描述 (file path + size) |
| L2 stdout | `cargo build` 通过 | **`cargo test --workspace --release` 0 errors** + workspace 全跑 (EPIC-102 升级: 必加 `--workspace` 字面) |
| L3 4-expert | master review APPROVE | + 至少 1 个 expert 提供 raw `cargo test --workspace` / `vitest run` 输出 |
| L4 independent | 5-Level Verify 脚本 | + verify 脚本**真跑** (cache 失效, 不复用上次) |
| L5 boundary | CLAUDE.md Rule check | + **check-claim-evidence.sh** 扫 README/CHANGELOG 数字 |

**禁止** (PRE-COMMIT hook 拦截):
- ❌ README/CHANGELOG 出现 `X/Y PASS` 数字无 `raw_output` 引用
- ❌ `5-Level Verify PASS` 字样但 L2 是 `cargo build`(必须 `cargo test`)
- ❌ "全过 / 全绿" 等裸数字宣称无 raw output 佐证

**新 EPIC 必跑 sentinel**:
```bash
bash scripts/scan-dead-code.sh  # exit 0 = pass
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage.test.ts \
  tests/dead-code-sentinel-coverage-d.test.ts \
  tests/dead-code-sentinel-coverage-e.test.ts \
  tests/dead-code-master-verify.test.ts
```

**5-Level 硬化** (EPIC-131/132, tsconfig strict + scan-dead-code gate-paint 防御): 详见 `.claude/rules/strict-tsconfig.md`

## 3. Rule 34 — Bugfix Ticket 必须独立复现 (EPIC-152, v3.31.0)

**起因**: KALLAX v3.30.0 + v3.30.1 canary 链 7 个 EPIC Performer 独立复现纠正 Master 错 diagnosis.

**Rule (强制)**:
1. **Master 建 bugfix ticket 必含 3 字段**:
   - `verification.reproduction_command` — 本地 or CI 复现命令
   - `verification.reproduction_exit_code` — 实跑 exit code (0 / 1 / 2 / ...)
   - `verification.reproduction_raw_output` — 复现 raw output (前 30 行足够)
   - **不能**只贴 CI log text + 一句话 hypothesis 就建卡. CI log 是 symptom, 不是 diagnosis.
2. **Performer 收到 ticket 必做独立复现 first**:
   - 跑 reproduction_command 验证诊断是否吻合 — 吻合 → 修
   - 不吻合 → **STOP**, ticket status → `blocked`, 上报 Master 报告 diagnosis mismatch
   - **0 source change 本身也是 valid conclusion** (案例 6 — EPIC-153)
3. **0 source change 不视失败**: 验证债已 cascading 修 / 误报 / 不存在 → ticket done + trace 记录.

**跟现有 Rule 复用 (0 增)**: Rule 5 DRY, Rule 9 KPI (X/Y 格式), Rule 33 decision-gate 对应, 不冲突.

### 3.1. Rule 35 — Sprint 规划时间盒 (EPIC-190, v3.34.2)

**起因**: 主公 2026-08-07 拍板 (EPIC-185 subagent-5 rule-add), 防止 Sprint 期间超大任务破坏节奏.

**Rule (强制)**:
1. **Sprint 容量上限**: 每个 Sprint 最多 5 个 EPIC, 每个 EPIC 最多 10 commits, 每个 commit ≤ 500 行 (沿用 Rule 8 Rule-of-500)
2. **0 超大任务**: 任何任务触及 4 个以上模块 / 涉及 5 个以上文件 → 必须拆 EPIC, 不接受单 PR 兜底 (docs-only 例外, 主公 2026-08-12 拍板 retrospective-batch-8 L13: 实质 1 docs scope, 不视超大)
3. **时间盒**: 单 EPIC 必走 4-PR 全程 (沿用 Rule 4), 不接受 0 静默跳过阶段 (testing / main / miao 任一)
4. **0 跨 Sprint 累积**: 未完成 EPIC 不延期, 必在当前 Sprint 关闭 (done / blocked / archived, 沿用 EPIC-188 retrospective)

**跟现有 Rule 复用 (0 增)**: Rule 4 (4-PR) / Rule 5 (DRY ≥60% 复用) / Rule 8 (≤500 行) / Rule 9 (KPI X/Y) / Rule 13 (3 模式 decision-gate) / Rule 34 (Bugfix 独立复现)

### 3.2. Rule 36 — Sprint 结束必跑 4 北极星 metric (EPIC-194, v3.34.5)

> **EPIC-277-H 主公 2026-08-22 拍板**: cross_epic_reuse_rate 阈值 60% → **40%** (基础设施型 EPIC 复用率天然低). mis_dispatch_rate 加 `multi_spec_intentional: true` 豁免 (跨多 specialization 是设计, 非错派). 见 `confluence/decisions/EPIC-277-cross-sprint-followup-2026-08-22.md` §3.

**起因**: 主公 2026-08-07 拍板 (数据源: EPIC-023-C 北极星 + EPIC-157 binding 字段), Sprint 结束必跑 `scripts/metrics/sprint-metrics.sh` 4 指标.

**Rule (强制)**:
1. **expert_activation_rate ≥ 5** — 每个 EPIC 必触发 ≥ 5 distinct experts (避免单点依赖)
2. **cross_epic_reuse_rate ≥ 40%** — file_scope.includes 中 ≥ 40% 已被其他 EPIC 覆盖 (复用而非新建). EPIC-277-H 主公拍板从 60% 放宽到 40% (基础设施型 EPIC 复用率天然低, 60% 阈值过严)
2b. **cross_epic_docs_reuse_rate ≥ 40%** (EPIC-253 副指标) — 只算 docs 类路径 (CLAUDE.md / .claude/rules / confluence / docs / *.md / tests/integration/*.sh), 给 docs-only EPIC 区分度. 阈值放宽因 docs 天然比 code 分散
3. **ab_hit_rate < 15%** (反向) — A+B 2-Group review 推荐 跟 final outcome 吻合率 ≥ 85%
4. **mis_dispatch_rate < 10%** — Performer 派单错率 < 10% (ticket 跨 specialization). EPIC-277-H 加豁免: `ticket.json.multi_spec_intentional: true` → scope_conflict 强制 0 (跨多 spec 是设计)

**0 静默跳过**:
- Sprint 结束时必跑 `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` 输出 4 指标
- 4 指标全 PASS 才算 Sprint 收尾 (沿用 Rule 35 Sprint 时间盒)
- 0 数据 (NO_DATA exit=2) 触发 ASK, 不接受 silent PASS
- docs-only EPIC 用 `--docs-only` flag 跳过 (exit 3 DOCS_ONLY_SKIP, 沿用 EPIC-198 + EPIC-204)
- **历史 EPIC 归档跳过** (EPIC-223): EPIC 编号 ≤ `jira/tickets/.archive-baseline.json` `archived_before` (当前 222) → 指标 #4 返回 `ARCHIVED_SKIP`, 不回溯. 新卡 (> 222) 强制 `check-ticket-schema.sh` required_fields 全填.

**跟现有 Rule 复用 (0 增)**:
- Rule 5 (DRY): 跨 EPIC 复用 ≥ 40% (数字取自 EPIC-023-C 北极星 #2, EPIC-277-H 主公拍板 60→40)
- Rule 9 (KPI X/Y): 4 指标必带 X/Y 数字 (e.g. expert_activation=5/5)
- Rule 13 (3 模式 decision-gate): NO_DATA 触发 ASK
- Rule 35 (Sprint 时间盒): Sprint 结束必跑 (本 Rule 收尾)
- EPIC-023-C 北极星 (源头)
- EPIC-157 ticket.json binding 字段 (指标 #4 数据源)
- EPIC-204 docs-only metrics 适配 (跳过路径)

## 4. Branch Flow Governance (EPIC-074, 主公拍板 2026-07-09)

**4-branch 强制流程** (v3.10.0+ 强制, 0 容忍):

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作                      UAT 验证    集成测试        稳定发布
```

| 阶段 | 操作 | 验证站 | Review 分级 | 合并权 (EPIC-275) |
|------|------|--------|---------------|------|
| 1. feature/* | `git worktree add -b feature/...` | 5-Level Verify | 0 (master 自开发) | — |
| 2. feature → testing | `gh pr create --base testing` | integration + cargo test + vitest env | **T1/T2/T3 分级** (EPIC-270) | **master 自审自合** |
| 3. testing → main | `gh pr create --base main` | full e2e + decision matrix 25 cells | **T1/T2/T3 分级 + comment 验证** | **master review 后自合** |
| 4. main → miao | `gh pr create --base miao` | conflict check | T1/T2/T3 分级 | **主公亲自** (EPIC-242 §3) |

**合并权 (EPIC-275, 2026-08-19 主公拍板)**: 前两段 master 自主合, `main → miao` 仍主公亲自. 起因: 2026-08-19 清 26 EPIC 积压走 6 个 PR 每段停等拍板. 自主指**合并动作**不需点头, review 责任不变 (T2/T3 仍必附 review_summary).

**Review 分级强制 (EPIC-270, 2026-08-18 主公拍板 — 取代 EPIC-207 的 4 sub-roles)**:
1. **T1** 0 源码 + ≤100 行 + 单 commit (Rule 37 阈值) | **T2** 有源码 或 >100 行 | **T3** ≥5 文件 或 >500 行 或 改 immutable/Rule/CI
2. **T2/T3 必附内联 review_summary**: PR body 写清核实什么/发现什么/怎么处理. 过程凭证不落库, 决策结论走 confluence/decisions/
3. **为什么换**: 实测 53 PR 全部 `reviews=0`; `gh pr review --approve` 对自己的 PR 物理上报错; 我扮 4 角色的 review 共享同一推理路径. subagent 独立 context 才真独立 (本 sprint 推翻我 11 处声明)
4. **Gate**: `scripts/ci/check-review-tier.sh` 校验 tier 跟 diff 规模相符 + review_summary 非空
5. **conflict check**: `git fetch origin <base>` + `git merge-tree --write-tree <base> <head>`. ⚠️ 老式两参数 `git merge-tree <a> <b>` 是 trivial-merge 输出, 不做三方合并, 冲突标记恒为 0 (EPIC-273 实测报 0 而 GitHub 实为 4 文件冲突)
6. **smoke retention**: PR 必跑 `bash scripts/check-smoke-retention.sh` (阈值来自 EPIC-174)
7. **跨主干必 merge commit, 禁 squash/rebase** (EPIC-273): 仓库设置已禁用 (`allow_squash_merge=false`). squash 让父节点不指向源分支 → 拓扑失真 + FF 失效 + DCO email-mismatch. 实测禁用后三主干反向 commit 从 22/21 降到 0/0, 冲突从 4 降到 0

**详细规则**: 详见 `.claude/rules/review-tier.md` (path-scoped lazy load)

**0 静默跳过 + if-then 详细规则** (4 阶段 × 5 验证站 + 合并权边界): 详见 `.claude/rules/branch-flow.md`

**docs-only 批模式 (主公 2026-08-12 拍板, retrospective-batch-8)**:
- **适用**: docs-only EPIC (0 source code 改动, 触及 CLAUDE.md + 1 test) → 落 T1 自评 (EPIC-270 分级)
- **CLAUDE.md §6.4 conflict**: 累积 EPIC 段必 conflict. 解决 `git checkout --ours CLAUDE.md` (本 EPIC 段必含)
- **写段禁 jargon (EPIC-252 纠正)**: merge commit 的 staged diff 把新写段算新增行, 含黑名单词会被 `check-decorative-claim.sh` 拦 (hook 已传 `KALLAX_STAGED_ONLY=1`). 写段前查 `jira/tickets/.jargon-blacklist.json` 直接避开. 同类误报 `check-disclaimer.sh` 已由 EPIC-274 修 (MERGE_HEAD 检测). **force-push 备案债 EPIC-275 废止** — 分叉已消除, 无需 force-push

- **参考**: `confluence/memory/patterns/docs-only-EPIC-batch-closure.md`

**4-branch bypass 历史债 (EPIC-155 + EPIC-176 已完成, EPIC-208 待办)**:
- **已 re-promote** (EPIC-178, 2026-08-05): 5 commits 已 re-apply 带 `[Q3-repromote]` prefix + DCO — 详见 `confluence/decisions/epic-178-q3-repromote-2026-08-05.md`
- **待 re-promote**: EPIC-208 4 commits (EPIC-203/204/205/206 testing→main, 主公 2026-08-08 拍板接受丢失)
- **本次新增债** (EPIC-223 备案): EPIC-217 PR-2 用 `--delete-branch` 删 testing → EPIC-218~222 跳过 testing 阶段直接 feature→main

## 5. 10 不可更改 法律 (immutable scripts) + 2 smoke 辅助

## 5. 10 不可更改 法律 (immutable scripts) + 2 smoke 辅助

> **数字对齐 (EPIC-223 + EPIC-224 + EPIC-225 + EPIC-277-E + EPIC-280, 主公 2026-08-08 / 2026-08-21 拍板)**: 曾出现 4/5/6/7 四个不一致数字, 已统一.
> **EPIC-277-E (2026-08-21)**: scripts/hooks/ 接入 4 新 (check-disclaimer / snapshot-claude-md / check-ticket-schema / check-jargon), install --verify 9/9 PASS 实测.
> **EPIC-280 (2026-08-21)**: 从 9 → 10 admission. 加 `verify-agent-note-format.sh` (DSH Path A 借鉴), install --verify 10/10 PASS.
> **完整清单 + 改数字强制流程**: 详见 `.claude/rules/immutable-scripts.md` (path-scoped lazy load).

**10 immutable** (fail-closed, 改动需主公亲自), 全部**已接入 hook** (EPIC-224 + EPIC-277-E + EPIC-280 验证):
- **原 5**: `scripts/hooks/check-decorative-claim.sh` / `check-narrative.sh` / `check-fail-closed.sh` / `check-self-heal.sh` (pre-commit 4-law loop) + `scripts/hooks/check-claim-evidence.sh` (EPIC-069-D)
- **EPIC-224 接入 3** (AC2/AC3/AC1): `scripts/hooks/check-disclaimer.sh` (EPIC-220, staged .md) + `scripts/hooks/snapshot-claude-md.sh` (EPIC-219, advisory) + `scripts/hooks/check-ticket-schema.sh` (EPIC-223, staged ticket.json)
- **EPIC-225 新增 1** (AC4): `scripts/hooks/check-jargon.sh` (黑名单扫 staged, 主公 2026-08-08 拍板 "以后都要禁止使用黑话")
- **EPIC-280 新增 1**: `scripts/hooks/verify-agent-note-format.sh` (DSH Path A 借鉴, 主公 2026-08-21 拍板 "9→10 admission")

**Canonical 路径清单** (跟 install --verify 10/10 PASS 1:1, 改数字强制流程见 immutable-scripts.md):
```
scripts/hooks/check-claim-evidence.sh
scripts/hooks/check-decorative-claim.sh
scripts/hooks/check-disclaimer.sh
scripts/hooks/check-fail-closed.sh
scripts/hooks/check-jargon.sh
scripts/hooks/check-narrative.sh
scripts/hooks/check-self-heal.sh
scripts/hooks/check-ticket-schema.sh
scripts/hooks/snapshot-claude-md.sh
scripts/hooks/verify-agent-note-format.sh
```

**2 辅助** (非 immutable, 可迭代): `scripts/check-smoke-retention.sh` + `scripts/audit/smoke-size-report.sh` — EPIC-174, smoke >=500 行告警

**不算 immutable**: `scan-dead-code.sh` (三态 0/1/2=BLOCKED-env, 跟二态契约不同, P0-7 治理)

**hook 体系健康 (EPIC-224 + EPIC-277-E 强制)**: `bash scripts/hooks/install.sh --verify` exit 0 才算生效 (9/9 PASS). CI `hook-health` job 每次 PR 验证. 起因: `core.hooksPath` 曾指向已删临时目录 → 所有 hook 静默失效.

**commit-msg gate (EPIC-221 + EPIC-224)**: DCO `Signed-off-by` 强制 + Conventional Commits type + header ≤100 字符.

## 6. Recent EPICs

> **EPIC-209 trim**: 24 EPICs 详情 (v3.32.2 → v3.34.6, 19 + 5 EPIC-203-208) 移到 `.claude/rules/recent-epics.md` (path-scoped lazy load, 沿用 EPIC-159). 主 CLAUDE.md 维持 ≤ 200 行.

## 6.4. Rule 37 — 小 effort auto-approve (EPIC-216, 2026-08-08)

> **主公 2026-08-08 拍板**: "effort 比较小的直接 auto-approve". 跟 EPIC-207 §1 "0 容忍 auto-merge" 矛盾, 主公拍板 override.
> **详细阈值 + 例外 + 跟 Rule 复用**: 详见 `.claude/rules/rule-37.md` (path-scoped lazy load).

## 7. 引用 (lazy load on-demand)

**Anthropic Memory docs** (≤ 200 行硬阈值): https://code.claude.com/docs/en/memory

**Path-scoped rules** (`.claude/rules/*.md`, 只在匹配 file 时加载):
- `.claude/rules/state-json.md` — EPIC-068-A state.json 路径约定
- `.claude/rules/testing.md` — EPIC-114 test 反模式 + live test skipIf
- `.claude/rules/branch-flow.md` — 4-branch flow if-then 详细
- `.claude/rules/strict-tsconfig.md` — EPIC-131/132 tsconfig strict + scan-dead-code gate-paint 防御
- `.claude/rules/recent-epics.md` — EPIC-209 24 EPICs 详情
- `.claude/rules/immutable-scripts.md` — EPIC-223 immutable 数字对齐 + 改数字流程
- `.claude/rules/retrospective.md` — EPIC-161 retrospective routine 6 阶段
- `.claude/rules/review-tier.md` — EPIC-270 T1/T2/T3 review 分级 + evidence 落仓

**Reference docs** (24, docs/reference/): `branch-flow-history.md` / `cli-reference-2026-06-19.md` / `slash-commands-2026-06-19.md` / `dco-and-licensing.md` / 等

**Manifesto** (5, confluence/manifesto/, EPIC-206): `01-top-design.md` / `02-scope-mission-vision.md` / `03-timeline.md` / `04-lessons.md` / `05-best-practices.md`