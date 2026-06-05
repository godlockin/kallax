/**
 * KALLAX Auto-Decompose — heuristic-driven requirement decomposition.
 * Vision: framework autonomously analyzes requirements and generates task DAGs.
 */
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface SubTask {
  id: string; title: string; description: string;
  estimatedComplexity: 'low' | 'medium' | 'high';
  dependencies: string[];
  suggestedFileScope: string[];
  suggestedCapabilities: string[];
}

export interface DecompositionResult {
  epic: string;
  subtasks: SubTask[];
  totalComplexity: number;
  recommendedMode: 'sequential' | 'parallel' | 'dag';
  confidence: number;
}

const TECH_KEYWORDS: Record<string, string[]> = {
  typescript: ['ts', 'typescript', 'node', 'express', 'nest'],
  rust: ['rust', 'cargo', 'async', 'traits'],
  python: ['python', 'django', 'flask', 'fastapi'],
  frontend: ['react', 'vue', 'angular', 'html', 'css', 'ui', 'component'],
  database: ['sql', 'database', 'db', 'migration', 'schema', 'postgres', 'mysql'],
  testing: ['test', 'jest', 'vitest', 'cargo test', 'coverage'],
  devops: ['docker', 'ci', 'cd', 'deploy', 'kubernetes', 'k8s'],
};

const ACTION_KEYWORDS: Record<string, string> = {
  implement: 'implement|add|create|build|write',
  fix: 'fix|bug|repair|correct|resolve',
  refactor: 'refactor|restructure|reorganize|rename|extract|split',
  test: 'test|verify|validate|assert',
  document: 'document|doc|readme|guide',
  optimize: 'optimize|perf|performance|speed|fast',
};

function extractTechStack(text: string): string[] {
  const lower = text.toLowerCase();
  const found: string[] = [];
  for (const [tech, keywords] of Object.entries(TECH_KEYWORDS)) {
    if (keywords.some(k => lower.includes(k))) found.push(tech);
  }
  return found;
}

function extractAction(text: string): string {
  const lower = text.toLowerCase();
  for (const [action, pattern] of Object.entries(ACTION_KEYWORDS)) {
    if (new RegExp(pattern, 'i').test(lower)) return action;
  }
  return 'implement';
}

function extractFilePaths(text: string): string[] {
  const paths = text.match(/[`'"]?([a-zA-Z0-9_\-/.]+\.(ts|rs|py|js|md|yml|yaml))[`'"]?/g);
  return paths ? paths.map(p => p.replace(/[`'"]/g, '')) : [];
}

function generateSubTaskId(index: number): string { return `subtask_${index}_${Date.now().toString(36)}`; }

export function decompose(requirement: string): KallaxResult<DecompositionResult> {
  try {
    const techStack = extractTechStack(requirement);
    const action = extractAction(requirement);
    const files = extractFilePaths(requirement);
    const subtasks: SubTask[] = [];

    if (techStack.length === 0) { techStack.push('typescript'); }

    const mainTask: SubTask = {
      id: generateSubTaskId(0), title: `${action} core logic`,
      description: `Main implementation of: ${requirement.slice(0, 80)}`,
      estimatedComplexity: techStack.length > 2 ? 'high' : 'medium',
      dependencies: [],
      suggestedFileScope: files.length > 0 ? files : ['src/'],
      suggestedCapabilities: [techStack[0] ?? 'typescript'],
    };
    subtasks.push(mainTask);

    // Add testing sub-task
    if (!action.includes('test')) {
      subtasks.push({
        id: generateSubTaskId(1), title: `add tests for ${action}`,
        description: `Write unit and integration tests covering edge cases`,
        estimatedComplexity: 'medium',
        dependencies: [mainTask.id],
        suggestedFileScope: files.map(f => f.replace('src/', 'tests/')),
        suggestedCapabilities: ['testing'],
      });
    }

    // Add documentation sub-task for complex changes
    if (techStack.length >= 2) {
      subtasks.push({
        id: generateSubTaskId(2), title: 'update documentation',
        description: 'Update API docs, architecture docs, and changelog',
        estimatedComplexity: 'low',
        dependencies: subtasks.map(s => s.id),
        suggestedFileScope: ['docs/', 'README.md'],
        suggestedCapabilities: ['documentation'],
      });
    }

    const hasDeps = subtasks.some(s => s.dependencies.length > 0);
    let recommendedMode: 'sequential' | 'parallel' | 'dag';
    if (hasDeps) {
      recommendedMode = 'dag';
    } else if (subtasks.length <= 1) {
      recommendedMode = 'sequential';
    } else {
      recommendedMode = 'parallel';
    }

    const complexity = subtasks.length >= 3 ? 5 : subtasks.length;
    const confidence = Math.min(0.9, 0.5 + (techStack.length * 0.1) + (files.length * 0.05));

    logger.info({ subtaskCount: subtasks.length, mode: recommendedMode, techStack }, 'auto-decompose complete');
    return ok({ epic: requirement, subtasks, totalComplexity: complexity, recommendedMode, confidence });
  } catch (error: unknown) {
    return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Decomposition failed', { cause: error }));
  }
}
