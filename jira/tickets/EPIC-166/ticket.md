# EPIC-166 — Heartbeat Daemon + Quota-aware 调度 + Run History Event Ledger

> **借鉴 loopx `loopx quota should-run` + heartbeat-prompt + run-history 1:1**

## 起源

主公 2026-08-05 review loopx 后拍板:

- **P0 最高 ROI**: KALLAX 缺 heartbeat daemon + quota-aware 调度 + run-history ledger, 解决 Master 派单瓶颈
- 架构师报告: "loopx 心跳调度 P0 + Quota-aware 调度 P0 + Run History Event Ledger P1"
- 详细分析: `confluence/decisions/loopx-vs-kallax-architecture-gap-2026-08-05.md`

## loopx 心跳/quota/run-history 模式 (借鉴)

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| 心跳 daemon | `loopx quota should-run` + `heartbeat-prompt` | 心跳 5 问 (Q1-Q5) 需人工 | **大** |
| Quota-aware 调度 | per-goal compute quota + spend ledger | 串行派单 Master 主观判断 | **大** |
| Scheduler Hint | P0/P1/P2 priority stack | 无 | **大** |
| Run History | append-only event ledger, 4 类 event | PR 描述碎片化 | **大** |

## 设计 (4 模块)

1. **`heartbeat-daemon.sh`** — 后台 daemon, 定时调 quota should-run, 返回 next allowed transition
2. **`quota.sh`** — per-ticket compute quota + spend ledger + eligible/throttled/paused 状态机
3. **`scheduler-hint.sh`** — P0/P1/P2 priority stack
4. **`run-history.sh`** — append-only event ledger (4 类 event)

## 4 类 event (跟 loopx 1:1)

```json
{"event_type":"work","agent_id":"performer-1","ticket_id":"EPIC-XXX","timestamp":"...","payload":{...}}
{"event_type":"decision","agent_id":"master","ticket_id":"EPIC-XXX","timestamp":"...","payload":{...}}
{"event_type":"accounting","agent_id":"daemon","ticket_id":"EPIC-XXX","timestamp":"...","payload":{"quota_spent":1}}
{"event_type":"evidence","agent_id":"performer-1","ticket_id":"EPIC-XXX","timestamp":"...","payload":{"raw_output":"..."}}
```

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破 |
| EPIC-161 retrospective-routine | ✅ 互补 (阶段性 vs 实时) |
| EPIC-160 install.sh Omnibus | ✅ 集成 (daemon install + start) |
| EPIC-023-C 北极星 4 指标 | ✅ **直接打通数据源** |
| EPIC-131/132 scan-dead-code | ✅ 退出码契约 0/1/2 1:1 |
| Rule 34 bugfix 独立复现 | ✅ 互补 |

## Acceptance (16 项)

AC1~AC16 见 `jira/tickets/EPIC-166/ticket.json` `acceptance` 字段.

## Scope

- **新增**: 4 daemon 脚本 + 1 ledger 持久化 + 3 test + 1 docs/reference + 1 confluence/decisions
- **改**: `scripts/install.sh` + `CLAUDE.md`
- **不动**: 现有 source code + Rule + BE-14/EPIC-054-A

## 估时

~20 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow (2026-08-05 主公拍板)