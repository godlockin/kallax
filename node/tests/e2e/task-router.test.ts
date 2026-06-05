import { describe, it, expect } from 'vitest';
import { routeTask } from '../../src/core/task-router.js';

describe('TaskRouter', () => {
  it('routes simple typo fix to direct strategy', () => {
    const r = routeTask('Fix typo in README');
    expect(r.isOk()).toBe(true);
    expect(r.value.decision.strategy).toBe('direct');
  });

  it('routes simple rename to direct strategy', () => {
    const r = routeTask('Rename variable in src/utils/helper.ts');
    expect(r.isOk()).toBe(true);
    expect(r.value.decision.strategy).toBe('direct');
  });

  it('routes multi-tech complex requirement to valid strategy', () => {
    const r = routeTask('Implement auth with TypeScript JWT PostgreSQL React Docker CI/CD');
    expect(r.isOk()).toBe(true);
    expect(['direct', 'panel']).toContain(r.value.decision.strategy);
  });

  it('panel route includes architect', () => {
    const r = routeTask('Design distributed task scheduler Rust async SQLite REST API');
    expect(r.isOk()).toBe(true);
    if (r.value.decision.strategy === 'panel') {
      expect(r.value.decision.panel.required).toContain('architect');
    }
  });

  it('direct route has performer capabilities', () => {
    const r = routeTask('Add tests for SQLite ticket operations module');
    expect(r.isOk()).toBe(true);
    expect(r.value.decision.suggestedPerformer.capabilities.length).toBeGreaterThan(0);
  });

  it('returns valid complexity score for any input', () => {
    const r = routeTask('Fix critical security bug in auth module');
    expect(r.isOk()).toBe(true);
    expect(r.value.decision.complexity.score).toBeGreaterThanOrEqual(0);
    expect(r.value.confidence).toBeGreaterThan(0);
  });
});
