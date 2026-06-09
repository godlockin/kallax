# ADR-016-B: Skill Metadata On-Demand Discovery

## Status

**Proposed** -- 2026-06-06. Target: EPIC-016 Layer A optimization.

## Context

EPIC-016 baseline measurements identified skill metadata as a **significant token overhead**:

### Current Skill Loading Model

Currently, all skills inject their **full content** into the system prompt at session start:

```
Session init:
├── ~/.claude/skills/kallax/SKILL.md (3.6K chars → ~900 tokens)
├── ~/.claude/skills/kallax/SKILL-DETAIL.md (est. 8K chars → ~2K tokens)
├── ~/.claude/skills/kallax/META-GUIDELINES.md (est. 4K chars → ~1K tokens)
└── Other skill files...
```

### Measured Skill Metadata Sizes

| Skill File | Size (chars) | Est. Tokens | Load Frequency |
|------------|-------------|-------------|-----------------|
| `SKILL.md` | 3,641 | ~900 | Every session |
| `SKILL-DETAIL.md` | ~8,000 | ~2,000 | Every session |
| `META-GUIDELINES.md` | ~4,000 | ~1,000 | Every session |
| **Total per skill** | ~15,600 | ~3,900 | Every session |

### The Problem

1. **Over-injection**: Full skill content loaded even when skill not needed
2. **Token tax**: ~4K tokens per skill × 2-3 skills = 8-12K tokens/session
3. **Context pollution**: Skill documentation competes with actual task context
4. **Cold start penalty**: Large system prompts slow down session initialization

### User Behavior Analysis

From EPIC-016 telemetry on skill usage:

| Skill | Usage Frequency | Typical Turn |
|-------|----------------|--------------|
| `kallax` | 95% of sessions | Session init |
| `code-review` | 23% of sessions | After first commit |
| `triage-issue` | 12% of sessions | Inbox processing |
| `git-guardrails` | 8% of sessions | Before git operations |

**Key insight**: Only `kallax` skill is used every turn. Other skills are situational.

### Token Budget Analysis

For a typical EPIC-016 session (600s / 2.5M tokens budget):

```
Total token budget: 2,500,000 tokens
Session overhead: ~400,000 tokens (CLAUDE.md, rules, etc.)
MCP overhead: ~6,000 tokens (before ADR-016-A optimization)
Skill overhead: ~12,000 tokens (before this ADR)
Available for task: ~2,082,000 tokens (83% utilization)
```

**Target**: Increase task utilization from 83% to 87% by reducing skill overhead.

## Decision

Implement **skill metadata on-demand discovery**:

### Core Principle

**Inject only description metadata into system prompt. Full content loaded on demand.**

### Metadata Schema

```typescript
interface SkillMetadata {
  name: string;           // e.g., "kallax"
  description: string;    // ~100-200 chars summary
  triggerKeywords: string[];  // Words that suggest skill relevance
  filePath: string;       // Absolute path to full SKILL.md
  lastAccessed?: Date;
}

interface SystemPromptSection {
  skills: SkillMetadata[];  // Lightweight metadata only
  // NOT full SKILL.md content
}
```

### Description Field Specification

For `kallax` skill, the description would be:

```markdown
## KALLAX Skills Command Index

| 命令 | 描述 | 触发场景 |
|------|------|----------|
| `/kallax-panel` | 启动专家评审面板 | 新 EPIC、架构决策 |
| `/kallax-expert <role>` | 召唤单个专家 | 特定领域深度分析 |
| `/kallax-skill <name>` | 执行特定技能 | 需要特定技术能力 |

Trigger: "kallax", "专家", "panel", "skill"
Path: ~/.claude/skills/kallax/SKILL.md
```

**Description size**: ~500 tokens (vs 3,900 for full content)

### On-Demand Loading Mechanism

```typescript
// When user mentions "kallax-init" or similar trigger
async function loadSkillFullContent(skillName: string): Promise<string> {
  const metadata = getSkillMetadata(skillName);
  const fullContent = await readFile(metadata.filePath);
  return fullContent;
}

// Triggered by:
// 1. Explicit skill invocation: /kallax-skill <name>
// 2. Keyword match in user message
// 3. Conductor explicit request
```

### Trigger Keywords for KALLAX Skill

```typescript
const KALLAX_TRIGGERS = [
  'kallax',
  'panel',
  'expert',
  '初始化',
  'skill',
  '/kallax',
  '专家评审',
  '召唤',
];
```

When user says "how do I use kallax-init?" or "start a panel", the agent:
1. Detects `kallax` keyword
2. Reads `~/.claude/skills/kallax/SKILL.md` (full content)
3. Answers the question using loaded content

### Token Savings Calculation

**Before (full content injection)**:
```
kallax SKILL.md: 900 tokens (every turn)
kallax SKILL-DETAIL.md: 2,000 tokens (every turn)
kallax META-GUIDELINES.md: 1,000 tokens (every turn)
Other skills (avg 2): 2 × 1,500 = 3,000 tokens
-----------------------------------------
Total per session: ~6,900 tokens
```

**After (metadata only)**:
```
kallax metadata: 500 tokens (description only)
Other skills metadata: 2 × 200 = 400 tokens
-----------------------------------------
Total per session: ~900 tokens
```

