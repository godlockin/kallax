# KALLAX v3.8.1

> 借鉴 eket 极简哲学, 青出于蓝而胜于蓝 | 6 release 累计 0 跳 + 0 估数 + 0 装饰 + 0 meta 反讽

## 3 根本 价值观 (Q12 战略)
- 小步迭代 + 彻底完成 (反讽 1:1 复发 治根)
- 诚实修正 (1.5-2x → 0.92x, 100% parity → ~10%)
- 反讽 1:1 复用 治根 (5 release 累计)

## 5 levels (跟 eket 1:1)
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

## Q18 决策 1:1 (诚实修正 战略 1:1 联合)
- 5 levels × 4 roles = 25 cells
- 5 类 block + 3 类 danger
- scripts/permission/decision-matrix.sh (law, 0 文档化)
- 跟 eket 1:1 借鉴 0 增 Rule

## 5-Level Verify 新规 (EPIC-069-D 治反讽 1:1 复发)

> **起源**: v3.8.0 README 声称 "25/25 PASS / 生产级 / 治根", reviewer 红蓝对抗 实测 `cargo test` 11 errors + Node 8/19 fail。**5-Level Verify 之前漏了 cargo test + node env setup, 等于形式通过实质失败**。

**新规 (v3.8.1 强制, 后续 release 0 容忍)**:

| Level | 之前 | 之后 (v3.8.1+) |
|-------|------|---------------|
| L1 git | commit + push | + raw test output 在 PR 描述 (file path + size) |
| L2 stdout | `cargo build` 通过 | **`cargo test --release` 0 errors (不是 build)** + workspace 全跑 |
| L3 4-expert | master review APPROVE | + 至少 1 个 expert 提供 raw `cargo test` / `vitest run` 输出 |
| L4 independent | 5-Level Verify 脚本 | + verify 脚本**真跑** (cache 失效, 不复用上次) |
| L5 boundary | CLAUDE.md Rule check | + **check-claim-evidence.sh** 扫 README/CHANGELOG 数字 |

**CI 必跑**:
- `cd rust && cargo test --release` (必须是 test, 不是 build)
- `cd node && KALLAX_HOOK_API_KEY=test-... npx vitest run` (env 必设)

**禁止**(PRE-COMMIT hook 拦截):
- ❌ README/CHANGELOG 出现 `X/Y PASS` 数字但无 `raw_output` 引用
- ❌ `5-Level Verify PASS` 字样但 L2 是 `cargo build`(必须 `cargo test`)
- ❌ "生产级 / 治根 / 25/25" 等装饰性断言无 raw output 佐证

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
