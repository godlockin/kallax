# DAG Scheduler

> Design document for the KALLAX Directed Acyclic Graph task scheduler.

---

## Overview

The DAG Scheduler orchestrates tasks that have interdependencies. It computes execution order via topological sort (Kahn's algorithm), prioritizes tasks using a Binary Heap, and identifies the critical path for timing estimates.

---

## Architecture

```
  ┌──────────────────────────────────────────────────────┐
  │                   DAG Scheduler                       │
  │                                                        │
  │  ┌──────────────┐   ┌──────────────┐   ┌───────────┐ │
  │  │  KahnSorter  │   │  PriorityQ   │   │  CritPath  │ │
  │  │  (topo sort) │   │  (bin heap)  │   │  analyzer  │ │
  │  └──────┬───────┘   └──────┬───────┘   └─────┬─────┘ │
  │         │                  │                  │        │
  │         ▼                  ▼                  ▼        │
  │  ┌──────────────────────────────────────────────┐     │
  │  │            Execution Engine                    │     │
  │  │  WorkerPool ───▶ TaskRunner ───▶ ResultSink   │     │
  │  └──────────────────────────────────────────────┘     │
  └──────────────────────────────────────────────────────┘
```

---

## Algorithms

### Kahn's Algorithm (Topological Sort)

```
in_degree = {node: count of unresolved predecessors}
queue = nodes with in_degree == 0
result = []

while queue not empty:
  node = queue.dequeue()
  result.append(node)
  for each successor of node:
    in_degree[successor]--
    if in_degree[successor] == 0:
      queue.enqueue(successor)
```

### Binary Heap Priority

Each node gets a priority score. Higher priority tasks execute first among ready (zero in-degree) tasks.

```
priority(node) = α * urgency + β * business_value - γ * estimated_duration
```

### Critical Path Analysis

The critical path is the longest path through the DAG (by duration). It determines the minimum total execution time.

```
dist[node] = max over predecessors of (dist[pred] + duration[pred])
critical_path = nodes where dist[node] + duration[node] == max_dist
```

---

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `max_concurrency` | `4` | Max parallel task runners |
| `priority.alpha` | `0.3` | Urgency weight |
| `priority.beta` | `0.5` | Business value weight |
| `priority.gamma` | `0.2` | Duration penalty weight |

---

## CLI Usage

```bash
kallax dag new          # Create a new DAG
kallax dag add          # Add a task node
kallax dag edge         # Add a dependency edge
kallax dag schedule     # Compute and show execution plan
kallax dag run          # Execute the DAG
kallax dag status       # Show DAG execution status
```

---

## Related Files

- `scripts/dag-run.sh` — DAG execution runner
- `node/src/core/dag/` — DAG implementation
- `node/src/core/dag/topological-sort.ts` — Kahn's algorithm
- `node/src/core/dag/priority-queue.ts` — Binary heap
- `node/src/core/dag/critical-path.ts` — Critical path
