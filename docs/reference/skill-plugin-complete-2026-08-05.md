# Skill Plugin Complete — EPIC-170 Reference

> **Date**: 2026-08-05
> **EPIC**: EPIC-170
> **Status**: Implemented

## Overview

EPIC-170 completes the plugin 化 of 9 expert skill packages (default + extended), following the loopx 6-skill pattern. Each expert is now a self-contained plugin with enabled_policy configuration and 5-step activation gates.

## Architecture

### Expert Skill Packages

| Expert | Tier | Default Policy | Trigger Keywords |
|--------|------|----------------|------------------|
| architect | default | default | 架构,边界,选型,模块,API契约 |
| backend | default | default | API,接口慢,数据库,SQL,缓存 |
| frontend | default | default | 页面卡,渲染慢,组件,React |
| pm | default | default | 跨团队,任务规划,协调,风险 |
| product | default | default | 优先级,需求,价值,ROI |
| security | default | enabled | 安全,注入,越权,XSS |
| ux | default | default | 交互,体验差,旅程,可用性 |
| auditor | extended | enabled | audit,verify,compliance |
| process-engineering | extended | default | process,governance,workflow |

### enabled_policy Values

| Value | Behavior |
|-------|----------|
| `default` | Enabled at startup, inherits from file frontmatter |
| `enabled` | Always enabled regardless of persistence |
| `disabled` | Always disabled, override any other setting |
| `owner-gated` | Requires owner file + explicit authorization |

### Policy Resolution Priority

1. Persisted policy from `state/skill-policy.json` (if not "default")
2. `enabled_policy` frontmatter in skill file
3. Default value: "default"

## 5-Step Activation Gates

### Gate 1: resolve_project
- **Check**: `.kallax/state/state.json` exists
- **Purpose**: Confirm valid KALLAX project context
- **Fail**: Exit with error

### Gate 2: confirm_todo
- **Check**: `jira/tickets/` has in_progress ticket
- **Purpose**: Confirm active work context
- **Warn**: Return code 2 (continues)

### Gate 3: check_boundary
- **Check**: Current file in ticket `file_scope`
- **Purpose**: Confirm work within defined scope
- **Skip**: Return 0 if no file context

### Gate 4: architecture_check
- **Check**: `.kallax/experts/INDEX.md` exists
- **Purpose**: Confirm expert index available
- **Fail**: Exit with error

### Gate 5: owner_gated
- **Check**: Owner file exists (only for owner-gated policy)
- **Purpose**: Confirm owner authorization
- **Skip**: Return 0 if not owner-gated policy

## Scripts

### skill-policy.sh

```bash
bash scripts/skill/skill-policy.sh <command> [expert]

Commands:
  enable <expert>      Enable an expert skill package
  disable <expert>     Disable an expert skill package
  list                List all expert policies
  check <expert>      Check if expert is enabled
  reset               Reset all policies to default
```

### skill-manager.sh

```bash
bash scripts/skill/skill-manager.sh <command> [expert]

Commands:
  list                List all expert skill packages
  status <expert>     Show expert status (policy + enabled_policy)
  enable <expert>     Enable expert (persist to policy.json)
  disable <expert>    Disable expert (persist to policy.json)
  validate <expert>   Validate 5 activation gates for expert
  check-gates         Check all experts' activation gates
  activation-gates    Show 5-step activation gate documentation
```

## Policy Persistence

Policies persist to:
```
.kallax/state/skill-policy.json
```

Schema:
```json
{
  "version": "1.0.0",
  "policies": {
    "architect": "enabled",
    "backend": "default",
    ...
  },
  "updated_at": "2026-08-05T12:00:00Z"
}
```

## Integration with 5-Level Verify

The auditor expert uses activation gates for L4 independent witness verification:
1. Gate1 ensures valid project context
2. Gate4 ensures expert index available
3. Gate5 ensures authorization (for owner-gated policies)

## Cross-Reference with EPIC-162

EPIC-170 builds on EPIC-162's 9-expert split:
- EPIC-162: Structural separation (1 expert 1 file)
- EPIC-170: Plugin capability (enabled_policy + activation gates)

## Related Documents

- `.kallax/experts/INDEX.md` — Expert symptom decision tree
- `.kallax/experts/default/*.md` — Default tier expert files
- `.kallax/experts/extended/*.md` — Extended tier expert files
- `scripts/skill/skill-manager.sh` — Main skill manager
- `scripts/skill/skill-policy.sh` — Policy persistence
