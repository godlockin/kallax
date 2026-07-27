# TODO/FIXME Backlog (2026-07-19)

## Summary

Total grep hits: 60
Filtered to actual TODO/FIXME items: 4
(excludes: mktemp `.XXXXXX` patterns, EPIC-XXX placeholders in comments/docs, scan-pattern definitions)

---

## HIGH (should fix in < 1 week)

| # | File | Line | Content | Category | Notes |
|---|------|------|---------|----------|-------|
| 1 | scripts/ticket-board.sh | 247 | `TODO: Add description` | ticket-board | Template output for new tickets — every `kallax ticket:new` spawns this stub |

---

## MED

| # | File | Line | Content | Category | Notes |
|---|------|------|---------|----------|-------|
| 2 | scripts/install.sh | 832 | `TODO future EPIC` | install | opencode config hint — non-critical, future EPIC |
| 3 | scripts/install.sh | 842 | `TODO future EPIC` | install | codex config hint — non-critical, future EPIC |
| 4 | scripts/install.sh | 852 | `TODO future EPIC` | install | gemini config hint — non-critical, future EPIC |

---

## LOW

| # | File | Line | Content | Category | Notes |
|---|------|------|---------|----------|-------|
| — | — | — | — | — | No LOW items |

---

## Filtered Out (Not Actual TODOs)

These were grep hits but are NOT actionable TODO items:

| Pattern | Files | Reason |
|---------|-------|--------|
| `mktemp ... XXXXXX` | setup.sh, metrics.sh, expert-arena.sh, bench-rust-node-bridge.sh, verify/*.sh, install.sh, cleanup-remote-branches.sh | mktemp template suffix, not TODO |
| `EPIC-XXX` placeholder | metrics/, branch-4pr.sh, verify/check-*.sh, epic-create.sh, governance-3phase.sh, migrate-invocations.sh, post-process.sh | Doc/examples placeholder, not TODO |
| Anti-pattern detection | check-anti-patterns.sh:56-77 | Scans for TODO+exit 0 stubs — the rule itself, not a TODO |
| Scan pattern def | scan-forbidden.sh:118 | Defines `scan_ts "TODO:\|FIXME:"` — the scanner, not a TODO |
| Logic comment | lib/expert-invocation-queue.sh:216 | `# Handle both EPIC-XXX pattern` — code comment, not TODO |
| Step description | post-process.sh:407 | `# Step 4: 技术债登记 (TODO/workaround → jira backlog)` — step name, not TODO |

---

## Analysis

**Root cause**: `ticket-board.sh:247` is the only HIGH — it's a template stub that ships in every new ticket. The install.sh items are LOW because they are aspirational hints ("future EPIC") for tooling config that does not block anything.

**Recommendation**: Fix #1 (ticket-board.sh) by either:
- Removing the TODO section entirely from the template
- Or replacing with a meaningful default placeholder
