---
paths:
  - node/**/*.test.ts
  - node/tests/**
  - rust/**/tests/**
  - "**/*.test.ts"
---

# Test 反模式 (EPIC-114) + Live Test SkipIf (EPIC-114/158)

> **Path-scoped rule**: 只在 test 文件被操作时加载.

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

## Reference

- EPIC-114 ticket.json: `jira/tickets/EPIC-114/`
- EPIC-158 ticket.json: `jira/tickets/EPIC-158/`
- `scripts/check-live-test-guard.sh` (force skipIf for live tests)