# KALLAX v3.8.1

> 借鉴 eket 极简哲学 | 6 release 累计: 0 跳流程, 0 估数字, 0 装饰性宣称, 0 元层自嘲

## 3 根本 价值观 (Q12 战略)
- 小步迭代 + 彻底完成 (防止假 PASS 症状复发)
- 诚实修正 (声称与实测偏差时以实测为准, 见 confluence/decisions/)
- 复盘同类症状, 从根源修复 (5 release 累计)

## 5 levels (对齐 eket)
L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary

## 4 roles
Conductor / Performer + 4 sub-roles (coder / reviewer / tester / docs)

## 4 根本 价值 (6 武器 整合)
- 审计: W1 Hash-Chain Audit (v3.8.1 仍 weak, EPIC-072 真锚点)
- 验证: W2 5-Level Fact-Forcing
- 治理: W3 Sub-Role + W4 EPIC 4 件套
- 可视化: W5 Hook + W6 Dashboard

## 4 不可更改 法律 (immutable scripts)
> **P0-7 路径澄清 (v3.32.1)**: 5 个 immutable scripts **不**全部在 `scripts/permission/`. 实际分布:
> - 4 个在 `scripts/verify/` — `check-decorative-claim.sh`, `check-narrative.sh`, `check-fail-closed.sh`, `check-self-heal.sh`
> - 1 个在 `scripts/hooks/` — `check-claim-evidence.sh` (pre-commit hook 上下文, 仅扫 staged files)
> - 退出码契约: 0=PASS, 1=FAIL (fail-closed, 禁止 print FAIL + exit 0); `scan-dead-code.sh` 加 2=BLOCKED-env (P0-7 治理)
- check-decorative-claim.sh (`scripts/verify/`, 0 装饰 引用)
- check-narrative.sh (`scripts/verify/`, 0 narrative 包装)
- check-fail-closed.sh (`scripts/verify/`, 0 fail-open)
- check-self-heal.sh (`scripts/verify/`, self-heal pattern)
- **check-claim-evidence.sh** (`scripts/hooks/`, v3.8.1 EPIC-069-D 新增, README/CHANGELOG 数字必带 raw test output 引用, pre-commit hook)

## Q18 决策矩阵 (对齐诚实修正战略)
- 5 levels × 4 roles = 25 cells
- 5 类 block + 3 类 danger
- scripts/permission/decision-matrix.sh (law, 0 文档化)
- 借鉴 eket 模式, 不新增 Rule

## Branch Flow Governance (EPIC-074, 主公拍板 2026-07-09)

> **起源**: 主公问 "有没有严格遵守 feature/xx-xx → testing → main (UAT) → miao (stable/prod)?"
> **Master 自查 (与 v3.8.0 reviewer 同样诚实)**: ❌ v3.8.1-3.9.2 5 release 跳过 testing + main (直推 miao)
> **主公拍板**: 以后用 + 上个 release 之后补 (推荐)

