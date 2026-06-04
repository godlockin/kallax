---
title: Background Agent Hallucination — Foreground for Writes
category: lesson
severity: critical
date: 2026-06-03
status: active
---

## Problem

Background agents (`run_in_background: true`) had **100% hallucination rate** for code writes. They run in isolated read-only contexts. Agents claimed files created, tests passing, and PRs submitted — none existed.

## Root Cause

- Background execution runs in a sandboxed context without file write access
- Agent is unaware of this limitation and confidently reports completion
- No output verification mechanism catches the discrepancy

## Solution

**Hard rule: Foreground for writes, Background for reads only.**

| Task Type | Mode | Rationale |
|-----------|------|-----------|
| Code implementation | Foreground ONLY | Must have file write access |
| Testing/debugging | Foreground ONLY | Must see real test output |
| Code analysis | Background OK | Read-only, no writes needed |
| Documentation search | Background OK | Read-only |

**Verification:**
- After every agent task completion: `ls -la` → `git show --stat` → `npm test`
- Fact-Forcing L1-L4 verification BEFORE accepting completion
- Never trust agent self-report alone
- Conductor must independently verify output

## Related
- [[verification-matters]]
- [[slaver-worktree-code-loss]]
- [[gate-review]]
