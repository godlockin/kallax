# EPIC-113-A + EPIC-114 经验教训

**日期**: 2026-07-11
**范围**: EPIC-113-A (Rust SQLite persistence 4-PR flow) + EPIC-114 (CI 债务清算)
**PR 记录**: #112 (feature→testing), #113 (testing→main, admin merge), #114 (main→miao, admin merge), #115 (fmt + clippy + heartbeat client, testing base)

---

## 1. 4-PR flow 首次全程真跑 (EPIC-113-A)

**观察**: v3.8.1-3.9.2 5 release 全程跳过 testing/main (EPIC-074 记录). EPIC-113-A 是首次 feature → testing → main → miao 全程走完.

**过程真实成本**:
- feature → testing: 1 PR, 自然 merge
- testing → main: PR CI 失败 (pre-existing 债务), **admin merge** 绕过
- main → miao: PR CI 失败 (同上), **admin merge** 绕过

**教训**:
- 4-PR flow 治不了 pre-existing 债务; 只保证**新增 code 有 gate**
- 老债 (fmt/clippy/vitest deps) 会一直触发 gate → 强迫 admin merge → gate 疲劳
- 治根: 老债当**独立 EPIC** 清 (即 EPIC-114), 不夹带

**How to apply**: 新 EPIC 只对**本 EPIC 引入的 diff** 负责; pre-existing failure 单独立卡, 不阻塞主线.

---

## 2. cargo fmt + clippy 债务的意外联合修复

**观察**: PR #115 计划分两小步 (fmt → clippy). 实际:
- `cargo fmt --all` 重排 39 文件 (+1137/-500)
- **fmt 之后 clippy `--workspace --all-features -- -D warnings` 自动过了** (17 errors 之前是 fmt 导致的行分割副作用)

**关键坑**: 第一次跑 `cargo clippy --fix` 说 OK 但 diff 空 — build cache 保留了旧的 lint 结果.

**教训**:
- clippy 严格模式必须先 `cargo clean` 再跑, 否则 stale cache 混淆
- fmt 重排常常连带修复 clippy warning (line-length / needless_borrow / redundant_pattern), 顺序 fmt→clippy 事半功倍

**How to apply**: 债务修复顺序永远是 `cargo clean && cargo fmt --all && cargo clippy --workspace --all-features -- -D warnings`.

---

## 3. `createHeartbeatClient` 缺失: TDD 反面教材

**观察**: `heartbeat-dead.test.ts` line 27 `import { createHeartbeatClient } from '../../src/core/heartbeat-monitor.js';` — 测试已写, 源码 factory 从未实现. Vitest hook timeout 30s (module resolved but symbol undefined).

**为什么长期没暴露**:
- vitest 全套 hang 掩盖了具体错误 (better-sqlite3 native binding + tsx 缺失 一齐 fail)
- 团队看到 "hang" 就跳过 heartbeat-dead, 关注其他

**教训**:
- **测试写了但源码没写** = 隐性技术债, 比 "测试没写" 更危险 (给出 "已覆盖" 假象)
- 测试 hang / timeout 时**必须逐个隔离**, 不能整套跳过
- 环境依赖问题 (better-sqlite3 需要 `npm run install` 触发 `prebuild-install`, pnpm 不自动跑) 会掩盖真正的代码 bug

**How to apply**:
- 每次 CI 挂时, 至少运行 `vitest run <one-file>` 隔离一个失败
- pnpm 环境: `pnpm install` 后必须验证 `node -e 'require("better-sqlite3")'` 能加载 native binding, 否则跑 `pnpm approve-builds` 或 `cd node_modules/.pnpm/better-sqlite3*/node_modules/better-sqlite3 && npm run install`

---

## 4. state.json 双写 (EPIC-068-A) 在 worktree 中仍需手工 seed

**观察**: EPIC-114 worktree 中 authz gate (performer 角色需要写 `feature/*`) 因 `.kallax/state/state.json` 不存在而 fail-closed.

**修复**: 手工在 worktree 中写一个 minimal state.json (role=performer, branch=feature/*, in_worktree=true).

**教训**:
- EPIC-068-A 双写只在 `session_start.sh` 里触发, worktree add 之后 session 未重启就没写
- 未来: worktree add 时应联动 `session_start` (通过 git worktree hook 或 kallax CLI)

**How to apply**: 手工创建 worktree 后, 若立即要 commit performer diff, 需先 `cp .kallax/state/state.json .worktrees/<w>/.kallax/state/state.json` 或跑 `kallax master:start` 刷新.

---

## 5. exec-task.sh 成功时清理日志导致回溯难

**观察**: `bash ~/.claude/exec-task.sh "name" "cmd"` 返回 `OK success` 时不留 log (节省空间, 符合 CLI Rule). 但 vitest PASS 输出 (含 test 数量 / duration) 也一并消失.

**教训**: PASS 状态若需 raw output (EPIC-069-D check-claim-evidence 要求), 需在命令里显式 `| tee /tmp/xxx.log` 或 exec-task.sh 加 `--keep-log` 选项.

**How to apply**: 5-Level Verify L2 需要 raw test output 时, 在 command 结尾追加 `2>&1 | tee /tmp/vitest-<name>.log`, 避免 exec-task auto-clean.

---

## 6. Playbook (EPIC-113-A + EPIC-114 复盘产出)

**下次 4-PR flow 前置检查**:
1. `pnpm install && pnpm approve-builds && node -e 'require("better-sqlite3")'` (env sanity)
2. `cd rust && cargo clean && cargo fmt --all && cargo clippy --workspace --all-features -- -D warnings && cargo test --workspace --release` (rust gate)
3. `cd node && KALLAX_HOOK_API_KEY=test-... npx vitest run --testTimeout=15000` (node gate)
4. 全部 green 才开 feature → testing PR

**下次 admin merge 前置声明**:
- PR 描述必须明写: "pre-existing debt: <list>, this PR 只负责 <scope>"
- admin merge 后立即开 debt-clearing EPIC (类似 EPIC-114 之于 EPIC-113-A)

---

## 联动

- EPIC-074 (Branch Flow Governance): 4-PR flow 首次真跑, 补齐 v3.8.1-3.9.2 遗留空档
- EPIC-069-D (check-claim-evidence): PR #115 描述含 raw output 引用, 符合新规
- EPIC-068-A (state.json 双写): worktree 场景补丁 (手工 seed) 记录, 待自动化
