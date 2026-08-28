---
paths:
  - scripts/**/*.sh
  - tests/**/*.sh
  - .github/workflows/**
---

# CLI execution guardrails (EPIC-026-A)

## Required wrapper behavior

- Run long or noisy CLI work in background; write output to `/tmp/claude-tasks/<task>-<timestamp>.log`.
- Check exit status explicitly. Never treat absent visible error as success.
- Success returns compact status. Failure includes static tail context; never use `tail -f`, `tail -F`, `less +F`, or `watch`.
- Prefer `~/.claude/exec-task.sh`; wrapper must use `set -e` and `trap ERR` so internal failures cannot disappear.

## Escape-path prevention

`nohup ... &` can bypass PreToolUse detection for log monitoring. Do not use it as an alternate execution path. Do not hide failures with `cmd || true`; use `if ! cmd; then ... exit 1; fi`.
