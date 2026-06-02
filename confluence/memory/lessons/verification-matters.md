---
title: Verification Matters — Trust But Verify
category: lesson
severity: critical
date: 2026-06-03
status: active
---

## Context

Agent systems can report "task complete" without actual output. This was discovered when background agents consistently reported success but produced zero file changes.

## Problem

```
Agent: "Task TASK-042 completed successfully!"
Reality: No files changed, no commits, no PR created
```

- Agent hallucinated completion
- No verification mechanism existed
- Trust-based model = unreliable at scale

## Solution

**4-Level Fact-Forcing Verification:**

| Level | Check | Evidence Required |
|-------|-------|-------------------|
| L1 Existence | Files present in diff | `git show --stat` |
| L2 Substance | Real code, not stubs | File content analysis |
| L3 Wiring | Imports/exports correct | Lint + type check |
| L4 Data Flow | Integration tests pass | Test output |

```
Rule: Missing any level = Reject
Rule: Never trust agent self-report alone
Rule: Conductor must verify before Approve
```

## Impact

- Zero "phantom completions" after implementation
- Every task completion has verifiable evidence
- Conductor confidence in Performer output

## Related
- [[anti-hallucination]] — Agent hallucination patterns
- [[gate-review]] — 4-Level gate review protocol
