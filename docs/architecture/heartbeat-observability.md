# Heartbeat & Observability Architecture

> **Version**: 1.0.0 (EPIC-025-D UP-4)
> **Status**: Active
> **Audience**: Conductor, Performer, Master
> **Cross-references**: `AGENTS.md:42-49` (Heartbeat Protocol 5Q), `docs/PROCESS.md:25-26` (心跳 5 问 Q1-Q5), `confluence/architecture/heartbeat-observability.md` (EPIC-021-F 11 项沉淀), `CLAUDE.md` §8 (Observable by Design)

---

## 1. 概述

Heartbeat 是 KALLAX 协作体系的**生命体征**。它不止于"实例还活着", 而是 Conductor / Performer / Master 之间的**结构化状态通道**。

本章规定两件事:

1. **心跳 5 问** — Master / Conductor / Performer 每个节点必须主动应答的 5 个状态问题 (跟 `docs/PROCESS.md:25-26` 联合, 跟 AGENTS.md `Heartbeat Protocol (5 Questions)` 联合)
2. **Observability 3 层** — Span 记录 → 持久化 → 实时推送 (跟 CLAUDE.md §8 "Observable by Design" 联合, 0 简单 console.log)

跟"反哺框架"战略 联合: 不是把观察结果**简单记录**, 而是让其**回流到框架** — 5 问的答案写入派遣 Checklist, 3 层输出写入 Rule 9 5 levels Fact-Forcing, 0 沉睡文档.

---

## 2. 心跳 5 问 (跟 PROCESS.md:25-26 联合)

### 2.1 协议定义

每个节点 (Master / Conductor / Performer) 在以下触发点**必须**应答 5 问:

- **Master**: 每完成一个任务节点 (task claim / done / blocked)
- **Conductor**: 定时 tick (默认 60s) + 派遣触发 + 阻塞恢复
- **Performer**: task claim / done / blocked 时立即上报 + 30s 心跳

输出 JSON 格式:

```json
{
  "q1_priority":   { "highPriorityCount": 2, "inboxCount": 1, "backlogCount": 17 },
  "q2_performers": { "activeCount": 3, "busyCount": 2, "idleCount": 1, "staleCount": 0 },
  "q3_progress":   { "totalTasks": 14, "completedTasks": 7, "completionRate": "50%" },
  "q4_blocked":    { "blockedTickets": ["EPIC-059-X"], "pendingDecisions": 1 },
  "q5_messages":   { "pendingMessages": 4, "priorityMessages": 1 }
}
```

### 2.2 Q1: Priority (优先级检查)

| 来源 | 检查项 | 阈值 |
|------|--------|------|
| `inbox/human_input.md` | 新需求 | 0 沉 24h |
| `jira/tickets/P0*` | P0 ticket 数 | >0 → 立即派单 |
| `jira/backlog/` | backlog 容量 | >20 → 触发 grooming |

**Action**: P0 发现 → 立即创建 task 并 dispatch; P1 累积 → 写入待办.

### 2.3 Q2: Performer Status (Performer 状态)

| 状态 | 判定 | 处理 |
|------|------|------|
| `active` | 30s 内 heartbeat | 正常 |
| `idle` | 60s 无 task claim | 触发 polling |
| `stale` | last_beat > 60s | 标记 stale, reassign task |
| `timeout` | 累计超时 `min(预估/10, 30min)` | kill -9 + 任务回滚 |

**Action**: stale 立即 reassign; timeout 立即触发 §3 Span 查询定位.

### 2.4 Q3: Project Progress (项目进度)

| 指标 | 公式 | 用途 |
|------|------|------|
| completion_rate | done / total | KPI 上报 |
| milestone_progress | epic 完成率 | PHASE review |
| blocker_rate | blocked / total | 治理信号 (>20% 异常) |

**Action**: blocker_rate > 20% → Master 介入; completion_rate < 50% (deadline-50%) → 升级 P0.

### 2.5 Q4: Blocking Decisions (阻塞决策)

