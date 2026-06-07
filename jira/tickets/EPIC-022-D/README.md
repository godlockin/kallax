# EPIC-022-D: Role Transition (Master/Conductor/Performer)

## Acceptance Criteria

1. **master role**
   - Full permissions + decision authority
   - Approve/reject all role transitions
   - Emergency override capabilities

2. **conductor role**
   - Coordination + review authority
   - Task assignment within scope
   - Merge approval for testing→miao

3. **performer role**
   - Development execution rights
   - Worktree creation/deletion
   - Submit PR to feature branches

4. **FSM state transitions**
   - Secure transition validation
   - Audit all role changes
   - Prevent invalid state jumps

## File Scope

- `src/roles/transition.ts`
- `src/roles/master.ts`
- `src/roles/conductor.ts`
- `src/roles/performer.ts`
- `tests/roles/transition*.test.ts`

## Dependencies

- EPIC-022-C (workspace switch prerequisite)

## Estimation

- 3 days (24 hours)