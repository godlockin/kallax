# EPIC-158: Pre-existing CI debt — Forbidden Patterns regex + sqlite skipIf

> **Pattern**: debt cleanup | **Version**: v3.32.3 | **Status**: done

## Summary

Two pre-existing CI debts discovered during EPIC-157 4-branch flow: (1) Forbidden Patterns Check regex false-positive on JSDoc prose, (2) expert-invocations-queue.test.ts failing in CI environments without SQLite.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-158",
  "epic": "EPIC-158",
  "title": "Pre-existing CI debt — Forbidden Patterns regex + expert-invocations-queue CI env skipIf",
  "status": "done",
  "priority": "P1",
  "type": "refactor",
  "created_at": "2026-08-03",
  "worktree_role": "performer",
  "labels": ["refactor", "ci-debt", "false-positive-fix", "skipif-pattern"],
  "rule_references": ["EPIC-114 (live test skipIf pattern)", "Rule 7 scope-check"]
}
```

Source: `jira/tickets/EPIC-158/ticket.json`

## Debt 1: Forbidden Patterns Check regex false-positive

| Aspect | Detail |
|--------|--------|
| **Problem** | `grep -rn ': any' --include="*.ts"` matches JSDoc prose `fail-closed: any error` |
| **Affected files** | `node/src/permissions/authz-check.ts:5`, `node/tests/l1-match.test.ts:9` (8 total) |
| **Impact** | PR #176/177/179 all fail this step (unrelated to their content) |
| **Root cause** | CI workflow grep regex doesn't exclude JSDoc `^\\s*(\\*|//)\\s` patterns |
| **Fix** | Add `--exclude-dir node_modules` + post-filter `grep -v -E '^\\s*(\\*|//)\\s'` |

## Debt 2: expert-invocations-queue.test.ts CI env fail

| Aspect | Detail |
|--------|--------|
| **Problem** | Test expects `'sqlite'` but CI env without SQLite → backend auto-degrades to `file` |
| **Affected line** | `expert-invocations-queue.test.ts:120` |
| **Impact** | PR #176 coverage gate fails (unrelated to content) |
| **Root cause** | factory pattern + test expectation mismatch, EPIC-114 skipIf pattern not applied |
| **Fix** | `describe.skipIf(!process.env.KALLAX_TEST_SQLITE_AVAILABLE)` (per EPIC-114 pattern) |

## 5-Level Verify Output

```
L1: git log --oneline EPIC-158 → 0649723 fix(ci): EPIC-158 pre-existing CI debt
L2: npm run build → exit 0
L3: vitest run tests/dead-code-sentinel-coverage{,-d,-e}.test.ts → 5 passed / 103 passed
L4: Forbidden Patterns Check on miao tip → exit 0 (8 JSDoc prose excluded)
L5: check-claim-evidence.sh → exit 0 (CHANGELOG [3.32.3] has raw_output refs)
```

## 4-Branch Flow Trajectory

```
feature/v3.32.3-EPIC-158 → testing → main → miao
64c7602 fix(ci): EPIC-158 pre-existing CI debt — Forbidden Patterns regex + sqlite skipIf
0649723 fix(ci): EPIC-158 pre-existing CI debt — Forbidden Patterns regex + sqlite skipIf (#182)
```

## Master Decision Record

**Date**: 2026-08-03
**Decision**: "EPIC-157 4-branch flow 暴露 2 个 pre-existing CI debt. 独立 EPIC 治理, 不混 EPIC-157 scope (per Rule 7 scope-check)."

**Key lesson**: 4-branch flow reveals hidden debt. Each EPIC should clean its own discovered debt.

## Evidence Links

- Ticket: `jira/tickets/EPIC-158/ticket.json`
- Workflow: `.github/workflows/kallax-ci.yml`
- Test: `node/tests/expert-invocations-queue.test.ts`
- Pattern: `CLAUDE.md §Stage 1 false-positive 沉淀`