| 类型 | 检查路径 | 上报 |
|------|----------|------|
| 外部依赖 | `inbox/human_feedback/` | 写 human_input |
| 跨 EPIC 冲突 | `jira/tickets/*/blocked_by` | 升级 Master |
| 主公拍板 | `inbox/human_feedback/pending` | 写 ESCALATION |

**Action**: 阻塞 > 1h → Conductor 写 `human_feedback/` 等 explicit 拍板 (跟"独立"战略联合).

### 2.6 Q5: Message Queue (消息队列)

| 来源 | 消费方 | 处理 |
|------|--------|------|
| `shared/message_queue/*` | Conductor | 处理 + 回执 |
| `performer→conductor` | Conductor inbox | 处理 + 状态更新 |
| `conductor→performer` | Performer 30s 轮询 | 接收 + ACK |

**Action**: pendingMessages > 10 → 触发 burst; priorityMessages > 0 → 优先处理.

### 2.7 5 问 → 派遣 Checklist 闭环

```
Q1 Priority  → §1.5 [N/M] 进度上报 + §1.1 防卡死
Q2 Performers → §1.8 worktree 隔离 + §1.6 run_in_background
Q3 Progress  → §1.5 进度上报 + §1.11 PASS raw output
Q4 Blockers  → §1.7 错误处理 (429/auth/conflict 停止)
Q5 Messages  → §1.6 run_in_background + §1.9 PR ~100 上限
```

**治根反讽**: 心跳 5 问不是文档摆设, 0 答 → 派遣 Checklist 11 项 0 联动 → 治理失效 (跟 BE-14 / BE-23 模式联合).

---

## 3. Observability 3 层 (Span 记录 + 持久化 + 实时推送)

### 3.1 架构总览

```
┌──────────────────────────────────────────────────────────────────┐
│ Layer 1: Span 记录 (in-process)                                  │
│  - OTel API: tracer.startSpan("tool-invocation")                  │
│  - 属性: tool / params / ticketId / performerId / timestamp      │
│  - 耗时: 自动埋点 (duration_ms)                                   │
│  - 输出: stdout JSON + in-memory ring buffer (last 1000)         │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼ (flush, batch)
┌──────────────────────────────────────────────────────────────────┐
│ Layer 2: 持久化 (durable storage)                                 │
│  - SQLite (default): .kallax/state/spans.db                       │
│  - PostgreSQL (production): swap-in via env var                   │
│  - JSONL fallback (Redis/SQLite fail): .kallax/logs/spans.jsonl  │
│  - 保留: 30d hot + 1y cold archive                                │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼ (CDC + LISTEN/NOTIFY)
┌──────────────────────────────────────────────────────────────────┐
│ Layer 3: 实时推送 (push to consumers)                            │
│  - SSE (default, browser-friendly): GET /api/spans/stream         │
│  - WebSocket (low-latency): ws://host/api/spans/ws                │
│  - Webhook (3rd-party integration): POST spans.{event_type}       │
│  - 消费者: dashboard / alerting / external audit                  │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 Layer 1 — Span 记录

**OTel 模式** (跟 CLAUDE.md §8 "Observable by Design" 联合):

```typescript
// ✅ OTel-compliant span
const span = tracer.startSpan('tool-invocation', {
  attributes: {
    'tool.name': toolName,
    'tool.params': JSON.stringify(params),
    'ticket.id': ticketId,
    'performer.id': performerId,
    'kallax.role': 'performer',  // 自定义 namespace
    'kallax.worktree': worktreePath,
  },
});

try {
  const result = await tool.execute(params);
  span.setStatus({ code: SpanStatusCode.OK });
  span.setAttribute('tool.duration_ms', Date.now() - start);
  return result;
} catch (e: unknown) {
  span.recordException(e as Exception);
  span.setStatus({ code: SpanStatusCode.ERROR, message: (e as Error).message });
  throw e;
} finally {
  span.end();
  spanExporter.export([span]);  // → Layer 2
}
```

**结构化日志** (跟 "Anti-Patterns §5 console.log" 联合):

```typescript
// ❌ 反例
console.log('Tool called:', toolName);

