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
worktree_role: master | conductor | performer | auditor   # EPIC-035-A 强制 schema
performer_sub_role: coder | reviewer | tester | docs       # EPIC-038-A Rule 15 sub-role
handoff_depth: L1 | L2 | L3 | L4                            # EPIC-038-A Rule 15 4 层接手
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

## handoff_depth Schema (EPIC-038-A Rule 15)

`handoff_depth` 定义 Performer 接手层级, enum: `L1 | L2 | L3 | L4`:

| Depth | 含义 | 跟 worktree_role 联动 | 跟 Sub-role 联动 |
|-------|------|---------------------|------------------|
| **L1** | 单 ticket 派单 (default) | performer + sub-role=coder/reviewer/tester/docs | 单 sub-role |
| **L2** | EPIC 内多 ticket 串行 (e.g. A→B) | performer + sub-role 切换 | 跨 sub-role (coder→tester) |
| **L3** | 跨 EPIC 同 PHASE 接手 (e.g. EPIC-038 → EPIC-039) | performer 复用, sub-role 升级 | sub-role 升级 (tester→reviewer) |
| **L4** | 跨 PHASE 接手 (e.g. PHASE-006 → PHASE-007) | performer 强制 sub-role reset | sub-role reset + context migration |

**强制约束** (跟 Rule 15 红线联合):
- ❌ `handoff_depth` 缺失 = dispatch FAIL (跟 EPIC-038-A Rule 15 5 红线 联合)
- ❌ `handoff_depth=L2/L3/L4` 但 `worktree_role != performer` = FAIL
- ❌ `handoff_depth=L4` 无 `context_migration` 字段 = FAIL
- ✅ `handoff_depth` 必须跟 `worktree_role` + `performer_sub_role` 三方一致 (1:1 验证)

**派生** (跟 dispatch.sh `--handoff-depth` 选项 联合):
- L1 → 单 performer 单一 sub-role, dispatch.sh 默认 (无需参数)
- L2 → 同 EPIC 串行, dispatch.sh 验证前 ticket done
- L3 → 跨 EPIC, dispatch.sh 验证 PHASE 一致
- L4 → 跨 PHASE, dispatch.sh 强制 context_migration 字段

**来源**: EPIC-038-A Rule 15 (主公 2026-06-12 拍 A, 5 能力研究 Q4 重大 Gap 40% 立即派, 跟 EPIC-035-A 一起做).

## File Scope Rules

1. **REQUIRED** for isolation — Conductor checks scope before assignment
2. **EXCLUSIVE** — no two performers can share file scope
3. **SPECIFIC** — paths relative to repo root
4. **VALIDATED** — `kallax isolation:check` before claim
