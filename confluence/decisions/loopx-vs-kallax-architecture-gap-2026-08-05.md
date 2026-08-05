# loopx vs KALLAX 架构差距分析

> 主公 2026-08-05 review loopx 后拍板 EPIC-166 (P0)

## 差距概览

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| heartbeat daemon | `loopx heartbeat-prompt` 定时 daemon | 手动 Q1-Q5 | **大** |
| quota system | `loopx quota should-run` 6 层 quota | 串行派单 Master 主观 | **大** |
| scheduler hint | P0/P1/P2 priority stack | 无 | **大** |
| run history | append-only event ledger, 4 类 event | PR 描述碎片化 | **大** |

## loopx 心跳调度模式

### heartbeat-prompt

```bash
# 定时调 quota + scheduler
loopx heartbeat-prompt --interval=60 --daemon
# 输出: next allowed transition
```

### quota should-run

```bash
# 6 层 quota check
loopx quota should-run <goal_id>
# 状态: eligible / throttled / paused
# exit: 0 / 1 / 2
```

### run-history

```json
{"event_type":"work","agent_id":"agent-1","ticket_id":"GOAL-1","timestamp":"...","payload":{}}
{"event_type":"accounting","agent_id":"daemon","ticket_id":"GOAL-1","timestamp":"...","payload":{"quota_spent":1}}
```

## KALLAX 现状

### 手动心跳

Q1: Task Priority (扫描 inbox / P0/P1 tickets)
Q2: Performer Status (心跳新鲜度 / 任务分配)
Q3: Project Progress (完成率 / milestone)
Q4: Blocking Decisions (human feedback / blocked 票)
Q5: Message Queue (未处理消息)

→ 每次需人工触发, 无 daemon 自动化

### 串行派单

Master 主观判断 ticket 优先级
无 quota-aware 调度
无 spend tracking

### PR 描述碎片化

每个 EPIC 的 progress 散落在各个 PR 描述
无统一 event ledger
无法做北极星 metrics 分析

## EPIC-166 解决方案

| 模块 | 借鉴 loopx | 实现 |
|------|------------|------|
| heartbeat-daemon.sh | heartbeat-prompt | 定时调 quota should-run |
| quota.sh | loopx quota | 6 层 quota + eligible/throttled/paused |
| scheduler-hint.sh | priority stack | P0/P1/P2 + BLOCKED |
| run-history.sh | run-history | 4 类 event append-only ledger |

## 互补 EPIC

| EPIC | 关系 |
|------|------|
| EPIC-161 retrospective-routine | 阶段性回顾 vs 实时 daemon |
| EPIC-160 install.sh Omnibus | daemon install 集成 |
| EPIC-023-C 北极星 | event ledger → 4 指标数据源 |
| EPIC-131/132 scan-dead-code | 退出码契约 0/1/2 1:1 |

## 主公拍板

- **时间**: 2026-08-05
- **结论**: P0 最高 ROI
- **原因**: 解决 Master 派单瓶颈
- **预计收益**:
  - Master 派单自动化, 不再成为 bottleneck
  - quota-aware 调度, 资源利用率 ↑
  - 统一 event ledger, 北极星 metrics 可追溯
