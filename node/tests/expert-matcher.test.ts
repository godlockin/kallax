import { describe, it, expect, beforeEach } from 'vitest';
import { createExpertMatcher } from '../src/core/expert-matcher.js';
import type { AgentProfile } from '../src/core/expert-matcher.js';

describe('ExpertMatcher', () => {
  let matcher: ReturnType<typeof createExpertMatcher>;

  const profiles: AgentProfile[] = [
    { performerId: 'agent-1', capabilities: ['typescript', 'react'], completedTasks: 50, successRate: 0.95, avgCompletionTimeMs: 3000, preferredLanguages: ['ts', 'js'], specializedDomains: ['frontend'], recentTaskIds: [] },
    { performerId: 'agent-2', capabilities: ['python', 'ml'], completedTasks: 30, successRate: 0.85, avgCompletionTimeMs: 5000, preferredLanguages: ['python'], specializedDomains: ['ml', 'data'], recentTaskIds: [] },
    { performerId: 'agent-3', capabilities: ['rust', 'systems'], completedTasks: 20, successRate: 0.98, avgCompletionTimeMs: 2000, preferredLanguages: ['rust'], specializedDomains: ['systems', 'performance'], recentTaskIds: [] },
  ];

  beforeEach(() => {
    matcher = createExpertMatcher();
    for (const p of profiles) matcher.addAgentProfile(p);
  });

  it('finds best match for frontend task', () => {
    const matches = matcher.findBestMatch(['typescript', 'react'], 'frontend');
    expect(matches.length).toBeGreaterThan(0);
    expect(matches[0]?.performerId).toBe('agent-1');
  });

  it('finds best match for ML task', () => {
    const matches = matcher.findBestMatch(['python', 'ml'], 'ml');
    expect(matches.length).toBeGreaterThan(0);
    expect(matches[0]?.performerId).toBe('agent-2');
  });

  it('returns results even for unknown capability (low scores)', () => {
    const matches = matcher.findBestMatch(['cobol', 'fortran']);
    expect(matches.length).toBeGreaterThan(0);
    // Unknown capability → capabilityMatch dimension is 0.
    // Baseline availability/success are still non-zero, so totalScore > 0
    // but capabilityMatch specifically must be 0.
    for (const m of matches) expect(m.breakdown.capabilityMatch).toBe(0);
  });

  it('scores breakdown includes all dimensions', () => {
    const matches = matcher.findBestMatch(['typescript']);
    expect(matches.length).toBeGreaterThan(0);
    const top = matches[0]!;
    expect(top.breakdown.capabilityMatch).toBeGreaterThanOrEqual(0);
    expect(top.breakdown.successRate).toBeGreaterThanOrEqual(0);
    expect(top.breakdown.domainExpertise).toBeGreaterThanOrEqual(0);
    expect(top.breakdown.availability).toBeGreaterThanOrEqual(0);
  });

  it('updates agent stats after task completion', () => {
    matcher.updateAgentStats('agent-1', { performerId: 'agent-1', taskId: 't1', success: true, durationMs: 2500, domain: 'frontend' });
    const matches = matcher.findBestMatch(['typescript'], 'frontend');
    expect(matches.length).toBeGreaterThan(0);
  });

  it('filters by available agents', () => {
    const matches = matcher.findBestMatch(['typescript', 'react'], undefined, ['agent-1', 'agent-3']);
    expect(matches.every(m => ['agent-1', 'agent-3'].includes(m.performerId))).toBe(true);
  });
});
