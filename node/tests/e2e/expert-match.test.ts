/**
 * Expert Matcher E2E tests.
 */
import { describe, it, expect } from 'vitest';
import { createExpertMatcher } from '../../src/core/expert-matcher.js';
import type { ExpertMatcher, AgentProfile } from '../../src/core/expert-matcher.js';

function makeProfile(overrides: Partial<AgentProfile> & { performerId: string }): AgentProfile {
  return {
    capabilities: [], completedTasks: 0, successRate: 1.0, avgCompletionTimeMs: 0,
    preferredLanguages: [], specializedDomains: [], recentTaskIds: [],
    ...overrides,
  };
}

describe('ExpertMatcher', () => {
  let matcher: ExpertMatcher;
  beforeEach(() => { matcher = createExpertMatcher(); });

  it('scores agents by capability match', () => {
    matcher.addAgentProfile(makeProfile({ performerId: 'ts-expert', capabilities: ['typescript', 'node', 'react'], specializedDomains: ['frontend'] }));
    matcher.addAgentProfile(makeProfile({ performerId: 'py-expert', capabilities: ['python', 'django', 'ml'], specializedDomains: ['data'] }));

    const results = matcher.findBestMatch(['typescript', 'react'], 'frontend');
    expect(results.length).toBe(2);
    expect(results[0]!.performerId).toBe('ts-expert');
    expect(results[0]!.totalScore).toBeGreaterThan(results[1]!.totalScore);
  });

  it('updates success rate from task history', () => {
    matcher.addAgentProfile(makeProfile({ performerId: 'agent-a' }));
    matcher.updateAgentStats('agent-a', { performerId: 'agent-a', taskId: 't1', success: true, durationMs: 100 });
    matcher.updateAgentStats('agent-a', { performerId: 'agent-a', taskId: 't2', success: false, durationMs: 200 });

    const profile = matcher.getAgentProfile('agent-a');
    expect(profile).toBeDefined();
    expect(profile!.successRate).toBe(0.5);
    expect(profile!.completedTasks).toBe(2);
  });

  it('filters by available agents', () => {
    matcher.addAgentProfile(makeProfile({ performerId: 'a1', capabilities: ['ts'] }));
    matcher.addAgentProfile(makeProfile({ performerId: 'a2', capabilities: ['ts'] }));
    matcher.addAgentProfile(makeProfile({ performerId: 'a3', capabilities: ['py'] }));

    const results = matcher.findBestMatch(['ts'], undefined, ['a1', 'a2']);
    expect(results.length).toBe(2);
    expect(results.every(r => ['a1','a2'].includes(r.performerId))).toBe(true);
  });

  it('scores empty capability requirements evenly', () => {
    matcher.addAgentProfile(makeProfile({ performerId: 'a1', specializedDomains: ['web'] }));
    matcher.addAgentProfile(makeProfile({ performerId: 'a2', specializedDomains: ['web'] }));
    const results = matcher.findBestMatch([]);
    expect(results.length).toBe(2);
  });
});
