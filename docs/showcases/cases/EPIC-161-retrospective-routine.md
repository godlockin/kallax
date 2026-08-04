# EPIC-161: retrospective-routine.sh — 6-stage periodic review

> **Pattern**: periodic review | **Version**: v3.32.6 | **Status**: done

## Summary

6-stage retrospective routine script (retrospect + consolidate + review-docs + upgrade + archive + delete) with `--dry-run` / `--apply` / `--phase` / `--stages` / `--json` flags.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-161",
  "epic": "EPIC-161",
  "title": "retrospective-routine.sh 6 阶段 routine (复盘/整理/review/升级/归档/删除)",
  "status": "done",
  "priority": "P1",
  "type": "feature",
  "created_at": "2026-08-03",
  "worktree_role": "performer",
  "labels": ["feature", "routine", "6-stage", "retrospective"],
  "rule_references": ["EPIC-160 (install.sh Omnibus — 互补)", "EPIC-059-E (Post-Process 11 步骤 — 兼容)"]
}
```

Source: `jira/tickets/EPIC-161/ticket.json`

## 6 Stages

| # | Stage | Function | Purpose |
|---|-------|----------|---------|
| 1 | retrospect | `stage_retrospect()` | List CHANGELOG.md last 10 releases |
| 2 | consolidate | `stage_consolidate()` | CLAUDE.md line count (≤200) + duplicate files + _archived/ size |
| 3 | review_docs | `stage_review_docs()` | .claude/rules/ + docs/reference/ + confluence/decisions/ count + paths: frontmatter |
| 4 | upgrade | `stage_upgrade()` | node/rustc version + Cargo.toml/package.json + install.sh Omnibus --inventory |
| 5 | archive | `stage_archive()` | DEPRECATED/ABANDONED markers + _archived/ dir |
| 6 | delete | `stage_delete()` | 0-byte files + scan-dead-code.sh exit |

## Flags

```bash
# Dry run (preview only)
bash scripts/retrospective-routine.sh --dry-run

# Apply changes
bash scripts/retrospective-routine.sh --apply

# Run specific stage
bash scripts/retrospective-routine.sh --phase=upgrade --stages=4

# JSON output (machine-readable)
bash scripts/retrospective-routine.sh --json

# Specific stages
bash scripts/retrospective-routine.sh --stages=1,2,3
```

## 5-Level Verify Output

```
L1: git log --oneline EPIC-161 → d5cec8e feat(routine): EPIC-161 retrospective-routine.sh 6 阶段
L2: npm run build → exit 0
L3: vitest run → Test Files 5 passed / Tests 103 passed
L4: tests/integration/retrospective-routine.test.sh → 17/17 PASS
L5: check-claim-evidence.sh → exit 0 (CHANGELOG [3.32.6] has raw_output refs)
```

Raw test output:
```
bash tests/integration/retrospective-routine.test.sh
→ EPIC-161 Retrospective Routine Tests: 17 passed, 0 failed

cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage{,-d,-e}.test.ts \
  tests/dead-code-master-verify.test.ts \
  tests/schema/expert-binding.test.ts
→ Test Files 5 passed (5) / Tests 103 passed (103)
```

## 4-Branch Flow Trajectory

```
feature/v3.32.6-EPIC-161 → testing → main → miao
f7b4527 feat(routine): EPIC-161 retrospective-routine.sh 6 阶段 (135 行 CLAUDE.md)
d5cec8e feat(routine): EPIC-161 retrospective-routine.sh 6 阶段 (135 行 CLAUDE.md) (#191)
```

## Master Decision Record

**Date**: 2026-08-03
**Decision**: "retrospective routine 需要 6 阶段: 复盘 + 整理 + review + 升级 + 归档 + 删除. 每个阶段有 dry-run + apply 模式."

**Key lesson**: Periodic review without automated tooling becomes optional. Automated tooling makes governance routine.

## Evidence Links

- Ticket: `jira/tickets/EPIC-161/ticket.json`
- Script: `scripts/retrospective-routine.sh`
- Test: `tests/integration/retrospective-routine.test.sh`
- Ref: `docs/reference/retrospective-routine-2026-08-03.md`
