# EPIC-152: Rule 34 — Bugfix tickets require independent reproduction

> **Pattern**: canary chain | **Version**: v3.31.0 | **Status**: done

## Summary

CLAUDE.md added Rule 34: Master must independently reproduce before creating bugfix tickets. Canary chain revealed 7 performers independently corrected Master mis-diagnosis in EPIC-141/145/148/153.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-152",
  "epic": "EPIC-152",
  "title": "Fact-Forcing cumulative 3 cases — Master must independently repro bugfix",
  "status": "done",
  "priority": "P1",
  "type": "docs",
  "created_at": "2026-07-26",
  "worktree_role": "master",
  "labels": ["governance", "fact-forcing", "rule-upgrade"],
  "derived_from": "EPIC-141 v1 + EPIC-145 + EPIC-148 累积 3 例"
}
```

Source: `jira/tickets/EPIC-152/ticket.json`

## Root Cause (3 canary cases)

| Case | Master Diagnosis | Performer Independent Repro | True Root Cause |
|------|-----------------|----------------------------|-----------------|
| EPIC-141 v1 | `utils.test.ts:53/61/78/96` has real throw | `utils.test.ts` 23/23 PASS | `validate-runner.ts:96-99` main() on import |
| EPIC-145 | script missing or tsc error | `npm run build` exit 0 | root `npm run build` prebuild hook triggers `version-check.sh` FAIL (EPIC-147) |
| EPIC-148 | workflow type-check → typecheck typo | exact error location | root npm missing `typecheck` script (only `node/` has) |

**Pattern**: Master infers from CI log position/keywords → creates ticket with wrong diagnosis → performer independently runs → real culprit differs from inference.

## Rule 34 (CLAUDE.md §3)

**For Master (creating bugfix tickets)**:
1. Must independently reproduce failure locally or in CI
2. Must attach `verification.reproduction_command` + `verification.reproduction_exit_code` + `verification.reproduction_raw_output` (first 30 lines)
3. Cannot just paste CI log position + one-line hypothesis

**For Performer (receiving bugfix tickets)**:
1. Must independently reproduce first (run reproduction_command)
2. If diagnosis matches → fix
3. If diagnosis mismatches → **STOP**, set ticket status to `blocked`, report to Master
4. **0 source change is a valid conclusion** (Case 6 — EPIC-153)

## 5-Level Verify Output

```
L1: git log --oneline EPIC-152 → 7123ca3 (commit exists)
L2: Rule 34 text in CLAUDE.md → grep "Rule 34" CLAUDE.md → found
L3: jira/tickets/EPIC-152/ticket.json → status: done, resolution_summary with 3 cases
L4: 7 canary performers confirmed Rule 34 caught mis-diagnosis
L5: check-claim-evidence.sh → exit 0 (0 decorative claims)
```

## 4-Branch Flow Trajectory

```
feature/v3.31.0-EPIC-152 → testing → main → miao
Direct edit by master (doc-level, 0 source change)
```

## Master Decision Record

**Date**: 2026-07-26
**Decision**: "canary 期间 3 例 performer 独立复现拒绝 master 错误 diagnosis. 加 Rule 34 到 CLAUDE.md. Option A + C: CLAUDE.md 段升级 + template checklist."

**Key lesson**: Master diagnosis from CI logs is symptom, not root cause.

## Evidence Links

- Rule: `CLAUDE.md §3`
- Decision: `confluence/decisions/fact-forcing-independent-repro-2026-07-26.md`
- Ticket: `jira/tickets/EPIC-152/ticket.json`
