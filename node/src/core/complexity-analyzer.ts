/**
 * KALLAX Complexity Analyzer
 * Determines if an EPIC needs DAG-mode execution or simple sequential mode.

 */

export interface ComplexityInput {
  /** Total number of subtasks */
  subtaskCount: number;
  /** Maximum dependency depth (BFS from root) */
  dependencyDepth: number;
  /** Maximum number of direct dependencies for any single task */
  maxBlockedBy: number;
  /** Number of distinct code modules touched */
  crossModuleCount: number;
}

export interface ComplexityResult {
  /** Total complexity score */
  score: number;
  /** Recommended execution mode */
  mode: 'sequential' | 'dag';
  /** Detailed breakdown */
  breakdown: ComplexityBreakdown;
  /** Human-readable recommendation */
  recommendation: string;
}

export interface ComplexityBreakdown {
  subtaskCount: { value: number; threshold: number; score: number; label: string };
  dependencyDepth: { value: number; threshold: number; score: number; label: string };
  maxBlockedBy: { value: number; threshold: number; score: number; label: string };
  crossModule: { value: number; threshold: number; score: number; label: string };
}

const DAG_THRESHOLD = 4;

/**
 * Analyze task complexity and recommend execution mode.
 * Score >= DAG_THRESHOLD → dag mode, otherwise sequential.
 */
export function analyzeComplexity(input: ComplexityInput): ComplexityResult {
  const breakdown: ComplexityBreakdown = {
    subtaskCount: {
      value: input.subtaskCount,
      threshold: 5,
      score: input.subtaskCount >= 5 ? 2 : 0,
      label: 'Subtask count',
    },
    dependencyDepth: {
      value: input.dependencyDepth,
      threshold: 3,
      score: input.dependencyDepth >= 3 ? 3 : 0,
      label: 'Dependency depth',
    },
    maxBlockedBy: {
      value: input.maxBlockedBy,
      threshold: 2,
      score: input.maxBlockedBy >= 2 ? 1 : 0,
      label: 'Max blocked-by',
    },
    crossModule: {
      value: input.crossModuleCount,
      threshold: 3,
      score: input.crossModuleCount >= 3 ? 1 : 0,
      label: 'Cross-module',
    },
  };

  const score =
    breakdown.subtaskCount.score +
    breakdown.dependencyDepth.score +
    breakdown.maxBlockedBy.score +
    breakdown.crossModule.score;

  const mode: 'sequential' | 'dag' = score >= DAG_THRESHOLD ? 'dag' : 'sequential';

  const recommendation =
    mode === 'dag'
      ? `DAG mode recommended (score: ${score}/${DAG_THRESHOLD}+). ${input.subtaskCount} subtasks with depth ${input.dependencyDepth}. Use 'kallax epic:plan' to generate DAG YAML.`
      : `Sequential mode sufficient (score: ${score}/${DAG_THRESHOLD}+). Simple enough for linear execution.`;

  return { score, mode, breakdown, recommendation };
}

/**
 * Calculate dependency depth using BFS from root nodes (no dependencies).
 * @param depsMap — taskId → list of task IDs it depends on
 */
export function calculateDependencyDepth(depsMap: Map<string, string[]>): number {
  // Build reverse adjacency: who depends on me?
  const dependents = new Map<string, string[]>();
  for (const [taskId, deps] of depsMap) {
    for (const dep of deps) {
      const list = dependents.get(dep) ?? [];
      list.push(taskId);
      dependents.set(dep, list);
    }
  }

  // Root nodes: tasks with no dependencies
  const roots: string[] = [];
  for (const [taskId, deps] of depsMap) {
    if (deps.length === 0) roots.push(taskId);
  }

  let maxDepth = 0;
  const visited = new Set<string>();

  for (const root of roots) {
    const queue: Array<{ id: string; depth: number }> = [{ id: root, depth: 1 }];
    visited.add(root);

    while (queue.length > 0) {
      const current = queue.shift()!;
      if (current.depth > maxDepth) maxDepth = current.depth;

      const children = dependents.get(current.id) ?? [];
      for (const child of children) {
        if (!visited.has(child)) {
          visited.add(child);
          queue.push({ id: child, depth: current.depth + 1 });
        }
      }
    }
  }

  return maxDepth;
}

/**
 * Count distinct modules touched by task list.
 * Modules are inferred from file path patterns.
 */
export function countCrossModules(fileScopes: string[][]): number {
  const modules = new Set<string>();
  for (const scope of fileScopes) {
    for (const path of scope) {
      if (path.startsWith('node/src/')) modules.add('node');
      else if (path.startsWith('rust/')) modules.add('rust');
      else if (path.startsWith('scripts/')) modules.add('scripts');
      else if (path.startsWith('web/')) modules.add('web');
      else if (path.startsWith('.github/')) modules.add('ci');
      else modules.add('other');
    }
  }
  return modules.size;
}
