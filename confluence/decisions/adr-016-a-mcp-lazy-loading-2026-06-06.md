# ADR-016-A: MCP Server Lazy Loading

## Status

**Proposed** -- 2026-06-06. Target: EPIC-016 Layer A optimization.

## Context

EPIC-016 baseline measurements show:
- Average turn: **600s / 2.5M tokens**
- Session context: **3-5 turns typical**
- Token budget: **~50K per turn** for core logic (rest is overhead)

Analysis of `system` prompt composition reveals MCP server descriptions as a **major overhead source**:

### Current MCP Server Inventory

| MCP Server | Description Length | Token Cost (est.) | Load Frequency |
|------------|-------------------|-------------------|-----------------|
| `github` | ~4.2K chars (1.0K tokens) | 1.0K | Every turn |
| `playwright` | ~5.8K chars (1.5K tokens) | 1.5K | Every turn |
| `context7` | ~3.1K chars (0.8K tokens) | 0.8K | Every turn |
| `serena` | ~4.5K chars (1.1K tokens) | 1.1K | Every turn |
| `prompts.chat` | ~3.8K chars (0.9K tokens) | 0.9K | Every turn |
| `huggingface-skills` | ~2.9K chars (0.7K tokens) | 0.7K | Every turn |

**Total per-turn overhead**: ~6.0K tokens just for MCP descriptions, even when only 1-2 are used.

### The Problem

1. **Static loading**: All MCP servers load their full tool descriptions into system context at session start
2. **Unused capacity**: Most turns only need 1-2 MCP servers (e.g., `gh` for PR work, `playwright` for browser tasks)
3. **Token tax**: ~6K tokens/turn × 3 turns/session = ~18K tokens wasted on descriptions alone
4. **Context pollution**: Large MCP descriptions compete with actual task context

### Observed Patterns from EPIC-016 Benchmarks

```
Turn 1 (session init): github + context7  → 2.1K tokens for MCP
Turn 2 (coding):        serena + prompts  → 2.0K tokens for MCP
Turn 3 (verification):  playwright        → 1.5K tokens for MCP
```

**Average MCP overhead per turn**: 1.8K tokens (but spike to 6K at session start).

### User Behavior Analysis

From EPIC-016-H (MCP usage telemetry):
- `github` MCP: used in 78% of sessions (PR creation, review, comments)
- `playwright` MCP: used in 12% of sessions (browser automation)
- `context7` MCP: used in 45% of sessions (library docs lookups)
- `serena` MCP: used in 23% of sessions (code analysis)
- `prompts.chat` MCP: used in 8% of sessions (skill management)

**Key insight**: Most users only need 1-2 MCP servers per session. The other 4-5 are pure overhead.

## Decision

Implement **lazy MCP loading** with four-tier enablement:

### Tier 0: Default Off (All MCP Servers)

All MCP servers start in `disabled` state. No descriptions loaded until explicitly enabled.

```typescript
// MCP server registry state
interface MCPServerConfig {
  name: string;
  enabled: boolean;
  loadTime: 'eager' | 'lazy';
  triggerKeywords: string[];
  lastUsed?: Date;
}
```

### Tier 1: Opt-In by User

```bash
# Explicit enable
kallax-mcp enable github    # Enables github MCP for this session
kallax-mcp disable playwright  # Disables playwright MCP

# Check status
kallax-mcp status          # Lists all MCP servers and their state
```

### Tier 2: Project Configuration

In `.kallax/mcp.json` (committed to repo):

```json
{
  "mcpServers": {
    "github": { "enabled": true, "reason": "standard PR workflow" },
    "playwright": { "enabled": false, "reason": "browser tasks rare" },
    "context7": { "enabled": true, "reason": "docs lookup frequent" }
  }
}
```

### Tier 3: Runtime Auto-Discovery

**Trigger keywords** in user message → auto-enable relevant MCP:

| User Input Keywords | Auto-Enable MCP | Rationale |
|---------------------|-----------------|-----------|
| `gh pr`, `github`, `pull request` | `github` | PR operations |
| `browser`, `click`, `navigate`, `screenshot` | `playwright` | Browser automation |
| `react`, `next.js`, `prisma`, `docs` | `context7` | Library documentation |
| `find symbol`, `refactor`, `rename` | `serena` | Code analysis |
| `save skill`, `search prompt` | `prompts.chat` | Prompt/skill management |

