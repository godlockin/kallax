# Heartbeat Daemon — EPIC-166 (2026-08-05)

> 借鉴 loopx heartbeat-prompt + quota + run-history 1:1

## 概述

Heartbeat Daemon 是 KALLAX 框架的自动化调度层:
- 后台 daemon, 定时检查 quota
- quota-aware 调度 (per-ticket budget)
- append-only event ledger (北极星 4 指标数据源)

## 组件

| Script | 职责 |
|--------|------|
| `scripts/heartbeat/heartbeat-daemon.sh` | 后台 daemon 主体 |
| `scripts/heartbeat/quota.sh` | 6 层 quota 系统 |
| `scripts/heartbeat/scheduler-hint.sh` | P0/P1/P2 priority stack |
| `scripts/heartbeat/run-history.sh` | append-only event ledger |

## 6 层 Quota (跟 loopx 1:1)

```
Layer 1: Global budget (per-hour tokens)
Layer 2: Per-ticket budget
Layer 3: Per-priority budget (P0/P1/P2)
Layer 4: Per-expert budget
Layer 5: Cooldown / throttle
Layer 6: Pause gate (human override)
```

### 状态机

| State | Exit Code | 说明 |
|-------|-----------|------|
| eligible | 0 | 可以运行 |
| throttled | 1 | quota 耗尽, 等待冷却 |
| paused | 2 | 人为暂停 |

### 退出码契约

| Code | 含义 |
|------|------|
| 0 | PASS (continue) |
| 1 | FAIL (stop, 报 Master) |
| 2 | BLOCKED-env (环境缺失) |

## 4 类 Event Schema

```json
{
  "event_type": "work|decision|accounting|evidence",
  "agent_id": "performer-1|master|daemon",
  "ticket_id": "EPIC-XXX",
  "timestamp": "ISO-8601",
  "payload": {}
}
```

### Event 类型

| Type | 用途 | 北极星关联 |
|------|------|------------|
| work | agent 开始工作 | throughput |
| decision | 人类/agent 做决策 | cycle_time |
| accounting | quota 消耗/心跳 | efficiency |
| evidence | raw output/验证结果 | quality |

## Priority Stack

```
P0 (truth-safety)      — 最高, 3 expert 验证
BLOCKED (human-decision) — 次高, 等待 human review
P1 (product-UX)        — 第三, 关键 product 功能
P2 (routine)           — 最后, 常规 work
```

## Usage

```bash
# Daemon
heartbeat-daemon.sh start [--interval=SECONDS]
heartbeat-daemon.sh stop
heartbeat-daemon.sh status

# Quota
quota.sh should-run <ticket_id>
quota.sh spend <ticket_id> <amount>
quota.sh status [ticket_id]
quota.sh pause [ticket_id]
quota.sh resume [ticket_id>

# Scheduler
scheduler-hint.sh next [eligible_ticket_id]
scheduler-hint.sh list
scheduler-hint.sh stats

# Run History
run-history.sh emit <type> <ticket_id> [payload]
run-history.sh query [--type=TYPE] [--agent=ID] [--ticket=ID]
run-history.sh stats
run-history.sh verify
```

## install.sh 集成

install.sh Omnibus (EPIC-160) 已加 heartbeat daemon install + start 阶段.

## 跟 EPIC-023-C 北极星打通

Event ledger 自动 emit work/accounting event → 北极星 4 指标数据源:

- throughput: work event 计数
- cycle_time: work → done 时间差
- efficiency: accounting event quota 消耗
- quality: evidence event 验证结果

## Tests

```bash
bash tests/integration/heartbeat-daemon.test.sh  # ≥8 cases
bash tests/integration/quota-scheduler.test.sh   # ≥5 cases
bash tests/integration/run-history-ledger.test.sh # ≥5 cases
```

## Reference

- EPIC-166 ticket: `jira/tickets/EPIC-166/`
- loopx 对比: `confluence/decisions/loopx-vs-kallax-architecture-gap-2026-08-05.md`
