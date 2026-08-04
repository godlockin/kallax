# KALLAX v3.32.4

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor

**v3.32.4** | 4-branch governance + 5-Level Verify + 7 showcase cases | [中文版](./README.md)

---

## Why KALLAX

KALLAX is a **multi-agent collaboration framework** for Claude Code-based engineering teams. It solves three real problems:

1. **No audit trail** — Who did what, when, why? KALLAX tracks every decision with SHA256 hash-chain.
2. **No verification standard** — "tests pass" is not enough. KALLAX has 5 independent verification levels.
3. **No governance process** — Tickets float without discipline. KALLAX enforces 4-branch flow + Rule 34 bugfix repro.

**Key differentiator**: KALLAX is built by the same team that uses it. Every rule is battle-tested. Every script is verified. Every number in this README comes from raw test output.

---

## Quick Start

### Install

```bash
git clone https://github.com/godlockin/kallax.git
cd kallax
bash scripts/install.sh --inventory   # preview deployment plan
bash scripts/install.sh               # deploy all components
```

### Create a ticket

```bash
kallax ticket:create "Implement Redis caching layer" --type feature --priority P1
```

### Run 5-Level Verify

```bash
kallax verify l1 TICKET-001   # git log SHA
kallax verify l2 TICKET-001   # raw test stdout
kallax verify l3 TICKET-001   # 4-expert wiring
kallax verify l4 TICKET-001   # master review (cross-subagent)
kallax verify l5 TICKET-001   # boundary check
```

---

## Capabilities

### 6 Weapons (KALLAX独有的)

| # | Weapon | What it does |
|---|--------|--------------|
| W1 | Hash-Chain Audit Log | SHA256 chain prevents silent tampering |
| W2 | 5-Level Fact-Forcing | L1-L5 independent verification scripts |
| W3 | Sub-Role Dispatch | 4 sub-roles (coder/reviewer/tester/docs) per ticket |
| W4 | EPIC 4-Piece Suite | A+B review + README + lessons + signoff |
| W5 | Hook Server Replay | Multi-AI tool integration + replay endpoints |
| W6 | Web Dashboard | 1 page ≤ 500 LOC (XSS-safe) |

### 4 Roles

```
Conductor  — analyze / split / review / merge / publish
Performer  — coder / reviewer / tester / docs (4 sub-roles)
```

### 4-Branch Flow

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable)
   worktree                  UAT verify    integration     master review
```

Every commit must pass all 5 levels. No decorative claims without evidence.

---

## Showcases (EPIC-165)

Real governance traces with evidence:

| Case | Pattern | Version |
|------|---------|---------|
| [EPIC-069-D: check-claim-evidence](./docs/showcases/cases/EPIC-069-D-check-claim-evidence.md) | fact-forcing | v3.8.1 |
| [EPIC-152: Rule 34 bugfix repro](./docs/showcases/cases/EPIC-152-rule-34-bugfix-repro.md) | canary chain | v3.31.0 |
| [EPIC-155: 4-branch bypass retro](./docs/showcases/cases/EPIC-155-4branch-bypass-retro.md) | retro remediation | v3.31.1 |
| [EPIC-157: expert binding 4-field](./docs/showcases/cases/EPIC-157-expert-binding.md) | metric wiring | v3.32.2 |
| [EPIC-158: sqlite skipIf CI debt](./docs/showcases/cases/EPIC-158-sqlite-skipif.md) | debt cleanup | v3.32.3 |
| [EPIC-160: install.sh Omnibus](./docs/showcases/cases/EPIC-160-install-omnibus.md) | framework distribution | v3.32.5 |
| [EPIC-161: retrospective-routine.sh](./docs/showcases/cases/EPIC-161-retrospective-routine.md) | periodic review | v3.32.6 |

Catalog: [docs/showcases/README.md](./docs/showcases/README.md)

---

## Docs Index

| Doc | Description |
|-----|-------------|
| [CLAUDE.md](./CLAUDE.md) | 160-line governance rules (Chinese) |
| [docs/showcases/README.md](./docs/showcases/README.md) | 7 real governance traces |
| [docs/i18n/README.md](./docs/i18n/README.md) | EN/CN sync rules |
| [docs/reference/branch-flow-history.md](./docs/reference/branch-flow-history.md) | 4-branch flow evolution |
| [docs/reference/cli-reference-2026-06-19.md](./docs/reference/cli-reference-2026-06-19.md) | 30-command cheatsheet |
| [docs/reference/slash-commands-2026-06-19.md](./docs/reference/slash-commands-2026-06-19.md) | /kallax-* commands |
| [docs/reference/installation-2026-08-03.md](./docs/reference/installation-2026-08-03.md) | install.sh Omnibus ref |
| [docs/reference/retrospective-routine-2026-08-03.md](./docs/reference/retrospective-routine-2026-08-03.md) | 6-stage routine ref |
| [CHANGELOG.md](./CHANGELOG.md) | release history with raw_output refs |

---

## Architecture

```
┌────────────────────────────────────────────┐
│  KALLAX v3.32 Multi-Agent Layer            │
│  Conductor + Performer (4 sub-roles)       │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  6 Weapons Layer                           │
│  Hash-Chain / 5-Level / Sub-Role /         │
│  EPIC-4-Piece / Hook-Server / Dashboard    │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Rust Core (~5ms startup)                  │
│  Axum HTTP API (:9877)                     │
└────────────────────────────────────────────┘
```

---

## License

MIT — see [LICENSE](./LICENSE)
