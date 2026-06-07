# EPIC-022-B: Pre-commit Hook + Conductor Scope Check

## Acceptance Criteria

1. **pre-commit hook**
   - Block write operations on miao branch
   - Allow read-only operations only
   - Exit with error on attempted writes

2. **conductor scope check**
   - Verify task assignment within conductor permissions
   - Scope: feature branch creation, worktree management
   - Reject out-of-scope operations

## File Scope

- `src/hooks/pre-commit.ts`
- `src/hooks/conductor-scope-check.ts`
- `tests/hooks/*.test.ts`

## Dependencies

- EPIC-022-A (role definitions required)

## Estimation

- 3 days (24 hours)