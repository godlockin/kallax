# loopx vs KALLAX Governance Gap — Public/Private Boundary

> **主公拍板**: 2026-08-05 P1
> **EPIC**: EPIC-163
> **起源**: review loopx AGENTS.md + docs/public-private-boundary.md

## 1. Gap Analysis

| Dimension | loopx | KALLAX (Before) | Gap |
|-----------|-------|-----------------|-----|
| Boundary Doc | `docs/public-private-boundary.md` (5078 bytes) | **None** | **Large** |
| Scanner | `loopx check` (tracked/untracked) | **None** | **Large** |
| Detection Classes | 4 (credentials/paths/logs/prompts) | 0 | **Large** |
| CONTRIBUTING.md | Pre-commit scan required | **None** | Medium |
| Security Rules | AGENTS.md Section 7 explicit | **None** | Medium |

## 2. Root Cause

KALLAX focused on:
- 5-Level Verify (L1-L5)
- Branch flow governance (4-branch)
- Immutable scripts (4 laws)
- Anti-fab tools (3 tools)

**Missing**: File-state boundary (tracked vs untracked) definition + scanner.

## 3. Solution (EPIC-163)

Borrow from loopx:
1. `docs/public-private-boundary.md` — 1:1 schema
2. `scripts/check-private-context.sh` — 1:1 detection classes
3. CONTRIBUTING.md — 1:1 scan requirement
4. CLAUDE.md Section 7 — 1:1 security rules

## 4. Exit Code Contract (1:1 with scan-dead-code.sh)

| Code | Meaning | Contract |
|------|---------|----------|
| 0 | PASS | No violations |
| 1 | FAIL | Fail-closed (block commit) |
| 2 | BLOCKED-env | Environment issue |

## 5. Adoption Path

```
v3.32.7 (EPIC-163)
  └── pre-commit hook integration
  └── 5-Level Verify L4 updates
  └── CONTRIBUTING.md update
```

## 6. Future Enhancements

- Add `--fix` mode to auto-remove credentials
- Integrate with .gitignore suggestions
- Add CI/CD gate (similar to pre-commit)
