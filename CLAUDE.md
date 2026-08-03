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

**4-branch bypass 历史债 备案 (EPIC-155, 2026-07-29 备案)**:
3 commits bypass 4-branch flow (v3.10.0+ 0 容忍):
1. `a8da33f` (miao direct) — archive 38 outdated docs to `_archived/` (v3.32.0 cleanup)
2. `1482ffa` (miao direct) — CLAUDE.md 224→110 + 6 reference docs lazy load (主公策略 A)
3. `40e2b8e` (main direct) — gitignore 清理 (内容 trivial, 主公接受丢失)

主公拍接受丢失 (Phase 3 拍板) — content trivial OR 已 absorb 进 v3.32.1. EPIC-155 计划 (Q3 2026) 创 feature branch retroactively re-promote. 详细: `confluence/decisions/branch-flow-governance-2026-07-09.md`

**Testing / Main 分支 sync 记录**: EPIC-142 (testing) + EPIC-146 (main) force-push pattern 1:1, 备案已 documentation 化.

## 5. 4 不可更改 法律 (immutable scripts)

> **P0-7 路径澄清 (v3.32.1)**: 5 个 immutable scripts **不**全部在 `scripts/permission/`. 实际分布:
> - 4 个在 `scripts/verify/` — `check-decorative-claim.sh`, `check-narrative.sh`, `check-fail-closed.sh`, `check-self-heal.sh`
> - 1 个在 `scripts/hooks/` — `check-claim-evidence.sh` (pre-commit hook 上下文, 仅扫 staged files)
> - 退出码契约: 0=PASS, 1=FAIL (fail-closed, 禁止 print FAIL + exit 0); `scan-dead-code.sh` 加 2=BLOCKED-env (P0-7 治理)

| Script | Path | 职责 |
|--------|------|------|
| `check-decorative-claim.sh` | `scripts/verify/` | 0 装饰 引用 |
| `check-narrative.sh` | `scripts/verify/` | 0 narrative 包装 |
| `check-fail-closed.sh` | `scripts/verify/` | 0 fail-open |
| `check-self-heal.sh` | `scripts/verify/` | self-heal pattern |
| `check-claim-evidence.sh` | `scripts/hooks/` | EPIC-069-D, README/CHANGELOG 数字必带 raw test output, pre-commit |

## 6. EPIC-157 — Expert Binding Tracking (v3.32.2+, 主公 2026-08-02 拍板)

**4 字段** (`jira/tickets/EPIC-XXX/ticket.json` `expert_binding` 对象):

| 字段 | 必填时机 | 治根 |
|---|---|---|
| `suggested_expert` | Master 拆卡时 | Master 主动分类, 不靠 Performer 猜 |
| `actual_expert` | Performer claim 时 (必填) | 强制 Performer 选定 expert pool |
| `expert_binding_at` | claim 时 (ISO8601 自动) | 审计 trail |
| `binding_change_reason` | 当 actual ≠ suggested (必填非空) | 治 silent 改 expert |

**工具**: `scripts/binding/binding-tracker.sh` 提供 `suggest` / `actual` / `validate` / `validate-all` / `report` 5 子命令. 退出码 0=PASS, 1=FAIL, 2=用户错误.

**Metric 副输出**: `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` 新增 `mis_dispatch_binding_rate` 字段 (跟原 `mis_dispatch_rate` 并列). 历史 ticket 跳过不计入分母.

**0 增 Rule, 0 增 immutable script** (跟 v2.4.1 Rule 合并反思一致).

## 7. EPIC-158 — Pre-existing CI Debt Fix (v3.32.3+, 主公 2026-08-03 拍板)

**Debt 1: Forbidden Patterns Check regex false-positive**:
- `.github/workflows/ci.yml` `grep -rn ': any'` 抓 JSDoc prose `fail-closed: any error` 等 (8 处 pre-existing)
- 修复: `grep -v -E '^[^:]+:[0-9]+:\s*\*'` 跟 `grep -v -E '^[^:]+:[0-9]+:\s*//'` 后置 filter
- 影响: PR #176 + #177 + #179 都因这个 false-positive fail, EPIC-158 修复后全 filter

**Debt 2: expert-invocations-queue.test.ts CI env fail**:
- 测试期望 `'sqlite'` 但 CI 环境无 SQLite 时 backend 自动降级 file
- 修复: `skipIfNoSqlite` helper 包裹 5 个 sqlite 依赖 it (跟 EPIC-114 live test guard 一致)
- 行为: `KALLAX_TEST_SQLITE_AVAILABLE=1` 时执行, 否则 skip

**0 改 source code**. CI workflow + test 改动 + EPIC-158 ticket 文档.

## 8. EPIC-160 — install.sh Omnibus (v3.32.5+, 主公 2026-08-03 拍板)

> **起源**: 主公拍板 framework 全部件 (commands/rules/experts/skills/hooks) 在新环境 onboarding + update 时一并部署+升级.

**核心改动** (install.sh ~50 lines):
- **`--inventory` flag**: 列 source→target 映射表 (跟 EPIC-069-D 透明可验证 1:1)
- **`--update` flag**: 升级 update 模式, 走 symlink 不破坏 user files (per install.sh:235)
- **`--skip-rules` / `--skip-experts` / `--skip-hooks`**: 3 新 skip flag
- **4 install function**: `install_rules_for_tool` / `install_experts_for_tool` / `install_hooks_for_tool` / `print_inventory`

**Inventory 95 files**:
- `.claude/skills/` (20) + `.claude/commands/` (62) + `.claude/rules/` (5, EPIC-159) + `experts/` (5) + `.claude/hooks/` (2) + `.claude/settings.json` (1)

**跟现有 Rule 联合 (0 冲突)**:
- EPIC-069-D check-claim-evidence: ✅ `--inventory` 透明可验证
- EPIC-074 4-branch flow: ✅ install.sh 改动走 4-PR
- EPIC-159 .claude/rules/*.md: ✅ 跟 .claude/skills/ 1:1 install
- install.sh:235 symlink mode: ✅ `--update` 复用

**0 增 Rule, 0 增 immutable script, 0 改 source code**. install.sh + tests + docs 改动.

## 9. 引用 (lazy load on-demand)

**Anthropic Memory docs** (≤ 200 行硬阈值): https://code.claude.com/docs/en/memory

**Path-scoped rules** (`.claude/rules/*.md`, 只在匹配 file 时加载):
- `.claude/rules/state-json.md` — EPIC-068-A state.json 路径约定
- `.claude/rules/testing.md` — EPIC-114 test 反模式 + live test skipIf
- `.claude/rules/branch-flow.md` — 4-branch flow if-then 详细
- `.claude/rules/strict-tsconfig.md` — EPIC-131/132 tsconfig strict + scan-dead-code gate-paint 防御

**Reference docs** (15 个, docs/reference/, manual load):
- `branch-flow-history.md` / `cli-reference-2026-06-19.md` / `slash-commands-2026-06-19.md` / `dco-and-licensing.md` / 等