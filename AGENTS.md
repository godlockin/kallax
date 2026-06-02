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
