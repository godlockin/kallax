# Projection Sink Design Principles

> **EPIC-175**: 借鉴 loopx `docs/concepts/interaction-pattern-catalog.md` 1:1
> **Version**: 1.0.0 | **Date**: 2026-08-05

---

## Overview

Projection sinks are the output destinations for projected state. This document defines the design principles for creating reliable, observable projection sinks.

---

## Three Design Principles

### 1. Stable Input Contract

**Principle**: Projection sinks must accept stable, well-defined input.

**Requirements**:
- Define input schema before implementation
- Version input contract explicitly
- Never break input contract (additive changes only)

**Pattern**:
```typescript
// Input schema (stable)
interface ProjectionInput {
  version: 1;           // Explicit version
  ticket_id: string;    // Stable identifier
  state: TicketState;   // Known state shape
  timestamp: number;    // Unix timestamp
}

// ❌ BAD: Untyped input
function project(data: any): void { }

// ✅ GOOD: Typed input
function project(input: ProjectionInput): void { }
```

**Anti-patterns**:
- `any` typed input
- Implicit optional fields
- Mixed version inputs

---

### 2. Lineage Preservation

**Principle**: Projection sinks must preserve the lineage of data.

**Requirements**:
- Include source reference in output
- Track transformation chain
- Maintain audit trail

**Pattern**:
```typescript
interface ProjectedOutput {
  // Lineage
  source_ticket_id: string;
  source_epic: string;
  projection_chain: string[];  // ["raw", "enriched", "projected"]

  // Payload
  data: unknown;
  metadata: {
    projected_at: number;
    projection_version: string;
  };
}
```

**Anti-patterns**:
- Output without source reference
- Lost transformation chain
- Missing timestamps

---

### 3. Public-Safe Output

**Principle**: Projection sink output must be safe for public consumption.

**Requirements**:
- Never leak credentials or secrets
- Redact private context
- Validate output before emission

**Pattern**:
```typescript
function sanitizeForPublic(output: ProjectedOutput): PublicOutput {
  return {
    // Public fields only
    ticket_id: output.source_ticket_id,
    status: output.data.status,
    updated_at: output.metadata.projected_at,

    // Explicit redaction
    _redacted: ["raw_data", "internal_notes"],
  };
}
```

**Anti-patterns**:
- Leaking `raw_logs`
- Leaking `sub-agent prompts`
- Leaking `credentials`

---

## Projection Sink Types

### 1. Event Ledger Sink

**Use**: Append-only audit trail

**Requirements**:
- Immutable entries
- Hash chain integrity
- Time-ordered

**Example**: `state/run-history.jsonl`

### 2. State Snapshot Sink

**Use**: Current state projection

**Requirements**:
- Atomic updates
- Consistent reads
- TTL/expiration

**Example**: `state/quota-db.json`

### 3. Metrics Sink

**Use**: Aggregated metrics

**Requirements**:
- Incremental updates
- Rollup support
- Queryable

**Example**: `scripts/dashboard/dashboard-metrics.sh`

### 4. Public-Facing Sink

**Use**: External API responses

**Requirements**:
- Sanitized output
- Schema validation
- Rate limiting

**Example**: `web/dashboard-metrics.html`

---

## Security Rules for Projection Sinks

**From `../public-private-boundary.md`**:

| Field Type | Private | Public-Safe |
|------------|---------|-------------|
| credentials | YES | NO |
| raw_logs | YES | NO |
| task_IDs | YES | NO |
| sub-agent prompts | YES | NO |
| ticket_id | NO | YES |
| status | NO | YES |
| timestamps | NO | YES |

---

## Integration with Automation Monitor

Projection sinks integrate with the automation monitor (EPIC-175) via:

1. **Heartbeat events**: Sinks emit `work` events on projection
2. **Monitoring**: `automation-monitor-todos.sh` tracks sink health
3. **Reporting**: `run-history.sh` ledger maintains projection lineage

---

## References

- [loopx interaction-pattern-catalog.md](https://github.com/godlockin/loopx/blob/main/docs/concepts/interaction-pattern-catalog.md)
- `../public-private-boundary.md`
- `./heartbeat-daemon-2026-08-05.md`
- `./epic-175-security-extended-2026-08-05.md`
