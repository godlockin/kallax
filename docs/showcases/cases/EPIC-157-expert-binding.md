# EPIC-157: Expert binding 4-field — mis_dispatch_rate north-star打通

> **Pattern**: metric wiring | **Version**: v3.32.2 | **Status**: done

## Summary

ticket.json schema extended with 4 binding fields (suggested_expert / actual_expert / expert_binding_at / binding_change_reason). mis_dispatch_rate north-star metric now has data source.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-157",
  "epic": "EPIC-157",
  "title": "Expert Binding Tracking — Master 建议 + Performer 实际 + Review 复盘",
  "status": "done",
  "priority": "P1",
  "type": "feature",
  "created_at": "2026-08-02",
  "worktree_role": "performer",
  "expert_binding": {
    "suggested_expert": "backend",
    "actual_expert": "frontend",
    "expert_binding_at": "2026-08-02T14:45:03Z",
    "binding_change_reason": "scope covers both backend + frontend"
  },
  "labels": ["feature", "expert-binding", "mis-dispatch", "north-star-metric"]
}
```

Source: `jira/tickets/EPIC-157/ticket.json`

## 4 Binding Fields (schema)

| Field | Who Sets | When | Required |
|-------|----------|------|----------|
| `suggested_expert` | Master (拆卡时) | ticket creation | Optional |
| `actual_expert` | Performer (claim时) | `/kallax-claim` | Required |
| `expert_binding_at` | Performer (claim时) | `/kallax-claim` | Auto (ISO8601) |
| `binding_change_reason` | Performer (claim时) | actual != suggested | Required (non-empty) |

## Before vs After

| Aspect | Before EPIC-157 | After EPIC-157 |
|--------|-----------------|----------------|
| Dispatch tracking | 0 | 4 fields in ticket.json |
| mis_dispatch_rate | "no data source" | `sprint-metrics.sh` reads ticket.json |
| Change reason | silent override | mandatory when actual != suggested |
| Phase review | manual | `phase-review` outputs binding_consistency_report |

## 5-Level Verify Output

```
L1: git log --oneline EPIC-157 → c8d0c00 feat(binding): EPIC-157 main → miao (final)
L2: npm run build → exit 0 (no TypeScript errors)
L3: vitest run → Test Files 5 passed / Tests 103 passed
L4: sprint-metrics.sh mis_dispatch_rate → reads ticket.json, outputs <10% PASS
L5: check-claim-evidence.sh → exit 0 (CHANGELOG [3.32.2] has raw_output refs)
```

Raw test output:
```
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage{,-d,-e}.test.ts \
  tests/dead-code-master-verify.test.ts \
  tests/schema/expert-binding.test.ts
→ Test Files 5 passed (5) / Tests 103 passed (103)
```

## 4-Branch Flow Trajectory

```
feature/v3.32.2-EPIC-157-P1 → testing → main → miao
P1 (schema+vitest): fbb5415
P2 (integration+docs): 64e0a59
P3 (claim+submit): 0ffd2ab
P4 (metrics+phase-review+CLAUDE): e0e585c
Final: c8d0c00
```

## Master Decision Record

**Date**: 2026-08-02
**Decision**: "Master 拆卡时给 suggested_expert, Performer claim 时 binding actual_expert + expert_binding_at. 偏离时 binding_change_reason 必填. sprint-metrics.sh mis_dispatch_rate <10% 阈值."

**Key lesson**: north-star metrics need data pipelines, not just definitions.

## Evidence Links

- Ticket: `jira/tickets/EPIC-157/ticket.json`
- Tracker: `scripts/binding/binding-tracker.sh`
- Metrics: `scripts/metrics/sprint-metrics.sh`
- Schema: `node/src/schema/ticket-schema.ts`
