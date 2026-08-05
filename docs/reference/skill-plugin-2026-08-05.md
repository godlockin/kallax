# Skill Plugin System — EPIC-162 (v3.32.7)

> **Date**: 2026-08-05
> **EPIC**: EPIC-162 — Skill plugin architecture (同仓库 plugin, 跟 EPIC-167 submodule 双层)

## Overview

KALLAX skill plugin system借鉴 loopx skill体系, 把 monolith skill 拆成 9 个独立 plugin 包, 支持:
- 独立 install/uninstall/enable/disable
- cross-host surface 抽象 (codex/claude-code/opencode/cursor)
- activation gate 5 步验证
- 跟 EPIC-167 submodule 双层升级粒度

## Skill Packages (9 Expert)

| Expert | Path | Scope |
|--------|------|-------|
| architect | `.claude/skills/kallax-experts/architect/` | architecture-design |
| backend | `.claude/skills/kallax-experts/backend/` | backend-development |
| frontend | `.claude/skills/kallax-experts/frontend/` | frontend-development |
| ux | `.claude/skills/kallax-experts/ux/` | ux-research-design |
| product | `.claude/skills/kallax-experts/product/` | product-planning |
| security-tool-bypass | `.claude/skills/kallax-experts/security-tool-bypass/` | security-analysis |
| process-engineering | `.claude/skills/kallax-experts/process-engineering/` | process-optimization |
| auditor | `.claude/skills/kallax-experts/auditor/` | audit-verification |
| compliance | `.claude/skills/kallax-experts/compliance/` | compliance-governance |
| decision-gate | `.claude/skills/kallax-experts/decision-gate/` | decision-analysis |

## Package Structure

Each skill package follows loopx pattern:

```
kallax-experts/<role>/
  SKILL.md           # frontmatter with enabled_policy field
  .kallax-skill-scope # 8-byte scope marker (跟 loopx .loopx-skill-scope 1:1)
  agents/
    <role>.md        # agent role definition
```

## skill-manager.sh — 6+3 子命令

### Plugin Commands (EPIC-162)

```bash
# Install skill plugin
bash scripts/skill/skill-manager.sh install <skill-name> [--surface HOST]

# Show skill status
bash scripts/skill/skill-manager.sh status [skill-name]

# Uninstall skill
bash scripts/skill/skill-manager.sh uninstall <skill-name>

# List available skills
bash scripts/skill/skill-manager.sh list [--all]

# Check if skill is enabled
bash scripts/skill/skill-manager.sh enabled [skill-name]

# Disable skill
bash scripts/skill/skill-manager.sh disable <skill-name>
```

### Submodule Commands (EPIC-167)

```bash
# Initialize submodules
bash scripts/skill/skill-manager.sh submodule-init

# Update submodules
bash scripts/skill/skill-manager.sh submodule-update

# Show submodule status
bash scripts/skill/skill-manager.sh submodule-status
```

## Cross-Host Surface (AC6)

```bash
# Install for specific host
bash scripts/skill/skill-manager.sh install architect --surface codex
bash scripts/skill/skill-manager.sh install backend --surface claude-code
bash scripts/skill/skill-manager.sh install frontend --surface opencode
bash scripts/skill/skill-manager.sh install ux --surface cursor
```

Supported hosts:
- `codex` → `~/.codex/skills/`
- `claude-code` → `~/.claude/skills/`
- `opencode` → `~/.opencode/skills/`
- `cursor` → `~/.cursor/skills/`

## Activation Gate (AC8)

Installation triggers 5-step activation gate:

1. **Resolve project** — Identify project context
2. **Confirm todo** — Verify task boundary
3. **Check boundary** — Ensure scope isolation
4. **Architecture check** — Validate technical approach
5. **Owner-gated** — Confirm authorization

## enabled_policy Field (AC4)

SKILL.md frontmatter includes:

```yaml
---
name: kallax-expert-<role>
description: Expert description...
enabled_policy: true  # or false to disable
expert_role: <role>
scope: <scope-name>
---
```

Runtime checks `enabled_policy` before activation.

## install.sh Integration (AC7)

```bash
# Full install (includes skill plugins)
bash scripts/install.sh

# Skip skill plugins
bash scripts/install.sh --skip-skill

# Scan available skills
bash scripts/install.sh --scan-skill

# Install specific skill
bash scripts/install.sh --install-skill architect
```

## Backward Compatibility (AC12)

Main skill `/kallax-expert` path remains functional:
- `.claude/skills/kallax/SKILL.md` unchanged
- Expert fallback to monolith skill if plugin not found

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | PASS |
| 1 | FAIL |
| 2 | User error (invalid args) |

## Integration Tests

```bash
bash tests/integration/skill-plugin.test.sh
```

Expected: ≥10 test cases PASS covering install/status/uninstall/list/enabled/disable/cross-host/activation-gate/scope/backward-compat.

## Related EPICs

| EPIC | Relationship |
|------|--------------|
| EPIC-160 | install.sh Omnibus pattern |
| EPIC-161 | 6-subcommand pattern |
| EPIC-167 | Submodule dual-layer management |

## Reference

- loopx skill system: https://github.com/huangruiteng/loopx
- Gap analysis: `confluence/decisions/loopx-vs-kallax-skill-gap-2026-08-05.md`
