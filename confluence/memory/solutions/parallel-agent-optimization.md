# Parallel Agent Optimization

> Strategies for running 5+ AI agents concurrently without chaos
> Updated: 2026-06-04 | KALLAX real parallel sessions

## Core Principle: Isolation is Everything

Two agents modifying the same file will conflict, regardless of how smart each is.

```
Without isolation: Agent A + Agent B → same file → conflict → 1h to resolve
With isolation:    Agent A (file scope A) + Agent B (file scope B) → no conflict → 5min merge
```

**Fundamental Rule**: No two agents share write access to the same file.

## Task Splitting Strategy

1. **One primary file per agent.** Each agent "owns" one file.
2. **Shared interfaces are read-only** during parallel execution.
3. **Test files follow the source** — same agent owns both.

### Example: EPIC-011 (proven 3.5x speedup)
```
Sequential: Agent implements DB + Analyzer + Webhook + Fingerprint → 8h
Parallel:   4 agents, 4 independent file scopes → 2.3h
```

## Verification Gate Pipeline

```
Agent completes → tsc --noEmit → vitest run → eslint → git commit → Conductor review
```

## Worktree Management

```bash
git worktree add .claude/worktrees/TASK-001 -b feature/TASK-001
# dev happens here
cd .claude/worktrees/TASK-001
# cleanup on failure:
rm -rf worktree_dir && git worktree prune && git branch -D feature/TASK-001
```

## Session Budgeting

Per agent: ~100K tokens → split work into <30 min chunks → /compact every 5-8 tool calls

## References
- [[multi-agent-collab-failures]]
- [[isolation-strategy]]
- [[context-overflow-defense]]
- [[kallax-rebuild-lessons]]
