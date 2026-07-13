# EPIC-115 Lint Audit (2026-07-13)

> 目的: 633 lint errors / 108 files / 25 rules 全量登记, 按**目录边界** 切 6 张 ticket, 6 专家并行修复, 0 文件重叠 0 merge conflict.

## 缘起

- `typescript-eslint@8` `strictTypeChecked` (EPIC-114 引入) 打开 24 条 type-aware rule
- 老代码历史积累 → 747 errors 首次暴露
- 已 landed 修复 (this session): Batch 1a (unused-vars) + Batch 8 auto-fix + Batch 2 部分 → 747 → **633**
- 主公 explicit: "先整个 review 找到并记录所有需要修复的地方, 然后用一个 epic 但是多个专家并行修改 + PR, 由 master 统一 review + merge"

## 数据源

- `npx eslint 'src/**/*.ts' -f json > /tmp/epic-115-audit/eslint.json` (2026-07-13, 1.0 MB)
- 聚合脚本: `node -e '...'` (rule + file + dir 三视角)

## Rule 分布 (25 条 / 633 errors)

| Rank | Rule | Count | 机械 vs 手工 |
|------|------|-------|-------------|
| 1 | `@typescript-eslint/restrict-template-expressions` | 171 | 机械 (String() 包裹) |
| 2 | `@typescript-eslint/require-await` | 85 | 半手工 (去 async / 加 await) |
| 3 | `@typescript-eslint/strict-boolean-expressions` | 83 | 手工 (显式 `!= null` / `.length > 0`) |
| 4 | `@typescript-eslint/no-unused-vars` | 83 | 机械 (`_` prefix / 删) |
| 5 | `@typescript-eslint/explicit-function-return-type` | 38 | 机械 (加 `: Promise<void>` / `: void`) |
| 6 | `@typescript-eslint/no-unnecessary-condition` | 30 | 手工 (删无效检查) |
| 7 | `@typescript-eslint/prefer-nullish-coalescing` | 28 | 机械 (`||` → `??`) |
| 8 | `@typescript-eslint/no-non-null-assertion` | 27 | 半手工 (加 guard) |
| 9 | `@typescript-eslint/no-unsafe-assignment` | 22 | 手工 (zod schema) |
| 10 | `@typescript-eslint/no-unsafe-member-access` | 20 | 手工 (zod / type guard) |
| 11 | `@typescript-eslint/no-unsafe-call` | 7 | 手工 |
| 12 | `@typescript-eslint/prefer-optional-chain` | 6 | 机械 |
| 13 | `@typescript-eslint/no-unsafe-argument` | 6 | 手工 |
| 14 | `@typescript-eslint/no-unnecessary-type-conversion` | 5 | 机械 |
| 15 | `@typescript-eslint/no-unnecessary-type-parameters` | 4 | 半手工 |
| 16 | `@typescript-eslint/no-require-imports` | 4 | 机械 (ESM import) |
| 17 | `@typescript-eslint/no-unsafe-return` | 3 | 手工 |
| 18 | `@typescript-eslint/no-base-to-string` | 2 | 机械 |
| 19 | `@typescript-eslint/no-empty-function` | 2 | 机械 (加注释) |
| 20 | `no-useless-escape` | 2 | 机械 |
| 21-25 | misc (namespace, redundant-type, misused-promises, dynamic-delete, await-thenable) | 5 | 手工 |

## Directory 分布 (0 重叠切分)

| Dir | Errors | 分票 |
|-----|--------|------|
| `node/src/core` | 395 | **拆 3 张** (context+dispatch / dag+queue+adapter / master-verify+skills+其余) |
| `node/src/commands` | 91 | **1 张** |
| `node/src/hooks` | 39 | 合入 utils 票 |
| `node/src/utils` | 35 | **1 张** (合 hooks) |
| `node/src/permissions` | 33 | 合入 api 票 |
| `node/src/api` | 29 | **1 张** (合 permissions) |
| `node/src/scripts` + `schema` + `index.ts` | 11 | 合入尾单 |

## Ticket 切分 (6 并行, 文件边界 0 冲突)

### TICKET-115-A — core/context + core/dispatch + top files (~140 err)
- **owner file scope**:
  - `node/src/core/context/**` (37)
  - `node/src/core/dispatch-dashboard.ts` (24)
  - `node/src/core/process-metrics.ts` (17)
  - `node/src/core/instance-registry.ts` (11)
  - `node/src/core/master-election.ts` (11)
  - `node/src/core/agent-farm.ts` (9)
  - `node/src/core/auto-scaler.ts` (9)
  - `node/src/core/enterprise-audit.ts` (10)
  - `node/src/core/complexity-analyzer.ts` (7)
  - `node/src/core/task-router.ts` (8)
  - `node/src/core/*` 其余小文件 (context 上下文相关)

