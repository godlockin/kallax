/**
 * KALLAX Expert Matcher — history-aware intelligent agent assignment.
 * Vision: framework autonomously assigns the right agent to the right task.
 */
import { ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface AgentProfile {
  performerId: string; capabilities: string[]; completedTasks: number;
  successRate: number; avgCompletionTimeMs: number;
  preferredLanguages: string[]; specializedDomains: string[];
  recentTaskIds: string[];
}

export interface TaskCompletionStats {
  performerId: string; taskId: string; success: boolean;
  durationMs: number; domain?: string;
}

export interface MatchScore {
  performerId: string; totalScore: number;
  breakdown: { capabilityMatch: number; successRate: number; domainExpertise: number; availability: number; };
}

export interface ExpertMatcher {
  addAgentProfile(profile: AgentProfile): void;
  updateAgentStats(performerId: string, stats: TaskCompletionStats): void;
  findBestMatch(requiredCaps: string[], domain?: string, availableAgents?: string[]): MatchScore[];
  getAgentProfile(performerId: string): AgentProfile | undefined;
}

function computeCapabilityScore(agent: AgentProfile, required: string[]): number {
  if (required.length === 0) return 20;
  const matched = required.filter(c => agent.capabilities.some(ac => ac.toLowerCase().includes(c.toLowerCase()))).length;
  return Math.round((matched / required.length) * 40);
}

function computeDomainScore(agent: AgentProfile, domain?: string): number {
  if (!domain) return 10;
  const match = agent.specializedDomains.some(d => d.toLowerCase().includes(domain.toLowerCase()));
  return match ? 20 : 5;
}

function computeAvailabilityScore(agent: AgentProfile): number {
  if (agent.recentTaskIds.length === 0) return 10;
  return Math.max(0, 10 - agent.recentTaskIds.length * 3);
}

export function createExpertMatcher(): ExpertMatcher {
  const agents = new Map<string, AgentProfile>();
  const recentCompletions = new Map<string, TaskCompletionStats[]>();

  return {
    addAgentProfile(profile: AgentProfile): void {
      agents.set(profile.performerId, profile);
      logger.info({ performerId: profile.performerId, capabilities: profile.capabilities }, 'agent profile added');
    },

    updateAgentStats(performerId: string, stats: TaskCompletionStats): void {
      const history = recentCompletions.get(performerId) ?? [];
      history.push(stats);
      if (history.length > 10) history.shift(); // sliding window of 10
      recentCompletions.set(performerId, history);

      const agent = agents.get(performerId);
      if (agent) {
        const successes = history.filter(h => h.success).length;
        agent.completedTasks = history.length;
        agent.successRate = history.length > 0 ? successes / history.length : 1;
        agent.avgCompletionTimeMs = history.length > 0
          ? history.reduce((sum, h) => sum + h.durationMs, 0) / history.length : 0;
        agents.set(performerId, agent);
      }
    },

    findBestMatch(requiredCaps: string[], domain?: string, availableAgents?: string[]): MatchScore[] {
      const results: MatchScore[] = [];
      const candidates = availableAgents
        ? Array.from(agents.values()).filter(a => availableAgents.includes(a.performerId))
        : Array.from(agents.values());

      for (const agent of candidates) {
        const capabilityMatch = computeCapabilityScore(agent, requiredCaps);
        const successScore = Math.round(agent.successRate * 30);
        const domainExpertise = computeDomainScore(agent, domain);
        const availability = computeAvailabilityScore(agent);
        const totalScore = capabilityMatch + successScore + domainExpertise + availability;

        results.push({
          performerId: agent.performerId, totalScore,
          breakdown: { capabilityMatch, successRate: successScore, domainExpertise, availability },
        });
      }

      results.sort((a, b) => b.totalScore - a.totalScore);
      logger.info({ candidates: results.length, top: results[0]?.performerId }, 'expert match complete');
      return results;
    },

    getAgentProfile(performerId: string): AgentProfile | undefined {
      return agents.get(performerId);
    },
  };
}

let defaultMatcher: ExpertMatcher | null = null;
export function getExpertMatcher(): ExpertMatcher {
  return defaultMatcher ?? (defaultMatcher = createExpertMatcher());
}
