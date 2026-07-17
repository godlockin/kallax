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
- check-decorative-claim.sh (0 装饰 引用)
- check-narrative.sh (0 narrative 包装)
- check-fail-closed.sh (0 fail-open)
- check-self-heal.sh (self-heal pattern)
- **check-claim-evidence.sh** (v3.8.1 EPIC-069-D 新增, README/CHANGELOG 数字必带 raw test output 引用)

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
