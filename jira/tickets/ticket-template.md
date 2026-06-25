# KALLAX Ticket Template

> Universal ticket format for all task types

## Template

```markdown
---
id: TASK-NNN
title: [Brief description of work]
status: backlog | todo | in_progress | review | blocked | done
priority: P0 | P1 | P2 | P3
type: feature | bugfix | refactor | docs | test | chore
assignee: [Performer ID]
created: YYYY-MM-DD
updated: YYYY-MM-DD
estimated_minutes: N
file_scope: [comma-separated file paths]
labels: [comma-separated tags]
---

## Description
[Detailed description of what needs to be done]

## Acceptance Criteria
- [ ] Criterion 1 — measurable and testable
- [ ] Criterion 2 — measurable and testable
- [ ] Criterion 3 — measurable and testable

## Technical Notes
[Implementation hints, constraints, references]

## File Scope
[Explicit list of files this task will modify — REQUIRED for isolation check]
- src/path/to/file1.ts
- src/path/to/file2.ts

## Dependencies
- [ ] Depends on: TASK-NNN
- [ ] Blocks: TASK-NNN

## Verification
- [ ] L1 Existence: Files present in diff
- [ ] L2 Substance: Real code, no stubs
- [ ] L3 Wiring: Imports/exports correct
- [ ] L4 Data Flow: Tests passing
```

## Priority Matrix

| Priority | SLA | Examples |
|----------|-----|----------|
| P0 Critical | 4 hours | Production outage, security vulnerability, data loss |
| P1 High | 24 hours | Blocking other tasks, customer-facing bug |
| P2 Medium | 1 week | Feature work, non-blocking improvements |
| P3 Low | 2 weeks | Chores, refactoring, documentation |

## Status Flow

```
backlog → todo → in_progress → review → done
                      ↓
                  blocked (waiting on dependency)
                      ↓
                  cancelled
```

## File Scope Rules

1. **REQUIRED** for isolation — Conductor checks scope before assignment
2. **EXCLUSIVE** — no two performers can share file scope
3. **SPECIFIC** — paths relative to repo root
4. **VALIDATED** — `kallax isolation:check` before claim
