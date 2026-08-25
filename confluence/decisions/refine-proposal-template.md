# Monthly evidence refinement proposal

**Period:** `YYYY-MM`
**Status:** Draft for human review

> This proposal is advisory. Do not apply changes automatically. Review evidence provenance before editing `scripts/binding/lib/expert-pool.sh` or `expert-resolver.sh`.

## 1. 累计 evidence 总览

- Evidence files: `N`
- Expert observations: `N`
- Distinct observed experts: `N`
- Invalid files skipped: `N`

| Expert | Observations |
|---|---:|
| `expert-name` | `N` |

## 2. expert-pool 配置对比

- Configured experts: `N`
- Observed experts configured: `N`
- Observed names outside configuration: `N`

| Category | Experts |
|---|---|
| Configured but not observed | `expert-name` |
| Observed but not configured | `expert-name` |

## 3. gap > 阈值项

**Threshold:** observed expert count below `2`, or observed name absent from current pool.

- `expert-name`: explain gap and attach evidence references.

## 4. 建议 refinement (人审, 0 自动改)

1. Human reviewer validates evidence provenance and expert-name spelling.
2. Human reviewer decides whether recurring gaps warrant an expert-pool proposal.
3. Apply approved changes manually in a separate reviewed change.

### Review decision

- [ ] Accept proposal
- [ ] Reject proposal
- [ ] Request more evidence

**Reviewer:**
**Date:**
**Notes:**
