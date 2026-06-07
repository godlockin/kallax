# EPIC-022-C: Workspace Switch + Read-only Path

## Acceptance Criteria

1. **workspace switch**
   - Dynamic worktree context switching
   - Auto-detect active worktree
   - Session-aware workspace binding

2. **read-only path**
   - Protect critical paths (miao, testing)
   - Force read-only on protected branches
   - Audit trail for read attempts

3. **conductor auto-switch**
   - Auto-switch workspace on role change
   - Maintain session state consistency

## File Scope

- `src/workspace/switch.ts`
- `src/workspace/readonly-path.ts`
- `tests/workspace/*.test.ts`

## Dependencies

- EPIC-022-B (hook + scope check prerequisite)

## Estimation

- 4 days (32 hours)