# EPIC-022-E: Integration Test + 5-Expert A+B Review

## Acceptance Criteria

1. **Integration tests**
   - Full 5-role workflow
   - Role transition FSM validation
   - Workspace switch integration

2. **E2E tests**
   - Session lifecycle (create→assign→complete→close)
   - Cross-role interaction scenarios
   - Error path coverage

3. **5-expert review**
   - Module A (roles) reviewed by expert in B (hooks)
   - Module B (hooks) reviewed by expert in A (roles)
   - Cross-pollination review comments

4. **CI pipeline**
   - All tests pass
   - Coverage threshold met
   - Lint checks pass

## File Scope

- `tests/integration/*.test.ts`
- `tests/e2e/*.test.ts`
- `tests/roles/integration*.test.ts`

## Dependencies

- EPIC-022-A, EPIC-022-B, EPIC-022-C, EPIC-022-D (all prior phases)

## Estimation

- 5 days (40 hours)