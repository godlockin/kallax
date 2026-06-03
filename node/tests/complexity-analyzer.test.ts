/**
 * Complexity Analyzer tests: 4-factor scoring, mode recommendation, depth calculation.
 */

import { describe, it, expect } from 'vitest';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules } from '../src/core/complexity-analyzer.js';

describe('ComplexityAnalyzer', () => {
  describe('analyzeComplexity', () => {
    it('returns sequential mode for simple tasks (score < 4)', () => {
      const result = analyzeComplexity({
        subtaskCount: 2,
        dependencyDepth: 1,
        maxBlockedBy: 1,
        crossModuleCount: 1,
      });

      expect(result.mode).toBe('sequential');
      expect(result.score).toBe(0);
      expect(result.recommendation).toContain('Sequential');
    });

    it('returns dag mode for complex tasks (score >= 4)', () => {
      const result = analyzeComplexity({
        subtaskCount: 5,
        dependencyDepth: 3,
        maxBlockedBy: 3,
        crossModuleCount: 4,
      });

      expect(result.mode).toBe('dag');
      expect(result.score).toBe(7); // 2 + 3 + 1 + 1
      expect(result.recommendation).toContain('DAG');
    });

    it('breaks down subtaskCount factor correctly', () => {
      expect(analyzeComplexity({ subtaskCount: 5, dependencyDepth: 0, maxBlockedBy: 0, crossModuleCount: 0 }).score).toBe(2);
      expect(analyzeComplexity({ subtaskCount: 4, dependencyDepth: 0, maxBlockedBy: 0, crossModuleCount: 0 }).score).toBe(0);
    });

    it('breaks down dependencyDepth factor correctly', () => {
      expect(analyzeComplexity({ subtaskCount: 0, dependencyDepth: 3, maxBlockedBy: 0, crossModuleCount: 0 }).score).toBe(3);
      expect(analyzeComplexity({ subtaskCount: 0, dependencyDepth: 2, maxBlockedBy: 0, crossModuleCount: 0 }).score).toBe(0);
    });

    it('breaks down maxBlockedBy factor correctly', () => {
      const r = analyzeComplexity({ subtaskCount: 0, dependencyDepth: 0, maxBlockedBy: 2, crossModuleCount: 0 });
      expect(r.breakdown.maxBlockedBy.score).toBe(1);
    });

    it('breaks down crossModule factor correctly', () => {
      const r = analyzeComplexity({ subtaskCount: 0, dependencyDepth: 0, maxBlockedBy: 0, crossModuleCount: 3 });
      expect(r.breakdown.crossModule.score).toBe(1);
    });

    it('includes full breakdown with all 4 factors', () => {
      const result = analyzeComplexity({ subtaskCount: 5, dependencyDepth: 3, maxBlockedBy: 2, crossModuleCount: 3 });
      const b = result.breakdown;
      expect(b.subtaskCount).toBeDefined();
      expect(b.dependencyDepth).toBeDefined();
      expect(b.maxBlockedBy).toBeDefined();
      expect(b.crossModule).toBeDefined();
    });
  });

  describe('calculateDependencyDepth', () => {
    it('returns 0 for empty map', () => {
      expect(calculateDependencyDepth(new Map())).toBe(0);
    });

    it('returns 1 for a single root node', () => {
      const deps = new Map([['A', []]]);
      expect(calculateDependencyDepth(deps)).toBe(1);
    });

    it('calculates BFS depth correctly', () => {
      const deps = new Map([
        ['A', []],
        ['B', ['A']],
        ['C', ['B']],
        ['D', ['C']],
      ]);
      // A(1) -> B(2) -> C(3) -> D(4) = depth 4
      expect(calculateDependencyDepth(deps)).toBe(4);
    });

    it('handles diamond dependencies correctly', () => {
      const deps = new Map([
        ['A', []],
        ['B', ['A']],
        ['C', ['A']],
        ['D', ['B', 'C']],
      ]);
      // A(1) -> B(2) -> D(3); A(1) -> C(2) -> D(3) => depth 3
      expect(calculateDependencyDepth(deps)).toBe(3);
    });
  });

  describe('countCrossModules', () => {
    it('returns 0 for empty input', () => {
      expect(countCrossModules([])).toBe(0);
    });

    it('returns 1 when all files are in same module', () => {
      const scopes = [['node/src/a.ts', 'node/src/b.ts']];
      expect(countCrossModules(scopes)).toBe(1);
    });

    it('counts distinct modules across file scopes', () => {
      const scopes = [
        ['node/src/a.ts'],
        ['rust/src/lib.rs'],
        ['web/app.tsx'],
      ];
      expect(countCrossModules(scopes)).toBe(3);
    });

    it('classifies unknown paths as "other"', () => {
      const scopes = [['some_unknown_path/file.py']];
      expect(countCrossModules(scopes)).toBe(1); // 'other'
    });
  });
});
