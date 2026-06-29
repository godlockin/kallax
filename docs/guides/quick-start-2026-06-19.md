# Quick Start Guide

> Get KALLAX running in 5 minutes.

---

## Prerequisites

- Node.js >= 20
- Git >= 2.30
- npm or pnpm

---

## Step 1: Install

```bash
# Install dependencies
cd node
npm install

# Build
npm run build
```

---

## Step 2: Initialize

```bash
# Verify everything is in order
kallax system doctor

# Check configuration
ls .kallax/config.yml
```

Expected output:

```
=== KALLAX Health Check ===
[PASS] Git repo: main
[PASS] SQLite DB: 24K
[PASS] Node: v22.0.0
[PASS] Worktrees: 0
[PASS] Config exists
```

---

## Step 3: Create a Ticket

```bash
# Create a ticket (CLI)
kallax ticket create "Implement login form" \
  --description "Add email/password login" \
  --priority P1 \
  --scope "src/auth/,src/components/Login.tsx"
```

This creates a ticket in SQLite and outputs:

```json
{"id":"TICKET-XXX","title":"Implement login form","status":"created"}
```

---

## Step 4: Start Conductor

```bash
# Start as conductor (orchestrator)
kallax start --role conductor

# Output:
# KALLAX conductor started - instance: inst_xxx

# Run heartbeat (5-question health check)
kallax conductor heartbeat
```

The conductor instance registers itself and begins monitoring. Heartbeat shows priority queue, performer status, progress, blockers, and messages.

---

## Step 5: Create and Claim a Task

```bash
# Create a task from the ticket
kallax task create TICKET-XXX --type development

# Start as performer (in a separate terminal)
kallax start --role performer

# Claim the task
kallax task claim TASK-XXX
```

When a performer claims a task:

1. An isolated git worktree is created at `.kallax/worktrees/TASK-XXX/`
2. A feature branch `feature/TASK-XXX-short-name` is created
3. The task status changes to `claimed`

---

## Step 6: Develop and Complete

```bash
# Update progress while working
kallax task progress TASK-XXX 50 --message "Auth logic done, UI in progress"

# Complete the task (Saga 5-step)
kallax task complete TASK-XXX --level 4
```

The completion process:

```
Step 1: run-tests       ✓
Step 2: run-lint        ✓
Step 3: commit-changes  ✓
Step 4: push-branch     ✓
Step 5: create-pr       ✓
Verification Level 4    ✓
Task completed           ✓ commit=abc123 pr=42
```

---

## Step 7: Verify Output

```bash
# Show task status
kallax task status TASK-XXX

# Verify output (Fact-Forcing 4-level)
kallax verify output TASK-XXX
```

---

## What's Next

| Topic | Documentation |
|-------|---------------|
| Conductor/Performer rules | `CLAUDE.md`, `template/docs/CONDUCTOR-RULES.md`, `PERFORMER-RULES.md` |
| API reference | `docs/api/tasks-api.md`, `docs/api/agents-api.md`, `docs/api/system-api.md` |
| Architecture | `docs/architecture/FRAMEWORK.md`, `DEGRADATION-STRATEGY.md` |
| ADRs | `docs/adr/ADR-001-degradation-strategy.md` |
| Operations | `docs/ops/backup-restore.md`, `docs/ops/runbook.md`, `docs/ops/monitoring.md` |

---

## Quick Reference

```bash
# Tickets
kallax ticket create TITLE               # Create ticket
kallax task create TICKET-ID             # Create task from ticket

# Lifecycle
kallax start --role conductor            # Start as conductor
kallax start --role performer            # Start as performer
kallax task claim TASK-ID                # Claim and worktree
kallax task progress TASK-ID 0-100       # Update progress
kallax task complete TASK-ID             # Complete via saga

# Monitoring
kallax system doctor                     # Full diagnostics
kallax conductor heartbeat               # 5-question check
kallax system degradation                # Tier status
kallax verify output TASK-ID             # Fact-Forcing check

# Isolation
kallax isolation check TASK-A TASK-B     # File overlap check
```
