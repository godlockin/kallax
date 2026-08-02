/**
 * EPIC-157 — ticket.json ExpertBindingSchema unit tests
 *
 * 覆盖 (per AC2 + AC7):
 *   1. ExpertBindingSchema accepts valid {suggested=actual} (no reason required)
 *   2. ExpertBindingSchema accepts valid divergent with reason
 *   3. ExpertBindingSchema rejects divergent WITHOUT reason
 *   4. ExpertBindingSchema rejects expert name not in pool
 *   5. ExpertBindingSchema accepts custom:<name>
 *   6. TicketSchema backward compat: legacy ticket without expert_binding still valid
 *   7. TicketSchema with expert_binding.valid passes
 */

import { describe, it, expect } from 'vitest';
import { ExpertBindingSchema, TicketSchema } from '../../src/core/schema-validator.js';

describe('EPIC-157 ExpertBindingSchema', () => {
  it('accepts consistent binding (suggested=actual)', () => {
    const result = ExpertBindingSchema.safeParse({
      suggested_expert: 'backend',
      actual_expert: 'backend',
      expert_binding_at: '2026-08-02T14:45:00Z',
    });
    expect(result.success).toBe(true);
  });

  it('accepts divergent binding with reason', () => {
    const result = ExpertBindingSchema.safeParse({
      suggested_expert: 'backend',
      actual_expert: 'frontend',
      expert_binding_at: '2026-08-02T14:45:00Z',
      binding_change_reason: 'scope spans both backend and frontend',
    });
    expect(result.success).toBe(true);
  });

  it('rejects divergent binding without reason', () => {
    const result = ExpertBindingSchema.safeParse({
      suggested_expert: 'backend',
      actual_expert: 'frontend',
      expert_binding_at: '2026-08-02T14:45:00Z',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      const issuePaths = result.error.issues.map((i) => i.path.join('.'));
      expect(issuePaths).toContain('binding_change_reason');
    }
  });

  it('rejects expert name not in pool (and not custom:)', () => {
    const result = ExpertBindingSchema.safeParse({
      suggested_expert: 'random-nonexistent-expert',
    });
    expect(result.success).toBe(false);
  });

  it('accepts custom:<name> namespace', () => {
    const result = ExpertBindingSchema.safeParse({
      suggested_expert: 'custom:my-specialist',
      actual_expert: 'custom:my-specialist',
      expert_binding_at: '2026-08-02T14:45:00Z',
    });
    expect(result.success).toBe(true);
  });

  it('rejects invalid ISO8601 timestamp', () => {
    const result = ExpertBindingSchema.safeParse({
      actual_expert: 'backend',
      expert_binding_at: 'not-a-date',
    });
    expect(result.success).toBe(false);
  });
});

describe('EPIC-157 TicketSchema backward compat', () => {
  it('accepts legacy ticket without expert_binding', () => {
    const result = TicketSchema.safeParse({
      id: 'EPIC-100',
      epicId: 'EPIC-100',
      phaseId: 'PHASE-018',
      title: 'legacy ticket',
      type: 'feature',
      priority: 'P2',
      status: 'done',
      created_by: 'master',
      created_at: '2026-01-01',
      acceptance_criteria: [],
    });
    expect(result.success).toBe(true);
  });

  it('accepts new ticket with valid expert_binding', () => {
    const result = TicketSchema.safeParse({
      id: 'EPIC-157',
      epicId: 'EPIC-157',
      phaseId: 'PHASE-018',
      title: 'EPIC-157 ticket',
      type: 'feature',
      priority: 'P1',
      status: 'in_progress',
      created_by: 'master',
      created_at: '2026-08-02',
      acceptance_criteria: [],
      expert_binding: {
        suggested_expert: 'backend',
        actual_expert: 'backend',
        expert_binding_at: '2026-08-02T14:45:00Z',
      },
    });
    expect(result.success).toBe(true);
  });

  it('rejects ticket with divergent expert_binding lacking reason', () => {
    const result = TicketSchema.safeParse({
      id: 'EPIC-157-X',
      epicId: 'EPIC-157',
      phaseId: 'PHASE-018',
      title: 'invalid binding',
      type: 'feature',
      priority: 'P1',
      status: 'in_progress',
      created_by: 'master',
      created_at: '2026-08-02',
      acceptance_criteria: [],
      expert_binding: {
        suggested_expert: 'backend',
        actual_expert: 'frontend',
        expert_binding_at: '2026-08-02T14:45:00Z',
        // binding_change_reason 缺失
      },
    });
    expect(result.success).toBe(false);
  });
});