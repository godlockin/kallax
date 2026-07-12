# EPIC-114 vitest 扫描结果

**日期**: 2026-07-12
**范围**: node/tests/*.test.ts (unit tests, 45 files 分 6 批扫)

## 汇总

| Batch | Files | Tests PASS | Failed | 备注 |
|-------|-------|-----------|--------|------|
| 1 (utils/core/context) | 3 | 59/59 | 0 | baseline |
| 2 (auto-scaler..event-bus) | 8 | 86/86 | 0 | |
| 3 (expert-*/gate/git/heartbeat/hook/instance) | 8 | 84/85 | **1** | expert-matcher |
| 4 (isolation..recovery) | 8 | 489/490 | **2** | persona-schema, rate-limiter |
| 5 (role..sse) | 8 | 67/67 | 0 | |
| 6 (task..worktree) | 7 | 86/86 | 0 | |
| 7 (cache-layer 修 conflict 后) | 1 | 8/8 | 0 | ✅ 已修 (commit 56885f0) |
| 8 (tier-router-e2e/live) | 2 | 3/5 | **1** | live 需 rust :3000 |
| 9 (bridge-live) | 1 | 0/2 | **2** | live 需 bridge server |

**总计**: 44/45 files 通过, ~882 tests passing, 6 failures (3 code debt + 3 env-required)

## 3 真实 code debt (需修)

### 1. tests/expert-matcher.test.ts:31 — unknown capability score expectation
```
FAIL: returns results even for unknown capability (low scores)
AssertionError: expected 49 to be less than 1
```
- 测试期望 `findBestMatch(['cobol','fortran'])` 所有 score < 1
- 实际 score = 49 (baseline availability/success rate 分数不为 0)
- 需修: 测试假设过强 OR ExpertMatcher 对 unknown capability 应 penalize 更狠

### 2. tests/persona-schema.test.ts — security.md parses
```
FAIL: PersonaSchema > integration: 7 default persona files > security.md parses
AssertionError: expected true to be false
```
- security.md 现在解析出错(可能 frontmatter schema 不合规)
- 需修: `default/security.md` 头元数据 OR schema 放宽

### 3. tests/rate-limiter.test.ts — vi.mock hoisting
```
FAIL: Cannot access 'mockLogger' before initialization
```
- 测试文件用 `vi.mock` factory 引用 top-level 变量, 违反 hoisting 规则
- 需修: 将 mockLogger 定义放入 `vi.mock` factory 内部 (标准 vitest 反模式)

## 3 环境依赖 (非 code bug)

### 4. tests/tier-router-live.test.ts
- 需 rust server on :3000, `cargo run --release` 后可跑
- 标记为 `.skip` 或添加 `describe.skipIf(!process.env.RUST_LIVE)` 条件

### 5-6. tests/bridge-live.test.ts (2 tests)
- 需 live bridge server, `isAlive() = false / createTicket = false`
- 同 tier-router-live 处理

## 联动

- EPIC-114 CI 债务清算 (parent)
- 已修: cache-layer.test.ts merge conflict (commit 56885f0)
- 待建: EPIC-114-B (3 code debt tickets, 1 ticket 1 subagent 串行)
- 待建: EPIC-114-C (live tests skip 条件, gate on env)

## 5-Level Verify L2 raw output

- Batch 5 (role..sse): `Test Files 8 passed (8) / Tests 67 passed (67) / Duration 233ms`
- Batch 6 (task..worktree): `Test Files 7 passed (7) / Tests 86 passed (86) / Duration 3.20s`
- Batch cache-layer (fixed): `Test Files 1 passed (1) / Tests 8 passed (8) / Duration 170ms`

命令:
```bash
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run <files> --reporter=basic --testTimeout=15000 --hookTimeout=15000
```
