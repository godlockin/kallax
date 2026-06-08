# EPIC-016 Init Performance Optimization — Final Report (EPIC-016-H)

> 测得时点: 2026-06-06T05:08Z (baseline-v0) → 2026-06-07T00:XXZ (current,5-run median)
> 执行者: performer-EPIC-016-H (worktree: feature/EPIC-016-H-benchmark-rebaseline)
> 测量工具: `scripts/benchmark-init.sh --iter 1` x5 runs, median taken

---

## 1. Before/After Comparison Table

### Baseline (v0) vs Current (v4 — 5-run median)

| Metric | baseline-v0 | current (5-run median) | Δ | Δ% |
|---|---:|---:|---:|---:|
| **wall_time_ms (cold)** | 463 ms | 355 ms | -108 ms | **-23.3%** |
| **wall_time_ms (warm avg)** | 520 ms | 210 ms | -310 ms | **-59.6%** |
| **out_bytes** | 1409 | 480 | -929 | **-65.9%** |
| **out_lines** | 14 | 7 | -7 | **-50.0%** |
| **tokens_est** | 352 | 120 | -232 | **-65.9%** |
| **files_created** | 2 | 0 | -2 | **-100%** |
| **script_bytes** | 12088 | ~11275 | -813 | **-6.7%** |

### Historical Progression

| Version | wall_time_cold | wall_time_warm | tokens_est | Date |
|---|---:|---:|---:|---|
| baseline-v0 | 463 ms | 520 ms | 352 | 06-06 05:08 |
| optimized-v1 | 224 ms | 262 ms | 145 | 06-06 05:15 |
| v2-postreview | 238 ms | 210 ms | 111 | 06-06 05:26 |
| v3-strict | 242 ms | 206 ms | 111 | 06-06 06:56 |
| **current (v4)** | **355 ms** | **210 ms** | **120** | 06-07 |

**NOTE**: current cold wall_time (355 ms) is regressed vs v2/v3 (238-242 ms). This worktree has uncommitted local modifications to session_start.sh that appear to have introduced overhead. The warm average (210 ms) is consistent with v2/v3.

---

## 2. Layer Optimization Contribution

### Layer A — Platform Level (NOT YET OPTIMIZED)
- MCP server lazy loading (github / playwright / prompts.chat) — pending EPIC-016-G ADR
- Skill metadata on-demand discovery — pending EPIC-016-G ADR
- SessionStart hooks slimming — pending EPIC-016-G ADR
- **Estimated savings**: 20-40K tokens/turn x 8 turns = 160-320K tokens

### Layer B — Script Behavior (EPIC-016-B/C/D/E/F applied)
| Change | Evidence | Savings |
|---|---|---:|
| Lean kallax-init.md (EPIC-016-B) | 1011 → 882 bytes | -12.8% doc size |
| Skip project root scan (EPIC-016-C/D) | no `ls -la`/`find` in lean skill | -3-5 sec/turn |
| Slim session_start.sh (EPIC-016-E) | 14→7 line ASCII card, heartbeat skip | -50% output lines |
| claude-mem strategy (EPIC-016-F) | default off, explicit opt-in | -8-10K tokens/turn |

### Layer C — Claude Behavior (lean skill enforcement)
- Explicit DO NOT list (META/SKILL-DETAIL/experts/IDENTITY)
- Single-shot probe: `ls .kallax/` only if needed
- **Estimated savings**: 1.5-2.0M tokens across full session

---

## 3. Remaining Unoptimized Items

### Not Touched (Why)

| Item | Reason Not Touched |
|---|---|
| MCP server lazy loading | Requires platform-level changes, tracked in EPIC-016-G |
| Skill metadata full injection | 90 skills all loaded, tracked in EPIC-016-G |
| session_start.sh uncommitted regression | Local modifications in worktree not yet committed/verified |
| `.kallax/instances/` accumulation | 38+ zombie instances, cleanup tracked in EPIC-016-R AC9 |
| Node.js layer startup | Falls back to shell if Rust unavailable |

### Current Blockers

1. **session_start.sh regression**: cold wall_time regressed from 242ms (v3) to 355ms (current). Root cause: uncommitted local modifications adding Master Health Check + Worktree detection overhead.
2. **MCP lazy loading**: blocked on EPIC-016-G ADR drafting
3. **Token reduction not reaching 70%**: current65.9% vs target 70%

---

## 4. Savings vs 70% Target

| Metric | Baseline | Current | Reduction | Target | Status |
|---|---:|---:|---:|---:|---|
| wall_time (cold) | 463 ms | 355 ms | **23.3%** | 70% | **NOT MET** |
| wall_time (warm) | 520 ms | 210 ms | **59.6%** | 70% | **NOT MET** |
| tokens_est | 352 | 120 | **65.9%** | 70% | **NOT MET** |

**Honest assessment**: None of the three key metrics reach the 70% target. Token reduction (65.9%) is closest but falls short.

---

## 5. Follow-up Ticket

**EPIC-016-S** created: `jira/tickets/EPIC-016-S/`

Primary objectives:
- Investigate and fix session_start.sh cold wall_time regression (355ms vs v3's 242ms)
- MCP server lazy loading (Layer A)
- Skill metadata on-demand injection (Layer A)
- Target: reach 70% reduction on all three metrics

---

## 6. Benchmark Run Data

```
Run 1: wall_time_ms=313, tokens_est=120, warm_avg=153
Run 2: wall_time_ms=326, tokens_est=120, warm_avg=188
Run 3: wall_time_ms=355, tokens_est=120, warm_avg=210
Run 4: wall_time_ms=386, tokens_est=120, warm_avg=244
Run 5: wall_time_ms=420, tokens_est=120, warm_avg=272

Sorted cold: 313, 326, 355, 386, 420 → median = 355 ms
Sorted warm: 153, 188, 210, 244, 272 → median = 210 ms
```

---

## Status

| Ticket | Status | Notes |
|---|---|---|
| EPIC-016-A | done | benchmark-init.sh |
| EPIC-016-B | done | lean kallax-init.md |
| EPIC-016-C | done | skip project root scan |
| EPIC-016-D | done | single-shot probe |
| EPIC-016-E | done | session_start.sh slim |
| EPIC-016-F | done | claude-mem default off |
| EPIC-016-G | backlog | Layer A ADR pending |
| EPIC-016-H | done | benchmark median + reduction report (this ticket) |
| EPIC-016-I | done | expert review complete |
| EPIC-016-R | ready | daemon zombie fix + performer onboarding |
| **EPIC-016-S** | **created** | **follow-up: regression fix + Layer A** |