**4-branch 强制流程** (v3.10.0+ 强制, 0 容忍):

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作                      UAT 验证    集成测试        稳定发布
```

| 阶段 | 操作 | 验证站 | 目的 |
|------|------|--------|------|
| 1. feature/* | `git worktree add -b feature/...` | 5-Level Verify (新规) | worktree 隔离 |
| 2. feature → testing | `gh pr create --base testing` | integration + cargo test + vitest env | 防止 v3.8.0 form-only PASS |
| 3. testing → main | `gh pr create --base main` | full e2e + decision matrix 25 cells | 防止 v3.8.0 "25/25 假 PASS" |
| 4. main → miao | `gh pr create --base miao` | master review + 4 sub-roles | 处理 v3.8.0 red-blue review 阻塞 |

**现状 (2026-07-09 修复后)**:
- `main` ✅ 创建 + 推到 remote (commit 0595fea)
- `testing` ✅ force-update 到 miao tip
- 5 feature 分支 ✅ 推到 remote (PR 追溯 record): v3.8.1/v3.8.2/v3.9.0/v3.9.1/v3.9.2

**5 release PR 追溯 record** (历史跳过, 已补 branch):
| Release | Feature branch (已推 remote) | testing/main PR |
|---------|------------------------------|-----------------|
| v3.8.1 | feature/v3.8.1-EPIC-069 | ❌ 跳过 (历史) |
| v3.8.2 | feature/v3.8.2-EPIC-070 | ❌ 跳过 (历史) |
| v3.9.0 | feature/v3.9.0-EPIC-071 | ❌ 跳过 (历史) |
| v3.9.1 | feature/v3.9.1-EPIC-072 | ❌ 跳过 (历史) |
| v3.9.2 | feature/v3.9.2-EPIC-073 | ❌ 跳过 (历史) |
| v3.29.0 | feature/v3.29.0-EPIC-136-to-139 | PR #148 → base=miao (testing 首次 sync via EPIC-142) |
| v3.30.0 | feature/v3.30.0-EPIC-140-to-142 | PR #149 → testing (merged 4307d2f2); PR #150 → main (closed 因 debt) → force-push (EPIC-146) |
| v3.30.1 | feature/v3.30.1-EPIC-143-to-147 | PR #158 → testing (history-sync, EPIC-146 force-push 时 absorb) |
| v3.32.0-doc-merge | `3105046` transient merge commit on main | ❌ 跳过 (历史) — `Merge remote-tracking branch 'origin/main'`, 跟 v3.32.1 cleanup 一起 accept, main→miao 流程自动 absorb |
| v3.32.0 | `a8da33f` + `1482ffa` direct commits to miao | ❌ 跳过 (历史) — EPIC-155 retroactive remediation 计划中 (CLAUDE.md lazy load + 38 docs archive, 主公策略 A 拍板) |
| v3.32.1-fixup | `40e2b8e` direct commit to main | ❌ 跳过 (历史) — gitignore 清理 (.eket + .kallax/.kallax + settings.local.json 冲突解), 内容 trivial, 主公接受丢失 |

## 4-branch bypass 历史债 备案 (EPIC-155, 2026-07-29 备案)

**3 commits bypass 4-branch flow (v3.10.0+ 0 容忍)**:

1. `a8da33f` (miao direct) — archive 38 outdated docs to `_archived/` (v3.32.0 cleanup)
2. `1482ffa` (miao direct) — CLAUDE.md 224→110 + 6 reference docs lazy load (主公策略 A, v3.32.0)
3. `40e2b8e` (main direct) — gitignore 清理 (.eket + .kallax/.kallax + settings.local.json)

**Root cause**:
- `a8da33f` + `1482ffa`: 在 EPIC-142 testing sync 之后 + v3.32.1 main→miao 流程之前, v3.32.0 doc 单独 ship 跳 testing+main
- `40e2b8e`: main 本地 uncommitted 清理, 内容 trivial (gitignore 3 行), 跟 testing→main 流程并行

**Acceptance**:
- 主公拍接受丢失 (Phase 3 拍板) — content trivial OR 已 absorb 进 v3.32.1
- `1482ffa` 错标 "EPIC-154" (实际是 CLAUDE.md trim, 跟 install.sh fix 的 EPIC-154 ticket 不同 scope) → P0-9 重命名

**Retroactive remediation** (P0-10):
- 本条目已 documentation 化进 CLAUDE.md
- EPIC-155 计划 (Q3 2026) 创 feature branch retroactively re-promote 3 commits 通过 4-branch flow
- 0 新 强制 4-PR 流程修改 — 跟 established pattern (v3.30.1 ❌ 跳过) 1:1

**跟 v3.30.1 治理债 联根**:
- v3.30.1 (PR #158) 已补 record 到上表 (testing 吸收, EPIC-146 force-push 落地)
- 跟当前 4-branch bypass 同 pattern: 历史 ship 跳流程, 备案 + accept, 不修改现 强制 4-PR 流程
- 跟 EPIC-146 "main 分支 sync record (2026-07-26)" 1:1 — main↔miao 同步用 force-push pattern

**testing 分支 sync 记录 (EPIC-142, 2026-07-26)**:
- 首次 4-branch flow 落地时 testing 已落后 miao 6 commit (EPIC-133/134/135 系列, 均未 Signed-off-by, DCO 上线前的历史)
- Master force-push testing 到 miao HEAD (v3.29.0 merge `7187bb5`)
- `check-dco.sh` 加 `--allow-pre-cutoff` 让未来 PR 只查本 PR commits, 不 pollute base 历史
- v3.30.0+ testing 分支强制跟 miao 同步 (每 release merge miao → testing)

**main 分支 sync 记录 (EPIC-146, 2026-07-26)**:
- 4-branch flow 第 2 段 (testing → main) 首次落地时 main 落后 testing 16 commit, 且 main 独有 3 merge commit (`b99fada` / `bb93164` / `fbdc73e` — 全部只是历史 miao/testing → main 的 merge commit, 无独立内容)
- Master 借 EPIC-142 pattern force-push main 到 testing HEAD (v3.30.0 sync commit `4307d2f2`)
- v3.31.0+ main 分支强制跟 testing 同步 (每 testing → main PR merge 后 auto-align)
- **Canary 战果**: PR #150 首次真走到 main 时抓到 main 分支 4 类历史债 (fmt / npm scripts / diverged commits / pre-DCO), 全部 记入 EPIC-143/144/145/146

**0 静默跳过** (配合 EPIC-069-D check-claim-evidence):
- v3.10.0+ 必走 4-PR 全程
- 紧急 bypass 仅 `git commit --no-verify` (主公明确批准时)
- 同类假 PASS 症状再次出现 → pre-commit hook 拦截

详细: `confluence/decisions/branch-flow-governance-2026-07-09.md`

## 5-Level Verify 新规 (EPIC-069-D 防止假 PASS 复发)

> **起源**: v3.8.0 README 声称 "25/25 PASS / 生产级 / 治根", reviewer 红蓝对抗 实测 `cargo test` 11 errors + Node 8/19 fail。**5-Level Verify 之前漏了 cargo test + node env setup, 等于形式通过实质失败**。

**新规 (v3.8.1 强制, 后续 release 0 容忍)**:

| Level | 之前 | 之后 (v3.8.1+) |
|-------|------|---------------|
| L1 git | commit + push | + raw test output 在 PR 描述 (file path + size) |
| L2 stdout | `cargo build` 通过 | **`cargo test --workspace --release` 0 errors (不是 build)** + workspace 全跑 (EPIC-102 升级: 必加 `--workspace` 字面) |
| L3 4-expert | master review APPROVE | + 至少 1 个 expert 提供 raw `cargo test --workspace` / `vitest run` 输出 |
| L4 independent | 5-Level Verify 脚本 | + verify 脚本**真跑** (cache 失效, 不复用上次) |
| L5 boundary | CLAUDE.md Rule check | + **check-claim-evidence.sh** 扫 README/CHANGELOG 数字 |

**CI 必跑**:
- `cd rust && cargo test --release` (必须是 test, 不是 build)
- `cd node && KALLAX_HOOK_API_KEY=test-... npx vitest run` (env 必设)

**禁止**(PRE-COMMIT hook 拦截):
- ❌ README/CHANGELOG 出现 `X/Y PASS` 数字但无 `raw_output` 引用
- ❌ `5-Level Verify PASS` 字样但 L2 是 `cargo build`(必须 `cargo test`)
- ❌ "生产级 / 25/25" 等装饰性断言无 raw output 佐证

## 5-Level Verify 硬化 (EPIC-131 + EPIC-132, v3.27.0+)

> **起源**: EPIC-131 主公抓的 "死代码/类型错误不被调用就不暴露" 治根. EPIC-132-A→G 跑了 `scripts/scan-dead-code.sh` 抓死债并 enabled strict.
> **L2 / L4 必跑扩展规则**:

| 检查 | 必须 | 禁止 |
|------|------|------|
| L2 stdout | `cd node && npm run build` (= `npx tsc`) | ❌ `npx tsc --noEmit` alone (跳过 emit 不算 build) |
| L2 strict | tsconfig 含 `strict: true` (含 noUncheckedIndexedAccess + noPropertyAccessFromIndexSignature + noImplicitOverride + noUnusedLocals + noUnusedParameters) | ❌ `--strict false` 任何 flag override |
| L4 sentinel | `bash scripts/scan-dead-code.sh` exit 0 | ❌ 改 scan 脚本让 sentinel 永远 exit 0 (gate-paint) |
| L4 coverage | `vitest tests/dead-code-sentinel-coverage*.test.ts` 100% pass | ❌ try/catch tolerant 验业务逻辑 (sentinel 仅验"module 加载不抛") |

**Stage 1 regex false-positive 沉淀** (主公 Phase F 教训):
- ❌ `grep -rnE '@ts-ignore'` 抓 JSDoc prose `"no @ts-ignore"` → 排除 `^\s*\*\s` 模式
- ❌ `grep -rnE ':\s*any'` 抓 JSDoc prose `"fail-closed: any error"` → 排除 JSDoc 行
- ❌ `grep -rnE '\bTODO\b'` 抓 enum literal `TicketStatus.TODO` + regex pattern `/TODO/` → 排除
- ❌ `grep -rnE 'catch\s*\('` 抓 `.catch((err: unknown) => ...)` Promise → 排除 `\.catch(`

**新 EPIC 必跑 sentinel**:
```bash
bash scripts/scan-dead-code.sh  # exit 0 = pass
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage.test.ts \
  tests/dead-code-sentinel-coverage-d.test.ts \
  tests/dead-code-sentinel-coverage-e.test.ts \
  tests/dead-code-master-verify.test.ts
```

**tsconfig 跟 5-Level 必须对齐** (跟 EPIC-131 教训):
```
"strict": true,                    # 含 noImplicit* 全套
"noUncheckedIndexedAccess": true,  # index access 后 必须 narrow
"noPropertyAccessFromIndexSignature": true,
"noUnusedLocals": true,             # EPIC-132-G 启用
"noUnusedParameters": true,         # EPIC-132-G 启用
"noImplicitOverride": true,
"noFallthroughCasesInSwitch": true,
```

**Pre-commit hook** (`.githooks/pre-commit`) 强制跑 `scripts/scan-dead-code.sh`。Stage 1 false positives 通过精确 regex 排除。

## CLI 执行规范 (借鉴 whisper-cpp 教训)

**来源**: whisper-cpp 10 段全失败未发现 (wrapper 无 fail-fast + 未主动 grep "FAILED")

**5 条强制**:
1. **后台执行** — 所有 CLI 命令后台跑，不阻塞主会话 (`run_in_background: true` 或 `bash ~/.claude/exec-task.sh`)
2. **日志到 /tmp** — 输出重定向到 `/tmp/claude-tasks/<task>-<ts>.log`
3. **检查 exit code** — 不假设"没看到错误=成功"，必须显式 `if ! cmd; then`
4. **返回 OK/FAILED + 自动 tail** — 成功只返回一行，失败自动 tail 最后 10 行
5. **禁止监控日志** — ❌ `tail -f` / `tail -F` / `less +F` / `watch`

**⚠️ nohup & 是逃逸路径**:
- `nohup ... &` 可绕过 PreToolUse hook 的 `tail -f` 拦截 (hook 认为是"后台任务"非"监控")
- 解法: 统一走 `~/.claude/exec-task.sh` wrapper
- Wrapper 自身必须 `set -e` + `trap ERR`，否则内部命令失败也静默

**Fail-Fast 强制** (EPIC-026-A 教训):
- ❌ 禁止 `cmd || true` 吞错误继续跑
- ✅ 必须 `if ! cmd; then echo "error"; exit 1; fi`
- 关键路径 (heartbeat-daemon / queue emit / atomic mv): 每步必须显式检查

**验证**: `bash ~/.claude/verify-rule.sh verify` 可检查规则完整性

## state.json 路径约定 (EPIC-068-A)

**写者**(session_start.sh, line 236+):
- 主写: `.kallax/state/state.json`(authz 读)
- 备份: `.kallax/instances/<id>/state.json`(历史/audit 兼容)
- atomic via tmp + mv 防 partial read

**读者**(9 个 authz 脚本):
- `scripts/permission/check.sh` 等读 `.kallax/state/state.json`
- role 必从 state.json 读,禁止 env 兜底(PHASE-002 9c)

**多实例**:
- `instances/<id>/` 是 per-instance 历史
- `state/` 是当前活跃实例的入口(单一权威)

**踩过的坑**:
- authz 之前找 `.kallax/state/state.json`,session_start 写到 `instances/.../state.json`,导致所有 authz fail-closed
- EPIC-068-A 修:session_start 双写,9 个脚本不改

## Setup 3 步
cargo install kallax / kallax init / kallax master:start

## EPIC-114 test 反模式 (0 复发)
- `*-live.test.ts` 必须 `describe.skipIf(!process.env.X_LIVE)` — check-live-test-guard.sh 强制
- 测试断言别绑死 totalScore/枚举硬编码,断维度 (软规,vitest fail-fast 兜底)
- source bug 不能 `it.skip` 逃避,必须修 source 再 unskip

## Rule 34 — Bugfix Ticket 必须独立复现 (EPIC-152, v3.31.0, canary 链 6+1 案例驱动)

**起因**: KALLAX v3.30.0 + v3.30.1 canary 链 7 个 EPIC (141 v1 / 145 / 148 / 150-A / 151 / 152 / 153) 的 Performer 独立复现纠正 Master (主公) 错 diagnosis. 决策 doc: `confluence/decisions/fact-forcing-independent-repro-2026-07-26.md`.

**Rule (强制)**:
1. **Master (主公) 建 bugfix ticket 必含 3 字段**:
   - `verification.reproduction_command` — 本地 or CI 复现命令 (e.g. `cd node && npx vitest run tests/x.test.ts`)
   - `verification.reproduction_exit_code` — 实跑 exit code (0 / 1 / 2 / ...)
   - `verification.reproduction_raw_output` — 复现 raw output (前 30 行足够)
   - **不能**只贴 CI log text + 一句话 hypothesis 就建卡. CI log 是 symptom, 不是 diagnosis.
2. **Performer (sub-agent) 收到 ticket 必做独立复现 first**:
   - 跑 reproduction_command 验实诊断一致 — 一致 → 修
   - 不一致 → **STOP**, ticket status → `blocked`, 上报 Master 报告 diagnosis mismatch
   - 不允许为 "fill commit" 编变化; **0 source change 本身也是 valid conclusion** (案例 6 — EPIC-153)
3. **0 source change 不视失败**: Performer 验证债已 cascading 修 / 误报 / 不存在 → ticket done + trace 记录实际状态, 不为 response SLA 编造 empty fix.

**跟现有 Rule 联合 (0 增)**: 跟 Rule 5 DRY (不增 keyword noise), Rule 9 KPI (X/Y 格式), Rule 33 decision-gate (上游 Master 拍"是否修", 下游 Performer 拍"怎么修") 1:1 一致, 不冲突.

**覆盖 ticket 模板 (`jira/tickets/EPIC-XXX/ticket.json`)**: 下方 `verification` block 必含上述 3 field. Master commit 时如 ticket 缺, 分支 fail.

**升级路径**: 此 Rule 在 v3.31.0 起强制 (5 immutable scripts 不增, doc-level enforcement + culture enforcement, 跟 v3.29.0 borrow-from-cindy 模式一致).

## EPIC-157 — Expert Binding Tracking (v3.32.2+, 主公 2026-08-02 拍板)

> **起源**: 主公 review 当前框架能否"同类多实例并行"时拍板 — Master 拆卡时建议 expert, Performer 领卡时 binding 实际 expert, 偏离必填 reason, 完成时 review 一致率. 4 字段直接打通 EPIC-023-C `mis_dispatch_rate` 北极星指标数据源.

**4 字段** (`jira/tickets/EPIC-XXX/ticket.json` `expert_binding` 对象):

| 字段 | 必填时机 | 治根 |
|---|---|---|
| `suggested_expert` | Master 拆卡时 | Master 主动分类, 不靠 Performer 猜 |
| `actual_expert` | Performer claim 时 (必填) | 强制 Performer 选定 expert pool |
| `expert_binding_at` | claim 时 (ISO8601 自动) | 审计 trail |
| `binding_change_reason` | 当 actual ≠ suggested (必填非空) | 治 silent 改 expert, 强制 Performer 解释 |

**跟现有 Rule 联合 (0 冲突)**:
- BE-14 1 ticket 1 subagent 串行: ✅ 不破 (metadata 不改派单模式)
- EPIC-054-A worktree 隔离: ✅ 不破 (字段在 ticket.json, 不动 git worktree)
- EPIC-023-C mis_dispatch_rate: ✅ **直接打通数据源** (新 metric: `mis_dispatch_binding_rate`)
- Rule 34 bugfix 独立复现: ✅ 互补 (binding 字段 + reproduction_command 字段正交)

**工具**: `scripts/binding/binding-tracker.sh` 提供 `suggest` / `actual` / `validate` / `validate-all` / `report` 5 子命令. 退出码 0=PASS, 1=FAIL, 2=用户错误.

**Metric 副输出**: `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` 新增 `mis_dispatch_binding_rate` 字段 (跟原 `mis_dispatch_rate` 并列, 不替换). 历史 ticket (无 `expert_binding`) 跳过不计入分母.

**0 增 Rule, 0 增 immutable script** (跟 v2.4.1 Rule 合并反思一致). 约定层 enforcement + culture enforcement (跟 Rule 34 模式 1:1).
