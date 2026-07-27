---
title: Context Window Explosion
category: pitfall
severity: critical
date: 2026-06-03
status: active
---

## Context

LLM-based agents accumulate context over long conversations, eventually exceeding token limits or degrading response quality.

## Problem

- Context grows unboundedly → API costs skyrocket
- Response quality degrades as irrelevant context dilutes attention
- Token limit errors cause mid-task failures
- Lost work when context must be truncated

## Solution

**Context Budget Management:**

1. **Track token usage** — Use context-mon to estimate tokens
2. **Compress at thresholds** — Summarize old context at 75% capacity
3. **Preserve recent** — Keep last 50 messages intact
4. **Persist state** — Save state to SQLite for resumption
5. **Session snapshots** — Create periodic checkpoints

```
Token Budget: 100,000
├── System Prompt:  ~5,000 (fixed)
├── Recent Context: ~30,000 (last 50 messages)
├── Summarized:     ~40,000 (compressed older messages)
└── Headroom:       ~25,000 (for responses)
```

## Related
- [[session-resume]] — Resume from context checkpoint
- [[context-compressor]] — Context compression algorithm
