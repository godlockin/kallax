# Dashboard Metrics — EPIC-168-BG

**Created**: 2026-08-05
**Phase**: 5G (北极星 dashboard 闭环 EPIC-023-C)

## Overview

`scripts/dashboard/dashboard-metrics.sh` aggregates event data from `state/run-history.jsonl` and computes 4 North Star metrics for the KALLAX dashboard.

## Usage

```bash
# JSON output (default)
scripts/dashboard/dashboard-metrics.sh

# Text output
scripts/dashboard/dashboard-metrics.sh --format=text

# Daemon status only
scripts/dashboard/dashboard-metrics.sh --daemon-status
```

## 4 North Star Metrics

| Metric | Definition | Formula |
|--------|------------|---------|
| `expert_activation` | % of work events with explicit expert binding | `expert_annotated / work_events * 100` |
| `cross_epic_reuse` | % of evidence events referencing multiple tickets | `unique_tickets / evidence_events * 100` |
| `ab_hit_rate` | % of decisions with evidence reference | `decisions_with_evidence / decision_events * 100` |
| `mis_dispatch_binding_rate` | % of work events without proper ticket binding | `unbound_work / work_events * 100` |

## Event Types

| Type | Description | Source |
|------|-------------|--------|
| `work` | Agent started work on ticket | heartbeat-daemon emit |
| `decision` | Human/agent made decision | Performer emit |
| `accounting` | Quota spend / heartbeat tick | Daemon auto-emit (60s) |
| `evidence` | Raw output / verification result | Performer emit |

## JSON Schema

```json
{
  "generated_at": "2026-08-05T00:00:00Z",
  "daemon_status": "running|down",
  "paused": true|false,
  "north_stars": {
    "expert_activation": 75.5,
    "cross_epic_reuse": 25.0,
    "ab_hit_rate": 50.0,
    "mis_dispatch_binding_rate": 10.0
  },
  "events": {
    "total": 150,
    "work": 50,
    "decision": 30,
    "accounting": 60,
    "evidence": 10
  }
}
```

## Daemon Status

- `running`: Daemon PID exists and process alive
- `down`: No PID file or process dead
- `paused`: Global quota pause active

## Files

- `scripts/dashboard/dashboard-metrics.sh` — Aggregator script
- `web/dashboard-metrics.html` — Static HTML dashboard (vanilla JS)
- `state/run-history.jsonl` — Event ledger (append-only)
- `state/heartbeat-daemon.pid` — Daemon PID file
