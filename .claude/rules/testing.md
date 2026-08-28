---
paths:
  - CLAUDE.md
  - node/**/*.test.ts
  - node/tests/**
  - rust/**/tests/**
  - "**/*.test.ts"
---

---
paths:
  - CLAUDE.md
  - node/**/*.test.ts
  - node/tests/**
  - rust/**/tests/**
  - "**/*.test.ts"
---

# Test 反模式 + canonical test commands/environment (EPIC-114/158/255/287)

> **Path-scoped rule**: 只在 test 文件被操作时加载.

## workspace 只保留根 package-lock.json (EPIC-255)

`package.json` 声明 `workspaces: ["node"]`, 依赖 hoist 到**仓库根** `node_modules/`.
子包**不该**有自己的 lockfile — 否则两份锁不同版本时会装出混合依赖树.

```bash
# 装依赖 (worktree 或主仓都一样) — 在仓库根跑
npm install --prefix <repo-or-worktree-root>

# 跑 test — 在 node/ 子目录
cd node && npx vitest run
```

### EPIC-255 修的问题

`node/package-lock.json` 锁 vitest **1.6.1**, 根 lockfile 锁 **4.1.10**,
`node/package.json` 声明 `^4.1.10`. 三者对不上.

装 1.6.1 时它按 hoisting 去根 `node_modules` 找 `tinypool` (v1 依赖它, v4 不用),
那里是 4.1.10 的树 → 报 `No handler function exported from vitest/dist/worker.js`.

`node/package-lock.json` 只有 1 次提交 (`080eb414` EPIC-211 `npm audit fix`),
是那次操作意外产生的. EPIC-255 删掉它, 根 lockfile 已完整覆盖 `node/` 的 15 个 devDependencies.

**验证**: vitest 4.1.10 下 `cd node && npx vitest run` → 984 passed / 49 files / 0 fail.

### 受影响的历史判断 (保持原样, 不追溯改写)

| Ticket | AC | 当时判断 |
|---|---|---|
| EPIC-157 | AC8 vitest sentinel | BLOCKED-env |
| EPIC-159 | AC5 vitest sentinel | BLOCKED-env |
| EPIC-160 | AC5 vitest sentinel | BLOCKED-env |
| EPIC-251 | AC7 vitest PASS | BLOCKED-env |

这些 ticket **不回填改 PASS** — 当时那个环境下 vitest 确实跑不起来, `BLOCKED-env` 记录的是
真实状态. 改写会掩盖"连续 4 个 EPIC 误判成 vitest bug"这个事实. 查这些 AC 时从本文件追根因即可.

**误判链** (4 层假设, 前 3 层都错):
1. "vitest 1.6.1 tinypool 是已知 env bug" — 不是 bug
2. "装依赖位置错 (`--prefix <wt>/node`)" — 方向对但非根因
3. "lockfile 被装坏了" — 干净 lockfile 同样复现
4. "两份 lockfile 锁不同 vitest 版本" — 真根因

**验证**: `tests/integration/lockfile-single-source.test.sh`

## 3 个 0 复发 反模式

1. **`*-live.test.ts` 必须 `describe.skipIf(!process.env.X_LIVE)`** — check-live-test-guard.sh 强制
2. **测试断言别绑死 totalScore/枚举硬编码**, 断维度 (软规, vitest fail-fast 兜底)
3. **source bug 不能 `it.skip` 逃避**, 必须修 source 再 unskip

## EPIC-158 skipIfNoSqlite pattern

```typescript
// CI 环境无 sqlite 时自动 skip
const skipIfNoSqlite = process.env.KALLAX_TEST_SQLITE_AVAILABLE === '1' ? it : it.skip;

// 5 个 sqlite 依赖的 it 改为 skipIfNoSqlite (覆盖 expert-invocations-queue fallback chain)
// 见 node/tests/expert-invocations-queue.test.ts:120 周边 5 处
```

## New EPIC sentinel gate

Every new EPIC must run both gates with fresh output:

```bash
bash scripts/scan-dead-code.sh
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage.test.ts \
  tests/dead-code-sentinel-coverage-d.test.ts \
  tests/dead-code-sentinel-coverage-e.test.ts \
  tests/dead-code-master-verify.test.ts
```

Do not replace workspace sentinel run with a cached result or a subset of files. Record raw exit status/output as verification evidence.


- EPIC-114 ticket.json: `jira/tickets/EPIC-114/`
- EPIC-158 ticket.json: `jira/tickets/EPIC-158/`
- `scripts/check-live-test-guard.sh` (force skipIf for live tests)