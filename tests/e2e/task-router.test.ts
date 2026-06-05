import { describe, it, expect } from 'vitest';
import { routeTask } from '../../src/core/task-router.js';

describe('TaskRouter', () => {
  it('routes simple typo to direct', () => {
    expect(routeTask('Fix typo in README').value!.decision.strategy).toBe('direct');
  });
  it('routes simple rename to direct', () => {
    expect(routeTask('Rename var in helper.ts').value!.decision.strategy).toBe('direct');
  });
  it('routes complex task to valid strategy', () => {
    expect(['direct','panel']).toContain(routeTask('Implement auth TypeScript JWT PostgreSQL React Docker').value!.decision.strategy);
  });
  it('panel route has architect', () => {
    const r = routeTask('Design distributed scheduler Rust async SQLite REST API');
    if (r.value!.decision.strategy === 'panel') expect(r.value!.decision.panel.required).toContain('architect');
  });
  it('direct route has caps', () => {
    expect(routeTask('Add tests for SQLite module').value!.decision.suggestedPerformer.capabilities.length).toBeGreaterThan(0);
  });
  it('returns valid complexity', () => {
    const r = routeTask('Fix critical bug in auth');
    expect(r.value!.decision.complexity.score).toBeGreaterThanOrEqual(0);
  });
});
