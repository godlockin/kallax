# KALLAX v3.32.15

> **K**nowledge-**A**ugmented **L**everaged **L**earning Agent e**X**ecutor

**Public Frontstage** | GitHub-hosted documentation and showcase

---

## Why KALLAX?

KALLAX is a **multi-agent collaboration framework** for AI-driven software development, featuring:

- **6 Weapons**: Hash-Chain Audit / 5-Level Fact-Forcing / Sub-Role Dispatch / EPIC 4-Piece / Hook Server / Dashboard
- **4-Branch Flow**: feature → testing → main → miao (production)
- **5-Level Verify**: L1 git → L2 stdout → L3 4-expert → L4 independent → L5 boundary
- **3-Layer Fallback**: Rust (~5ms) → Node.js → Shell
- **Zero Decorations**: No fake metrics, no narrative wrapping — only raw evidence

### Compare: KALLAX vs Others

| Feature | KALLAX | Others |
|---------|--------|--------|
| Hash-Chain Audit | SHA256 chain | None |
| 5-Level Fact-Forcing | 5 independent scripts | Name-only rules |
| Sub-Role Dispatch | 4 sub-roles (coder/reviewer/tester/docs) | Single role |
| Decision Model | 5×4=25 cells, all verified | Unverified claims |
| Rust Core | ~5ms startup | N/A |

---

## Try It

```bash
# Clone
git clone https://github.com/godlockin/kallax.git
cd kallax

# Install (Rust + Node.js + dependencies)
bash scripts/install.sh

# Create ticket
kallax ticket:create "Implement feature X" --type feature --priority P1

# Claim + develop (in isolated worktree)
kallax ticket:claim TICKET-001
cd .worktrees/TICKET-001
# ... develop ...

# 5-Level Verify
kallax verify all TICKET-001

# Complete
kallax ticket:complete TICKET-001
```

---

## Capabilities

### Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              KALLAX v3.32.15 Multi-Agent Layer              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐│
│  │  Conductor   │  │ Performer    │  │ Sub-Role Dispatch  ││
│  │  (coordinate │  │ (coder/      │  │ (4 sub-roles)      ││
│  │   review/    │  │  reviewer/   │  │                    ││
│  │   merge)     │  │  tester/     │  │                    ││
│  │              │  │  docs)       │  │                    ││
│  └──────────────┘  └──────────────┘  └────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    6 Weapons Layer                           │
│  Weapon 1: Hash-Chain Audit Log (SHA256)                     │
│  Weapon 2: 5-Level Fact-Forcing (5 independent scripts)     │
│  Weapon 3: Sub-Role Dispatch (4 sub-roles)                 │
│  Weapon 4: EPIC 4-Piece (A+B review + readme + lessons)     │
│  Weapon 5: Hook Server Replay + Audit                       │
│  Weapon 6: Web Dashboard (≤500 LOC, XSS-safe)              │
└─────────────────────────────────────────────────────────────┘
```

### 4-Branch Flow Governance

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable)
   development               UAT         integration    production
```

Every PR must pass 5-Level Verify before merge.

### 5-Level Verify System

| Level | Check | Standard |
|-------|-------|----------|
| L1 | git log SHA | Real change, not empty commit |
| L2 | raw test stdout | `cargo test --workspace` 0 errors |
| L3 | 4-expert wiring | coder/reviewer/tester/docs connected |
| L4 | independent witness | Cross-subagent verification |
| L5 | boundary check | check-claim-evidence.sh |

---

## Documentation

| Doc | Description |
|-----|-------------|
| `../README.md` | Chinese version (主文档) |
| [docs/showcases/](showcases/) | 7 case showcase catalog |
| [docs/i18n/](i18n/) | Internationalization sync rules |
| [docs/community/](community/) | Community channels (Lark/WeChat/GitHub) |
| [docs/sponsor/](sponsor/) | Sponsorship information |
| `../CONTRIBUTING.md` | Contribution guidelines |
| `../SECURITY.md` | Security policy |

### Quick Links

- `../docs/architecture/ARCHITECTURE.md`
- `../docs/process.md`
- `../docs/reference/cli-reference-2026-06-19.md`
- `../docs/phase-index.md`

---

## Community

### Join Us

