/**
 * KALLAX Task Router — pre-execution complexity gate.
 *
 * Flow:
 *   requirement → decompose → analyze complexity
 *     ├─ sequential → direct: create ticket, summon performer, start
 *     └─ dag        → panel: summon expert panel, analyze, plan, then execute
 */
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { decompose, type DecompositionResult } from './auto-decompose.js';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules, type ComplexityResult } from './complexity-analyzer.js';

export interface DirectRoute {
  readonly strategy: 'direct';
  readonly decomposition: DecompositionResult;
  readonly complexity: ComplexityResult;
  readonly recommendation: string;
  readonly suggestedPerformer: { readonly capabilities: string[]; readonly domain?: string };
}

export interface PanelRoute {
  readonly strategy: 'panel';
  readonly decomposition: DecompositionResult;
  readonly complexity: ComplexityResult;
  readonly recommendation: string;
  readonly panel: ExpertPanelComposition;
  readonly estimatedRounds: number;
}

export interface ExpertPanelComposition {
  readonly required: string[]; readonly optional: string[];
  readonly chair: string; readonly expectedOutput: string;
}

export type RouteDecision = DirectRoute | PanelRoute;

export interface RouteResult {
  readonly decision: RouteDecision;
  readonly requirement: string;
  readonly confidence: number;
  /**
   * EPIC-064-5: Auto-dispatch hints for subagent consumption.
   * - direct: single `kallax <verb> <args>` to invoke
   * - panel: list of `kallax <verb> <args>` to invoke sequentially
   * Empty when no confident mapping (caller falls back to human decision).
   */
  readonly dispatch: ReadonlyArray<{ readonly verb: string; readonly args: readonly string[]; readonly reason: string }>;
}

const DOMAIN_EXPERT_MAP: Record<string, string[]> = {
  typescript: ['backend', 'frontend'], rust: ['backend', 'systems'],
  python: ['backend', 'data'], frontend: ['frontend', 'ux'],
  database: ['backend', 'database', 'data'], testing: ['test', 'qa'],
  devops: ['devops', 'infra', 'sre'], security: ['security'],
};

function buildComplexityInput(result: DecompositionResult): {
  subtaskCount: number;
  dependencyDepth: number;
  maxBlockedBy: number;
  crossModuleCount: number;
} {
  const depsMap = new Map<string, string[]>();
  for (const st of result.subtasks) depsMap.set(st.id, st.dependencies);
  return {
    subtaskCount: result.subtasks.length,
    dependencyDepth: calculateDependencyDepth(depsMap),
    maxBlockedBy: Math.max(0, ...result.subtasks.map(s => s.dependencies.length)),
    crossModuleCount: countCrossModules(result.subtasks.map(s => s.suggestedFileScope)),
  };
}

function pickExpertPanel(decomposition: DecompositionResult, complexity: ComplexityResult): ExpertPanelComposition {
  const domains = new Set<string>();
  for (const st of decomposition.subtasks) {
    for (const cap of st.suggestedCapabilities) {
      const mapped = DOMAIN_EXPERT_MAP[cap];
      if (mapped) for (const d of mapped) domains.add(d);
      else domains.add(cap);
    }
  }
  const required: string[] = ['architect'];
  const optional: string[] = [];
  if (complexity.score >= 6) required.push('product');
  for (const domain of domains) {
    if (domain === 'backend' || domain === 'frontend') required.push(domain);
    else optional.push(domain);
  }
  return {
    required: [...new Set(required)], optional: [...new Set(optional)],
    chair: complexity.score >= 6 ? 'architect' : 'product',
    expectedOutput: complexity.score >= 6
      ? 'Full execution plan with DAG, risk assessment, and resource estimation'
      : 'Task breakdown with acceptance criteria and test plan',
  };
}

export function routeTask(requirement: string): KallaxResult<RouteResult> {
  const decompositionResult = decompose(requirement);
  if (decompositionResult.isErr()) return err(decompositionResult.error);

  const decomposition = decompositionResult.value;
  const complexityInput = buildComplexityInput(decomposition);
  const complexity = analyzeComplexity(complexityInput);

  // Simple = complexity-analyzer says sequential mode (no DAG needed)
  const isSimple = complexity.mode === 'sequential';

  if (isSimple) {
    const caps = decomposition.subtasks.flatMap(s => s.suggestedCapabilities);
    const decision: DirectRoute = {
      strategy: 'direct', decomposition, complexity,
      recommendation: `Simple (${complexity.mode}, score ${String(complexity.score)}). Create ticket, summon ${[...new Set(caps)].join('+') || 'general'} Performer, start.`,
      suggestedPerformer: { capabilities: [...new Set(caps)], domain: caps[0] },
    };

    // EPIC-064-5: auto-dispatch hints
    const dispatchHints: Array<{ verb: string; args: string[]; reason: string }> = [];
    if (caps.includes('backend') || caps.includes('frontend') || caps.includes('fullstack')) {
      dispatchHints.push({
        verb: 'epic', args: ['create', 'AUTO', requirement.slice(0, 60)],
        reason: 'Complex enough to warrant EPIC tracking',
      });
    } else {
      dispatchHints.push({
        verb: 'task', args: ['create', 'AUTO', requirement.slice(0, 60)],
        reason: 'Single subtask → task ticket',
      });
    }
    dispatchHints.push({ verb: 'load', args: ['all'], reason: 'Pre-load context (cheatsheet + 5-levels + 4-roles)' });

    logger.info({ strategy: 'direct', score: complexity.score }, 'task routed: direct');
    return ok({ decision, requirement, confidence: decomposition.confidence, dispatch: dispatchHints });
  }

  const panel = pickExpertPanel(decomposition, complexity);
  const estimatedRounds = Math.max(2, Math.ceil(complexity.score / 3));
  const decision: PanelRoute = {
    strategy: 'panel', decomposition, complexity,
    recommendation: `Complex (${complexity.mode}, score ${String(complexity.score)}). Panel: ${panel.required.join(', ')}. ~${String(estimatedRounds)} rounds.`,
    panel, estimatedRounds,
  };

  // EPIC-064-5: panel dispatch
  const dispatchHints: Array<{ verb: string; args: string[]; reason: string }> = [
    { verb: 'epic', args: ['create', 'PANEL', requirement.slice(0, 60)], reason: `Complex task → EPIC for panel decomposition (score ${String(complexity.score)})` },
    { verb: 'load', args: ['all'], reason: `Pre-load context for ${String(panel.required.length)} panel members` },
    { verb: 'route', args: [requirement.slice(0, 80)], reason: 'Recurse sub-tasks through route' },
  ];

  logger.info({ strategy: 'panel', score: complexity.score, panelRoles: panel.required }, 'task routed: panel');
  return ok({ decision, requirement, confidence: decomposition.confidence, dispatch: dispatchHints });
}

export function getComplexityThreshold(): number {
  return 4; // DAG_THRESHOLD from complexity-analyzer
}
