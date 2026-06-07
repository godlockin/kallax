---
name: kallax
description: KALLAX multi-agent orchestration — Conductor/Performer/Master roles, worktree isolation, heartbeat daemon, ticket-driven workflow.
---

# KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor

## Role Detection

On session_start.sh, role is detected in priority order:
1. `KALLAX_ROLE` env var
2. `--role <role>` CLI arg
3. `.kallax/state/instance_config.yml` `role:` field
4. Git branch fallback: `feature/*` → performer, else → conductor

## Role Responsibilities

| Role | Responsibilities |
|---|---|
| **Master** | EPIC creation, master takeover, handoff |
| **Conductor** | Team state, task dispatch, PR review, merge to testing/miao |
| **Performer** | Claim ticket → create worktree → implement → submit PR |

## Performer Onboarding Protocol

When initializing as Performer (`/kallax` → Performer or `KALLAX_ROLE=performer bash session_start.sh`), the Performer receives full context before first response via a 4-step state-check:

### Step 1/4: Project State Scan

```bash
# Master status
MASTER_STATE=".kallax/instances/master_main/state.json"
[ -f "$MASTER_STATE" ] && jq -r '.status' "$MASTER_STATE"

# Active EPICs
find jira/epics -maxdepth 1 -mindepth 1 -type d | while read d; do
  [ -f "$d/epic.json" ] && jq -r '.id' "$d/epic.json"
done

# Ready tickets (unassigned, sorted by priority)
find jira/tickets -maxdepth 2 -name ticket.json | xargs jq -r \
  'select(.status == "ready" and (.assignee == null or .assignee == "")) | "\(.id)\t\(.priority)\t\(.title)"'
```

**Output:** Master status, active EPICs list, ready tickets with priority.

### Step 2/4: Session State Scan

```bash
BRANCH=$(git branch --show-current)
IN_WORKTREE=$(git rev-parse --git-dir 2>/dev/null | grep -q worktrees && echo yes || echo no)
# Current in-progress task for any performer
jq -r '.current_task.ticket_id // empty' .kallax/instances/*/state.json | grep -v '^$' | head -1
```

**Decision logic:**
- If `feature/*` branch + worktree + in_progress task → **continue** (skip claim)
- If `miao`/`testing` branch → **warning**: "Performer should not work on main branch"

### Step 3/4: Candidate Ticket Ranking

```bash
# Rank by priority number (P1=1, P2=2, ...)
find jira/tickets -maxdepth 2 -name ticket.json | xargs jq -r \
  'select(.status == "ready" and .assignee == null) | "\(.priority[1])\t\(.id)\t\(.title)"' | \
  sort -t$'\t' -k1,1n | head -5
```

**Output:** Top-5 candidates with priority and title.

### Step 4/4: User Confirmation + Auto-Claim + EnterWorktree

```bash
# User selects ticket
select tid in EPIC-016-R EPIC-016-N EPIC-016-M; do
  [ "$tid" = "EPIC-016-R" ] && break
done

# Update ticket.json
jq ".status = \"in_progress\" | .performer = \"$INSTANCE_ID\"" \
  "jira/tickets/$tid/ticket.json" > /tmp/t.json && mv /tmp/t.json "jira/tickets/$tid/ticket.json"

# Create worktree
git worktree add ".kallax/worktrees/performer-$tid" -b "feature/$(echo $tid | tr 'A-Z' 'a-z')"

# Update state.json current_task
jq ".current_task = {ticket_id: \"$tid\", worktree_path: \"$WORKTREE_PATH\"}" \
  ".kallax/instances/$INSTANCE_ID/state.json" > /tmp/s.json && mv /tmp/s.json \
  ".kallax/instances/$INSTANCE_ID/state.json"
```

**Success card:**
```
╔════════════════════════════════════════════════════╗
║  READY TO WORK                                      ║
╠════════════════════════════════════════════════════╣
║  TICKET  ▸ EPIC-016-R                               ║
║  TASK    ▸ session_start.sh 卡死全面防御             ║
║  ACs     ▸ 17 (stdio + Performer onboarding)        ║
║  WORKTREE▸ .kallax/worktrees/performer-EPIC-016-R  ║
╠════════════════════════════════════════════════════╣
║  NEXT: cd worktree && implement ACs                 ║
╚════════════════════════════════════════════════════╝
```

### 4 Failure Fallbacks

| Scenario | Condition | Response |
|---|---|---|
| (a) No EPIC | No `jira/epics/*/epic.json` | "请先由 master 初始化一个 EPIC" |
| (b) Normal | Master exists + ready tickets | Proceed to Step 2 |
| (c) Continue | `feature/*` + in_progress task | "你已在处理 EPIC-016-X，是否继续？(y/n)" |
| (d) No master | No `master_main/state.json` | "⚠ 无 master 协调，建议先初始化 master" |

## Conductor Session Init

On startup, Conductor runs 3-step state-check:

1. **Active performers**: count + list with current task/branch
2. **Inbox queue**: pending items per performer
3. **PR status**: stale/zombie instances, pending reviews

## Key Commands

```bash
# Performer workflow
kallax task:claim EPIC-016-R    # auto-creates worktree
# ... implement ...
kallax task:complete EPIC-016-R # atomic commit + PR

# Conductor workflow
kallax conductor:heartbeat       # team status scan
kallax status                   # overview

# Master takeover
KALLAX_ROLE=master bash .kallax/hooks/session_start.sh
```

## Heartbeat Daemon

Daemon is started via `run_daemon()` from `scripts/lib/daemon.sh`:
- Only when `EXISTING_INSTANCES_COUNT > 0` (not first boot)
- On-demand: only when master is STALE/CLOSING
- Full stdio isolation: `< /dev/null >/dev/null 2>&1 &` + `setsid` + `disown`
- PID written to `state.json.heartbeat.heartbeat_daemon_pid`
- On exit (INT/TERM/EXIT): daemon killed + state marked CLOSING + diagnostic JSONL logged

## ZOMBIE Defense

If daemon process is dead but state.json still shows ACTIVE, check-stale.sh marks it ZOMBIE:
```
DAEMON_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' "$state_file")
if [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  jq '.status = "ZOMBIE"' "$state_file" > "${state_file}.tmp"
fi
```

## Files

- `.kallax/hooks/session_start.sh` — session init hook
- `scripts/heartbeat-daemon.sh` — daemon process
- `scripts/check-stale.sh` — stale/zombie detector
- `scripts/lib/daemon.sh` — `run_daemon()` stdio-isolated launcher
- `scripts/performer-session-init.sh` — Performer 4-step onboarding
- `scripts/conductor-session-init.sh` — Conductor 3-step startup
- `scripts/test-no-hang.sh` — regression gate (< 1s, no orphans)