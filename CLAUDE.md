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

> **起源**: v3.8.0 README 声称 "25/25 PASS / 生产级 / 治根", reviewer 红蓝对抗 实测 `cargo test` 11 errors + Node 8/19 fail。

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
- ❌ "生产级 / 25/25" 等装饰性断言无 raw output 佐证

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
   - 跑 reproduction_command 验实诊断一致 — 一致 → 修
   - 不一致 → **STOP**, ticket status → `blocked`, 上报 Master 报告 diagnosis mismatch
   - **0 source change 本身也是 valid conclusion** (案例 6 — EPIC-153)
3. **0 source change 不视失败**: 验证债已 cascading 修 / 误报 / 不存在 → ticket done + trace 记录.

**跟现有 Rule 联合 (0 增)**: 跟 Rule 5 DRY, Rule 9 KPI (X/Y 格式), Rule 33 decision-gate 1:1 一致, 不冲突.

### 3.1. Rule 35 — Sprint 规划时间盒 (EPIC-190, v3.34.2)

**起因**: 主公 2026-08-07 拍板 (EPIC-185 subagent-5 rule-add), 防止 Sprint 期间超大任务破坏节奏.

**Rule (强制)**:
1. **Sprint 容量上限**: 每个 Sprint 最多 5 个 EPIC, 每个 EPIC 最多 10 commits, 每个 commit ≤ 500 行 (跟 Rule 8 Rule-of-500 联合)
2. **0 超大任务**: 任何任务触及 4 个以上模块 / 涉及 5 个以上文件 → 必须拆 EPIC, 不接受单 PR 兜底 (docs-only 例外, 主公 2026-08-12 拍板 retrospective-batch-8 L13: 实质 1 docs scope, 不视超大)
3. **时间盒**: 单 EPIC 必走 4-PR 全闭环 (跟 Rule 4 联合), 不接受 0 静默跳过阶段 (testing / main / miao 任一)
4. **0 跨 Sprint 累积**: 未完成 EPIC 不延期, 必在当前 Sprint 关闭 (done / blocked / archived, 跟 EPIC-188 retrospective 联合)

**跟现有 Rule 联合 (0 增)**: Rule 4 (4-PR) / Rule 5 (DRY ≥60% 复用) / Rule 8 (≤500 行) / Rule 9 (KPI X/Y) / Rule 13 (3 模式 decision-gate) / Rule 34 (Bugfix 独立复现)

### 3.2. Rule 36 — Sprint 结束必跑 4 北极星 metric (EPIC-194, v3.34.5)

**起因**: 主公 2026-08-07 拍板 (跟 EPIC-023-C 北极星打通 + EPIC-157 binding 字段联合), Sprint 结束必跑 `scripts/metrics/sprint-metrics.sh` 4 指标.

**Rule (强制)**:
1. **expert_activation_rate ≥ 5** — 每个 EPIC 必触发 ≥ 5 distinct experts (避免单点依赖)
2. **cross_epic_reuse_rate ≥ 60%** — file_scope.includes 中 ≥ 60% 已被其他 EPIC 覆盖 (复用而非新建; docs-only 永远 0%, 留待下个 Sprint 加 `cross_epic_docs_reuse_rate`)
3. **ab_hit_rate < 15%** (反向) — A+B 2-Group review 推荐 跟 final outcome 一致率 ≥ 85%
4. **mis_dispatch_rate < 10%** — Performer 派单错率 < 10% (ticket 跨 specialization)

**0 静默跳过**:
- Sprint 结束时必跑 `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` 输出 4 指标
- 4 指标全 PASS 才算 Sprint 闭环 (跟 Rule 35 Sprint 时间盒 联合)
- 0 数据 (NO_DATA exit=2) 触发 ASK, 不接受 silent PASS
- docs-only EPIC 用 `--docs-only` flag 跳过 (exit 3 DOCS_ONLY_SKIP, 跟 EPIC-198 + EPIC-204 1:1)
- **历史 EPIC 归档跳过** (EPIC-223): EPIC 编号 ≤ `jira/tickets/.archive-baseline.json` `archived_before` (当前 222) → 指标 #4 返回 `ARCHIVED_SKIP`, 不回溯. 新卡 (> 222) 强制 `check-ticket-schema.sh` required_fields 全填.

