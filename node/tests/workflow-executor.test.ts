/**
 * Workflow Executor tests: state transitions, role validation, progress.
 */

import { describe, it, expect } from 'vitest';
import { createWorkflowExecutor } from '../src/core/workflow/executor.js';
import { FEATURE_DEV_TEMPLATE, PARALLEL_REVIEW_TEMPLATE } from '../src/core/workflow/templates.js';
import { WorkflowState, isValidTransition } from '../src/core/workflow/state-machine.js';

const executor = createWorkflowExecutor();

describe('WorkflowState', () => {
  it('isValidTransition allows pending to backlog', () => {
    expect(isValidTransition(WorkflowState.PENDING, WorkflowState.BACKLOG)).toBe(true);
  });

  it('isValidTransition rejects invalid transitions', () => {
    expect(isValidTransition(WorkflowState.PENDING, WorkflowState.DONE)).toBe(false);
  });

  it('isValidTransition allows review back to development', () => {
    expect(isValidTransition(WorkflowState.REVIEW, WorkflowState.DEVELOPMENT)).toBe(true);
  });
});

describe('WorkflowExecutor', () => {
  it('create returns instance with pending state', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, { ticketId: 'T-1' });
    expect(wi.currentState).toBe(WorkflowState.PENDING);
    expect(wi.ticketId).toBe('T-1');
    expect(wi.completedSteps).toEqual([]);
  });

  it('getNextSteps returns first step of template', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    const next = executor.getNextSteps(wi, FEATURE_DEV_TEMPLATE);
    expect(next.length).toBe(1);
    expect(next[0]?.name).toBe('triage');
  });

  it('canTransition returns true for correct role at correct state', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    expect(executor.canTransition(wi, FEATURE_DEV_TEMPLATE, 'conductor')).toBe(true);
  });

  it('canTransition returns false for wrong role', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    expect(executor.canTransition(wi, FEATURE_DEV_TEMPLATE, 'performer')).toBe(false);
  });

  it('executeTransition advances workflow state', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    const result = executor.transition(wi, FEATURE_DEV_TEMPLATE, 'conductor');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().currentState).toBe(WorkflowState.BACKLOG);
    expect(result._unsafeUnwrap().completedSteps).toContain('triage');
  });

  it('executeTransition rejects wrong role', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    const result = executor.transition(wi, FEATURE_DEV_TEMPLATE, 'performer');
    expect(result.isErr()).toBe(true);
  });

  it('executeTransition handles multi-step progression with role enforcement', () => {
    const wi = executor.create(FEATURE_DEV_TEMPLATE, {});
    const c = 'conductor'; const p = 'performer';
    const s1 = executor.transition(wi, FEATURE_DEV_TEMPLATE, c)._unsafeUnwrap();
    expect(s1.currentState).toBe(WorkflowState.BACKLOG);
    const s2 = executor.transition(s1, FEATURE_DEV_TEMPLATE, c)._unsafeUnwrap();
    expect(s2.currentState).toBe(WorkflowState.ANALYSIS);
    const s3 = executor.transition(s2, FEATURE_DEV_TEMPLATE, c)._unsafeUnwrap();
    expect(s3.currentState).toBe(WorkflowState.DESIGN);
    // develop step requires performer — conductor must fail
    const s4 = executor.transition(s3, FEATURE_DEV_TEMPLATE, c);
    expect(s4.isErr()).toBe(true);
    // But performer can do it
    const s4ok = executor.transition(s3, FEATURE_DEV_TEMPLATE, p);
    expect(s4ok.isOk()).toBe(true);
  });

  it('getProgress returns 0 for fresh instance', () => {
    const wi = executor.create(PARALLEL_REVIEW_TEMPLATE, {});
    const progress = executor.getProgress(wi, PARALLEL_REVIEW_TEMPLATE);
    expect(progress).toBe(0);
  });

  it('getProgress increases after each step', () => {
    const wi = executor.create(PARALLEL_REVIEW_TEMPLATE, {});
    const advanced = executor.transition(wi, PARALLEL_REVIEW_TEMPLATE, 'conductor')._unsafeUnwrap();
    expect(executor.getProgress(advanced, PARALLEL_REVIEW_TEMPLATE)).toBeGreaterThan(0);
  });
});
