---
title: Multi-Agent Collaboration Failure Modes
category: lesson
severity: critical
date: 2026-06-03
status: active
---

## Problem

5 parallel Performers completed estimated 2-3 hour work in 20 minutes, BUT:

1. **Focus drift** — Performers helping each other instead of staying on assigned tasks
2. **Linter auto-revert** — Two performers' linters undoing each other's formatting
3. **Environment competition** — Redis/SQLite port conflicts between parallel instances
4. **Implicit dependencies** — Task B depending on Task A's output without explicit declaration
5. **Task ambiguity** — Unclear boundaries → duplicate work or gaps

## Solution

### Pre-execution Gates
- **File scope declaration mandatory** — every ticket must list exact files it touches
- `kallax isolation:check` before assignment
- Conflict = automatic block (not warning)

### During Execution
- **No cross-Performer help** — each Performer stays in its worktree
- **Separated environments** — each worktree has own DB/queue context
- **Explicit dependency declaration** — "Blocks: TASK-NNN" in ticket metadata

### Post-execution
- Conductor does NOT assign tasks — Conductor REMOVES BLOCKERS
- Dedicated docs agent produces better documentation than distributed writing
- Phase review catches integration gaps

## Related
- [[conductor-single-point-failure]]
- [[isolation-strategy]]
- [[background-agent-hallucination-2026-06-19]]