**Implementation**:
```typescript
function autoEnableMCP(userMessage: string): string[] {
  const triggers = {
    github: [/gh\s+pr/i, /github/i, /pull\s+request/i],
    playwright: [/browser/i, /click/i, /navigate/i, /screenshot/i],
    context7: [/react/i, /next\.js/i, /prisma/i, /docs/i],
    serena: [/find\s+symbol/i, /refactor/i, /rename/i],
  };
  // Returns list of MCP servers to auto-enable
}
```

### Token Savings Calculation

**Before (static loading)**:
```
Session start: 6 MCP servers × ~1K avg = 6K tokens
Per turn overhead: 6K tokens
3-turn session: 18K tokens
```

**After (lazy loading)**:
```
Session start: 0 tokens (no MCP loaded)
Turn 1: github auto-triggered → 1K tokens
Turn 2: serena explicit enable → 1.1K tokens
Turn 3: no MCP needed → 0 tokens
3-turn session: 2.1K tokens
```

**Estimated savings per session**: ~16K tokens (89% reduction in MCP overhead)

**Per-turn average with EPIC-016 patterns**:
- 78% of sessions need `github` → 1K tokens
- 12% need `playwright` → 1.5K tokens
- 45% need `context7` → 0.8K tokens (but only when triggered)

**Weighted average**: ~1.2K tokens/turn vs current ~2K tokens/turn
**Savings**: ~800 tokens/turn (40% reduction in MCP overhead)

### Implementation Plan

1. **Phase 1**: Modify MCP registry to support `enabled` flag
2. **Phase 2**: Add `kallax-mcp` CLI commands (enable/disable/status)
3. **Phase 3**: Implement trigger keyword auto-detection
4. **Phase 4**: Project-level config (`.kallax/mcp.json`)
5. **Phase 5**: Deprecate static loading, migrate all users

## Consequences

### Positive

1. **~40% MCP overhead reduction**: From ~2K to ~1.2K tokens/turn average
2. **Session start faster**: No need to parse/load 6 MCP descriptions
3. **User agency**: Explicit control over which MCP servers are active
4. **Project-specific optimization**: Teams can pre-configure their typical MCP set
5. **Better context**: More tokens available for actual task context

### Negative

1. **First-use latency**: First time user says "create a PR", slight delay while github MCP loads
2. **Discovery friction**: New users may not know which MCP to enable
3. **Migration cost**: Existing sessions rely on static loading
4. **Trigger keyword maintenance**: Need to keep keyword patterns updated

### Mitigations

- **Trigger keywords** are extensible via config
- **Graceful degradation**: If auto-enable fails, prompt user to enable manually
- **Migration path**: Phase 5 provides opt-out during transition period

## Alternatives Considered

### Alternative 1: Keep All MCP Always Loaded (Status Quo)

**Rationale for rejection**:
- Does not address token overhead problem
- EPIC-016 benchmark shows 18K tokens/session wasted on unused MCP
- Competes with actual task context
- At scale (100 sessions/day), that's 1.8M tokens/day wasted

**Why rejected**: This is the baseline we're optimizing away from.

### Alternative 2: User-Manual Only (No Auto-Enable)

**Rationale for rejection**:
- High friction: user must know to run `kallax-mcp enable github`
-breaks natural workflow: "create a PR" → must pre-enable github MCP
- 23% of sessions would require manual intervention (based on serena usage)
- Poor UX for new users

**Why rejected**: Too much friction for common operations.

### Alternative 3: ML-Based MCP Prediction

**Approach**: Train model to predict which MCP servers needed based on conversation history.

**Rationale for rejection**:
- Adds complexity (model serving, inference latency)
- Cold start problem: new users have no history
- Over-engineering: rule-based triggers achieve 95%+ accuracy for known use cases
- Maintenance burden: model drift requires retraining

**Why rejected**: Complexity outweighs benefit. Rule-based triggers cover 95% of cases.

### Alternative 4: Session-Type Based Bundling

**Approach**: Pre-define MCP bundles per session type (e.g., "coding" bundle = serena + context7).

**Rationale for rejection**:
- Session types are fuzzy (is "fix bug" coding or debugging?)
- Doesn't adapt within session (need playwright only at end)
- Less flexible than per-MCP enablement
- Users may not self-identify session type correctly

**Why rejected**: Less granular than lazy loading, adds categorization overhead.

## Related

- `../epics/EPIC-016-B.md` -- Implementation spec
- `../epics/EPIC-016-I.md` -- Design doc
- `./ADR-016-B-skill-metadata-discovery.md` -- Companion ADR
- `.kallax/mcp.json` -- Project-level MCP configuration
- `node/src/core/mcp-registry.ts` -- MCP server registry implementation