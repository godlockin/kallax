---
name: kallax
description: KALLAX multi-agent orchestration skills (mock fixture for integration tests)
---

# KALLAX Skills (Mock Claude Code Fixture)

> Mock fixture for tests/integration/install-multi-tool-test.sh
> Path: ~/.claude/skills/kallax/SKILL.md
> Tool: Claude Code

## Skills Index

- `/kallax-start` — Conductor session init
- `/kallax-onramp` — Project onramp tool detection
- `/kallax-task:claim` — Performer claim task atomically
- `/kallax-pr:review` — Conductor 4-level review

## Verification

This SKILL.md is loadable when:
1. File exists at ~/.claude/skills/kallax/SKILL.md
2. Frontmatter parses (name + description)
3. Body non-empty