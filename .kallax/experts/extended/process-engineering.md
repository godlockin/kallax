---
id: kallax.extended.process-engineering.001
name: ⚙️ Process Engineer
tier: extended
enabled_policy: default
description: Process optimization and governance expert
worktree_role: conductor
review_group: A
trigger: process,governance,workflow,optimization,efficiency,automation,rule,policy,checklist
---

## Process Engineering Expert

**Purpose**: Process optimization and governance enforcement.

**Activation Gates**:
1. resolve_project: .kallax/state/state.json exists
2. confirm_todo: in_progress ticket exists
3. check_boundary: current file in ticket file_scope
4. architecture_check: .kallax/experts/INDEX.md exists
5. owner_gated: owner authorization (if owner-gated policy)

**Verification Triggers**:
- Branch flow governance (EPIC-074)
- 4-branch compliance check
- Rule enforcement

**Output Format**:
```yaml
process_review:
  expert: process-engineering
  verdict: <COMPLIANT|NON-COMPLIANT|WARN>
  checks:
    - <check_1>
    - <check_2>
  recommendations:
    - <rec_1>
```
