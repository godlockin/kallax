# Changelog

All notable changes to KALLAX will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-01

### Added

#### Core Features
- **Conductor-Performer Model**: Multi-agent collaboration framework
  - Conductor: Coordinates tasks, reviews PRs, merges code
  - Performer: Claims tasks, develops code, submits PRs
- **Three-Level Architecture**: Rust → Node.js → Shell degradation
  - Level 1 (Rust): High-performance core (~8ms startup)
  - Level 2 (Node.js): Feature-rich layer (~400ms startup)
  - Level 0 (Shell): Emergency fallback
- **Three-Repository Separation**:
  - Confluence: Knowledge base
  - Jira: Task management
  - Code: Source code
- **DAG Scheduler**: Task dependency management and critical path analysis
- **Expert Panel**: 5 core experts + 50+ extended roles

#### KALLAX Improvements (vs KALLAX)
- **Parallel Isolation**: Mandatory worktree + file scope declaration
  - Solves KALLAX's parallel conflict issues
  - `kallax isolation:check` command for overlap detection
- **Error Handling**: Banned `expect()`/`unwrap()`/`panic!()` in production
  - All errors propagated via `Result<T, E>`
  - CI auto-detection of violations
- **Output Verification**: 4-Level Fact-Forcing protocol
  - Solves KALLAX's agent hallucination issues
  - `kallax verify:output` command for validation
- **Resource Management**: Mandatory TTL for all caches
  - LRU cache with configurable expiration
  - Solves KALLAX's memory leak issues
- **Type Safety**: Banned `any`/`@ts-ignore`
  - CI enforcement of strict TypeScript
- **Naming**: Master/Slaver → Conductor/Performer
  - Avoids sensitive terminology

#### CLI Commands
- `kallax task:create` - Create new ticket
- `kallax task:claim` - Atomically claim task (with worktree)
- `kallax task:complete` - Saga 5-step completion
- `kallax task:status` - View task status
- `kallax task:progress` - DAG progress with critical path
- `kallax conductor:heartbeat` - Conductor heartbeat check
- `kallax conductor:poll` - Process performer reports
- `kallax performer:register` - Register performer
- `kallax performer:poll` - Long-poll mailbox
- `kallax knowledge:index` - Build FTS index
- `kallax knowledge:search` - Full-text search
- `kallax isolation:check` - Check file scope overlap
- `kallax verify:output` - Verify performer output
- `kallax system:doctor` - System diagnostics
- `kallax team:status` - Team overview

#### Configuration
- `.kallax/config.yml` - Main configuration
- Modular configs: tasks, monitoring, permissions, git, review_merge
- Environment-based settings

#### Documentation
- CLAUDE.md - Claude Code integration
- AGENTS.md - Multi-agent specification
- Architecture docs: FRAMEWORK, DEGRADATION-STRATEGY
- Template docs: CONDUCTOR-RULES, PERFORMER-RULES, ANTI-PATTERNS
- Knowledge base: patterns, research, glossary

#### Skills System
- Core experts: Architect, Backend, Frontend, UX, Product
- Extended experts: 50+ roles across AI, Business, Design, etc.
- Slash commands: /kallax-start, /kallax-claim, /kallax-status, etc.

### Technical Details

#### Rust Crates
- `kallax-core`: Types, error handling, middleware, isolation
- `kallax-engine`: Event bus, DAG scheduler, knowledge base
- `kallax-cli`: CLI entry point and commands
- `kallax-server`: Axum HTTP API (port 9877)
- `context-mon`: Token estimation and memory monitoring

#### Node.js Modules
- `commands/`: 40+ command implementations
- `core/`: Message queue, cache, circuit breaker, saga executor
- `api/`: HTTP server, web dashboard
- `utils/`: Structured logging, error handling, cleanup

#### Performance
- Rust CLI startup: ~8ms (vs KALLAX Node.js 1500ms)
- Memory footprint: ~12MB (vs KALLAX 120MB)
- Command latency: ~21ms average

---

## Design Decisions

### ADR-001: Conductor-Performer Naming
- **Decision**: Rename Master/Slaver to Conductor/Performer
- **Reason**: Avoid sensitive terminology while maintaining clear role semantics

### ADR-002: Mandatory Worktree Isolation
- **Decision**: Force all performers to work in isolated git worktrees
- **Reason**: Prevent parallel conflicts experienced in KALLAX

### ADR-003: Banned Panic Patterns
- **Decision**: Prohibit `expect()`/`unwrap()`/`panic!()` in production code
- **Reason**: Improve error propagation and prevent unexpected crashes

---

## Migration from KALLAX

| KALLAX | KALLAX | Notes |
|------|--------|-------|
| Master | Conductor | Role rename |
| Slaver | Performer | Role rename |
| `.kallax/` | `.kallax/` | Data directory |
| `kallax` CLI | `kallax` CLI | Command prefix |
| /kallax-* | /kallax-* | Slash commands |

---

[1.0.0]: https://github.com/your-org/kallax/releases/tag/v1.0.0
