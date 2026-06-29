# KALLAX Rebuild — Lessons Learned

> Full lifecycle: EKET migration -> Rust core -> Node CLI -> 5-agent parallel -> Production
> Updated: 2026-06-04 | 2925 observations across project history

---

## 1. Project Overview

### The Journey

KALLAX started as **EKET** — an experimental multi-agent framework. After 6 months of real usage, fundamental architectural flaws forced a ground-up rebuild:

```
EKET (v0)                              KALLAX (v1)
├── Single agent per session           ├── 5 parallel performers
├── Shared file space                  ├── Isolated worktrees
├── Silent degradation                 ├── 3-level explicit degradation
├── trust-based verification           ├── 5-Level Fact-Forcing
├── `expect()`/`unwrap()` everywhere   ├── `Result<T, E>` enforced
├── Master/Performer naming            ├── Conductor/Performer naming
├── `~/.kallax/` global data           ├── `<project>/.kallax/` scoped data
└── 1474-line index.ts                 └── 85-line index.ts + 19 command files
```

### Key Numbers

| Metric | Before (EKET) | After (KALLAX) |
|--------|--------------|----------------|
| Parallel agents | 1 | 5 |
| File conflicts/week | 8-12 | 0 |
| Phantom completions | ~40% | 0% |
| Memory footprint | ~120MB (Node only) | ~12MB (Rust+Node) |
| CLI startup | ~400ms | ~8ms |
| index.ts size | 1474 lines | 85 lines |
| Test count | ~40 | ~120 |

### Timeline (Compressed)

```
Week 1:  EKET -> KALLAX renaming + directory restructuring
Week 2:  Phase 0a — split index.ts (1474 -> 85)
Week 3:  Phase 0b — split sqlite-manager.ts (938 -> 7 files)
Week 4:  Phase 0c — split routes/tasks.ts (547 -> 356+281)
Week 5:  Rust core + HTTP bridge (CRIT-11/14)
Week 6:  EPIC-009 — 6 test files + 4 E2E suites (62+20 tests)
Week 7:  EPIC-010 — 9 shell scripts + 6 docs
Week 8:  EPIC-011 — Rust DB persistence, analyzer, webhook, fingerprint
Week 9:  Dogfooding — discovered 3 blocking bugs
Week 10: Production hardening — caching, error handling, monitoring
```

---

## 2. Key Architecture Decisions

### 2.1 3-Level Degradation Architecture

**Problem**: EKET was a single Node.js process. Any failure = total outage.

**Solution**: Layered architecture with automatic fallback:

```
Level 3: Rust Core (8ms startup, ~12MB)
  → Level 2: Node.js (400ms startup, ~120MB)
    → Level 1: Shell Scripts (~50ms, bash+git)
```

Each level can operate independently. RecoveryManager probes upward every 60s and escalates after 3 consecutive success checks. Degradation is always logged with structured context — never silent.

**Lesson**: The 3-level design cost ~2 weeks extra but prevented 4 production outages in the first month of dogfooding. Worth every hour.

### 2.2 Conductor-Performer Model

**Problem**: EKET let agents both coordinate and execute. Single agent was the bottleneck. Two agents overwrote each other's work.

**Solution**: Strict role separation:

| Role | Responsibilities | Forbidden |
|------|-----------------|-----------|
| Conductor | Analyze, decompose, dispatch, review, merge | Write code, self-review |
| Performer | Claim, develop, test, submit | Merge to main, self-review |

**Lesson**: The strict separation sometimes feels slow (Conductor idle while Performer waits for review), but it prevents the "wild west" chaos of unstructured multi-agent work.

### 2.3 Worktree Isolation

**Problem**: Two performers modifying the same file caused merge conflicts that took 2-3 hours to resolve.

**Solution**:
- `kallax task:claim` auto-creates `git worktree add`
- File scope declaration mandatory per ticket
- `kallax isolation:check` before dispatch detects overlap

```bash
# Before dispatch — Conductor MUST run:
kallax isolation:check TASK-001 TASK-002
# Overlap → block. No exceptions.
```

**Lesson**: We tried "soft isolation" (warnings, not errors). It failed. Hard enforcement is the only strategy that works at scale.

### 2.4 HTTP Bridge (Rust <-> Node)

**Problem**: Needed Rust's performance for core operations but Node.js ecosystem for CLI/scripts.

**Solution**: Axum HTTP server on :9877 with REST endpoints. Node calls it via fetch().

```rust
// Rust server (kallax-server/src/main.rs)
Router::new()
  .route("/health", get(health_check))
  .route("/tasks", get(list_tickets).post(create_ticket))
  .route("/performers", get(list_performers))
  .layer(CorsLayer::new().allow_origin(Any));
```

```typescript
// Node client
const response = await fetch(`http://localhost:9877/tasks`);
const tasks = await response.json();
```

**Why not napi-rs?** napi-rs requires matching Node ABI versions, complex build pipelines, and breaks with every Node major upgrade. HTTP bridge is simpler, debuggable, and version-independent.

**Why not child_process?** Spawning a Rust binary per command adds ~8ms overhead (acceptable) but the real issue is state — child_process requires serializing state each invocation. HTTP server keeps state in memory.

---

## 3. Large File Splitting Strategy

### The Problem

index.ts had **1474 lines** with 19 concerns mixed together. Any change risked breaking unrelated functionality.

### The Approach

Phase-based splitting — never big-bang:

```
Phase 0a: index.ts (1474) -> index.ts (85) + 19 command files
  Strategy: Extract one command file at a time, verify each works
  Test: "Does the CLI still respond to every command?"

