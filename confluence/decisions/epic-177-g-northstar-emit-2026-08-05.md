# EPIC-177-G North Star Emit Integration

> **Date**: 2026-08-05
> **EPIC**: EPIC-177-G
> **Type**: Technical implementation
> **Status**: APPROVED (主公 Phase 6 G 拍板)

## Decision

Integrate `run-history.sh` emit hooks into 6 main scripts to close EPIC-023-C north star metrics loop.

## Context

9 expert review (480-line Master report) identified 1 HIGH blocker:
- `state/run-history.jsonl` had 0 production events, only 35 test lines
- 4 north star metrics (expert_activation / cross_epic_reuse / ab_hit_rate / mis_dispatch_binding_rate) couldn't be computed

## Solution

| Script | Emit Hook | Event Type | Frequency |
|--------|-----------|------------|-----------|
| binding-tracker.sh | cmd_actual | accounting | per binding |
| binding-tracker.sh | cmd_validate | accounting | per validation |
| binding-tracker.sh | cmd_validate_all | decision | batch complete |
| heartbeat-daemon.sh | main loop | work/decision | 60s |
| heartbeat-daemon.sh | main loop | accounting | 5s |
| heartbeat-daemon.sh | main loop | evidence | 10min |
| post-process.sh | final | work + decision | EPIC done |
| branch-4pr.sh | each PR | decision | 4 stages |
| install.sh | stamp_version | evidence | install complete |
| skill-manager.sh | enable/disable | work | skill change |

## JSON Pattern (EPIC-175-fix 1:1)

```bash
local payload
payload=$(jq -n \
  --argjson count 10 \
  --arg mode "install" \
  '{install_complete: true, count: $count, mode: $mode}')
"$RUN_HISTORY" emit evidence "install" "$payload"
```

## Constraints

- 0 改 source code (only scripts)
- 0 增 Rule
- 0 增 immutable script
- Use `jq -n` pattern (EPIC-175-fix)

## Verification

```bash
# Run integration tests
bash tests/integration/run-history-emit-integration.test.sh

# Verify run-history ledger
bash scripts/heartbeat/run-history.sh verify

# Check dashboard JSON
bash scripts/dashboard/dashboard-metrics.sh
cat web/dashboard-metrics.json
```

## Rollback

If issues detected:
1. Remove emit blocks from each script (they're idempotent)
2. No data corruption (append-only ledger)
3. Dashboard falls back to "N/A" values

## Related

- EPIC-023-C (north star metrics)
- EPIC-157 (binding tracker)
- EPIC-160 (install.sh)
- EPIC-162 (skill-manager.sh)
- EPIC-166 (heartbeat daemon)
- EPIC-175-fix (jq -n pattern)
