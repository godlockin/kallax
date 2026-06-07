---
name: kallax
description: KALLAX multi-agent orchestration — Conductor/Performer/Master roles, worktree isolation, heartbeat daemon, ticket-driven workflow.
triggerKeywords: [kallax, panel, expert, 初始化, skill, /kallax, 专家评审, 召唤, conductor, performer, master, worktree, ticket, architect, backend, frontend, ux, product]
filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/SKILL.md
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

## 3-Stage Preamble (EPIC-023-B)

KALLAX uses a 3-stage Preamble to reduce friction and route tasks efficiently.

### Stage 1: Keyword Detection (Automatic)

Keywords in user message → direct expert routing:

| Keyword | Expert | Review Group |
|---------|--------|-------------|
| architect,架构, 系统设计 | architect | A |
| backend, 后端, api, database | backend | B |
| frontend, 前端, ui, 界面 | frontend | B |
| ux, 用户体验, design | ux | A |
| product, 产品, pm | product | AB |
| security, 安全, auth | security | A |

**Decision tree:** keyword hit → show expert panel → user confirms → invoke expert

### Stage 2: Task Complexity Assessment

If no keyword hit, assess task complexity:

- **Simple** (1 file, < 2h): Performer directly claims ticket
- **Medium** (multi-file, 2-8h): Conductor reviews AC before dispatch
- **Complex** (cross-EPIC, > 8h): Master escalation + EPIC creation

### Stage 3: Review Intensity

Based on task type, determine review intensity:

| Task Type | Review Group | Intensity |
|-----------|--------------|-----------|
| Hotfix / urgent | A only | Fast track |
| Feature | A+B (2-Group) | Standard |
| Refactor | B only | Lower |
| Architecture | A only | Deep |

**Note:** KALLAX users are already team members, so EKET's "team config" question is skipped.

---

**Full content available on-demand.** Trigger this skill by mentioning any keyword above.