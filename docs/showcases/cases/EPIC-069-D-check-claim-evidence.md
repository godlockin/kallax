# EPIC-069-D: check-claim-evidence — Prevent decorative PASS claims

> **Pattern**: fact-forcing | **Version**: v3.8.1 | **Status**: done

## Summary

Pre-commit hook forces README/CHANGELOG to include `raw_output` references when citing test results. Root cause: v3.8.0 claimed "25/25 PASS / production-grade" but red-blue review found `cargo test` 11 errors + Node 8/19 failures.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-069-D",
  "epic": "EPIC-069",
  "title": "5-Level Verify fact-forcing + check-claim-evidence pre-commit",
  "status": "done",
  "priority": "P1",
  "type": "feature",
  "created_at": "2026-07-09",
  "labels": ["fact-forcing", "5-level-verify", "pre-commit", "v3.8.1"],
  "rule_references": ["v3.8.0 red-blue review", "EPIC-069-A cargo test", "EPIC-069-B vitest hook-replay"]
}
```

Source: `jira/tickets/EPIC-069-D/` (exists in miao branch)

## Root Cause (from v3.8.0 red-blue review)

| Claim | Reality |
|-------|---------|
| "25/25 PASS" | `cargo test` 11 errors + Node hook-replay 8/19 fail |
| "production-grade" | Hash-Chain tamper-proof = 0 (no algorithm) |
| "root-cause fixed" | Only docs updated, no source fix |

## Solution

**`scripts/hooks/check-claim-evidence.sh`** (pre-commit hook):
- Scans staged README.md + CHANGELOG.md for `\d+/\\d+ PASS` patterns
- Requires `raw_output:` reference with file path
- Exit 1 (fail-closed) if decorative claim without evidence

## 5-Level Verify Output

```
L1: git log --oneline EPIC-069 → ac03d3c (commit exists)
L2: cargo test --workspace --release → test result: ok. 74 passed; 0 failed
L3: git show miao:jira/tickets/EPIC-069-D/ticket.json (ticket exists + master APPROVE)
L4: red-blue review 2 experts confirmed check-claim-evidence.sh catches all X/Y patterns
L5: check-claim-evidence.sh on staged files → exit 0 (no decorative claims without evidence)
```

## 4-Branch Flow Trajectory

```
feature/v3.8.1-EPIC-069 → testing (PR #N) → main (PR #N+1) → miao (PR #N+2)
```

Commit: `7e3376c chore: v3.8.1 release (EPIC-069, Master APPROVE 5-Level Verify 新规 PASS)`

## Master Decision Record

**Date**: 2026-07-09
**Decision**: "v3.8.0 README 声称 25/25 PASS 但 reviewer 红蓝对抗实测 cargo test 11 errors. 必须加 pre-commit hook 强制数字必带 raw output 引用."

**Key lesson**: decorative claims without evidence = technical debt that compounds.

## Evidence Links

- Script: `scripts/hooks/check-claim-evidence.sh`
- Decision: `confluence/decisions/fact-forcing-independent-repro-2026-07-26.md`
- CHANGELOG: `[3.8.1]` entry with raw_output refs
