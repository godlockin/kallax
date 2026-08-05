# run-history emit integration (EPIC-177-G)

> **Date**: 2026-08-05
> **EPIC**: EPIC-177-G
> **Author**: Performer (EPIC-177-G)
> **Status**: DONE

## Overview

EPIC-177-G integrates `run-history.sh` emit hooks into 6 main scripts to close the EPIC-023-C north star metrics loop.

**Problem**: `state/run-history.jsonl` had 0 production events, only 35 test lines. The 4 north star metrics (expert_activation / cross_epic_reuse / ab_hit_rate / mis_dispatch_binding_rate) couldn't be computed.

**Solution**: Integrate emit hooks into 6 main scripts following EPIC-175-fix `jq -n` pattern.

## 6 Scripts with Emit Hooks

### 1. `scripts/binding/binding-tracker.sh`

| Function | Event Type | Trigger |
|----------|------------|---------|
| `cmd_actual` | `accounting` | After actual expert binding |
| `cmd_validate` | `accounting` | After validation (valid/invalid) |
| `cmd_validate_all` | `decision` | After batch validation complete |

```bash
# Example payload for cmd_actual
{
  "suggested_expert": "backend",
  "actual_expert": "backend",
  "action": "actual_binding"
}
```

### 2. `scripts/heartbeat/heartbeat-daemon.sh`

| Event Type | Frequency | Payload |
|------------|-----------|---------|
| `accounting` | Every 5s (every tick) | `{}` |
| `work` | Every 60s (1x per interval) | `{heartbeat_tick, type}` |
| `decision` | Every 60s (1x per interval) | `{quota_check, type}` |
| `evidence` | Every 600s (1x per 10min) | `{status_snapshot, type}` |

### 3. `scripts/post-process.sh`

| Event Type | Trigger |
|------------|---------|
| `work` | After 11-step post-process complete |
| `decision` | After post-process (all_passed flag) |

### 4. `scripts/branch-4pr.sh`

| Event Type | Trigger |
|------------|---------|
| `decision` | PR 1 (feature→testing) |
| `decision` | PR 2 (testing→main) |
| `decision` | PR 3 (main→miao) |
| `decision` | All 4-PR complete |

### 5. `scripts/install.sh`

| Event Type | Trigger |
|------------|---------|
| `evidence` | After install/upgrade complete |

```bash
# Payload
{
  "install_complete": true,
  "version": "2.3.0-symlink-default-10tool",
  "mode": "install|upgrade",
  "method": "symlink|copy",
  "tool_count": 10
}
```

### 6. `scripts/skill/skill-manager.sh`

| Function | Event Type | Trigger |
|----------|------------|---------|
| `cmd_enable` | `work` | After expert skill enabled |
| `cmd_disable` | `work` | After expert skill disabled |

## Dashboard Integration

### `scripts/dashboard/dashboard-metrics.sh`

Pre-generates `web/dashboard-metrics.json` with:
- 4 north star metrics
- 4 event counts (work/decision/accounting/evidence)
- Daemon status + pause flag
- Timestamp

### `web/dashboard-metrics.html`

Fetches pre-generated JSON instead of running script:
```javascript
const METRICS_JSON = '../web/dashboard-metrics.json';
```

## 4 North Star Metrics

| Metric | Target | Source | Implementation |
|--------|--------|--------|----------------|
| `expert_activation` | ≥5 distinct experts | run-history.jsonl work events | Count distinct agent_id |
| `cross_epic_reuse` | ≥60% | ticket.json file_scope | File overlap % |
| `ab_hit_rate` | <15% mismatch | ticket.json review field | A/B vs final mismatch |
| `mis_dispatch_binding_rate` | <10% | ticket.json expert_binding | actual vs suggested mismatch |

## JSON Pattern (EPIC-175-fix 1:1)

All emit hooks use `jq -n` for JSON payload construction:

```bash
# Correct pattern (EPIC-175-fix)
local payload
payload=$(jq -n \
  --argjson count 10 \
  --arg mode "install" \
  '{install_complete: true, count: $count, mode: $mode}')
"$RUN_HISTORY" emit evidence "install" "$payload"

# Avoid: direct string concatenation (broken in strict mode)
```

## Test Coverage

`tests/integration/run-history-emit-integration.test.sh` includes 12 test cases:

1. binding-tracker.sh cmd_actual emit accounting
2. binding-tracker.sh cmd_validate emit accounting
3. binding-tracker.sh cmd_validate-all emit decision
4. post-process.sh emit work + decision
5. branch-4pr.sh emit decision (dry-run)
6. install.sh emit evidence
7. skill-manager.sh enable emit work
8. dashboard-metrics.sh pre-generate JSON
9. run-history.jsonl append-only
10. 4 north star metrics computed
11. event counts in dashboard JSON
12. run-history.sh verify passes

## Related EPICs

| EPIC | Description | Relationship |
|------|-------------|--------------|
| EPIC-023-C | 4 north star metrics | Data source |
| EPIC-157 | Binding tracker | emit accounting event |
| EPIC-160 | install.sh | emit evidence event |
| EPIC-162 | skill-manager.sh | emit work event |
| EPIC-166 | heartbeat daemon | emit work/decision/accounting/evidence |
| EPIC-175-fix | jq -n JSON injection fix | JSON pattern 1:1 |
| EPIC-177 | North star real run | Parent EPIC |

## File Scope

```
Modified:
- scripts/binding/binding-tracker.sh
- scripts/heartbeat/heartbeat-daemon.sh
- scripts/post-process.sh
- scripts/branch-4pr.sh
- scripts/install.sh
- scripts/skill/skill-manager.sh
- scripts/dashboard/dashboard-metrics.sh
- web/dashboard-metrics.html

New:
- tests/integration/run-history-emit-integration.test.sh
- docs/reference/run-history-emit-integration-2026-08-05.md
- confluence/decisions/epic-177-g-northstar-emit-2026-08-05.md
```
