# EPIC-160: install.sh Omnibus — 95 files, --inventory + --update + 3 skip flags

> **Pattern**: framework distribution | **Version**: v3.32.5 | **Status**: done

## Summary

install.sh upgraded to deploy all framework components (commands/rules/experts/skills/hooks) — from ~50% coverage to 95 files. New `--inventory` flag (transparent by design per EPIC-069-D), `--update` flag for upgrade mode, 3 skip flags.

## Ticket Chain

```json
{
  "ticket_id": "EPIC-160",
  "epic": "EPIC-160",
  "title": "install.sh Omnibus — framework 全部件 deploy + update",
  "status": "done",
  "priority": "P1",
  "type": "feature",
  "created_at": "2026-08-03",
  "worktree_role": "performer",
  "labels": ["feature", "install", "omnibus", "deployment"],
  "rule_references": ["EPIC-069-D (check-claim-evidence — 透明可验证)", "EPIC-159 (.claude/rules/*.md)"]
}
```

Source: `jira/tickets/EPIC-160/ticket.json`

## Before vs After

| Aspect | Before EPIC-160 | After EPIC-160 |
|--------|-----------------|----------------|
| Coverage | ~50% (commands/skills/settings) | **95 files** (all components) |
| rules/ | 0 install | 5 files (EPIC-159 + installation.md) |
| experts/ | 0 install | 5 files (4 .md + 1 .yml index) |
| hooks/ | referenced but not copied | 2 files (post-edit + UserPromptSubmit) |
| skills/kallax sub-modules | 0 install | 12 files |
| skills/caveman/ | 0 install | 5 files |
| Update mode | not supported | `--update` flag (symlink mode) |
| Inventory | not available | `--inventory` flag (source→target map) |
| Skip flags | 3 (--skip-cli/skills/commands) | **6** (+ rules/experts/hooks) |

## New Flags

```bash
# List deployment plan (transparent per EPIC-069-D)
bash scripts/install.sh --inventory
# → source→target mapping table (≥40 files)

# Upgrade existing installation (symlink mode, no user file overwrite)
bash scripts/install.sh --update

# Partial install (opt-in skip)
bash scripts/install.sh --skip-rules --skip-experts --skip-hooks
```

## 5-Level Verify Output

```
L1: git log --oneline EPIC-160 → dac6085 feat(install): EPIC-160 install.sh Omnibus
L2: npm run build → exit 0
L3: vitest run → Test Files 5 passed / Tests 103 passed
L4: tests/integration/install-omnibus.test.sh → 13/13 PASS
L5: check-claim-evidence.sh → exit 0 (CHANGELOG [3.32.5] has raw_output refs)
```

Raw test output:
```
bash tests/integration/install-omnibus.test.sh
→ EPIC-160 Install Omnibus Tests: 13 passed, 0 failed
```

## 4-Branch Flow Trajectory

```
feature/v3.32.5-EPIC-160 → testing → main → miao
dac6085 feat(install): EPIC-160 install.sh Omnibus — 全部件 deploy + update (v3.32.5)
29a9e55 feat(install): EPIC-160 install.sh Omnibus — 全部件 deploy + update (v3.32.5) (#189)
```

## Master Decision Record

**Date**: 2026-08-03
**Decision**: "kallax 里的 command、rules、experts…等等都是框架的一部分, 在新环境 onboarding 以及 update 的时候都应该一并部署和升级."

**Key lesson**: Framework consistency requires consistent deployment, not just consistent code.

## Evidence Links

- Ticket: `jira/tickets/EPIC-160/ticket.json`
- Script: `scripts/install.sh`
- Test: `tests/integration/install-omnibus.test.sh`
- Ref: `docs/reference/installation-2026-08-03.md`
