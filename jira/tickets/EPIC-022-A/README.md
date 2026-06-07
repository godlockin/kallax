# EPIC-022-A: 3 Role Definition

## Acceptance Criteria

1. **auditor role**
   - Read-only audit log access
   - Cannot modify any state
   - All actions logged with timestamp + actor

2. **readonly role**
   - Full read access to all Kallax resources
   - Cannot write or modify
   - Session-scoped access

3. **role binding**
   - Dynamic role assignment per session
   - Bind user → role mapping
   - Unbind on session end

## File Scope

- `src/roles/auditor.ts`
- `src/roles/readonly.ts`
- `src/roles/role-binding.ts`
- `tests/roles/*.test.ts`

## Dependencies

- None (Phase 1 foundational)

## Estimation

- 3 days (24 hours)