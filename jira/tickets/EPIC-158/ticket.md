# EPIC-158 — Pre-existing CI debt

> **Origin**: EPIC-157 (v3.32.2) 4-branch flow 暴露 2 个 pre-existing CI 算法债. 主公 2026-08-03 拍板独立治理.

## 2 项 Debt

### Debt 1: Forbidden Patterns Check regex false-positive

`.github/workflows/kallax-ci.yml` Forbidden Patterns Check 步骤跑 `grep -rn ': any'` 抓 JSDoc prose `fail-closed: any error` 等非类型断言字面.

**错误捕获** (实测, 跟 EPIC-157 无关):
- `node/src/permissions/conductor-scope.ts:5` — `* - fail-closed: any authz error exit 1 deny`
- `node/src/permissions/role-transition.ts:5` — `* - fail-closed: any error exit 1 deny`
- `node/src/permissions/authz-check.ts:5` — `* - fail-closed: any authz error exit 1 deny`
- `node/src/permissions/workspace-switcher.ts:5` — `* - fail-closed: any error exit 1 deny`
- `node/src/permissions/readonly-path.ts:5` — `* - fail-closed: any error exit 1 deny`
- `node/tests/l1-match.test.ts:9` — `*   1. exact: any keyword in target expert's trigger set`

**CLAUDE.md Stage 1 false-positive 沉淀已记录 regex 排除模式 `^\s*\*\s` 跟 `^\s*//\s`, 但 CI workflow 未应用**.

**Fix**: 在 grep 后置加 `grep -v -E '^\s*(\*|//)\s'` filter.

### Debt 2: expert-invocations-queue.test.ts:120 CI env fail

测试:
```typescript
expect(result._unsafeUnwrap()).toBe('sqlite')
```

期望 sqlite backend, 但 CI 环境无 SQLite (apt-get install 缺) 时 factory 自动降级 file backend, 测试 fail.

**Fix**: 加 `describe.skipIf(!process.env.KALLAX_TEST_SQLITE_AVAILABLE)` (跟 EPIC-114 live test guard 模式一致).

## 跟现有 Rule 联合 (0 冲突)

| Rule | 关系 |
|---|---|
| EPIC-114 live test skipIf | ✅ 复用 |
| CLAUDE.md Stage 1 false-positive 沉淀 | ✅ 应用 |
| Rule 7 scope-check | ✅ 独立 EPIC, 不混 EPIC-157 |
| EPIC-069-D check-claim-evidence | ✅ raw output refs |

## Scope

- 改: `.github/workflows/kallax-ci.yml` (regex), `node/tests/expert-invocations-queue.test.ts` (skipIf)
- 不改: source code (`kallax/node/src/*`)
- 不动: EPIC-157 任何文件

## Acceptance

AC1~AC10 见 `jira/tickets/EPIC-158/ticket.json` `acceptance` 字段.

## 估时

~2 h (1 EPIC 周期, 含 5-Level Verify + 4-branch flow).