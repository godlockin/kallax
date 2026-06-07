# Architecture Decision Records

> Decisions that shaped the KALLAX framework. See [docs/adr/](../docs/adr/) for full ADR index.

---

## EPIC-016: Token Optimization ADRs

> Layer A platform-level optimizations targeting 60-80% token reduction

### ADR-016-A: MCP Server Lazy Loading

**Status**: Proposed | **Date**: 2026-06-06

Implements four-tier lazy loading for MCP servers (github, playwright, context7, serena, etc.).
Default-off model with opt-in, project-config, and trigger-based auto-enable.

**Key savings**: ~800 tokens/turn (40% MCP overhead reduction)

[Read ADR-016-A](./ADR-016-A-mcp-lazy-loading.md)

---

### ADR-016-B: Skill Metadata On-Demand Discovery

**Status**: Proposed | **Date**: 2026-06-06

Changes skill loading from full content injection to description-metadata only.
Full content loaded on-demand via trigger keywords or explicit invocation.

**Key savings**: ~700 tokens/turn (30% skill overhead reduction)

[Read ADR-016-B](./ADR-016-B-skill-metadata-discovery.md)

---

## Framework ADRs

### ADR-001: Three-Tier Degradation (Redis -> SQLite -> Filesystem)

**Status**: Accepted | **Date**: 2026-01

Three-tier degradation model with periodic probing for resilience across Rust, Node.js, and shell environments.

[Read ADR-001](../docs/adr/ADR-001-degradation-strategy.md)

---

### ADR-002: Conductor-Performer over Master-Slaver

**Status**: Accepted | **Date**: 2026-01

Naming convention change replacing "Master/Slaver" with "Conductor/Performer" for cultural sensitivity and technical clarity.

[Read ADR-002](../docs/adr/ADR-001-degradation-strategy.md)

---

### ADR-003: Saga Compensation over Simple Rollback

**Status**: Accepted | **Date**: 2026-01

Saga pattern adoption where each forward step has a compensating action for reliable multi-step task completion.

[Read ADR-003](../docs/adr/ADR-001-degradation-strategy.md)

---

## Notes

- EPIC-016 ADRs target Layer A (platform-level) optimizations
- Layer B (agent-level) and Layer C (task-level) documented separately
- Combined target: 60-80% token reduction from 2.5M/600s baseline