**跟现有 Rule 联合 (0 增)**:
- Rule 5 (DRY): 跨 EPIC 复用 ≥ 60% (跟 EPIC-023-C 北极星 #2 一致)
- Rule 9 (KPI X/Y): 4 指标必带 X/Y 数字 (e.g. expert_activation=5/5)
- Rule 13 (3 模式 decision-gate): NO_DATA 触发 ASK
- Rule 35 (Sprint 时间盒): Sprint 结束必跑 (本 Rule 闭环)
- EPIC-023-C 北极星 (源头)
- EPIC-157 ticket.json binding 字段 (指标 #4 数据源)
- EPIC-204 docs-only metrics 适配 (跳过路径)

## 4. Branch Flow Governance (EPIC-074, 主公拍板 2026-07-09)

**4-branch 强制流程** (v3.10.0+ 强制, 0 容忍):

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作                      UAT 验证    集成测试        稳定发布
```

| 阶段 | 操作 | 验证站 | Master Review | 目的 |
|------|------|--------|---------------|------|
| 1. feature/* | `git worktree add -b feature/...` | 5-Level Verify | 0 (master 自开发) | worktree 隔离 |
| 2. feature → testing | `gh pr create --base testing` | integration + cargo test + vitest env | **master + 4 sub-roles** (Architect/Backend/Frontend/Security) | 防止 v3.8.0 form-only PASS |
| 3. testing → main | `gh pr create --base main` (FF) | full e2e + decision matrix 25 cells | **master + 4 sub-roles + comment 验证** (跟 EPIC-207 v2 1:1) | 防止 v3.8.0 "25/25 假 PASS" |
| 4. main → miao | `gh pr create --base miao` | master review + 4 sub-roles + conflict check | **master 仲裁 + 主公拍板** | 处理 v3.8.0 red-blue review 阻塞 |

**Master Review 强制 (EPIC-207, 2026-08-08 主公拍板)**:
1. **0 容忍 auto-merge**: `gh pr merge --merge --auto` 禁用, 4-PR 任一必走 master + 4 sub-roles review
2. **4 sub-roles 1:1**: Architect / Backend / Frontend / Security 各出 1 份 review (跟 EPIC-056-A 3 阶段 治理 1:1)
3. **conflict check**: PR 必先 `git fetch origin <base>` + `git diff --check` 验 0 conflict
4. **smoke retention**: PR 必跑 `bash scripts/check-smoke-retention.sh` (跟 EPIC-174 联合, smoke ≥ 500 行告警)
5. **PR-2 v2 修正**: testing → main 在 FF 关系下独立 PR 不可行, 走 FF push + comment 验证 (跟 EPIC-207 §5.1 1:1)

**0 静默跳过** (配合 EPIC-069-D check-claim-evidence):
- v3.10.0+ 必走 4-PR 全程
- **0 force-push bypass** (除 EPIC-155/176 备案, 主公明确批准)
- 紧急 bypass 仅 `git commit --no-verify` (主公明确批准时)
- 同类假 PASS 症状再次出现 → pre-commit hook 拦截

**if-then 详细规则** (4 阶段 × 5 验证站): 详见 `.claude/rules/branch-flow.md`

**docs-only 批模式 (主公 2026-08-12 拍板, retrospective-batch-8)**:
- **适用**: docs-only EPIC (0 source code 改动, 触及 CLAUDE.md + 1 test)
- **跳过 4 sub-roles review**: 走 Rule 37 + master 自审 + 主公拍板
- **CLAUDE.md §6.4 conflict**: 累积 EPIC 段必 conflict. 解决 `git checkout --ours CLAUDE.md` (本 EPIC 段必含)
- **写段禁 jargon (EPIC-252 纠正)**: merge commit 的 staged diff 把新写段算新增行, 含黑名单词会被 `check-decorative-claim.sh` 拦 (hook 已传 `KALLAX_STAGED_ONLY=1`, 历史行已豁免). 写段前查 `jira/tickets/.jargon-blacklist.json`, 直接避开, 不用 bypass
- **4-PR 备案债**: testing/main 落后时必 force-push (`--force-with-lease`). 累计 16 个 epicXXX-* 远端 branch 留 audit chain
- **参考**: `confluence/memory/patterns/docs-only-EPIC-batch-closure.md`

**4-branch bypass 历史债 (EPIC-155 + EPIC-176 已闭环, EPIC-208 待办)**:
- **已 re-promote** (EPIC-178, 2026-08-05): 5 commits 已 re-apply 带 `[Q3-repromote]` prefix + DCO — 详见 `confluence/decisions/epic-178-q3-repromote-2026-08-05.md`
- **待 re-promote**: EPIC-208 4 commits (EPIC-203/204/205/206 testing→main, 主公 2026-08-08 拍板接受丢失)
- **本次新增债** (EPIC-223 备案): EPIC-217 PR-2 用 `--delete-branch` 删 testing → EPIC-218~222 跳过 testing 阶段直接 feature→main

## 5. 9 不可更改 法律 (immutable scripts) + 2 smoke 辅助

> **数字对齐 (EPIC-223 + EPIC-224 + EPIC-225, 主公 2026-08-08 拍板)**: 曾出现 4/5/6/7 四个不一致数字, 已统一.
> **完整清单 + 改数字强制流程**: 详见 `.claude/rules/immutable-scripts.md` (path-scoped lazy load).

**9 immutable** (fail-closed, 改动需主公亲自), 全部**已接入 hook** (EPIC-224 验证):
- **原 5**: `check-decorative-claim.sh` / `check-narrative.sh` / `check-fail-closed.sh` / `check-self-heal.sh` (`scripts/verify/`) + `check-claim-evidence.sh` (`scripts/hooks/`, EPIC-069-D)
- **EPIC-224 接入 3**: `check-disclaimer.sh` (EPIC-220, staged .md) + `snapshot-claude-md.sh` (EPIC-219, advisory) + `check-ticket-schema.sh` (EPIC-223, staged ticket.json)
- **EPIC-225 新增 1**: `check-jargon.sh` (黑名单扫 staged, 主公 2026-08-08 拍板 "以后都要禁止使用黑话")

**2 辅助** (非 immutable, 可迭代): `check-smoke-retention.sh` (`scripts/`) + `smoke-size-report.sh` (`scripts/audit/`) — EPIC-174, smoke >=500 行告警

**不算 immutable**: `scan-dead-code.sh` (三态 0/1/2=BLOCKED-env, 跟二态契约不同, P0-7 治理)

**hook 体系健康 (EPIC-224 强制)**: `bash scripts/hooks/install.sh --verify` exit 0 才算生效. CI `hook-health` job 每次 PR 验证. 起因: `core.hooksPath` 曾指向已删临时目录 → 所有 hook 静默失效.

**commit-msg gate (EPIC-221 + EPIC-224)**: DCO `Signed-off-by` 强制 + Conventional Commits type + header ≤100 字符.

## 6. Recent EPICs

> **EPIC-209 trim**: 24 EPICs 详情 (v3.32.2 → v3.34.6, 19 + 5 EPIC-203-208) 移到 `.claude/rules/recent-epics.md` (path-scoped lazy load, 跟 EPIC-159 联合). 主 CLAUDE.md 维持 ≤ 200 行.

## 6.4. Rule 37 — 小 effort auto-approve (EPIC-216, 2026-08-08)

> **主公 2026-08-08 拍板**: "effort 比较小的直接 auto-approve". 跟 EPIC-207 §1 "0 容忍 auto-merge" 矛盾, 主公拍板 override.
> **详细阈值 + 例外 + 跟 Rule 联合**: 详见 `.claude/rules/rule-37.md` (path-scoped lazy load).

**EPIC-157 binding tracking (v3.32.2+)** — Rule 36 北极星 #4 数据源: ticket.json `expert_binding.{suggested_expert,actual_expert,expert_binding_at,binding_change_reason}` 4 字段, Master 拆卡建议 → Performer claim 实际 → 偏离必填 reason. Metric: `scripts/metrics/lib/metrics.sh:compute_mis_dispatch_binding_rate`. 历史 ticket 无 binding 跳过, 不计入分母.

**EPIC-158 CI debt fix (v3.32.3+)** — `.github/workflows/kallax-ci.yml` Forbidden Patterns regex 排除 JSDoc prose (`@ts-ignore` / `:\s*any` / `TODO` 等在 JSDoc `^\s*\*` 行豁免) + `node/tests/expert-invocations-queue.test.ts:120` 5 sqlite 依赖 `it` → `skipIfNoSqlite` (CI 无 sqlite 自动 skip). 5/5 ci-debt-fix.test.sh PASS, 0 改 source code, 跟 EPIC-114 test 反模式 + BE-14 串行.

**EPIC-160 install.sh Omnibus (v3.32.5+)** — `scripts/install.sh` 全部件 deploy + `--inventory`/`--update`/3 skip flag, 95 files 覆盖. `--update` symlink mode 不破 user files, re-run idempotent (13/13). Ref: `.claude/rules/installation.md`.

## 7. 引用 (lazy load on-demand)

**Anthropic Memory docs** (≤ 200 行硬阈值): https://code.claude.com/docs/en/memory

**Path-scoped rules** (`.claude/rules/*.md`, 只在匹配 file 时加载):
- `.claude/rules/state-json.md` — EPIC-068-A state.json 路径约定
- `.claude/rules/testing.md` — EPIC-114 test 反模式 + live test skipIf
- `.claude/rules/branch-flow.md` — 4-branch flow if-then 详细
- `.claude/rules/strict-tsconfig.md` — EPIC-131/132 tsconfig strict + scan-dead-code gate-paint 防御
- `.claude/rules/recent-epics.md` — EPIC-209 24 EPICs 详情
- `.claude/rules/immutable-scripts.md` — EPIC-223 immutable 数字对齐 + 改数字流程

**Reference docs** (24, docs/reference/): `branch-flow-history.md` / `cli-reference-2026-06-19.md` / `slash-commands-2026-06-19.md` / `dco-and-licensing.md` / 等

**Manifesto** (5, confluence/manifesto/, EPIC-206): `01-top-design.md` / `02-scope-mission-vision.md` / `03-timeline.md` / `04-lessons.md` / `05-best-practices.md`