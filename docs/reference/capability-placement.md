# Capability And Extension Placement Decision Tree

> **EPIC-175**: 借鉴 loopx `docs/reference/extensions.md` 1:1
> **Version**: 1.0.0 | **Date**: 2026-08-05

---

## Overview

This document defines the decision tree for placing capabilities and extensions in the KALLAX architecture. Follow this tree when adding new functionality to determine the correct placement.

---

## Decision Tree

```
Question 1: Is this a capability or extension?
├── YES → Continue
└── NO → Built-in (skip to §5)

Question 2: Does it have a stable, well-defined interface?
├── YES → Question 3
└── NO → Extension Provider (skip to §4)

Question 3: Is it essential to core KALLAX operation?
├── YES → Built-in (skip to §5)
└── NO → Continue

Question 4: Is it a name-based lookup?
├── YES → Name-based Extension (§1)
└── NO → Continue

Question 5: Does it extend an existing capability?
├── YES → Extend Pattern (§2)
└── NO → Continue

Question 6: Does it provide a new capability to external consumers?
├── YES → Extension Provider (§4)
└── NO → Continue

Question 7: Is it a stable, internal implementation detail?
└── YES → Built-in (§5)
```

---

## 1. Name-Based Extension

**Use when**: Capability is discovered by name lookup (e.g., expert plugins, skill packages).

**Placement**: `external/kallax-experts/` or `.claude/skills/<name>/`

**Pattern**:
```
.capability/
├── SKILL.md           # Primary interface
├── .kallax-scope      # File scope marker
└── agents/            # Optional agent definitions
    └── *.md
```

**Examples**:
- Expert plugins: `architect/`, `backend/`, `frontend/`
- Skill packages: `kallax/`, `caveman/`

**Pros**: Dynamic discovery, runtime loading
**Cons**: Name collision risk, interface stability

---

## 2. Extend Pattern

**Use when**: New capability extends an existing one (e.g., adding validation to existing gate).

**Placement**: Extend the existing file in place, or add `*-extended.md` sibling.

**Pattern**:
```
Existing/
├── index.md           # Original capability
└── index-extended.md  # Extension (if complex)
```

**Examples**:
- Adding new check to existing verify script
- Extending tier-router with new tier

**Pros**: Minimal duplication, clear inheritance
**Cons**: Tight coupling, potential conflicts

---

## 3. Built-in Pattern

**Use when**: Capability is stable, essential, and internal.

**Placement**: Core source code (`node/src/`, `rust/src/`)

**Pattern**:
```
core/
├── src/
│   ├── module/
│   │   └── capability.ts
│   └── index.ts
└── tests/
    └── capability.test.ts
```

**Examples**:
- Ticket schema validation (EPIC-157)
- Hash-chain audit (EPIC-072)
- Quota management (EPIC-166)

**Pros**: Type safety, compile-time checks
**Cons**: Requires recompilation, less flexible

---

## 4. Extension Provider Pattern

**Use when**: Capability is provided to external consumers via API/plugin.

**Placement**: `scripts/skill/` or `tools/`

**Pattern**:
```
scripts/
├── skill/
│   ├── skill-manager.sh    # Extension registry
│   └── skill-policy.sh     # Policy enforcement
└── skill-provider.sh       # Provider interface
```

**Examples**:
- Skill plugin system (EPIC-162, EPIC-170)
- Expert binding tracker (EPIC-157)

**Pros**: Clear public API, version stability
**Cons**: More boilerplate, backward compatibility concerns

---

## 5. Package Pattern

**Use when**: Capability is distributed as a standalone package.

**Placement**: Separate repository or `external/` submodule

**Pattern**:
```
external/
└── kallax-experts/         # Submodule
    ├── architect/
    ├── backend/
    └── ...
```

**Examples**:
- `kallax-experts` submodule (EPIC-167)
- External tool integrations

**Pros**: Independent versioning, clear boundaries
**Cons**: Submodule complexity, sync overhead

---

## Decision Matrix

| Criterion | Name | Extend | Built-in | Provider | Package |
|-----------|------|--------|----------|----------|---------|
| Stability | Medium | High | Highest | High | Medium |
| Flexibility | High | Low | Low | Medium | High |
| Coupling | Low | High | Highest | Medium | Low |
| Versioning | None | Tied | Tied | Independent | Independent |
| Discovery | Dynamic | Static | Static | Dynamic | Dynamic |

---

## Common Patterns in KALLAX

| Capability | Placement | Rationale |
|------------|-----------|-----------|
| Ticket schema | Built-in | Core, stable, type-checked |
| Expert plugins | Name | Runtime discovery |
| Skill system | Provider | Public API, versioning |
| Heartbeat daemon | Built-in | Core orchestration |
| Capability gate | Built-in | Core security |
| Benchmark smoke | Built-in | Quality gate |

---

## References

- [loopx extensions.md](https://github.com/godlockin/loopx/blob/main/docs/reference/extensions.md)
- `./skill-plugin-2026-08-05.md`
- [EPIC-170 Expert Plugin Complete](./skill-plugin-complete-2026-08-05.md)
- `./epic-175-security-extended-2026-08-05.md`
