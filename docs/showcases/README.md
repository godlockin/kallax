# KALLAX Showcase Catalog

7 real-world cases demonstrating KALLAX capabilities.

---

## Case 1: Epic-Driven Development

**Problem**: Scattered EPIC delivery, no standard process

**Solution**: KALLAX EPIC 4-Piece (A+B review + README + lessons + signoff)

**Evidence**: `jira/tickets/EPIC-XXX/` directories

---

## Case 2: 5-Level Verify Pipeline

**Problem**: Fake "PASS" metrics, no real verification

**Solution**: L1 git → L2 stdout → L3 4-expert → L4 independent → L5 boundary

**Evidence**: `scripts/verify/level-{1..5}.sh`

---

## Case 3: Multi-Agent Collaboration

**Problem**: Single-agent bottleneck

**Solution**: Conductor + Performer + 4 sub-roles (coder/reviewer/tester/docs)

**Evidence**: `scripts/conductor/dispatch.sh --sub-role=...`

---

## Case 4: Hash-Chain Audit Trail

**Problem**: No immutable audit log

**Solution**: SHA256 hash chain for all changes

**Evidence**: `scripts/verify/hash-chain.sh`

---

## Case 5: Worktree Isolation

**Problem**: Development pollution of main branch

**Solution**: Isolated worktrees per feature

**Evidence**: `git worktree add -b feature/...`

---

## Case 6: Decision Matrix

**Problem**: Unclear decision authority

**Solution**: 5×4=25 cells, all verified

**Evidence**: `docs/process/q18-decision.md`

---

## Case 7: Skill Plugin System

**Problem**: Monolithic skill system

**Solution**: 9 expert skills as plugins

**Evidence**: `.claude/skills/kallax-experts/<role>/`

---

## Catalog JSON

```json
{
  "cases": [
    {"id": 1, "title": "Epic-Driven Development", "path": "../EPIC/"},
    {"id": 2, "title": "5-Level Verify Pipeline", "path": "../../scripts/verify/"},
    {"id": 3, "title": "Multi-Agent Collaboration", "path": "../../scripts/conductor/"},
    {"id": 4, "title": "Hash-Chain Audit Trail", "path": "../../scripts/verify/hash-chain.sh"},
    {"id": 5, "title": "Worktree Isolation", "path": ".worktrees/"},
    {"id": 6, "title": "Decision Matrix", "path": "../../docs/process/q18-decision.md"},
    {"id": 7, "title": "Skill Plugin System", "path": "../../.claude/skills/"}
  ]
}
```

---

## Contribute a Case

To add a new showcase case:

1. Create `docs/showcases/case-N-title.md`
2. Add entry to this catalog
3. Update `showcase-catalog.json`
4. Submit PR with `kallax verify all CASE-N`
