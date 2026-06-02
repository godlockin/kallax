---
title: Branch Strategy
category: guide
severity: high
date: 2026-06-03
status: active
---

## Branch Model

```
main ────────────────────────────────────────── (Conductor only, production)
  │
  ├── feature/TASK-001 ──→ PR ──→ main          (Performer worktree)
  ├── feature/TASK-002 ──→ PR ──→ main
  └── feature/TASK-003 ──→ PR ──→ main
```

## Rules

1. **Conductor** owns `main` branch — merges after review
2. **Performer** works in `feature/*` branches — created via worktree
3. **Never commit directly to main** — all changes via PR
4. **One branch per task** — branch name = `kallax/TASK-NNN`
5. **Delete branch after merge** — keep repo clean

## Workflow

```bash
# Performer claims task → auto-creates worktree + branch
kallax task:claim TASK-001

# Work in isolated worktree
cd .kallax/worktrees/TASK-001

# Submit when done
kallax task:complete TASK-001  # Saga 5-step

# Conductor reviews → merges → cleans up
kallax review-pr <PR-NUMBER>
kallax merge <PR-NUMBER>
```
