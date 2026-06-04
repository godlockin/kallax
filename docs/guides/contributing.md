# Contributing Guide

> Guidelines for contributing to the KALLAX codebase.

---

## Codebase Overview

```
kallax/
  rust/               # Core engine (performance-critical code)
    crates/
      kallax-core/    # Types, errors, cache, middleware, registry, isolation
      kallax-engine/  # TicketEngine, AgentPool, ConflictResolver, KnowledgeBase
      kallax-cli/     # CLI application (clap-based)
      kallax-server/  # API server (future)
      context-mon/    # Context window monitoring daemon
  node/               # Enhancement layer (Node.js)
    src/
      commands/       # CLI command registrations (commander)
      core/           # Core logic (SQLite, worktree, assigner, verifier)
      api/            # Express API server (routes, middleware, server)
      types/          # TypeScript type definitions (zod schemas)
      utils/          # Logger, startup validator, process cleanup
    tests/            # Vitest test suite
  scripts/            # Operational shell scripts
  confluence/         # Knowledge base (long-term memory)
  jira/               # Task management (epics, sprints, schemas)
  docs/               # Documentation
    architecture/     # Design docs (FRAMEWORK, THREE_REPO, ISOLATION)
    guides/           # How-to guides (quick-start, migration, contributing)
    ops/              # Operations guides (backup, monitoring, runbook)
    reference/        # Reference docs (CLI, error codes)
    adr/              # Architecture Decision Records
```

---

## Development Setup

### Prerequisites

- Node.js >= 20
- Rust toolchain (rustc 1.75+, cargo)
- Git >= 2.30
- sqlite3 CLI (for database operations)

### Install Dependencies

```bash
# Node.js layer
cd node && npm install

# Rust core
cd rust && cargo build --release

# Both (from project root)
npm run build:all
```

### Run Tests

```bash
# All tests
npm run test:all

# Rust only
npm run test:rust

# Node only
npm run test
```

### Lint

```bash
cd node && npm run lint
```

---

## Coding Standards

### Rust

- **No unwrap/expect/panic** in production code — use `Result<T, KallaxError>`.
- All errors carry structured context (`KallaxError` enum).
- Prefer owned data over mutable references.
- Builder pattern for complex object construction.
- Tests live in `#[cfg(test)] mod tests` blocks within each file.

### TypeScript

- **No `any`**, no `@ts-ignore`. Use `unknown` + type guards.
- All types defined as Zod schemas in `types/index.ts`.
- `neverthrow` `Result` types for fallible operations (no thrown exceptions).
- Structured error codes via `KallaxErrorCode`.
- `const` assertions for enum-like objects.

### Shell Scripts

- `set -euo pipefail` at the top of every script.
- Prefer `sqlite3` for database queries over `node -e`.
- Check for tool availability before usage (`command -v`).
- Meaningful error messages to stderr.

---

## Pull Request Process

1. **Branch naming**: `feature/TICKET-XXXX-description` or `fix/TASK-XXXX-description`.
2. **Single responsibility**: one PR = one logical change.
3. **Tests required**: new features must include tests; bug fixes must include regression tests.
4. **Fact-Forcing**: Conductor verifies PR via 4-level check (L1 existence, L2 substance, L3 wiring, L4 data flow).
5. **No self-merge**: only Conductor merges to `main`.

### Pre-submit Checklist

- [ ] Tests pass (`npm run test:all`)
- [ ] Lint passes (`npm run lint`)
- [ ] No `any` types or `@ts-ignore`
- [ ] No `unwrap()`/`expect()` in Rust production code
- [ ] No `console.log` — use logger
- [ ] Constants extracted (no magic numbers)
- [ ] Commits are atomic and well-described

---

## Architecture Decisions

Significant architectural changes must be documented as ADRs in `docs/adr/`. Use the template at `confluence/decisions/ADR-template.md`.

---

## Getting Help

- Open an issue in the project repository
- Check `kallax system:doctor` for system health
- Review `docs/ops/runbook.md` for common operational issues
