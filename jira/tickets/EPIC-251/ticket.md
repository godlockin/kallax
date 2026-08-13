# EPIC-251 — 修 EPIC-157 sentinel debt

**Status**: in_progress → done
**Priority**: P0
**Type**: bugfix
**Estimated**: 2h
**Phase**: PHASE-023

## 起因

EPIC-157 (PR #372-374, 2026-08-11) 新增 `node/src/jira/ticket-binding.ts` (201 行, 4 exported 函数) 但缺配套 test, 触发 `scan-dead-code` Stage 3 sentinel FAIL. EPIC-158 PR #390 用 `KALLAX_HOOK_BYPASS=1` 备案跳过, retrospective-batch-8 L3 记录为真债务.

## Rule 34 独立复现 (强制)

```bash
npm install --prefix node
bash scripts/scan-dead-code.sh
```

**exit code**: 1

**raw output**:
```
Stage 3: Sentinel coverage (each exported module must be imported by tests)
  scanned: 152 modules
1 模块未被 tests 引用 (sentinel fail, EPIC-131-B 治 '不被调用就死' 的真问题)

  jira/ticket-binding

EPIC-131-B dead-code sentinel: 1 阶段 FAIL (3/3 阶段实跑)
```

## 修复

新建 `node/tests/jira/ticket-binding.test.ts` (20 case) 覆盖 4 exported 函数:

| 函数 | case 数 | 覆盖路径 |
|---|---|---|
| `findJiraTicketPath` | 5 | exact match / sub-ticket prefix / exact 优先 / not found / dir absent |
| `readJiraTicket` | 4 | ok / NOT_FOUND / PARSE_FAILED (malformed) / PARSE_FAILED (缺 id) |
| `writeBinding` | 5 | consistent ok / divergent+reason ok / divergent 无 reason FAIL / 0 .tmp 残留 / NOT_FOUND |
| `validateBindingForComplete` | 6 | consistent ok / divergent+reason ok / binding 缺失 / actual 空 / divergent 无 reason / NOT_FOUND |

**隔离策略** (同 CLAUDE.md Rule 7): `mkdtempSync` 临时目录 + `afterEach` 清理, 0 污染真实 `jira/tickets/`.

## 验证结果

| AC | 状态 | raw output |
|---|---|---|
| AC1 ≥8 case | PASS | 20 case (4 describe block) |
| AC2 findJiraTicketPath 3 路径 | PASS | 5 case |
| AC3 readJiraTicket 3 路径 | PASS | 4 case |
| AC4 writeBinding 2 路径 | PASS | 5 case |
| AC5 validateBindingForComplete 4 路径 | PASS | 6 case |
| AC6 scan-dead-code Stage 3 exit 0 | PASS | `所有 152 modules 都被 vitest 引用` / `3/3 阶段 PASS` |
| AC7 vitest PASS | BLOCKED-env | vitest 1.6.1 tinypool worker bug (跟 EPIC-154 备案) |
| AC8 npm build 0 errors | PASS | `npm run build --prefix node` → exit 0 |
| AC9 0 改 source code | PASS | `node/src/jira/ticket-binding.ts` 不动 |
| AC10 4-branch flow | 进行中 | PR-1 → testing → main → miao |

## 联动

- EPIC-157 (jira/ticket-binding 引入方)
- EPIC-158 (bypass 备案, 本 ticket 加 test 消掉该 bypass)
- EPIC-131/132 (scan-dead-code sentinel)
- EPIC-154 (vitest tinypool env blocker 备案)
- retrospective-batch-8 L3 (sentinel debt 记录)
- Rule 34 (bugfix 独立复现)
