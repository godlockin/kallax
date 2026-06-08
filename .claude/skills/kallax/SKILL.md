---
name: kallax
description: KALLAX multi-agent orchestration — Conductor/Performer/Master roles, worktree isolation, heartbeat daemon, ticket-driven workflow.
triggerKeywords: [kallax, panel, expert, 初始化, skill, /kallax, 专家评审, 召唤, conductor, performer, master, worktree, ticket]
filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/worktrees/performer-EPIC-016-S/.claude/skills/kallax/SKILL.md
---

# KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor

> **Lightweight metadata only.** Full content loaded on-demand via trigger keywords.

## Quick Reference

| Command | Description | Trigger |
|---------|-------------|---------|
| `/kallax-start` | Start role selection | role init |
| `KALLAX_ROLE=performer` | Become Performer | performer mode |
| `KALLAX_ROLE=conductor` | Become Conductor | conductor mode |
| `KALLAX_ROLE=master` | Become Master | master mode |

## Role Responsibilities

| Role | Responsibilities |
|---|---|
| **Master** | EPIC creation, master takeover, handoff |
| **Conductor** | Team state, task dispatch, PR review, merge to testing/miao |
| **Performer** | Claim ticket → create worktree → implement → submit PR |

## Key Files

- `.kallax/hooks/session_start.sh` — session init hook
- `scripts/heartbeat-daemon.sh` — daemon process
- `scripts/check-stale.sh` — stale/zombie detector
- `scripts/lib/daemon.sh` — `run_daemon()` stdio-isolated launcher

## Heartbeat Daemon

- Started via `run_daemon()` from `scripts/lib/daemon.sh`
- Only when `EXISTING_INSTANCES_COUNT > 0` (not first boot)
- On-demand: only when master is STALE/CLOSING
- Full stdio isolation: `< /dev/null >/dev/null 2>&1 &` + `setsid` + `disown`
- On exit (INT/TERM/EXIT): daemon killed + state marked CLOSING + diagnostic JSONL logged

## ZOMBIE Defense

If daemon process is dead but state.json still shows ACTIVE, check-stale.sh marks it ZOMBIE.

---

**Full content available on-demand.** Trigger this skill by mentioning any keyword above.