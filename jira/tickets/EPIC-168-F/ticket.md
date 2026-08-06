# EPIC-168-F — EPIC-166 daemon 真跑验证

> **主公 2026-08-05 Phase 5 F 拍板: 防止 EPIC-166 假 PASS**

## 起源

主公 2026-08-05 拍板 Phase 5 顺序 (F → G → E → B → C → D → A), 第一项 F = 验证 EPIC-166 真跑有效.

**跟 EPIC-069-D 5-Level Verify 一致**: 5-Level Verify 之前漏 cargo test + node env setup 等于形式通过实质失败 (v3.8.0 教训). EPIC-166 实施完成但未真跑过 daemon, 必须**真跑 60s 循环** 验证.

## 任务

1. **daemon 真跑 60s** — start → 60s wait → status → stop
2. **quota 真测** — 6 层 + 3 状态
3. **scheduler-hint 真测** — P0 > BLOCKED > P1 > P2
4. **run-history 真测** — 4 类 event emit + query
5. **append-only 真验** — 改写拦截
6. **state 持久化真验** — stop 后文件保留
7. **北极星打通真验** — EPIC-023-C 4 指标
8. **5-Level Verify L1-L5 跑实**

## Acceptance (10 项)

AC1~AC10 见 `jira/tickets/EPIC-168-F/ticket.json` `acceptance` 字段

## 约束

- 0 改 source code
- 0 增 Rule
- 0 增 immutable script (纯 verification + 1 test script)

## Phase

PHASE-020 — EPIC-166 Runtime Verification (2026-08-05 主公拍板)