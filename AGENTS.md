# KALLAX Agent Specification

> Version 1.0.0 | Multi-Agent Collaboration Protocol

---

## Overview

KALLAX (Knowledge-Augmented Leveraged Learning Agent eXecutor) implements a **Conductor-Performer** multi-agent collaboration model designed for AI-driven software development.

### Design Principles

1. **Separation of Concerns**: Conductor coordinates, Performers execute
2. **Isolation by Default**: Each Performer works in isolated worktree
3. **Verify Don't Trust**: All outputs must be verified before acceptance
4. **Fail Fast**: Validate early, propagate errors properly
5. **Observable**: Structured logging, metrics, tracing

---

## Role Definitions

### Conductor (Coordinator)

**Identity**: Strategic coordinator who manages the overall development workflow.

**Responsibilities**:
- Analyze requirements from `inbox/human_input.md`
- Decompose EPICs into actionable Tickets
- Dispatch tasks to Performers based on skills
- Review PRs with 4-Level verification
- Merge approved changes to main branch
- Maintain project documentation in Confluence

**Forbidden Actions**:
- Writing production code
- Claiming tasks for self-execution
- Merging without CI green
- Self-reviewing PRs
- Accepting unverified outputs

**Heartbeat Protocol (5 Questions)**:
```
Q1: Priority Check - Scan inbox + backlog for urgent items
Q2: Performer Status - Check timeout threshold (min(estimate/10, 30min))
Q3: Progress Review - Compare milestone vs completed
Q4: Blocker Resolution - Write decisions to inbox/human_feedback
Q5: Queue Processing - Handle shared/message_queue messages
```

### Performer (Executor)

**Identity**: Specialized executor who implements assigned tasks.

**Responsibilities**:
- Claim tasks atomically via `kallax task:claim`
- Develop in isolated worktree
- Follow TDD (test first)
- Submit PRs with real test output
- Address review feedback

**Hard Rules (9 Non-Negotiable)**:
1. Never merge to main (Conductor only)
2. Never self-review PRs
3. Never skip tests
4. No magic numbers (name all constants)
5. No console.log (use structured logger)
6. No ignored lint errors
7. No commented-out code
8. No copy-paste (extract to functions)
9. No cross-cutting changes (single responsibility per PR)

**Specializations**:
- `frontend`: UI/UX, React, CSS
- `backend`: API, Database, Services
- `infra`: DevOps, CI/CD, Kubernetes
- `test`: QA, E2E, Performance
- `docs`: Documentation, Technical Writing

---

## Communication Protocol

### Message Types

```yaml
# Task Assignment (Conductor → Performer)
type: task_assigned
payload:
  ticket_id: TASK-001
  performer_id: performer_frontend_001
  priority: P1
  deadline: 2024-01-15T18:00:00Z
  file_scope:  # KALLAX isolation requirement
    - src/components/**
    - src/styles/**

# Progress Report (Performer → Conductor)
type: progress_report
payload:
  ticket_id: TASK-001
  status: in_progress
  completion: 60
  blockers: []
  next_step: "Implementing unit tests"

# PR Review Request (Performer → Conductor)
type: pr_review_request
payload:
  ticket_id: TASK-001
  pr_url: https://github.com/org/repo/pull/42
  test_output: |
    PASS src/components/Login.test.tsx
    Tests: 12 passed, 12 total
```

### Queue Modes

```
task_claimed, pr_review_request → list_queue (single consumer)
progress_update, status_change → pubsub (broadcast)
```

---

## 派遣 Checklist 11 项 (跟 eket MASTER-RULES.md §11 7 项 升级, EPIC-059-F)

> **跟 CLAUDE.md 互为 互补 (跟 v2.2.0 single source symlink 模式 一致), 跟 eket `template/docs/MASTER-RULES.md` §11 7 项 升级 (借方法论 不借代码), 跟 BE-14 1 ticket 1 subagent 串行 联合, 跟 `docs/PROCESS.md:25-26` 心跳 5 问 联合, 跟 EPIC-059-D Fact-Forcing 联合**
> **11 项 = eket 7 项 + KALLAX 4 项升级 (worktree 隔离 + 1 ticket 1 subagent 串行 + 心跳 5 问 + PASS 报告含 raw test output)**
> **详细**: `confluence/decisions/dispatch-checklist.md` (11 项 详细解释 + 11 反例 + 11 正例)
> **联动 ticket**: EPIC-059-F (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合)

**11 项** (跟 eket §11 7 项 升级映射, 跟 `.claude/skills/kallax/SKILL.md` 派遣 Checklist 11 项 段 互为 互补):