**On-demand loading** (when triggered):
```
First trigger: +900 tokens (full SKILL.md read)
Subsequent turns: 0 tokens (cached in context)
```

**Per-session savings**: ~6,000 tokens (87% reduction)

**Per-turn average** (accounting for triggers):
- 95% of sessions trigger kallax → 500 + 900 = 1,400 tokens
- 23% trigger code-review → +200 = 1,600 tokens
- 12% trigger triage-issue → +200 = 1,800 tokens
- **Weighted average**: ~1,600 tokens/turn vs current ~2,300 tokens/turn

**Savings**: ~700 tokens/turn (30% reduction in skill overhead)

### Combined with ADR-016-A (MCP Lazy Loading)

| Overhead Type | Before | After | Savings |
|--------------|--------|-------|---------|
| MCP servers | 2,000/turn | 1,200/turn | 800/turn |
| Skill metadata | 2,300/turn | 1,600/turn | 700/turn |
| **Combined** | **4,300/turn** | **2,800/turn** | **1,500/turn** |

**EPIC-016 target**: 60-80% total token reduction
- Layer A (MCP + Skill): ~35% of target
- Layer B/C (additional optimizations): remainder

## Consequences

### Positive

1. **~30% skill overhead reduction**: From ~2.3K to ~1.6K tokens/turn
2. **Faster session init**: No need to parse/validate full skill content
3. **Better context utilization**: More tokens available for actual task
4. **Extensible**: New skills auto-get metadata injection (no code change)
5. **Backward compatible**: Existing skill invocations continue to work

### Negative

1. **First-access latency**: First time skill triggered, file read adds ~50ms
2. **Discovery gap**: Agent may not know skill exists without description
3. **Cache management**: Need to manage skill content in rolling context
4. **Risk of "where is the skill"**: User asks about skill agent hasn't loaded

### Mitigations

- **Trigger keywords** ensure relevant skills load before user asks
- **Description includes path**: Agent can always find skill if needed
- **Graceful fallback**: If read fails, use cached metadata
- **Conductor guidance**: Can explicitly request skill load in complex tasks

## Alternatives Considered

### Alternative 1: Keep Full Content (Status Quo)

**Rationale for rejection**:
- EPIC-016 benchmark shows 83% context utilization
- Skill overhead (~7K tokens) competes with task content
- At 100 sessions/day, that's 700K tokens/day on skill content alone
- Does not scale: adding new skills increases overhead linearly

**Why rejected**: This is the baseline we're optimizing away from.

### Alternative 2: Skill Content Compression

**Approach**: Compress skill content, decompress on load.

**Rationale for rejection**:
- Compression still requires full content in system prompt
- Decompression adds CPU overhead
- 87% savings with on-demand is better than compression (~30%)
- Complexity not justified for text content

**Why rejected**: On-demand achieves better savings with less complexity.

### Alternative 3: Skill Bundling by Task Type

**Approach**: Pre-define skill bundles (e.g., "coding" bundle = tdd + refactoring).

**Rationale for rejection**:
- Task type classification is fuzzy
- Bundles lock content together (can't use 1 skill without others)
- Less flexible than per-skill on-demand
- Doesn't solve the "which skill do I need" problem

**Why rejected**: Less granular, same problem of skill discovery.

### Alternative 4: ML-Based Skill Prediction

**Approach**: Predict which skills needed based on conversation context.

**Rationale for rejection**:
- Adds model serving complexity
- Cold start problem for new users
- Rule-based triggers cover 95% of cases
- Over-engineering for skill selection

**Why rejected**: Complexity outweighs benefit.

### Alternative 5: Lazy Load All Skills (No Metadata)

**Approach**: Don't even inject description, load on first use.

**Rationale for rejection**:
- Agent has no way to know skill exists
- User asks "how do I use /kallax-panel" → agent says "I don't know that command"
- No trigger keywords = no auto-discovery
- Too aggressive, breaks natural language interaction

**Why rejected**: Too much friction, breaks UX.

## Implementation Plan

### Phase 1: Metadata Extraction

1. Create `SkillMetadata` schema
2. Write script to extract description from existing SKILL.md files
3. Generate `.claude/skills/<name>/metadata.json` for each skill

### Phase 2: System Prompt Modification

1. Modify session init to inject only metadata array
2. Remove full SKILL.md content from system prompt
3. Add trigger keyword matching

### Phase 3: On-Demand Loading

1. Implement `loadSkillFullContent(skillName)` function
2. Add trigger detection in message processing
3. Implement caching strategy (LRU with 5-skill max)

### Phase 4: Migration

1. Update all skill metadata files
2. Deprecate full-content injection
3. Monitor for discovery failures

## Related

- [EPIC-016-I: On-Demand Discovery Mechanism](../epics/EPIC-016-I.md) -- Design doc
- [ADR-016-A: MCP Server Lazy Loading](./ADR-016-A-mcp-lazy-loading.md) -- Companion ADR
- [EPIC-016-F: Skill Metadata Schema](../epics/EPIC-016-F.md) -- Implementation spec
- `~/.claude/skills/kallax/metadata.json` -- Example metadata
- `node/src/core/skill-loader.ts` -- Skill loading implementation