Phase 0b: sqlite-manager.ts (938) -> 7 files under sqlite/
  Strategy: types.ts → schema.ts → sync-client.ts → async-client.ts → ...
  Test: "Do all DB operations pass?"

Phase 0c: routes/tasks.ts (547) -> tasks.ts (356) + routes/tasks-ui.ts (281)
  Strategy: Identify natural seam (UI vs API concerns) and split there
  Test: "E2E tests pass"
```

### Rules Extracted

1. **Never big-bang refactor a file >500 lines.** Always phase-based with per-phase tests.
2. **Identify the natural seam first.** Look for import groups, responsibility boundaries, and test patterns.
3. **Each file <300 lines is the target.** Files >300 lines trigger a refactor reflex.
4. **Keep re-exports in the original location.** Consumer code doesn't change.

---

## 4. Parallel Development Mode

### The Experiment

In weeks 7-8, we ran 5 agents in parallel for the first time:

```
Performer A: Shell scripts (9 scripts)
Performer B: Documentation (6 pages)
Performer C: Rust DB persistence
Performer D: Analyzer module
Performer E: Integration tests
```

**Result**: Estimated 2-3 days of sequential work completed in ~4 hours. Net throughput gain: ~4x.

### What Made It Work

1. **Independent file scopes** — no two agents touched the same file
2. **Clear interfaces** — each module had a well-defined API boundary
3. **Short-lived branches** — each merged within 2 hours
4. **Conductor as traffic cop** — unblocked, didn't assist with coding

### What Failed (And Fixed)

| Failure | Root Cause | Fix |
|---------|-----------|-----|
| Focus drift | Performers helping each other | "No cross-Performer help" rule |
| Linter conflicts | Two formatters undoing each other | Unified prettier config |
| Port conflicts | Two servers on same port | `KALLAX_PORT` env per worktree |
| Implicit dependencies | Task B blocked on Task A | Explicit "Blocks: TASK-NNN" declaration |
| Phantom completions | Background agent hallucination | Foreground-only writes, 5-Level verify |

### Optimal Formula

```
5 agents parallel = 4x throughput gain
Rule: max(5, performer_count / 2) is the sweet spot
Above 7: coordination overhead > parallel gains
```

---

## 5. Dogfooding: The Reality Check

### The Practice

After the rebuild, we used KALLAX to develop KALLAX for 3 weeks. This caught issues that testing never would.

### The 3 Blocking Bugs

| Bug | Symptom | Root Cause | Fix |
|-----|---------|-----------|-----|
| DB directory | `kallax task:claim` crashed with "no such table" | `.kallax/data/` not auto-created | `mkdir -p` in bootstrap |
| CLI output | Empty output on `kallax status` | Async command not awaited | `.parseAsync` instead of `.parse` |
| Worktree retry | `kallax task:claim` failed after previous failed claim | Worktree dir/branch left behind | Full cleanup: branch + dir + prune |

### Why Dogfooding Matters

- **Real workflows expose edge cases.** Our test suite had 90% coverage, yet missed all three bugs.
- **Tooling credibility.** If KALLAX can't manage its own development, why would anyone use it?
- **Documentation validation.** Writing docs for KALLAX using KALLAX showed where the docs were wrong.

**Lesson**: Dogfood for at least 2 weeks before any public release. The bugs found in weeks 2-3 are the ones that would tank adoption.

---

## 6. Anti-Patterns Catalog

### Avoided (by enforcement)

1. **`expect()`/`unwrap()` in production** — CI auto-scanner rejects PRs containing them
2. **`any` types** — strict TypeScript with `unknown` + type guards
3. **TTL-less caches** — LRU + TTL mandatory for all cache definitions
4. **Silent degradation** — every level switch must log `{ event: 'degradation_triggered', from, to, reason }`
5. **Background writes** — all code writes must be foreground with real file I/O

### Found in Dogfooding

6. **Hardcoded `~` paths** — 4 files used `process.env.HOME`. Fixed to `git rev-parse --show-toplevel`.
7. **Long-running background agents** — hit 400 "prompt token exceeds limit". Fixed with context compaction.
8. **Implicit file dependencies** — two tickets modifying the same file without coordination. Fixed with explicit `file_scope` declarations.

### Metrics on Enforcement

```yaml
CI scan results (monthly):
  expect/unwrap violations: 12 -> 0
  any type violations: 46 -> 3
  TTL-less caches: 8 -> 0
  hardcoded paths: 4 -> 0
  console.log: 23 -> 0
```

---

## 7. Recommendations for Similar Projects

### Do

- Start with file splitting before adding features. 1474-line index.ts is not a foundation for growth.
- Enforce isolation at the tooling level, not the convention level. Git hooks > code reviews.
- Dogfood from week 1. If the tool doesn't feel natural to use, neither will adoption.
- Budget 30% of dev time for infrastructure (CI, monitoring, error handling).

### Don't

- Don't trust agent self-reports. 5-Level verification is not paranoia, it's experience.
- Don't use background agents for code writes. They will hallucinate confidently.
- Don't merge without CI green. Every skip creates a cascading debugging session.
- Don't let the Conductor write code. The moment the Conductor codes, coordination breaks.

---

## References

- [Architecture Decision Records](../../decisions/)
- [Multi-Agent Collaboration Failures](multi-agent-collab-failures.md)
- [Background Agent Hallucination](background-agent-hallucination-2026-06-19.md)
- [Verification Matters](verification-matters-2026-06-19.md)
- [Isolation Strategy](../patterns/isolation-strategy.md)
- [Degradation Strategy](../../architecture/DEGRADATION-STRATEGY.md)
- [Framework White Paper](../../architecture/FRAMEWORK.md)
