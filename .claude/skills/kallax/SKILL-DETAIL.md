---
name: kallax-detail
description: Detailed reference for KALLAX — daemon invocation standard, zombie defense, Performer onboarding protocol, diagnostic logging.
---

# KALLAX Detailed Reference

## Daemon Invocation Standard (AC3)

Every daemon MUST be launched via `run_daemon()` from `scripts/lib/daemon.sh`:

```bash
source "${SCRIPTS_DIR}/lib/daemon.sh"
run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}"
```

**Four mandatory elements:**
1. `< /dev/null` — stdin isolation (prevents parent shell pipe hang)
2. `> /dev/null 2>&1` — stdout/stderr isolation
3. `setsid` — new session/process group (orphans from parent)
4. `disown` — remove from shell job table

**Failure mode without isolation:**
- Node.js `child_process.spawn` inherits parent stdout/stderr pipes
- Parent waits for all child fd to close → permanent hang
- Seen in: EPIC-016-R incident (session_start.sh:193 missing `>/dev/null 2>&1`)

## run_daemon() Contract

```bash
run_daemon <name> <script> [args...] → writes PID to $STATE_FILE.heartbeat.${name}_pid
- Returns 0: daemon confirmed within 3s via state.json
- Returns 1: timeout or not executable
- State file must contain: .heartbeat.${name}_pid field
```

## ZOMBIE Detection (AC5)

**Definition:** Daemon process is dead but state.json still shows ACTIVE.

**check-stale.sh detection:**
```bash
DAEMON_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' "${state_file}" 2>/dev/null || true)
if [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  jq '.status = "ZOMBIE"' "${state_file}" > "${state_file}.tmp" 2>/dev/null && \
    mv "${state_file}.tmp" "${state_file}" 2>/dev/null || true
  echo "  ZOMBIE ${INSTANCE_ID} (daemon pid ${DAEMON_PID} dead, state was ACTIVE)"
fi
```

**ZOMBIE causes:**
- Ctrl-C without EXIT trap firing
- Daemon crash (OOM, segfault)
- `kill -9` without cleanup

**Prevention:** EXIT/INT/TERM trap in session_start.sh kills daemon on any exit.

## Performer 初始化协议 (AC15)

### Trigger Conditions

- `/kallax` init → select Performer role
- `KALLAX_ROLE=performer bash .kallax/hooks/session_start.sh`
- `bash scripts/performer-session-init.sh`

### 4-Step State-Check Output Format

**Step 1/4: Project State**
```
─── Step 1/4: Project State ───
  Master: ACTIVE
  Active EPICs: EPIC-016
  Ready tickets:
   [EPIC-016-R] session_start.sh 卡死全面防御 [P1]
   [EPIC-016-N] ...
```

**Step 2/4: Session State**
```
─── Step 2/4: Session State ───
  Branch: miao
  In worktree: no
  Current task: none
```

**Step 3/4: Candidate Ranking**
```
─── Step 3/4: Candidate Tickets ───
  Top candidates:
    [EPIC-016-R] session_start.sh 卡死全面防御 [P1] ★ recommended
    [EPIC-016-N] ...
```

**Step 4/4: Claim Confirmation**
```
─── Step 4/4: Claim Ticket ───
Select ticket to claim (or 'q' to skip): 1

  ✓ Claimed EPIC-016-R
  ✓ Worktree: /path/to/.kallax/worktrees/performer-EPIC-016-R
  ✓ State updated

╔════════════════════════════════════════════════════╗
║  READY TO WORK                                      ║
╠════════════════════════════════════════════════════╣
║  TICKET  ▸ EPIC-016-R                               ║
║  WORKTREE▸ .kallax/worktrees/performer-EPIC-016-R ║
║  BRANCH  ▸ feature/epic-016-r-stdio-defense        ║
╠════════════════════════════════════════════════════╣
║  NEXT: cd worktree && implement ACs                 ║
╚════════════════════════════════════════════════════╝
```

### 4 Failure Scenarios

| Scenario | Output |
|---|---|
| (a) No EPIC | "请先由 master 初始化一个 EPIC" |
| (b) Normal flow | Proceed through Steps 1-4 |
| (c) Already on feature branch | "你已在处理 EPIC-016-X，是否继续？(y/n)" |
| (d) No master | "⚠ 无 master 协调，建议先初始化 master" |

## Diagnostic JSONL Format (AC6)

On every session_start.sh exit, structured diagnostic is written:

```json
{"ts":"2026-06-06T15:30:00Z","event":"session_start_exit","instance":"performer_host_12345","pid":98765,"daemon_pid":98766,"exit_code":0}
```

**Fields:**
- `ts` — ISO 8601 UTC timestamp
- `event` — always `session_start_exit`
- `instance` — instance_id
- `pid` — session_start.sh PID ($$)
- `daemon_pid` — heartbeat daemon PID (null if not started)
- `exit_code` — exit code of the shell

**Log location:** `.kallax/logs/session_start.diag.jsonl`

## First-Boot Heartbeat Skip (AC7)

**Two modes:**

1. **Opt-in (default):** `KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT=0` forces heartbeat even on first boot
2. **On-demand (recommended):** Only start daemon if `master_main/state.json` exists AND status is STALE/CLOSING

**Implementation:**
```bash
if [ "${EXISTING_INSTANCES_COUNT}" -gt 0 ]; then
  # ... candidate resolution ...
  if [ -n "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT:-}" ] && \
     [ "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT}" = "0" ]; then
    run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}"
  elif [ -f "${MASTER_STATE}" ]; then
    MASTER_STATUS=$(jq -r '.status // "unknown"' "${MASTER_STATE}" 2>/dev/null || echo "unknown")
    if [ "${MASTER_STATUS}" = "STALE" ] || [ "${MASTER_STATUS}" = "CLOSING" ]; then
      run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}"
    fi
  fi
fi
```

## Cleanup & Archive (AC9)

Zombie/stale instances are archived (NOT deleted) to `.kallax/instances/.archive/`:

```bash
# Criteria: ZOMBIE or STALE, or daemon process dead
IS_ZOMBIE=false
if [ "$STATUS" = "ZOMBIE" ] || [ "$STATUS" = "STALE" ]; then
  IS_ZOMBIE=true
elif [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  IS_ZOMBIE=true
fi

if [ "$IS_ZOMBIE" = true ]; then
  ARCHIVE_SUBDIR="${ARCHIVE_DIR}/$(date +%Y%m%d_%H%M%S)_${INSTANCE_ID}"
  mkdir -p "$ARCHIVE_SUBDIR"
  mv "$INSTANCE_DIR"/* "$ARCHIVE_SUBDIR/" 2>/dev/null || true
  rmdir "$INSTANCE_DIR" 2>/dev/null || true
fi
```

Archive naming: `{date}_{instance_id}/` — sortable, timestamp-prefixed.

## Performance Gate (AC10)

**bash -n syntax check** on all modified scripts:
```bash
bash -n .kallax/hooks/session_start.sh
bash -n scripts/heartbeat-test.sh
bash -n scripts/check-stale.sh
bash -n scripts/test-no-hang.sh
```

**Time gate:** `time bash .kallax/hooks/session_start.sh < 0.5s`

## Test Scripts

| Script | Purpose |
|---|---|
| `scripts/test-no-hang.sh` | AC8: 10 iterations, < 1s each, no orphan heartbeat |
| `scripts/test-performer-onboarding.sh` | AC16: 4 scenarios (a/b/c/d) |
| `scripts/heartbeat-test.sh` | Full E2E: daemon start → tick → stale → revival |