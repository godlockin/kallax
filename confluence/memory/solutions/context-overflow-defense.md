---
title: Context Overflow Defense
category: solution
severity: critical
source: KALLAX context-overflow-defense
date: 2026-06-03
status: active
---

## Problem

Claude Code sessions hit 400 "prompt token exceeds limit" when context grows unboundedly. Three sources: global CLAUDE.md, project CLAUDE.md, SKILL.md loaded at SessionStart.

## Solution: Three-Layer Defense

### A. Session Lifecycle Management
- **1 task = 1 session** — clean start each time, short lifespan
- **Periodic context reset** — /compact every 5 tool calls
- **Session save/resume** — `/kallax-save` and `/kallax-resume` for long sessions

### B. Explicit Context Budgeting
- **Smart file reading**: small files → direct read, medium → summarize, large → first 500 lines + structure overview
- **Tool output filtering**: grep capped at 100 lines, glob at 200 files
- **Token estimation**: track BOTH input and output tokens, not just output
- **Language-aware**: Chinese ~1.5 chars/token, English ~3.5 chars/token

### C. Emergency Auto-Recovery
- On 400 error: auto-compact and retry
- 3 task-level / 5 system-level 400 errors → alert
- Save session snapshot before compact for potential recovery

## Implementation Priority
1. Emergency fix (1 day): detect 400, compact, retry
2. Architecture (3 days): session lifecycle + context budgeting
3. Monitoring (2 days): alert system + pro-active reporting

## Related
- [[context-tracker-not-triggered]]
- [[context-defense-guide]]
- [[session-start-optimization]]
