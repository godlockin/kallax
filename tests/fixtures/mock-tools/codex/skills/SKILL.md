---
name: kallax
description: KALLAX multi-agent orchestration skills (mock fixture for Codex integration tests)
---

# KALLAX Skills (Mock Codex Fixture)

> Mock fixture for tests/integration/install-multi-tool-test.sh
> Path: ~/.codex/skills/kallax/SKILL.md
> Tool: Codex CLI

## Skills Index

- `/kallax-start` — Conductor session init
- `/kallax-onramp` — Project onramp tool detection

## Codex Notes

Codex uses `~/.codex/prompts/` for slash commands (NOT `commands/`).
Binary may not exist (codex not installed) — fallback: detect via `~/.codex/` dir.
