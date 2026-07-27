# EPIC-114 test 反模式 (0 复发)

> 主 CLAUDE.md 引用, 没展开

**主 CLAUDE.md**: root, 引用本文件
**本文件加载场景**: 写 *-live.test.ts 或 vitest 时

---

## 反模式清单

1. **`*-live.test.ts` 必须 `describe.skipIf(!process.env.X_LIVE)`**
   - `check-live-test-guard.sh` (5 immutable scripts 之一) 强制
   - 替代方案: skip 整个 specfile, 用 env 提示 user 手动跑 live
   - 永远不要让 CI 默认跑 live test (会 leak real provider account)

2. **测试断言别绑死 totalScore / 枚举硬编码**
   - 断言维度, 不 assert 整数 totalScore (debug 时 fragile, 升迭代总会 break)
   - 软规: vitest fail-fast 是兜底 (failure 立刻 fail, 不会 leak)
   - 例: 断言 `result.kind === 'success'` 而不是 `result.code === 42`

3. **source bug 不能 `it.skip` 逃避**
   - 必须修 source 再 unskip
   - 任何 PR 在 source change 里加 new skip 必须人工 justification (PR body 必填)

---

## 与 Rule 34 的边界

Rule 34 (CLAUDE.md 第 Rule 34 段) 是 ticket-level discipline; 本表是 code-level discipline. 两者独立:

| Layer | Rule | 来源 |
|---|---|---|
| **Ticket** | Rule 34 — 必含 reproduction 3 field | EPIC-152 |
| **Test code** | EPIC-114 — 3 项反模式 | EPIC-114 + 5 immutable scripts |

---

## 死代码 sentinel 专属:

- `tests/dead-code-sentinel-coverage*.test.ts` 4 个文件 100% pass (跟 5-Level Verify 联合)
- 任何删 module / 改名 module 必须 verify sentinel 不掉 coverage
- 详细见 `docs/reference/5-level-verify-harden.md`
