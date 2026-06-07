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
- **NEVER hallucinate** ASCII card — must verbatim copy script stdout. If you output something you did not directly read from the script's stdout, you are hallucinating.

## INBOX PATHS
- `inbox/<instance_id>/` = **个人队列** (per-instance, 只给本 instance 看)
- `inbox/<role>/` = **全局未认领** (per-role, 任何该 role instance 可读)
- `outbox/<instance_id>/` = **本 instance 发出的消息**

**ASCII card 上的 `INBOX(you)`** 指个人队列, 不是项目全局。
项目全局 INBOX 需查看 `.kallax/queue/inbox/` 目录结构。

## EXACT SEQUENCE (3 steps — follow in order)

### Step 1: Confirm OR Install script (1-call self-bootstrap)
The script lives at `~/.claude/skills/kallax/hooks/session_start.sh`.
**Auto-install fallback** (no extra tool call): if the script is missing, the
Step 2 command below will self-install in the same call. Do NOT run install
scripts as a separate step — that wastes a tool call.

### Step 2: Run exactly this bash command (copy verbatim, do not paraphrase)
```bash
KALLAX_INSTALL_DIR="${HOME}/.claude/skills/kallax/hooks"
mkdir -p "${KALLAX_INSTALL_DIR}"
[ ! -f "${KALLAX_INSTALL_DIR}/session_start.sh" ] && cp .kallax/hooks/session_start.sh "${KALLAX_INSTALL_DIR}/session_start.sh" 2>/dev/null
KALLAX_ROLE=<role> bash "${KALLAX_INSTALL_DIR}/session_start.sh" --role <role>
```

The 3-line mini-script above is **one bash invocation** that:
1. Creates `~/.claude/skills/kallax/hooks/` if missing
2. Copies `.kallax/hooks/session_start.sh` from project to global path if missing
3. Runs session_start.sh with the requested role

`<role>` = `master` | `conductor` | `performer` (default `master`).

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

## REPORT ONLY SCRIPT OUTPUT
The ASCII card is **script output, not agent generation**. You must reproduce it verbatim from the script's stdout. Do not:
- Paraphrase or summarize the card content
- "Clean up" or reformat the card
- Fill in missing details from your own knowledge

If the script outputs 6 lines, you output exactly those 6 lines. If it outputs 7 lines, you output exactly 7 lines.

## STDOUT HASH VERIFICATION
To detect hallucination, use hash comparison:

1. **Script outputs expected hash**: `bash scripts/benchmark-init.sh --hash-session-start`
   - Outputs session_start.sh stdout + sha256 hash
   - Writes `expected_stdout_sha256: <hash>` to `.kallax/benchmarks/expected_card_hash.txt`

2. **User verification flow**:
   - User runs `/kallax init` → gets ASCII card from agent
   - User runs `bash scripts/benchmark-init.sh --hash-session-start` → gets expected hash
   - User computes agent's card hash: `echo -n "<card>" | shasum -a 256`
   - User compares: if agent hash != expected hash → hallucination detected

3. **Hallucination deviation record**: If mismatch found, document in `confluence/decisions/HALLUCINATION-DEVIATION-LOG.md`
