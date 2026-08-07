# KALLAX v3.32.4

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
- ❌ README/CHANGELOG 出现 `X/Y PASS` 数字但无 `raw_output` 引用
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

## 3.1. Rule 35 — Sprint 规划时间盒 (EPIC-190, v3.34.2)

**起因**: 主公 2026-08-07 拍板 (EPIC-185 subagent-5 rule-add), 防止 Sprint 期间超大任务破坏节奏.

**Rule (强制)**:
1. **Sprint 容量上限**: 每个 Sprint 最多 5 个 EPIC, 每个 EPIC 最多 10 commits, 每个 commit ≤ 500 行 (跟 Rule 8 Rule-of-500 联合)
2. **0 超大任务**: 任何任务触及 4 个以上模块 / 涉及 5 个以上文件 → 必须拆 EPIC, 不接受单 PR 兜底
3. **时间盒**: 单 EPIC 必走 4-PR 全闭环 (跟 Rule 4 联合), 不接受 0 静默跳过阶段 (testing / main / miao 任一)
4. **0 跨 Sprint 累积**: 未完成 EPIC 不延期, 必在当前 Sprint 关闭 (done / blocked / archived, 跟 EPIC-188 retrospective 联合)

**跟现有 Rule 联合 (0 增)**:
- Rule 4 (4-branch flow): Sprint 内 EPIC 必走 4-PR 全闭环
- Rule 5 (DRY): 单 EPIC 不重复造轮子, 跨 EPIC 复用 ≥ 60% (跟 EPIC-023-C 北极星 #2 联合)
- Rule 8 (Rule-of-500): 单 commit ≤ 500 行
- Rule 9 (KPI X/Y): Sprint 总结必带 X/Y 格式测试结果
- Rule 13 (3 模式 decision-gate): Sprint 边界触发 ASK
- Rule 34 (Bugfix 独立复现): Sprint 内修 bug 必带 reproduction

## 3.2. Rule 36 — Sprint 结束必跑 4 北极星 metric (EPIC-194, v3.34.5)

**起因**: 主公 2026-08-07 拍板 (跟 EPIC-023-C 北极星打通 + EPIC-157 binding 字段联合), Sprint 结束必跑 `scripts/metrics/sprint-metrics.sh` 4 指标.

**Rule (强制)**:
1. **expert_activation_rate ≥ 5** — 每个 EPIC 必触发 ≥ 5 distinct experts (避免单点依赖)
2. **cross_epic_reuse_rate ≥ 60%** — file_scope.includes 中 ≥ 60% 已被其他 EPIC 覆盖 (复用而非新建)
3. **ab_hit_rate < 15%** (反向) — A+B 2-Group review 推荐 跟 final outcome 一致率 ≥ 85%
4. **mis_dispatch_rate < 10%** — Performer 派单错率 < 10% (ticket 跨 specialization)

**0 静默跳过**:
- Sprint 结束时必跑 `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` 输出 4 指标
- 4 指标全 PASS 才算 Sprint 闭环 (跟 Rule 35 Sprint 时间盒 联合)
- 0 数据 (NO_DATA exit=2) 触发 ASK, 不接受 silent PASS

**跟现有 Rule 联合 (0 增)**:
- Rule 5 (DRY): 跨 EPIC 复用 ≥ 60% (跟 EPIC-023-C 北极星 #2 一致)
- Rule 9 (KPI X/Y): 4 指标必带 X/Y 数字 (e.g. expert_activation=5/5)
- Rule 13 (3 模式 decision-gate): NO_DATA 触发 ASK
- Rule 35 (Sprint 时间盒): Sprint 结束必跑 (本 Rule 闭环)
- EPIC-023-C 北极星 (源头)
- EPIC-157 ticket.json binding 字段 (指标 #4 数据源)

## 4. Branch Flow Governance (EPIC-074, 主公拍板 2026-07-09)

**4-branch 强制流程** (v3.10.0+ 强制, 0 容忍):

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作                      UAT 验证    集成测试        稳定发布
```

| 阶段 | 操作 | 验证站 | 目的 |
|------|------|--------|------|
| 1. feature/* | `git worktree add -b feature/...` | 5-Level Verify | worktree 隔离 |
| 2. feature → testing | `gh pr create --base testing` | integration + cargo test + vitest env | 防止 v3.8.0 form-only PASS |
| 3. testing → main | `gh pr create --base main` | full e2e + decision matrix 25 cells | 防止 v3.8.0 "25/25 假 PASS" |
| 4. main → miao | `gh pr create --base miao` | master review + 4 sub-roles | 处理 v3.8.0 red-blue review 阻塞 |

**0 静默跳过** (配合 EPIC-069-D check-claim-evidence):
- v3.10.0+ 必走 4-PR 全程
- 紧急 bypass 仅 `git commit --no-verify` (主公明确批准时)
- 同类假 PASS 症状再次出现 → pre-commit hook 拦截

**if-then 详细规则** (4 阶段 × 5 验证站): 详见 `.claude/rules/branch-flow.md`

**4-branch bypass 历史债 备案 (EPIC-155 + EPIC-176, 主公 Phase 3/5 A 拍板)**:
5 commits bypass (a8da33f / 1482ffa / 40e2b8e / 30e923a / 33ecc9b), 主公拍接受丢失 (Phase 3 + Phase 5 A 拍板). EPIC-155/176 计划 Q3 2026 retractively re-promote.
Testing/Main 分支 sync: EPIC-142 (testing) + EPIC-146 (main) force-push pattern 1:1. 详细: `confluence/decisions/branch-flow-governance-2026-07-09.md` + `confluence/decisions/commit-hygiene-2026-08-05.md`

## 5. 4 不可更改 法律 (immutable scripts) + smoke retention

> **P0-7 路径澄清 (v3.32.1)**: 5 个 immutable scripts **不**全部在 `scripts/permission/`. 实际分布:
> - 4 个在 `scripts/verify/` — `check-decorative-claim.sh`, `check-narrative.sh`, `check-fail-closed.sh`, `check-self-heal.sh`
> - 1 个在 `scripts/hooks/` — `check-claim-evidence.sh` (pre-commit hook 上下文, 仅扫 staged files)
> - 退出码契约: 0=PASS, 1=FAIL (fail-closed, 禁止 print FAIL + exit 0); `scan-dead-code.sh` 加 2=BLOCKED-env (P0-7 治理)
>
> **smoke retention (v3.32.20)**: `docs/process/smoke-retention-policy.md` — 5 条规则治理 smoke 测试膨胀 (>=500 行告警)

| Script | Path | 职责 |
|--------|------|------|
| `check-decorative-claim.sh` | `scripts/verify/` | 0 装饰 引用 |
| `check-narrative.sh` | `scripts/verify/` | 0 narrative 包装 |
| `check-fail-closed.sh` | `scripts/verify/` | 0 fail-open |
| `check-self-heal.sh` | `scripts/verify/` | self-heal pattern |
| `check-claim-evidence.sh` | `scripts/hooks/` | EPIC-069-D, README/CHANGELOG 数字必带 raw test output, pre-commit |
| `check-smoke-retention.sh` | `scripts/` | EPIC-174, smoke >=500 行检测 |
| `smoke-size-report.sh` | `scripts/audit/` | EPIC-174, smoke 状态报告 |

## 6. Recent EPICs (v3.32.2 → v3.32.23, 主公 2026-08-02/03/05 拍板)

| EPIC | Version | 关键 | 工具 / 文件 |
|---|---|---|---|
| EPIC-157 | v3.32.2 | ticket.json 4 expert binding 字段 + mis_dispatch_binding_rate 北极星打通 | `scripts/binding/binding-tracker.sh`, `sprint-metrics.sh` |
| EPIC-158 | v3.32.3 | Forbidden Patterns regex false-positive + sqlite skipIf (CI debt) | `.github/workflows/ci.yml`, `skipIfNoSqlite` |
| EPIC-159 | v3.32.4 | CLAUDE.md 307→160 行 + `.claude/rules/*.md` path-scoped lazy load | `.claude/rules/{state-json,testing,branch-flow,strict-tsconfig}.md` |
| EPIC-160 | v3.32.5 | install.sh Omnibus — 全部件 deploy + `--inventory`/`--update`/3 skip flag | `scripts/install.sh`, 95 files |
| EPIC-161 | v3.32.6 | retrospective-routine.sh 6 阶段 routine (复盘/整理/review/升级/归档/删除) | `scripts/retrospective-routine.sh`, `--json` |
| EPIC-168-F | v3.32.13 | daemon 真跑验证 — 抓 3 真 bug (review 漏抓) | `tests/integration/heartbeat-daemon-runtime.test.sh` (10/16 → 抓 3 bug) |
| EPIC-168-BG | v3.32.14 | 修 EPIC-166 4 真 bug + 建北极星 dashboard | `heartbeat-daemon.sh`, `scheduler-hint.sh`, `run-history.sh`, `dashboard-metrics.sh`, `dashboard-metrics.html` |
| EPIC-169 | v3.32.15 | 公开化路径: README.en + frontstage + Lark/WeChat 群 | `README.en.md`, `web/showcase/`, `docs/community/`, `docs/sponsor/` |
| EPIC-170 | v3.32.16 | Expert plugin complete — enabled_policy + activation gates (9 expert 1:1 loopx) | `scripts/skill/skill-manager.sh`, `scripts/skill/skill-policy.sh` |
| EPIC-171 | v3.32.17 | 战略沉淀 — 3 视角 (PR+CTO+Marketing) 定位文档 + README "Why vs Claude Code?" | `confluence/research/kallax-positioning-2026-08-05.md`, `README.md` |
| EPIC-172 | v3.32.18 | 公开化协同 — Lark/WeChat 群 + hosted frontstage + growth loop | `docs/community/`, `web/showcase/`, `confluence/research/kallax-growth-loop-2026-08-05.md` |
| EPIC-175 | v3.32.21 | Security Rules 强化 — Release Capability Usage Gate + Contributor Attribution + Capability Placement 决策树 | `scripts/check-release-capability.sh`, `scripts/automation-monitor-todos.sh`, `scripts/check-benchmark-smoke.sh`, `docs/reference/capability-placement.md`, `docs/process/projection-sink-design.md` |
| EPIC-176 | v3.32.23 | Commit Hygiene 备案 + 未来指南 (跟 EPIC-155 1:1 pattern) | `confluence/decisions/commit-hygiene-2026-08-05.md`, `docs/reference/commit-hygiene-pattern-2026-08-05.md` |
| EPIC-177-G | v3.33.0 | run-history emit integration — 6 脚本 emit hook 闭环 4 北极星 | `binding-tracker.sh`, `heartbeat-daemon.sh`, `post-process.sh`, `branch-4pr.sh`, `install.sh`, `skill-manager.sh` |
| EPIC-180-A | v3.33.2 | frame-task.sh — 4 档路由 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX) + 9 类破坏性拦 + FRAME 表单 | `scripts/frame-task.sh`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/frame-task.test.sh` |
| EPIC-181 | v3.33.2 | 4-PR wrapper 硬化 R1-R5 — `--epic` 必填 + base 同步校验 + state 验证 + 默认删 branch + 退出码契约 0/1/2/3 | `scripts/branch-4pr.sh`, `tests/integration/branch-4pr-harden.test.sh` |
| EPIC-182 | v3.33.4 | 4-PR 实战回归 28 用例 (wrapper R1-R5 + Check 2.7 + branch allowlist + 9 类 + frame preamble) | `tests/integration/4pr-regression.test.sh` |
| EPIC-183 | v3.33.5 | release-entry.sh CHANGELOG 自动生成 + emit decision (跟 EPIC-177-G 联合) | `scripts/release-entry.sh`, `tests/integration/release-entry.test.sh` |
| EPIC-184 | v3.33.6 | frame-task multi-turn clarify (partial/answer/complete) — COMPLEX 档多轮主公澄清 | `scripts/frame-task.sh`, `tests/integration/multi-turn-clarify.test.sh` |
| EPIC-185 | v3.33.7 | 8 subagent 并行派单实测 (frame-task + emit + ledger 跨 agent 查询) | `tests/integration/multi-agent-dispatch.test.sh` |
| EPIC-186 | v3.33.8 | frame-llm.sh LLM v2 入口 + claude-haiku prompt 模板 (跟 heuristic 1:1 兼容) | `scripts/frame-llm.sh`, `tests/integration/frame-llm.test.sh` |
| EPIC-187 | v3.33.9 | AUTO-PERMS 扩展 — git fetch/pull/log/diff 等 read-only 命令默认通过 | `.claude/skills/kallax/SKILL.md`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/auto-perms-expand.test.sh` |

**0 增 Rule, 0 增 immutable script, 0 改 source code** for all 19 EPICs. Full docs + tests + scripts in each.

## 9. 引用 (lazy load on-demand)

**Anthropic Memory docs** (≤ 200 行硬阈值): https://code.claude.com/docs/en/memory

**Path-scoped rules** (`.claude/rules/*.md`, 只在匹配 file 时加载):
- `.claude/rules/state-json.md` — EPIC-068-A state.json 路径约定
- `.claude/rules/testing.md` — EPIC-114 test 反模式 + live test skipIf
- `.claude/rules/branch-flow.md` — 4-branch flow if-then 详细
- `.claude/rules/strict-tsconfig.md` — EPIC-131/132 tsconfig strict + scan-dead-code gate-paint 防御

**Reference docs** (15 个, docs/reference/, manual load):
- `branch-flow-history.md` / `cli-reference-2026-06-19.md` / `slash-commands-2026-06-19.md` / `dco-and-licensing.md` / 等