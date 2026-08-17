# EPIC-255 — 删冗余 node/package-lock.json (vitest 版本分叉根因)

**Status**: in_progress → done
**Priority**: P1
**Type**: bugfix
**Estimated**: 3h
**Phase**: PHASE-024

## 表面现象

worktree 内跑 vitest 报:

```
Vitest caught 51 unhandled errors during the test run.
Error: No handler function exported from .../node_modules/vitest/dist/worker.js
 ❯ ../../../../node_modules/tinypool/dist/esm/entry/worker.js:70:15
 Test Files  no tests
     Errors  51 errors
```

之前多个 EPIC 把这记成 "vitest 1.6.1 tinypool env blocker",标 `AC BLOCKED-env`。

## 4 层挖掘 (前 3 层假设都错)

| 层 | 假设 | 实测 |
|---|---|---|
| 1 | vitest 1.6.1 tinypool 是已知 bug | ❌ 不是 bug |
| 2 | 装依赖位置错 (`--prefix <wt>/node` vs `--prefix <wt>`) | ⚠️ 方向对但非根因 |
| 3 | lockfile 被装坏了 | ❌ 用干净 lockfile 的新 worktree 同样复现 |
| 4 | **两份 lockfile 锁不同 vitest 版本** | ✅ **真根因** |

第 3 层的验证方式:另建一个全新 worktree (`agent-clean`),lockfile 是干净 git 版本 (226851 字节,含 tinypool 记录),用正确 prefix 装 → 仍是 291 包、仍缺 tinypool。假设排除。

## 真根因

| 位置 | vitest 版本 | 依赖 tinypool |
|---|---|---|
| `node/package.json` 声明 | `^4.1.10` | — |
| 根 `package-lock.json` | 4.1.10 ✅ | 否 |
| `node/package-lock.json` | **1.6.1** ❌ 过期 | **是** |

装 1.6.1 时它按 workspace hoisting 去根 `node_modules` 找 tinypool,那里是 4.1.10 的依赖树 (无 tinypool) → 报错。

主仓能跑是因为它的 `node_modules` 是历史遗留的 1.6.1 完整树 (含 tinypool),自洽。

## `node/package-lock.json` 来历

```
git log --oneline -- node/package-lock.json
080eb414 fix(ci): EPIC-211 npm audit fix (Rule 8 备案: lockfile 406 packages)
```

只 1 次提交 — 那次 `npm audit fix` 意外产生。workspace 项目只该有根 lockfile,根 lockfile 已完整覆盖 `node/` 的 15 个 devDependencies。

## 修法

`git rm node/package-lock.json`

## CI 同步改动 (3 个 workflow)

| workflow | 原来 | 改成 |
|---|---|---|
| `dual-engine.yml` | `cache-dependency-path: node/package-lock.json`<br>`cd node && npm ci` | `cache-dependency-path: package-lock.json`<br>`npm ci` (根) |
| `kallax-ci.yml` | `working-directory: node` + `npm install` | 根目录 `npm install` |
| `release.yml` | `cd node` → `npm ci` → `npm run build` | `npm ci` (根) → `cd node` → `npm run build` |

不受影响的 6 处 (`ci.yml` ×4 / `coverage-gate.yml` / `perf-baseline.yml`) 本来就在根跑。

## 历史 AC 不回填

EPIC-157 AC8 / EPIC-159 AC5 / EPIC-160 AC5 / EPIC-251 AC7 标的 `BLOCKED-env` **保持原样**。

当时那个环境下 vitest 确实跑不起来,记录的是真实状态。改成 PASS 会掩盖"连续 4 个 EPIC 误判成 vitest bug"这个事实。查这些 AC 时从 `.claude/rules/testing.md` 追根因即可。

## 验证结果

| AC | 状态 | raw output |
|---|---|---|
| AC1 lockfile 已删 | PASS | test Case 2 → `node/package-lock.json absent` |
| AC2 根 lockfile 覆盖 | PASS | test Case 3 → `records all 15 node/ devDependencies` |
| AC3 版本吻合 | PASS | test Case 4 → `declared ^4.1.10, locked 4.1.10 (major 4 matches)` |
| AC4 tinypool 不在根 | PASS | test Case 6 → `not in root lockfile` |
| AC5 vitest 全过 | PASS | `cd node && npx vitest run` → **984 passed / 49 files / 0 fail** |
| AC6 3 workflow 改动 | PASS | dual-engine / kallax-ci / release |
| AC7 YAML 语法 | PASS | 见下方 raw output |

**AC7 raw_output** (3 个 workflow 用 python yaml 解析器逐个验证):

```
dual-engine.yml: valid
kallax-ci.yml: valid
release.yml: valid
```

复现命令见 `/tmp/yaml-proof.sh` 模式 — 对每个 workflow 跑 python yaml 解析, 成功则打印 valid.

| AC8 无残留引用 | PASS | 仅剩说明注释 |
| AC9 rule doc | PASS | test Case 5 → 4 项 PASS |
| AC10 test ≥8 case | PASS | **10 passed, 0 failed** |
| AC11 不回填 | PASS | 4 个历史 ticket 未改 |
| AC12 4-branch | 进行中 | PR-1 → testing → main → miao |

## Follow-up: dual-engine.yml 的延迟验证

`dual-engine.yml` 触发条件:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'node/src/**'
      - 'rust/crates/**'
```

本次改动**不含** `node/src/**` 或 `rust/crates/**`,所以这个 workflow 在 4-branch 全程都不会触发,改动无法立即验证。

**CI 触发时机对照**:

| workflow | 触发 | PR-1 (→testing) | PR-2 (→main) |
|---|---|---|---|
| `kallax-ci.yml` | push + PR to miao/main/testing | ✅ 会跑 | ✅ 会跑 |
| `release.yml` | push to miao/main/testing + tag | ✅ 会跑 | ✅ 会跑 |
| `dual-engine.yml` | push to main + paths 过滤 | ❌ 不跑 | ⚠️ 本次不跑 |

**待确认**:下次有 `node/src/**` 或 `rust/crates/**` 改动合入 main 时,确认 `dual-engine` 的 `npm ci` (根目录) + `cache-dependency-path: package-lock.json` 跑通。

**风险评估**:改动是 2 行路径修正,跟 `kallax-ci.yml` 同一模式。后者在 PR-1 验证通过即可推断此处正确。若 `dual-engine` 仍失败,症状会是 `npm ci` 找不到 lockfile 或 cache miss,修复成本低 (单文件 2 行)。

## 联动

- EPIC-211 (`080eb414` 意外产生该 lockfile)
- EPIC-223 (历史不追溯原则)
- EPIC-157/159/160/251 (受影响的历史判断)
- EPIC-114 (`.claude/rules/testing.md` 所属 rule)
- Rule 34 (独立复现)
