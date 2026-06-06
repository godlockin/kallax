---
name: kallax-init
description: Initialize KALLAX session. STRICT MODE — 1 Bash call only. Auto-installs hooks if missing.
---

# KALLAX Init — STRICT MODE v4 (EXACT SEQUENCE)

## HARD STOPS
- **1 tool call only.** Any Read/Write/Edit/ls/find = failure.
- **NEVER Read** any file in this init.
- **NEVER Write/Edit** — the script owns its output.
- **NEVER ls / find / cat** the project.
- **NEVER call claude-mem** unless user asked for history.
- **NEVER fabricate** the card — verbatim from script stdout.

## EXACT SEQUENCE (3 steps — follow in order)

### Step 1: Confirm script is globally available
The script lives at `~/.claude/skills/kallax/hooks/session_start.sh`.
It is shipped globally by `scripts/install.sh`, so it works in any project
without per-project setup. If `~/.claude/skills/kallax/hooks/session_start.sh`
is missing, the user must run `bash scripts/install.sh` first — but that
is the USER's job, not yours. Do not run install scripts in init.

### Step 2: Run exactly this bash command (copy verbatim, do not paraphrase)
```bash
KALLAX_ROLE=<role> bash "${HOME}/.claude/skills/kallax/hooks/session_start.sh" --role <role>
```

`<role>` = `master` | `conductor` | `performer` (default `master`).

### Step 3: Reproduce 4 lines verbatim from stdout, then result line, then STOP
```
ROLE     : <line 2>
INSTANCE : <line 3>
INBOX    : <line 4>
NEXT     : <line 5>
```

Then output: `result: master 会话初始化完成 — instance_id=<X>`,STOP.

## WHY THIS IS STRICT
- Each Read ≈ 3K tokens. Lean mode targets 70-80% reduction.
- Each extra tool call = 1-3 sec + permission interrupt.
- Soft "DO NOT" doesn't work — Claude's training pulls toward exploration.
- The 3-step structure forces a *commit point* at each step (verify path → run → extract), making drift detectable and unblockable.

## IF YOU THINK YOU NEED MORE TOOLS
You don't. The script is self-contained. Re-read Step 2.