| Channel | Link / Contact | Notes |
|---------|----------------|-------|
| **GitHub Issues** | [godlockin/kallax/issues](https://github.com/godlockin/kallax/issues) | Bug reports, feature requests |
| **GitHub Discussions** | [godlockin/kallax/discussions](https://github.com/godlockin/kallax/discussions) | Q&A, ideas |
| **Lark Group** | See [docs/community/](community/) | QR code placeholder |
| **WeChat** | huangrt00 | Add with note "KALLAX" |

### Showcase Catalog

7 real-world cases demonstrating KALLAX capabilities:

1. Epic-Driven Development
2. 5-Level Verify Pipeline
3. Multi-Agent Collaboration
4. Hash-Chain Audit Trail
5. Worktree Isolation
6. Decision Matrix
7. Skill Plugin System

See [docs/showcases/](showcases/) for details.

---

## Contributing

We welcome contributions! See `../CONTRIBUTING.md` for:

- Development environment setup
- Branch strategy (4-branch flow)
- Commit conventions (Conventional Commits)
- Pull Request workflow
- Code standards (TypeScript/Rust)

### Quick Start

```bash
# Fork + clone
git clone https://github.com/YOUR_HANDLE/kallax.git
cd kallax

# Create worktree
git worktree add -b feature/TASK-XXX .worktrees/TASK-XXX

# Develop in isolated worktree
cd .worktrees/TASK-XXX
# ... code ...

# 5-Level Verify before PR
kallax verify all TASK-XXX

# Submit PR to testing branch
gh pr create --base testing
```

---

## License

Apache License 2.0 — see [LICENSE](../LICENSE)

---

## Appendix A: 6 Weapons Deep Dive

### Weapon 1: Hash-Chain Audit Log

Every change is recorded with SHA256 hash chain:

```
commit_1 (SHA256) → commit_2 (SHA256) → commit_3 (SHA256) → ...
```

Benefits:
- Immutable audit trail
- Tamper-evident
- Forensics-ready

Implementation: `scripts/verify/hash-chain.sh`

### Weapon 2: 5-Level Fact-Forcing

No decorations, no fake metrics. Only raw evidence:

| Level | Evidence Required |
|-------|-------------------|
| L1 | git log shows real SHA change |
| L2 | raw test stdout, no "should work" |
| L3 | 4-expert wiring verified |
| L4 | independent cross-check |
| L5 | boundary check passed |

### Weapon 3: Sub-Role Dispatch

Single Conductor → Multiple Performers with 4 sub-roles:

| Sub-Role | Responsibility |
|----------|---------------|
| coder | Implementation |
| reviewer | Code review |
| tester | Test coverage |
| docs | Documentation |

### Weapon 4: EPIC 4-Piece

Every EPIC delivery includes:

1. **A+B Review** — Two independent reviewers
2. **README** — Clear usage documentation
3. **lessons** — What we learned
4. **signoff** — Explicit approval

### Weapon 5: Hook Server

Multi-AI tool integration with replay endpoints:

- `/hooks/replay` — Replay agent actions
- `/hooks/audit` — Audit trail
- Event store for forensics

### Weapon 6: Web Dashboard

Single-page dashboard, ≤500 LOC:

- XSS-safe (textContent, escape)
- Real-time updates
- System health visualization

---

## Appendix B: Architecture Details

### 3-Layer Fallback

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Rust Core (~5ms startup)                          │
│  - Event Bus                                                │
│  - DAG Scheduler                                            │
│  - Ticket Engine                                            │
│  - Agent Pool                                               │
│  - Axum HTTP API (:9877)                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (fallback if Rust unavailable)
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Node.js (~400ms startup)                          │
│  - Web Dashboard                                            │
│  - Hook Events Store                                        │
│  - 5-Level Scripts                                          │
│  - Decision Matrix                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (fallback if Node.js unavailable)
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Shell Scripts (~1s startup)                       │
│  - Basic ticket operations                                  │
│  - Git hooks                                                │
│  - Simple automation                                        │
└─────────────────────────────────────────────────────────────┘
```

### Decision Matrix (5×4=25 cells)

| Role \ Level | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |
|--------------|--------|-----------|-------------|----------------|-------------|
| **Conductor** | 自主 | 自主 | 推荐 | 主公拍 | 推荐 |
| **Performer/coder** | 自主 | 自主 | 推荐 | 主公拍 | 推荐 |
| **Performer/reviewer** | 自主 | 自主 | 自主 | 主公拍 | 推荐 |
| **Performer/tester** | 自主 | 自主 | 自主 | 主公拍 | 推荐 |
| **Performer/docs** | 自主 | 自主 | 推荐 | 主公拍 | 推荐 |

Legend:
- 自主 = Autonomous (AI can decide)
- 推荐 = Recommended (AI decides, but human can override)
- 主公拍 = Master must decide (cannot be delegated to AI)

---

## Appendix C: Comparison with Alternatives

### KALLAX vs Traditional CI/CD

| Aspect | Traditional CI/CD | KALLAX |
|--------|-------------------|--------|
| Verification | Build passes | 5-Level Verify |
| Metrics | Coverage % | Raw evidence only |
| Audit | Optional | SHA256 hash chain |
| Decision | Human only | 5×4 matrix |

### KALLAX vs Single-Agent Tools

| Aspect | Single-Agent | KALLAX |
|--------|---------------|--------|
| Capacity | 1x | 4x (sub-roles) |
| Review | Manual | Automated A+B |
| Documentation | Optional | Required |
| Isolation | None | Worktree per feature |

---

## Appendix D: Getting Help

### Resources

- [GitHub Issues](https://github.com/godlockin/kallax/issues) — Bug reports
- [GitHub Discussions](https://github.com/godlockin/kallax/discussions) — Q&A
- [docs/](docs/) — Full documentation
- [confluence/](confluence/) — Design decisions

### Community

| Channel | Contact |
|---------|---------|
| WeChat | huangrt00 (note "KALLAX") |
| Lark | See docs/community/ |

---

## Appendix: Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v3.32.15 | 2026-08-05 | Public path: README.en + frontstage + Lark/WeChat |
| v3.32.14 | 2026-08-05 | EPIC-168-BG: heartbeat daemon + dashboard metrics |
| v3.32.7-12 | 2026-08-05 | 6 EPIC loopx borrow + submodule + 6 sub-system |
| v3.32.6 | 2026-08-03 | EPIC-161: retrospective-routine.sh |
| v3.32.5 | 2026-08-03 | EPIC-160: install.sh Omnibus |
| v3.32.4 | 2026-08-02 | EPIC-159: CLAUDE.md ≤200 lines |

Full changelog: `../CHANGELOG.md`
