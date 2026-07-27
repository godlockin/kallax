# KALLAX v3.31.0

> 借鉴 eket 极简哲学 — 0 跳流程, 0 估数字, 0 装饰性宣称, 0 元层自嘲

## 身份确认 (新环境)

```bash
kallax whoami   # 看当前角色; 或 /kallax-start
```

模板: `template/CLAUDE-TEMPLATE.md` 给新项目 init 用 (跟仓库根 CLAUDE.md 完全隔离).

---

## 核心纪律 (永久权威, v3.31.0)

### 5 不可变 scripts (5 immutable laws)

```
scripts/check-decorative-claim.sh   # 0 装饰引用
scripts/check-narrative.sh          # 0 narrative 包装
scripts/check-fail-closed.sh        # 0 fail-open
scripts/check-self-heal.sh          # self-heal pattern
scripts/check-claim-evidence.sh     # 数字必带 raw test output
```

### 5-Level Verify (5 fact-forcing levels, 5 个 levels = L1-L5)

```
L1 git:        commit + push + raw output file path
L2 stdout:     cd rust && cargo test --workspace --release  (0 errors)
               cd node && KALLAX_HOOK_API_KEY=test-... npx vitest run
L3 4-expert:   master review + ≥1 expert 提供 raw cargo / vitest 输出
L4 independent: 5-Level Verify 脚本真跑 (cache 失效)
L5 boundary:   check-claim-evidence.sh 扫 README/CHANGELOG 数字
```

详细硬要求 (tsconfig strict / dead-code sentinel 等): 见 `docs/reference/5-level-verify-harden.md`.

### 4-branch 强制流程 (v3.10.0+)

```
feature/v3.X.Y-EPIC-ZZZ  →  testing (UAT)  →  main (整合)  →  miao (stable)
```

每段 PR 都需 8/9 CI (cargo test + vitest + coverage + audit + check-dco + check-body + pre-commit + CHANGELOG). PR Size > Rule of 500 = Approved-Large-PR-By marker bypass.

历史追溯 (5 release PR record + testing/main sync record): `docs/reference/branch-flow-history.md`.

### Q18 决策矩阵 (5 levels × 4 roles = 25 cells)

脚本: `scripts/permission/decision-matrix.sh` (law, 0 文档化). 借鉴 eket, 不新增 Rule.

### Rule 34 (最新上, EPIC-152, v3.31.0)

bugfix ticket.json 必含 3 field (Performer 独立复现 + 0 source change 是 valid conclusion):

```
verification.reproduction_command    # local or CI
verification.reproduction_exit_code  # 0/1/2/...
verification.reproduction_raw_output # 前 30 行足够
```

7 case 驱动 (EPIC-141 v1 / 145 / 148 / 150-A / 151 / 152 / 153): Performer 独立复现纠正 Master 错 diagnosis 全过程.

详细: `confluence/decisions/fact-forcing-independent-repro-2026-07-26.md`.

---

## 4 根本价值观 + 工具 (核心抽象, 一句话)

- **审计**: 5-Level Verify + immutable scripts (上)
- **验证**: cargo test --workspace + vitest run + raw output
- **治理**: 4 roles (Conductor / Performer + 4 sub-roles) + Rule 34
- **可视化**: WebHook API + Dashboard

---

## 价值观 (Q12 战略, 3 条)

1. **小步迭代 + 彻底完成** — 防止假 PASS 症状复发
2. **诚实修正** — 声称与实测偏差时以实测为准 (见 `confluence/decisions/`)
3. **复盘同类症状, 从根源修复** — canary chain 实践

---

## 细节文档 (按需加载, 不在根 CLAUDE.md)

| 段 | 详情位置 |
|---|---|
| Branch Flow 历史追溯 | `docs/reference/branch-flow-history.md` |
| 5-Level Verify 硬化细节 (tsconfig, sentinel, Stage 1 false-positives) | `docs/reference/5-level-verify-harden.md` |
| CLI 执行规范 (whisper-cpp 教训) | `docs/reference/cli-execution-rules.md` |
| state.json 路径 + 多实例 | `docs/reference/state-json-path-conventions.md` |
| EPIC-114 test 反模式 | `docs/reference/test-anti-patterns.md` |
| Supply-chain 治理 (Node 三重锁, cargo-audit, postinstall) | `docs/reference/supply-chain-cargo.md` + 决定 `docs/reference/version-management.md` |
| DCO governance + Apache-2.0 LICENSE 切换 | `docs/reference/dco-and-licensing.md` |

---

## 模板 (新项目 init, 仓库根不参与)

`template/CLAUDE-TEMPLATE.md` — 完整 4 roles + 项目 metadata placeholder. install.sh 不拷贝根 CLAUDE.md (隔离设计).

---

## 引用历史

- Confluence 决策 (L1 → L2 候选): `confluence/decisions/borrow-from-cindy-2026-07-26.md` + `confluence/decisions/fact-forcing-independent-repro-2026-07-26.md` + `confluence/decisions/branch-flow-governance-2026-07-09.md`.
- 借鉴模式: eket MASTER-RULES.md (锚) + Cindy governance chain (借方法论).