### TICKET-115-B — core/dag + core/expert-invocations-queue + core/data-adapter (~90 err)
- **owner file scope**:
  - `node/src/core/dag-executor.ts` (23)
  - `node/src/core/dag-generator.ts` (10)
  - `node/src/core/dag-visualizer.ts` (6)
  - `node/src/core/expert-invocations-queue/**` (22)
  - `node/src/core/data-adapter/**` (23)
  - `node/src/core/message-queue/**` + `message-queue.ts` (17)
  - `node/src/core/saga-executor.ts` (7)
  - `node/src/core/recovery-manager.ts` (4)

### TICKET-115-C — core/master-verify + core/skills + core/其余 (~90 err)
- **owner file scope**:
  - `node/src/core/master-verify/**` (22)
  - `node/src/core/skills/**` (18)
  - `node/src/core/gate-reviewer.ts` (15)
  - `node/src/core/task-assigner.ts` (7)
  - `node/src/core/quality-trend.ts` (6)
  - `node/src/core/project-pool.ts` (7)
  - `node/src/core/expert-matcher.ts` (5)
  - `node/src/core/span-tracer.ts` (5)
  - `node/src/core/tier-router.ts` (5)
  - `node/src/core/worktree-manager.ts` (5)
  - `node/src/core/brief-inference/**` (4)
  - `node/src/core/{di-container,event-bus,waiting-for-expert,sqlite,knowledge-base,master-verify-bridge,redis-pubsub,git-service,heartbeat-monitor,plugin-system,rust-bridge,sse-bus,auto-decompose,cache-layer,claim-queue,isolation-checker,role-selector,trust-score}.ts`

### TICKET-115-D — commands (~91 err)
- **owner file scope**: `node/src/commands/**`
- 主要文件: `system.ts` (14), `knowledge-cmd.ts` (12), `verify-cmd.ts` (10), `conductor.ts`, `performer.ts`, 其余

### TICKET-115-E — utils + hooks (~74 err)
- **owner file scope**:
  - `node/src/utils/**` (35, top: `startup-validator.ts` 28)
  - `node/src/hooks/**` (39, top: `http-hook-server.ts` 15, `fact-forcing-gate.ts`)

### TICKET-115-F — api + permissions + scripts + schema + index (~73 err)
- **owner file scope**:
  - `node/src/api/**` (29)
  - `node/src/permissions/**` (33, top: `role-transition.ts` 21, `authz-check.ts` 10)
  - `node/src/scripts/**` (7)
  - `node/src/schema/**` (3)
  - `node/src/index.ts` (1)

## 修复策略 (每 ticket 内)

1. **机械先行** (低风险): `pnpm exec eslint --fix <scope>` (auto-fix 覆盖 rule 5, 7, 12, 14, 16, 18, 19, 20)
2. **半机械**: sed 批量 `void (async () => {` → `void (async (): Promise<void> => {`, unused arg 加 `_` prefix
3. **手工**: strict-boolean, no-unsafe-*, non-null-assertion → 加 zod schema 或 `unknown` + type guard, 遵循 CLAUDE.md `as unknown as T` 双转换

## 验证 (每 ticket PR)

```bash
cd node
pnpm exec eslint '<scope glob>' --max-warnings 0
KALLAX_HOOK_API_KEY=test-... npx vitest run --changed
pnpm exec tsc --noEmit
```

PR 描述必带上述 3 条命令 raw output (EPIC-069-D 强制).

## 并行 0 冲突 保证

- 6 张 ticket 的 `owner file scope` **两两不相交** (用 `grep -c` 验证过)
- 共享文件 (config / package.json / eslint.config.js) **禁改** — 若确需, 由 master 单开 PR

## Checkin points (EPIC-111 强制, ≥1)

- **CP-1** (T+24h): 6 专家各自开 PR against `testing`, master 汇总进度
- **CP-2** (PR ready): master unified review, 逐个 squash-merge

## Out of Scope

- e2e / integration test 修复 (vitest exclude 已设)
- rust workspace 修复
- 历史 CHANGELOG / docs/evidence/*.txt 触碰 (禁改)
