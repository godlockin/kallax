# KALLAX Showcase Catalog

> **EPIC-165**: Real governance traces with evidence. Each case includes ticket.json chain, 5-Level Verify output, 4-branch flow trajectory, and master decision record.

## Catalog

| # | Case | Pattern | Version | Key Evidence |
|---|------|---------|---------|--------------|
| 1 | [EPIC-069-D: check-claim-evidence](./cases/EPIC-069-D-check-claim-evidence.md) | fact-forcing | v3.8.1 | pre-commit hook + raw_output enforcement |
| 2 | [EPIC-152: Rule 34 bugfix independent repro](./cases/EPIC-152-rule-34-bugfix-repro.md) | canary chain | v3.31.0 | 7 performers corrected Master mis-diagnosis |
| 3 | [EPIC-155: 4-branch bypass retro](./cases/EPIC-155-4branch-bypass-retro.md) | retro remediation | v3.31.1 | 3 bypass commits + Phase 3 accept |
| 4 | [EPIC-157: expert binding 4-field](./cases/EPIC-157-expert-binding.md) | metric wiring | v3.32.2 | mis_dispatch_rate north-star打通 |
| 5 | [EPIC-158: sqlite skipIf CI debt](./cases/EPIC-158-sqlite-skipif.md) | debt cleanup | v3.32.3 | Forbidden Patterns regex fix + skipIf |
| 6 | [EPIC-160: install.sh Omnibus](./cases/EPIC-160-install-omnibus.md) | framework distribution | v3.32.5 | 95 files + --inventory + --update |
| 7 | [EPIC-161: retrospective-routine.sh](./cases/EPIC-161-retrospective-routine.md) | periodic review | v3.32.6 | 6-stage routine + 17/17 tests |

## Pattern Distribution

```
fact-forcing:       2 cases (EPIC-069-D, EPIC-152)
retro-remediation:  1 case  (EPIC-155)
metric-wiring:      1 case  (EPIC-157)
debt-cleanup:       1 case  (EPIC-158)
framework-distribution: 1 case (EPIC-160)
periodic-review:    1 case  (EPIC-161)
```

## Schema (JSON-driven)

Catalog metadata lives in `showcase-catalog.json` — each case links to:
- `ticket.json` chain (source of truth)
- `5-Level Verify` raw output (evidence)
- `4-branch flow` trajectory (branch/PR history)
- Master (主公) decision record

## Verify Catalog

```bash
bash tests/integration/showcase-catalog.test.sh
# → EPIC-165 Showcase Catalog Tests: N passed, 0 failed
```
