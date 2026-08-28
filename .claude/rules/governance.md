---
paths:
  - CLAUDE.md
  - jira/tickets/**
  - scripts/metrics/**
  - confluence/decisions/EPIC-277-*.md
---

# Governance detail: Rule 34/35/36

## Rule 34 — independent bugfix reproduction

Bugfix tickets must carry `verification.reproduction_command`, `verification.reproduction_exit_code`, and `verification.reproduction_raw_output` (first 30 lines is sufficient). A CI symptom or hypothesis alone is not diagnosis.

Performer must run reproduction command before changing source. Matching diagnosis permits repair; mismatch means STOP, mark `blocked`, and report diagnosis mismatch. Zero source change is valid when verification debt already cascaded, issue is false positive, or defect is absent. Record trace, do not convert a blocked reproduction into PASS.

## Rule 35 — sprint time box

- Maximum 5 EPICs per Sprint; maximum 10 commits per EPIC; maximum 500 lines per commit.
- Touching 4+ modules or 5+ files requires splitting EPIC. Docs-only batch with one substantive docs scope is explicit exception.
- Every EPIC traverses feature → testing → main → miao; no silent stage skip.
- Unfinished EPIC closes in current Sprint as done, blocked, or archived; no cross-Sprint accumulation.

Reuse: `.claude/rules/branch-flow.md` owns branch mechanics; `.claude/rules/rule-37.md` owns small-effort approval boundary.

## Rule 36 — Sprint close metrics

Run `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` at Sprint close. Four metrics are required:

1. `expert_activation_rate >= 5` distinct experts per EPIC.
2. `cross_epic_reuse_rate >= 40%` using `file_scope.includes` (EPIC-277-H changed 60% to 40%).
3. `cross_epic_docs_reuse_rate >= 40%` for docs paths.
4. `ab_hit_rate < 15%` (A+B recommendation agreement target >= 85%) and `mis_dispatch_rate < 10%`.

`ticket.json.multi_spec_intentional: true` exempts intentional multi-specialization scope from mis-dispatch. `NO_DATA` (exit 2) asks for intervention, not silent PASS. Docs-only uses `--docs-only` (exit 3 `DOCS_ONLY_SKIP`). Archived EPICs at or before `jira/tickets/.archive-baseline.json:archived_before` return `ARCHIVED_SKIP`; new tickets still require schema fields.

Source lineage: EPIC-023-C north-star metrics, EPIC-157 binding fields, EPIC-194 Sprint close, EPIC-204 docs-only adaptation, EPIC-277-H threshold/exception decision.
