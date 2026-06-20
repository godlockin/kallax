# Recommender System

> Design document for the KALLAX task-to-performer matching engine.

---

## Overview

The Recommender System matches tasks to the most suitable performer based on capability similarity. It uses TF-IDF vectorization and cosine similarity to rank performers by how well their declared capabilities match the capabilities required by a task.

---

## Architecture

```
  Task (with capabilities)
        │
        ▼
  ┌─────────────────────┐
  │    Recommender       │
  │                      │
  │  1. Extract caps     │  Parse task metadata for capability requirements
  │  2. Vectorize        │  Build TF-IDF vectors for task + all performers
  │  3. Score & Rank     │  Cosine similarity → ranked list
  │  4. Return top-N     │  Return recommendations with scores
  └─────────────────────┘
        │
        ▼
  Recommendations [{performer, score, capabilities}]
```

---

## Algorithm

### 1. Capability Extraction

Task capabilities are read from `metadata.capabilities` (an array of strings set when the task is created).

Performer capabilities are read from the `instances` table.

### 2. TF-IDF Vectorization

The corpus consists of all capability strings from both the task and all performers.

```
TF(term, doc)  = count of term in doc / total terms in doc
IDF(term)      = log(total docs / docs containing term)
TF-IDF(term)   = TF * IDF
```

This gives higher weight to rare, discriminating capabilities and lower weight to common ones.

### 3. Cosine Similarity

```
similarity(task, performer) = dot(task_vec, perf_vec) / (|task_vec| * |perf_vec|)
```

Results range from 0.0 (no overlap) to 1.0 (exact match).

### 4. Ranking

Performers are sorted by descending similarity score. The top-N results are returned.

---

## Data Flow

```
Task Created
    │
    ▼
Extract capabilities from task metadata
    │
    ▼
Fetch all active performer instances from DB
    │
    ▼
Build TF-IDF vectors
    │
    ▼
Score each performer against task
    │
    ▼
Sort by score (descending)
    │
    ▼
Return top-N with {performerId, score, matchedCapabilities}
```

---

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `topN` | `10` | Maximum number of recommendations |

---

## CLI Usage

```bash
# Recommend for a specific task
kallax recommend match TASK-001 --top 5

# Output format (JSON)
{
  "taskId": "TASK-001",
  "requiredCapabilities": ["react", "typescript"],
  "recommendations": [
    { "performerId": "PERF-001", "score": 0.85, "matchedCapabilities": ["react", "typescript"] },
    { "performerId": "PERF-002", "score": 0.45, "matchedCapabilities": ["react"] }
  ],
  "totalCandidates": 5
}
```

---

## Limitations

- **Static capabilities**: Performer capabilities are declared at registration and not dynamically learned.
- **No historical data**: Past performance quality is not factored into recommendations.
- **No load balancing**: A performer with high score but already busy tasks will still rank high.

### Future Improvements

- Add execution history weighting (success rate, avg completion time).
- Incorporate real-time load (active task count per performer).
- Support capability synonyms and hierarchical capabilities.

---

## Related Files

- `node/src/commands/recommend-cmd.ts` — CLI command registration
- `node/src/core/recommender/matcher.ts` — TF-IDF matcher implementation
- `node/src/types/index.ts` — PerformerProfile type definition
- `docs/reference/cli-reference.md` — CLI command reference
