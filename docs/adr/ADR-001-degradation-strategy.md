# Architecture Decision Records

> Decisions that shaped the KALLAX framework.

---

## ADR-001: Three-Tier Degradation (Redis -> SQLite -> Filesystem)

### Status

**Accepted** -- 2026-01. Implemented in `recovery-manager.ts`.

### Context

KALLAX runs across Rust, Node.js, and shell environments. Any single component can fail -- Redis goes down, Node crashes, or disk fills up. The framework needed a resilience strategy that:

- Keeps the system running when dependencies fail, not crashing entirely
- Recovers automatically when failed components come back
- Makes the degradation state observable (not silent)

The existing `DEGRADATION-STRATEGY.md` outlines the tier architecture but does not codify the probing logic or recovery mechanics.

### Decision

We chose a **three-tier degradation model with periodic probing**:

| Tier | Stack | Data Layer | Startup |
|------|-------|-----------|---------|
| L3: Rust | Rust binary | Redis + SQLite | ~8ms |
| L2: Node.js (default) | Express + better-sqlite3 | SQLite (WAL) | ~400ms |
| L1: Shell | Bash scripts | Filesystem queue | ~50ms |
| L0: Degraded | None | None | N/A |

Key design choices:

1. **Probe interval = 60s**: Frequent enough for fast recovery, rare enough to avoid thundering herd.
2. **Consecutive-failure counting**: 2 failures to degrade (avoids transient blips), 3 successes to upgrade (avoids flapping).
3. **Crash-limit circuit breaker**: 5 crashes within 5 minutes forces automatic degradation.
4. **Best-effort compensation**: Failed compensations are logged but never block forward progress.

### Consequences

**Positive:**
- Zero-downtime operation during Redis outages (falls back to SQLite message queue)
- Automatic recovery when Rust binary is rebuilt (probe detects it within 60s)
- Crash-limit prevents runaway degradation in pathological states

**Negative:**
- L1 Shell fallback loses advanced features (DAG scheduling, real-time SSE)
- Probing adds minimal CPU overhead (~2ms per probe cycle)
- Recovery Manager singleton must be initialized before any other component

### Alternatives Considered

- **Retry-only strategy**: Does not address component unavailability -- infinite retries on a dead Redis just wastes CPU.
- **Manual failover**: Requires human operator, violates KALLAX automation principle.
- **Two-tier only (Node+Shell)**: Rust layer would never be adopted, losing performance benefits.

### Related

- `docs/architecture/DEGRADATION-STRATEGY.md` -- Full tier specification
- `node/src/core/recovery-manager.ts` -- Implementation
- `node/tests/master-election.test.ts` -- Redis failure test

---

## ADR-002: Conductor-Performer over Master-Slaver

### Status

**Accepted** -- 2026-01. Reflects naming conventions across the entire codebase.

### Context

Early KALLAX prototypes used "Master" and "Slaver" terminology. This caused:

1. **Cultural insensitivity**: Offensive terminology in a global context
2. **Technical ambiguity**: "Master" implies ownership, but the orchestrator is a coordinator
3. **Industry shift**: GitHub, Redis, Python, Django all migrated away from master/slave

### Decision

Replace "Master/Slaver" with **"Conductor/Performer"** :

| Old Term | New Term | Rationale |
|----------|----------|-----------|
| Master | Conductor | Orchestrates, doesn't own. Like a symphony conductor |
| Slaver | Performer | Executes tasks autonomously within scope |
| Master election | Instance registry | No election needed -- Conductor is a role, not a leader |
| Slave heartbeat | Performer heartbeat | Same function, clearer semantics |

### Consequences

**Positive:**
- Immediate clarity: Conductor decomposes/dispatches/reviews; Performer builds/tests/commits
- No cultural baggage
- Clear permission boundaries: Conductor cannot push to feature branches, Performer cannot merge to main

**Negative:**
- Migration cost: renaming symbols, config keys, and documentation
- File `master-election.ts` still exists for historical Redis-based coordinator elections (deprecated)

### Alternatives Considered

- **Orchestrator/Worker**: Functional but generic. "Conductor" better conveys the music analogy.
- **Lead/Contributor**: Implies hierarchy, contradicts flat AI agent collaboration.

### Related

- `CLAUDE.md` -- Role definitions and prohibited operations
- `node/src/core/role-selector.ts` -- Role detection at startup
- `node/src/core/instance-registry.ts` -- Instance registration
- `template/docs/CONDUCTOR-RULES.md` -- Conductor responsibilities
- `template/docs/PERFORMER-RULES.md` -- Performer 9 hard rules

---

## ADR-003: Saga Compensation over Simple Rollback

### Status

**Accepted** -- 2026-01. Implemented in `saga-executor.ts`.

### Context

Task completion is multi-step: run tests, lint, commit, push branch, create PR. Simple rollback has flaws:

1. **No partial recovery**: A failed commit cannot "un-run" tests.
2. **Cascading failures**: Rollback failure (git revert fails) corrupts state.
3. **Observability gap**: No record of which steps succeeded or were compensated.

### Decision

Adopt the **Saga pattern** -- each forward step has a compensating action:

```typescript
{
  name: 'commit-changes',
  execute(state) { return git.commit(state.worktreePath, state.message); },
  compensate(state) { return git.resetSoft(state.worktreePath, 'HEAD~1'); },
}
```

| Aspect | Simple Rollback | Saga Compensation |
|--------|----------------|-------------------|
| Reversibility | Assumes all actions reversible | Each step defines own undo |
| Granularity | All-or-nothing | Per-step compensation |
| Failure mode | Entire revert fails | Best-effort per step, logged |
| Observability | "Operation failed" | Step-level success/failure |
| Partial state | Lost on revert | Preserved for inspection |

The 5-step task completion saga:

```
Step 1: run-tests       -> compensate: no-op
Step 2: run-lint        -> compensate: no-op
Step 3: commit-changes  -> compensate: git reset-soft
Step 4: push-branch     -> compensate: delete remote branch
Step 5: create-pr       -> compensate: close PR + delete remote branch
```

### Consequences

**Positive:**
- No permanent corruption -- every forward step has a valid undo
- Compensating failures are logged but do not cascade
- Detailed execution results enable debugging and manual intervention

**Negative:**
- More code than simple rollback
- Compensating actions can also fail (git reset on uncommitted worktrees)
- Saga state must be serializable for recovery after Node.js restart

### Alternatives Considered

- **Single transaction**: Impossible across git, GitHub API, and database boundaries.
- **Two-phase commit**: Overkill for agent coordination.
- **Manual cleanup only**: Not acceptable for automated tasks.

### Related

- `node/src/core/saga-executor.ts` -- Generic Saga implementation
- `node/src/core/saga-executor.ts::createTaskCompletionSaga` -- 5-step task saga
- `node/tests/saga-executor.test.ts` -- Saga test coverage
- `node/src/commands/complete.ts` -- Command invoking the saga
