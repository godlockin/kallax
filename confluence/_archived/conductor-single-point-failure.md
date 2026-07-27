---
title: Conductor Single Point of Failure
category: pitfall
severity: critical
date: 2026-06-03
status: active
---

## Problem

When Conductor becomes a bottleneck:
- >3 parallel Performers → message queue backlog grows
- Conductor dies → all Performer work stops with no failover
- Single coordinator cannot scale beyond ~5 performers

## Solution: Load-Balancing + Supervisor

### L1: Dedicated Assistants
Delegate specific coordinator functions to specialized assistants:
- **PR Reviewer** — handles code review independently
- **Scrum Master** — manages task assignment and polling
- **Gate Reviewer** — runs 4-level gate checks

### L2: Supervisor Process
External watchdog monitoring Conductor heartbeats:
- Checks Conductor heartbeat every 30s
- If stale > 2 min: promote backup Conductor
- Logs all failover events for post-mortem

### L3: Direct Performer-to-Performer
For non-conflicting tasks, performers can negotiate directly:
- Check isolation scope before claiming
- Report completion to message queue (not blocking on Conductor)
- Conductor does periodic reconciliation (eventual consistency)

## Related
- [[master-failure-defense]]
- [[multi-agent-collab-failures]]
- [[dual-track-degradation]]
