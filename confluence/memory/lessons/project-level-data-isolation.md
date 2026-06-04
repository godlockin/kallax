---
title: Project-Level Data Isolation
category: lesson
severity: critical
date: 2026-06-03
status: active
---

## Problem

SQLite databases stored at `~/.kallax/` (global location) caused data cross-contamination between multiple projects. Task data from Project A appeared in Project B's queries.

## Root Cause

- Used `process.env.HOME` / `~` as base path instead of project root
- 4 files had hardcoded home-directory paths
- No project-scoping mechanism

## Solution

**All project data in `<project-root>/.kallax/`, never `~/.kallax/`**

| Data | Location | Rationale |
|------|----------|-----------|
| SQLite DB | `<root>/.kallax/data/kallax.db` | Project-scoped |
| Config | `<root>/.kallax/config.yml` | Project-scoped |
| State | `<root>/.kallax/state/` | Project-scoped |
| Logs | `<root>/.kallax/logs/` | Project-scoped |
| Queue | `<root>/.kallax/queue/` | Project-scoped |
| Global config | `~/.claude/CLAUDE.md` | User-level OK |

## Rule
- Never use `process.env.HOME` for data paths
- Always use `git rev-parse --show-toplevel` as project root
- CI check: if any path contains `HOME` or `~`, reject

## Related
- [[project-level-data-isolation]]