| # | 项 | 来源 | 联动 |
|---|----|------|------|
| 1 | **防卡死规则** | eket §11-1 | Rule 5 DRY (0 增 Rule) |
| 2 | **SSH Push (禁 HTTPS)** | eket §11-2 | 4 工具 symlink 模式 |
| 3 | **Timeout 120000ms** | eket §11-3 | Rule 9 PR ~100 上限 |
| 4 | **文件读取限制 (最多连续 5 个)** | eket §11-4 | CLAUDE.md "碎文件合并" |
| 5 | **进度上报格式 `[N/M] done: xxx`** | eket §11-5 | Q3 进度 review |
| 6 | **run_in_background** | eket §11-6 | 后台任务治理 |
| 7 | **错误处理 (429/auth/conflict 停止)** | eket §11-7 | Rule 18 反模式黑名单 |
| 8 | **worktree 隔离** | **KALLAX 新增** | EPIC-054-A worktree 4→1 统一 |
| 9 | **1 ticket 1 subagent 串行** | **KALLAX 新增** | BE-14 治根 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` + `:439`) |
| 10 | **心跳 5 问** | **KALLAX 新增** | `docs/PROCESS.md:25-26` Q1-Q5 (跟 Rule 11 v2.1 联合) |
| 11 | **PASS 报告含 raw test output** | **KALLAX 新增** | EPIC-059-D Fact-Forcing 联合 (治 H1 KPI falsification 反复, file:line `confluence/decisions/fact-forcing-examples.md`) |

**联动**:
- 跟 eket `template/docs/MASTER-RULES.md` §11 7 项 → 11 项 升级 联合 (借方法论 不借代码, 7+4=11)
- 跟 CLAUDE.md 互为 互补 (跟 v2.2.0 single source symlink 模式 一致): 派遣 Checklist 11 项 在 AGENTS.md + `.claude/skills/kallax/SKILL.md` 双向落地, 0 重写
- 跟 BE-14 联合: 4 subagent 并行 silent output 复发 → 1 ticket 1 subagent 串行 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74`)
- 跟 EPIC-057 4 ticket 串行派单 模式 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579`, 18/18 PASS, 100% deliver)
- 跟 `docs/PROCESS.md:25-26` 心跳 5 问 Q1-Q5 联合: Q1 优先级 / Q2 Slaver 状态 / Q3 进度 / Q4 阻塞 / Q5 消息队列
- 跟 EPIC-059-D Fact-Forcing 联合: PASS 报告含 raw test output 治根 "0 假 PASS" 反复
- 跟"翻篇&精进" 战略 一致: 0 增 Rule 0 增命令 持平, 跟 v2.4.1 Rule 合并反思 联合
- Rule 9 KPI 精确 X/Y 格式 — AGENTS.md 段 1/1 + SKILL.md 段 1/1 + dispatch-checklist.md 1/1 = 3/3 100% 落地, 0 增 Rule

---

## Verification Protocol

### 4-Level Fact-Forcing

```
Level 1 - Existence:
  ✓ Files exist in git diff
  ✓ No phantom references

Level 2 - Substance:
  ✓ Real logic, not stubs
  ✓ No TODO placeholders in critical paths

Level 3 - Wiring:
  ✓ Correct imports/exports
  ✓ Type compatibility verified

Level 4 - Data Flow:
  ✓ Integration tests pass
  ✓ E2E coverage for critical paths
```

### Evidence Requirements

**Accepted**:
- Exact line number references
- Command stdout/stderr output
- Real test execution results
- Git diff showing actual changes

**Rejected**:
- "Should work"
- "Looks correct"
- Unverified claims
- Mock-based assertions for integration

---

## Isolation Requirements (KALLAX Enhancement)

### Worktree Enforcement

```bash
# Performer claims task → automatic worktree creation
kallax task:claim TASK-001
# Creates: .claude/worktrees/TASK-001/

# Conductor verifies isolation before dispatch
kallax isolation:check TASK-001 TASK-002
# Fails if file scopes overlap
```

### File Scope Declaration

Every ticket MUST declare file scope:

```yaml
# jira/tickets/TASK-001.md frontmatter
file_scope:
  includes:
    - src/components/Login/**
    - src/hooks/useAuth.ts
  excludes:
    - src/components/shared/**  # Shared by other tasks
```

### Conflict Prevention

1. Conductor checks file scope overlap before dispatch
2. Performers cannot modify files outside scope
3. Shared files require explicit coordination handoff

---

## Error Handling (KALLAX Enhancement)

### Rust Layer

```rust
// ❌ FORBIDDEN in production code
let value = risky_operation().expect("should work");
let value = risky_operation().unwrap();
panic!("unexpected state");

// ✅ REQUIRED pattern
let value = risky_operation()
    .map_err(|e| KallaxError::Operation { 
        context: "processing ticket",
        source: e 
    })?;

// Custom error types with context
#[derive(Debug, thiserror::Error)]
pub enum KallaxError {
    #[error("operation failed in {context}: {source}")]
    Operation {
        context: &'static str,
        #[source]
        source: Box<dyn std::error::Error + Send + Sync>,
    },
    
    #[error("ticket {id} not found")]
    TicketNotFound { id: String },
    
    #[error("performer {id} timeout after {elapsed:?}")]
    PerformerTimeout { id: String, elapsed: Duration },
}
```

### TypeScript Layer

```typescript
// ❌ FORBIDDEN
function process(data: any): any { }
// @ts-ignore
catch (e) { /* silent */ }