// ✅ 正例
logger.info({
  event: 'tool_invocation',
  tool: toolName,
  params,
  ticketId,
  slaverId,
  timestamp: Date.now(),
  duration_ms: 42,
  trace_id: span.spanContext().traceId,  // OTel trace 串联
}, `performer invoked ${toolName}`);
```

### 3.3 Layer 2 — 持久化

```sql
-- SQLite schema (默认)
CREATE TABLE spans (
  trace_id        TEXT NOT NULL,
  span_id         TEXT NOT NULL,
  parent_span_id  TEXT,
  name            TEXT NOT NULL,
  start_time_ns   INTEGER NOT NULL,
  duration_ms     INTEGER NOT NULL,
  status          TEXT CHECK(status IN ('ok','error')),
  attributes      TEXT NOT NULL,  -- JSON
  events          TEXT,           -- JSON array
  ticket_id       TEXT,
  performer_id    TEXT,
  PRIMARY KEY (trace_id, span_id)
);

CREATE INDEX idx_spans_ticket ON spans(ticket_id, start_time_ns);
CREATE INDEX idx_spans_performer ON spans(performer_id, start_time_ns);
CREATE INDEX idx_spans_status ON spans(status) WHERE status = 'error';
```

**降级链** (跟 degradation-strategy.md 联合):

| Level | Backend | 触发 |
|-------|---------|------|
| L3 (default) | PostgreSQL | production |
| L2 | SQLite | dev / single-node |
| L1 | JSONL file | Redis/SQLite fail |
| L0 | stdout only | file system fail |

### 3.4 Layer 3 — 实时推送

```typescript
// SSE 推送 (default)
sseBus.publish('span_emitted', {
  trace_id: span.spanContext().traceId,
  span_id: span.spanContext().spanId,
  name: span.name,
  duration_ms: span.duration[0],
  status: span.status.code,
  ticket_id: attributes['ticket.id'],
  performer_id: attributes['performer.id'],
});

// 消费者订阅
sseBus.subscribe('span_emitted', (span) => {
  if (span.status === 'error') {
    alerting.emit({
      severity: 'warn',
      message: `Tool ${span.name} failed for ${span.ticket_id}`,
      trace_id: span.trace_id,
    });
  }
});
```

**消费者矩阵**:

| Consumer | 协议 | 用途 |
|----------|------|------|
| Dashboard (web) | SSE | 实时 trace 可视化 |
| Alerting | Webhook | error / slow / stuck 告警 |
| Audit log | 持久化定期 dump | 合规 / 复盘 |
| External SIEM | Webhook | 集成 Splunk / Datadog |

### 3.5 反哺框架 (跟"反哺框架"战略联合)

> 3 层输出**不是**观察终点, 而是**框架输入**:

```
Layer 3 流 → Master 仲裁 (跟 EPIC-056-A Phase 3 联合)
            ↓
     写入 confluence/decisions/  (跨 release 累计)
            ↓
     触发 Rule 修订 / 新建 (Rule 9 Fact-Forcing / Rule 6 LESSONS-LEARNED 草稿)
            ↓
     CLAUDE.md / AGENTS.md 落地
            ↓
     下次派遣 Checklist 11 项 强制生效
```

**反例** (0 反哺 = 0 简单记录):

```
span 记录 → DB 写入 → 0 消费 → 0 决策 → 0 Rule 修订
   ↑                                              ↓
   └──── 5 年后 复盘发现同样问题 (跟 EPIC-021-F 教训 联合) ────┘
```

**正例** (跨 release 累计 12 术语 → KALLAX-GLOSSARY 扩 42→54, 跟 PHASE-012 联合):

```
span 记录 → 5 release 累计 BE-9/BE-14/BE-19/BE-22/BE-23 → 写入 confluence/decisions/accumulated-lessons.md
            ↓
     触发 P1-1 pre-commit ALLOWED_PATTERNS 加 ^jira/ (治根 --no-verify workaround)
            ↓
     v2.3.0 落地 (commit 7db6107)
            ↓
     派遣 Checklist 11 项 §1.7 错误处理 自动联动
