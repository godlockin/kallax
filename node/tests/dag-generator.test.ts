/**
 * DAG Generator tests: Kahn topological sort, cycle detection, YAML generation.
 */

import { describe, it, expect } from 'vitest';
import { topologicalSort, generateDagYaml } from '../src/core/dag-generator.js';
import type { DagNodeDef } from '../src/core/dag-generator.js';

describe('DAG Generator', () => {
  describe('topologicalSort', () => {
    it('sorts nodes in dependency order', () => {
      const nodes: DagNodeDef[] = [
        { id: 'A', script: 'echo A', deps: [] },
        { id: 'B', script: 'echo B', deps: ['A'] },
        { id: 'C', script: 'echo C', deps: ['B'] },
      ];
      const sorted = topologicalSort(nodes);
      expect(sorted.map((n) => n.id)).toEqual(['A', 'B', 'C']);
    });

    it('handles nodes with no dependencies', () => {
      const nodes: DagNodeDef[] = [
        { id: 'A', script: '', deps: [] },
        { id: 'B', script: '', deps: [] },
      ];
      const sorted = topologicalSort(nodes);
      expect(sorted.length).toBe(2);
    });

    it('throws on cycle detection', () => {
      const nodes: DagNodeDef[] = [
        { id: 'A', script: '', deps: ['B'] },
        { id: 'B', script: '', deps: ['A'] },
      ];
      expect(() => topologicalSort(nodes)).toThrow('Cycle detected');
    });

    it('handles diamond dependency graph', () => {
      const nodes: DagNodeDef[] = [
        { id: 'A', script: '', deps: [] },
        { id: 'B', script: '', deps: ['A'] },
        { id: 'C', script: '', deps: ['A'] },
        { id: 'D', script: '', deps: ['B', 'C'] },
      ];
      const sorted = topologicalSort(nodes);
      expect(sorted.map((n) => n.id)).toEqual(['A', 'B', 'C', 'D']);
    });

    it('returns empty array for empty input', () => {
      expect(topologicalSort([])).toEqual([]);
    });
  });

  describe('generateDagYaml', () => {
    it('generates YAML with version and epic', () => {
      const yaml = generateDagYaml([], 'EPIC-1');
      expect(yaml).toContain('version: "1.0"');
      expect(yaml).toContain('epic: "EPIC-1"');
    });

    it('maps P0 to priority 90', () => {
      const yaml = generateDagYaml([{ id: 'T1', title: 'Critical', priority: 'P0' }], 'E1');
      expect(yaml).toContain('priority: 90');
    });

    it('maps P1 to priority 70', () => {
      const yaml = generateDagYaml([{ id: 'T1', title: 'High', priority: 'P1' }], 'E1');
      expect(yaml).toContain('priority: 70');
    });

    it('outputs node id and description', () => {
      const yaml = generateDagYaml([{ id: 'T1', title: 'Setup DB', priority: 'P2' }], 'E1');
      expect(yaml).toContain('id: "T1"');
      expect(yaml).toContain('description: "Setup DB"');
    });

    it('includes settings block', () => {
      const yaml = generateDagYaml([], 'E1');
      expect(yaml).toContain('max_parallel: 3');
      expect(yaml).toContain('retry_count: 2');
      expect(yaml).toContain('on_failure: stop');
    });
  });
});