// ✅ REQUIRED pattern
function process(data: unknown): Result<ProcessedData, ProcessError> {
  if (!isValidData(data)) {
    return err(ProcessError.invalidInput(data));
  }
  
  try {
    const result = transform(data);
    return ok(result);
  } catch (e: unknown) {
    if (e instanceof NetworkError) {
      return err(ProcessError.network(e));
    }
    return err(ProcessError.unknown(e));
  }
}
```

---

## Resource Management (KALLAX Enhancement)

### Cache TTL Requirement

```typescript
// ❌ FORBIDDEN - no TTL
const cache = new Map<string, Data>();

// ✅ REQUIRED - with TTL
const cache = new LRUCache<string, Data>({
  max: 1000,
  ttl: 5 * 60 * 1000,  // 5 minutes
  updateAgeOnGet: true,
  dispose: (value, key) => {
    logger.debug({ key }, 'cache entry disposed');
  }
});
```

### Connection Pool Management

```typescript
// ✅ REQUIRED - with timeout and limits
const pool = createPool({
  max: 10,
  min: 2,
  acquireTimeoutMillis: 30000,
  idleTimeoutMillis: 30000,
  reapIntervalMillis: 1000,
});
```

### Circuit Breaker

```typescript
const breaker = new CircuitBreaker({
  state: 'CLOSED',
  failureThreshold: 3,
  resetTimeout: 30000,
  onOpen: () => logger.warn('circuit opened'),
  onClose: () => logger.info('circuit closed'),
});
```

---

## Degradation Strategy

```
┌─────────────────────────┐
│  Level 3: Redis + Full  │
│  (Production)           │
└──────────┬──────────────┘
           ↓ Redis timeout
┌─────────────────────────┐
│  Level 2: Node.js + File│
│  (Degraded)             │
└──────────┬──────────────┘
           ↓ Node.js crash
┌─────────────────────────┐
│  Level 1: Rust CLI      │
│  (Minimal)              │
└──────────┬──────────────┘
           ↓ Rust failure
┌─────────────────────────┐
│  Level 0: Shell         │
│  (Emergency)            │
└─────────────────────────┘
```

**Requirements**:
- Degradation MUST be logged with warning level
- Degradation MUST emit metric
- Recovery MUST be attempted periodically

---

## Observability

### Structured Logging

```typescript
// ✅ REQUIRED format
logger.info({
  event: 'task_claimed',
  ticketId: 'TASK-001',
  performerId: 'performer_001',
  timestamp: Date.now(),
  duration: 42,
}, 'performer claimed task');

// ❌ FORBIDDEN
console.log('Task claimed:', taskId);
```

### Metrics

```typescript
// Track key events
metrics.increment('kallax.task.claimed', { performer: id });
metrics.timing('kallax.task.duration', elapsed);
metrics.gauge('kallax.performers.active', count);
```

### Tracing

```typescript
const span = tracer.startSpan('task:claim', {
  attributes: {
    'ticket.id': ticketId,
    'performer.id': performerId,
  }
});
```

---

## Anti-Patterns

### DO NOT

1. **Silent Catch**: Catch and ignore errors
2. **Any Escape**: Use `any` to bypass type checking
3. **Infinite Retry**: Loop without backoff or limit
4. **Cross-Layer Call**: Controller directly accessing DB
5. **Hardcoded Secrets**: Credentials in code
6. **TTL-less Cache**: Cache without expiration
7. **Background Hallucination**: Claim completion without verification
8. **Scope Violation**: Modify files outside declared scope
9. **Self-Review**: Approve own PR
10. **Mock Integration**: Use mocks for integration tests

### DO

1. **Propagate Errors**: Use Result types consistently
2. **Type Everything**: Strict TypeScript, no any
3. **Exponential Backoff**: Retry with increasing delays
4. **Layer Separation**: Controller → Service → Repository
5. **Environment Variables**: Secrets in env only
6. **TTL Everything**: All caches must expire
7. **Verify Outputs**: Run actual commands to verify
8. **Scope Declaration**: Explicit file boundaries
9. **Cross-Review**: Different agent reviews PR
10. **Real Tests**: Integration tests hit real systems