```

---

## 4. Heartbeat × Observability 联动

### 4.1 数据流

```
Performer 操作 → Layer 1 Span (OTel)
                     ↓
              Layer 2 持久化 (SQLite)
                     ↓
              Layer 3 SSE 推送 → Conductor Dashboard
                                     ↓
                              Conductor 心跳 tick (60s)
                                     ↓
                              Q1-Q5 答 → Layer 1 Span (role=conductor)
                                     ↓
                              Master 收 → Phase 3 仲裁
```

### 4.2 心跳 5 问 → Span 字段映射

| Q | Span attribute | 类型 |
|---|---------------|------|
| Q1 priority | `kallax.q1.high_priority_count` | int |
| Q2 performers | `kallax.q2.stale_count` | int |
| Q3 progress | `kallax.q3.completion_rate` | float (0-1) |
| Q4 blocked | `kallax.q4.pending_decisions` | int |
| Q5 messages | `kallax.q5.priority_messages` | int |

每次 Q1-Q5 应答 → 自动 emit 1 个 `kallax.heartbeat.tick` span → Layer 2 持久化 → 7d 后归档.

### 4.3 Stale 检测 (Q2 → Span 查询)

```typescript
// Conductor Q2 检测到 stale performer
async function handleStalePerformer(performerId: string) {
  // 1. Span 查询 — 最后一次成功操作
  const lastSpan = await db.query(`
    SELECT * FROM spans
    WHERE performer_id = ?
    ORDER BY start_time_ns DESC LIMIT 1
  `, [performerId]);

  // 2. 定位 — 是 tool 慢? 还是网络? 还是卡死?
  const diagnosis = {
    lastTool: lastSpan.name,
    lastDuration: lastSpan.duration_ms,
    lastStatus: lastSpan.status,
    traceId: lastSpan.trace_id,  // 串联 Layer 3 SSE 流
  };

  // 3. Action
  if (diagnosis.lastStatus === 'error') {
    reassignTask(performerId, 'error_recovery');
  } else if (diagnosis.lastDuration > 30000) {
    killAndRestart(performerId);
  } else {
    sendKeepAlive(performerId);
  }
}
```

---

## 5. Anti-Patterns (跟"反讽"战略联合)

### 5.1 ❌ 反例

```typescript
// 反例 1: console.log 替代结构化日志
console.log('Task claimed:', taskId);

// 反例 2: 心跳 5 问只答 Q3 (项目进度), 跳过 Q1/Q2/Q4/Q5
heartbeat.report({ q3_progress: '50%' });  // 0 优先级 / 0 状态 / 0 阻塞 / 0 队列

// 反例 3: Span 只写 Layer 1 in-memory, 0 Layer 2 持久化, 0 Layer 3 推送
const span = tracer.startSpan('tool');
span.end();  // crash 后丢失

// 反例 4: 3 层输出 0 反哺 — 写完不消费 / 不决策 / 不改 Rule
db.insertSpan(span);  // 0 follow-up, 沉睡 5 年

// 反例 5: --no-verify 绕过 pre-commit, 0 心跳检查 → 0 治理信号
git commit --no-verify -m "..."  // 跟 BE-9/BE-14/BE-23 模式联合
```

### 5.2 ✅ 正例

```typescript
// 正例 1: OTel span + 结构化 logger + trace_id 串联
const span = tracer.startSpan('tool-invocation', { attributes: {...} });
logger.info({ event: 'tool_invocation', trace_id: span.spanContext().traceId, ... }, msg);

// 正例 2: 5 问全答 (Q1-Q5 0 缺)
heartbeat.report({
  q1_priority: scanInbox(),
  q2_performers: scanPerformers(),
  q3_progress: calculateProgress(),
  q4_blocked: scanBlocked(),
  q5_messages: scanQueue(),
});

// 正例 3: 3 层全链路 — Layer 1 emit → Layer 2 persist → Layer 3 push
spanExporter.export([span]);
sseBus.publish('span_emitted', span.attributes);

