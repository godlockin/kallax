# EPIC-155: 4-branch bypass retrospective — 3 commits, full trace

> **Pattern**: retro remediation | **Version**: v3.31.1 | **Status**: done (bypass accepted)

## Summary

v3.30.0 + v3.30.1 had 3 commits bypassing 4-branch flow (a8da33f / 1482ffa / 40e2b8e). Master documented root cause, accepted loss, planned Q3 2026 retro re-promote.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-155",
  "epic": "EPIC-155",
  "title": "4-branch bypass historical debt 备案 + retrospective re-promote",
  "status": "done",
  "priority": "P0-10",
  "type": "docs",
  "created_at": "2026-07-29",
  "worktree_role": "master",
  "labels": ["governance", "retro-remediation", "4-branch-flow", "bypass-acceptance"]
}
```

Source: `jira/tickets/EPIC-155/` (exists in miao branch as commit `78391eb`)

## Bypass Commits (3 total)

| Commit | SHA | Reason |
|--------|-----|--------|
| a8da33f | bypass 1 | v3.30.0 hotfix (unknown reason) |
| 1482ffa | bypass 2 | v3.30.1 CLAUDE.md trim (PR #162) |
| 40e2b8e | bypass 3 | main → miao direct (Phase 3 accept) |

## Root Cause

| Factor | Detail |
|--------|--------|
| v3.10.0 | 4-branch flow first introduced |
| v3.30.0 | First bypass (a8da33f) — hotfix under time pressure |
| v3.30.1 | Second bypass (1482ffa) — perceived as "doc-only" |
| v3.31.0 | Third bypass (40e2b8e) — main → miao direct |

**Pattern**: "doc-only" commits perceived as exempt from 4-branch flow.

## Solution (Phase 3 decision)

**Master (主公) accepted bypass loss**:
- No retroactive force-push (too risky for closed PRs)
- Documented in CLAUDE.md §4 branch-flow section
- Planned Q3 2026 retro re-promote via EPIC-155

**Branch sync pattern** (documented in `.claude/rules/branch-flow.md`):
- testing → miao: force-push (EPIC-142 pattern)
- main → testing: force-push (EPIC-146 pattern)
- main ↔ miao: bypass documented + accepted

## 5-Level Verify Output

```
L1: git log --oneline → 78391eb docs(CLAUDE.md): EPIC-155 4-branch bypass 历史债 备案
L2: CLAUDE.md §4 → 4-branch bypass section exists + links to EPIC-155
L3: jira/tickets/EPIC-155/ → status: done (master direct edit)
L4: .claude/rules/branch-flow.md → bypass documentation present
L5: check-claim-evidence.sh → exit 0
```

## 4-Branch Flow Trajectory

```
v3.30.0: bypass (a8da33f) → no PR
v3.30.1: bypass (1482ffa) → PR #162 direct to miao
v3.31.0: bypass (40e2b8e) → main → miao direct
v3.31.1: EPIC-155 retrospective (78391eb) → doc fix only
```

## Master Decision Record

**Date**: 2026-07-29
**Decision**: "3 commits bypass 4-branch flow. 主公拍接受丢失 (Phase 3 拍板). EPIC-155 计划 Q3 2026 retractively re-promote."

**Key lesson**: "doc-only" is not exempt from governance. Every commit needs trace.

## Evidence Links

- Rule: `.claude/rules/branch-flow.md` (bypass documentation)
- Decision: `confluence/decisions/branch-flow-governance-2026-07-09.md`
- Commit: `78391eb` (EPIC-155 bypass documentation)
