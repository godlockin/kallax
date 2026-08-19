<!--
  KALLAX PR Template (EPIC-138-A)
  规则源: CLAUDE.md 5-Level Verify + Branch Flow Governance + EPIC-131/132 sentinel
  0 装饰性宣称 · 0 假 PASS · 数字必带 raw output
  下游 CI 校验: EPIC-138-B (check-pr-template.sh)
-->

## PR 标题

> 建议格式 (Conventional Commits): `type(scope): desc`
> 例: `feat(EPIC-138-A): PR template 7 类风险 checkbox`

## 摘要

<!-- 1-2 段说清: 改了什么 + 为什么 -->



## 变更类型

- [ ] feat — 新功能
- [ ] fix — bug 修复
- [ ] refactor — 重构 (无行为变更)
- [ ] docs — 文档
- [ ] test — 测试
- [ ] chore — 杂项
- [ ] release — 发版
- [ ] ci — CI/hook

## 关联 ticket

<!-- 必填. 格式: EPIC-XXX / EPIC-XXX-Y / PHASE-XXX. 无 ticket 禁 merge. -->

- Ticket:

## 🐛 Bugfix 独立复现 (Rule 34, EPIC-152, v3.31.0)

> **bugfix PR 必填 3 字段** (跟 CLAUDE.md Rule 34 1:1). 仅 fix 类型 PR 填, 其他类型勾"不涉及". 缺任一字段 = CI fail.

| 字段 | 必填值 |
|------|--------|
| **reproduction_command** | `<paste 本地 or CI 复现命令, 例: cd rust && cargo test --workspace --release ticket_engine::bug_xxx>` |
| **reproduction_exit_code** | `<实跑 exit code (0/1/2/...)>` |
| **reproduction_raw_output** | `<paste 前 30 行 raw output, 跟## 自动验证 (raw output) 段链接>` |

- [ ] ✅ 3 字段齐, raw output 已贴 (或链接到上方 ## 自动验证 (raw output))
- [ ] 不涉及 (非 bugfix PR): <类型如 feat/docs/refactor>

---

## 🔒 KALLAX 7 类风险 checkbox

> 规则: 每项 **必填**. 勾选 ✅ 或写 `不涉及: <原因 ≥5 字>`. 空项 = CI fail.

### 1. 5-Level Verify (L2)

> `cd node && npm run build` 通过? `cd rust && cargo test --workspace --release` 0 errors? 附 raw output 到下方 `## 自动验证 (raw output)`.

- [ ] ✅ L2 全绿, raw output 已附
- [ ] 不涉及: <原因>

### 2. state.json 边界

> 是否改 `.kallax/state/*` 读写路径 / authz 脚本 (`scripts/permission/*`) / session_start.sh?

- [ ] ✅ 已改, 已跑 9 authz 脚本 fail-closed 验证
- [ ] 不涉及: <原因>

### 3. worktree 隔离

> 变更文件是否全在 `ticket.json.file_scope.includes` 内? 越界 = 违反 Branch Flow Governance.

- [ ] ✅ 全在 scope 内
- [ ] 不涉及: <原因>

### 4. Dead-code sentinel

> 是否新增未被调用的 module? 跑 `bash scripts/scan-dead-code.sh` exit 0?

- [ ] ✅ scan-dead-code.sh exit 0, 无新 dead module
- [ ] 不涉及: <原因>

### 5. Rule / immutable script

> 是否新增/改 5 immutable scripts (`check-decorative-claim.sh` / `check-narrative.sh` / `check-fail-closed.sh` / `check-self-heal.sh` / `check-claim-evidence.sh`) 或 CLAUDE.md Rule?

- [ ] ✅ 已改, 主公明确批准 (link decision doc)
- [ ] 不涉及: <原因>

### 6. Rust ↔ Node 边界

> 是否跨语言改 IPC / protocol / schema / hook API?

- [ ] ✅ 已改, 双端已 sync + 端到端测试
- [ ] 不涉及: <原因>

### 7. 跨 EPIC 复用

> 是否有 `file_scope.includes` 跟其他 EPIC 已完成 ticket overlap 但未记录?

- [ ] ✅ 已 grep 冲突, 无 overlap 或已记录 (link)
- [ ] 不涉及: <原因>

---

## 自动验证 (raw output)

> 强制粘贴 raw output (0 装饰). 无 output = CI fail (EPIC-138-B).

### cargo test (Rust)

```
$ cd rust && cargo test --workspace --release
<paste raw output here>
```

### vitest (Node)

```
$ cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run
<paste raw output here>
```

### scan-dead-code

```
$ bash scripts/scan-dead-code.sh
<paste raw output here>
```

## 手工验证

<!-- bullet list, 描述人肉验证过的行为. 例: -->
<!-- - 本地跑 `kallax init` 生成 .kallax/ 结构, 8 目录齐 -->
<!-- - Master 起来后 4 sub-role 全 spawn (ps aux | grep kallax) -->

-

## 未执行验证

<!-- 显式声明哪些没跑 (跟 Fact-Forcing 一致, 0 假 PASS). 例: -->
<!-- - 未跑 e2e 端到端 (需 3 台机器) -->
<!-- - 未验证 macOS 以外平台 -->

-

## 回滚方案

<!-- 一句话: 如何回滚? -->
<!-- 例: `git revert <sha>` 直接回退, 无 schema migration -->



---

## Review 分级 (EPIC-270, 主公 2026-08-18 拍板)

> **必填**. 取代原 "4-expert review" —— 单人项目下 4 条 APPROVE 物理上做不到
> (`gh pr review --approve` 对自己的 PR 报 "Can not approve your own pull request"),
> 且我扮演 4 个角色写的 review 共享同一条推理路径, 买不到独立性.
> subagent 是独立 context, 看不到我的推理, 只能自己跑命令 —— 这才是真独立。
>
> 判据 (复用 Rule 37 阈值, 不新造):
> - **T1 自评**: 0 源码改动 + ≤100 行 + 单 commit
> - **T2 单 subagent**: 有源码改动 或 >100 行 → 必附 review_summary
> - **T3 多 subagent**: ≥5 文件 或 >500 行 或 改 immutable/Rule/CI → 必附 review_summary
>
> review_summary 是 PR body 内联文字 (不是文件路径) —— 核实报告是过程描述,
> 不落库. 有决策价值的结论走 confluence/decisions/ 文档. 写清:
> 核实了什么 / 发现什么 / 怎么处理.

```
review_tier: T1
review_summary:
```

<!--
T2/T3 示例:
review_tier: T2
review_summary: |
  独立核实者复现 pattern 边界, 发现 AC2 描述错 (matched 修前就是 8).
  已修 ticket AC2 + 补 env var 覆盖 bug.
-->

Gate: `scripts/ci/check-review-tier.sh` 校验 tier 声明跟 diff 规模相符 + T2/T3 review_summary 非空.

---

## 提交前 checklist

- [ ] DCO 签核 (`Signed-off-by:` 在 commit message)
- [ ] 无凭证入库 (API key / token / password 均在 env 或 secret)
- [ ] 文档同步 (README / CHANGELOG / CLAUDE.md 数字必带 raw output 引用)
- [ ] 测试全绿 (cargo test --workspace --release + vitest 均 pass)
- [ ] Branch flow 已走 (`feature/*` → `testing` → `main` → `miao`, 0 直推 miao)
- [ ] Review 分级已填 (T1 自评 / T2 单 subagent / T3 多 subagent, T2+ 附落仓 evidence)