// 正例 4: 反哺框架 — Span → 决策 → Rule 修订 → 下次派遣 Checklist 联动
master.arbitrate(spans).then(decision => writeDecision(decision));

// 正例 5: 走正确路径 — pre-commit hook branch-aware (BE-23 治根 commit 7347ae6)
git commit -m "..."  // 0 --no-verify
```

---

## 6. 配置参考

```yaml
# .kallax/config.yml
heartbeat:
  conductor:
    interval_ms: 60000           # 60s tick
    timeout_threshold: "min(预估/10, 30min)"
    stale_threshold_s: 60        # >60s 标记 stale
  performer:
    interval_ms: 30000           # 30s tick
    auto_claim: true
    worktree_required: true      # 跟 §1.8 worktree 隔离 联合

observability:
  layer1_span:
    backend: otel                # otel | custom
    sampling_rate: 1.0           # 100% (dev), 0.1 (prod)
    ring_buffer_size: 1000
  layer2_persist:
    backend: sqlite              # sqlite | postgres | jsonl
    sqlite_path: ".kallax/state/spans.db"
    retention_days: 30
    archive_path: ".kallax/archive/spans/"
  layer3_push:
    sse:
      enabled: true
      endpoint: "/api/spans/stream"
      heartbeat_interval_s: 15
    websocket:
      enabled: false             # 按需启用
      endpoint: "ws://host/api/spans/ws"
    webhook:
      enabled: false
      targets: []
```

---

## 7. 跨文档索引

| 维度 | 文档 | 联合点 |
|------|------|--------|
| 协议 | `AGENTS.md:42-49` | Heartbeat Protocol (5 Questions) |
| 流程 | `docs/PROCESS.md:25-26` | 心跳 5 问 Q1-Q5 |
| 派遣 | `AGENTS.md:126-159` | 派遣 Checklist 11 项 §10 心跳 5 问 |
| F 沉淀 | `confluence/architecture/heartbeat-observability.md` | EPIC-021-F 11 项修复 + 3 层降级 + macOS 兼容 |
| 降级 | `docs/architecture/degradation-strategy.md` | 4 层降级 Level 0-3 |
| 可观测 | `CLAUDE.md` §8 | Observable by Design (Layer 1/2/3) |
| 教训 | `confluence/decisions/accumulated-lessons-2026-06-19.md` | BE-9/BE-14/BE-19/BE-22/BE-23 跨 release 累计 |
| 决策 | `confluence/decisions/dispatch-checklist-2026-06-19.md` | §1.10 心跳 5 问 + §1.11 PASS raw output |

---

## 8. 维护说明

### 8.1 修订触发

- **Layer 1 改动** (新增 OTel attribute): 跟 OTel spec 联合, 需更新 §3.2 示例
- **Layer 2 改动** (新增 backend): 跟 degradation-strategy.md 联合, 需更新降级链
- **Layer 3 改动** (新增 consumer): 跟 alerting 联合, 需更新 §3.4 消费者矩阵
- **5 问改动** (新增 Q): 跟 PROCESS.md:25-26 联合, 0 单方面改 (跟"独立"战略 0 跨 session 拍板)

### 8.2 失效信号

| 信号 | 检测 | 处理 |
|------|------|------|
| Heartbeat 5 问 0 答 | Layer 2 span 缺失 `kallax.q*.count` | 升级 Master, 触发 §1.1 防卡死 |
| Layer 1 → Layer 2 断链 | export queue 堆积 | 触发 degradation Level 1-2 |
| 反哺 0 闭环 | confluence/decisions/ 30d 0 新增 | 触发 Phase 3 Master 仲裁 review |

---

**Author**: Performer EPIC-025-D (1 ticket 1 subagent 串行)
**Reviewers**: 待 Phase 2 4+5 专家并行 (Backend / Frontend / UX / Product + security-tool-bypass / process-engineering / auditor / compliance / decision-gate)
**Approved**: 待 Master 仲裁 + 主公拍板 (跟 EPIC-055-B P0/P1/P2 联合)
**Evidence**: commit SHA 待 §6 提交后回填