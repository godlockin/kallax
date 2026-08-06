# EPIC-170 Complete Plugin — Decision Record

**Date**: 2026-08-05
**EPIC**: EPIC-170
**Status**: Implemented
**Author**: Performer (Agent)

## Context

EPIC-162 completed the structural separation of 9 experts into individual files (default + extended tier). However, the implementation lacked complete plugin 化 — no enabled_policy configuration mechanism, no persistent policy storage, and no activation gates.

## Decision

Upgrade EPIC-162's 9-expert structure to complete plugin 化:

1. **enabled_policy mechanism**: Each expert skill package gets `enabled_policy` field in frontmatter
2. **skill-policy.sh**: New script for policy persistence to `state/skill-policy.json`
3. **5-step activation gates**: validate project context, todo, boundary, architecture, owner
4. **skill-manager.sh enhancement**: Add enable/disable/validate subcommands

## Alternatives Considered

### Option A: Keep EPIC-162 as-is (No Plugin 化)
- **Pros**: No additional complexity
- **Cons**: Experts are static, no runtime enable/disable
- **Verdict**: Rejected — doesn't meet loopx 6-skill pattern parity

### Option B: Full Skill Package (External Registry)
- **Pros**: Maximum flexibility
- **Cons**: Heavy weight, requires external storage
- **Verdict**: Overkill — KALLAX is internal framework

### Option C: Frontmatter + JSON Policy (Chosen)
- **Pros**: Simple, file-local, no external dependencies
- **Cons**: Requires script updates
- **Verdict**: Accepted — matches EPIC-162 pattern, minimal overhead

## Implementation

### enabled_policy Values

| Value | Behavior |
|-------|----------|
| `default` | Enabled at startup |
| `enabled` | Always enabled |
| `disabled` | Always disabled |
| `owner-gated` | Requires owner authorization |

### Policy Resolution

```
persisted_policy != "default" → use persisted
else → use frontmatter
else → use "default"
```

### 5 Activation Gates

| Gate | Check | Purpose |
|------|-------|---------|
| 1 | state.json exists | Valid project context |
| 2 | in_progress ticket | Active work |
| 3 | file in scope | Boundary compliance |
| 4 | INDEX.md exists | Expert index available |
| 5 | owner file exists | Authorization (if owner-gated) |

## Consequences

### Positive
- Experts can be enabled/disabled at runtime
- Policy persists across sessions
- Activation gates ensure context-aware invocation
- Parity with loopx 6-skill pattern

### Negative
- Additional complexity in skill-manager.sh
- Policy file must be initialized

## Rollback

If issues arise:
1. Remove `enabled_policy` from expert frontmatter (revert to default)
2. Delete `state/skill-policy.json`
3. Remove enable/disable/validate commands from skill-manager.sh

## References

- EPIC-162 (9 expert split foundation)
- EPIC-159 (path-scoped rules pattern)
- EPIC-069-D (check-claim-evidence transparency)
- loopx 6-skill pattern
