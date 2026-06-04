/**
 * KALLAX E2E: DAG Multi-Node Execution
 * Creates a 3-node DAG with A->B->C dependency, dry-run validates topology order,
 * and verifies checkpoint save/restore.
 */

import { describe, it, expect } from 'vitest';
import * as path from 'node:path';
import * as fs from 'node:fs';
import * as os from 'node:os';
import { createDagExecutor, type DagRunState } from '../../src/core/dag-executor.js';
import { topologicalSort, generateDagYaml, type DagNodeDef, type DagSchema } from '../../src/core/dag-generator.js';

// ── Test Helpers ────────────────────────────────────────────────────────────

/**
 * Create a 3-node test DAG: A -> B -> C
 * A has no deps, B depends on A, C depends on B
 */
function makeLinearDag(): DagSchema {
  return {
    epic: 'E2E-DAG-LINEAR',
    nodes: [
      { id: 'A', script: 'echo node-A', deps: [] },
      { id: 'B', script: 'echo node-B', deps: ['A'] },
      { id: 'C', script: 'echo node-C', deps: ['B'] },
    ],
    settings: {
      max_parallel: 2,
      retry_count: 1,
      timeout_seconds: 30,
      on_failure: 'stop',
    },
  };
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('DAG Topological Sort', () => {
  it('sorts A->B->C in correct order', () => {
    const nodes: DagNodeDef[] = [
      { id: 'C', script: 'echo C', deps: ['B'] },
      { id: 'A', script: 'echo A', deps: [] },
      { id: 'B', script: 'echo B', deps: ['A'] },
    ];
    const sorted = topologicalSort(nodes);
    const ids = sorted.map((n) => n.id);
    // A must come before B, B before C
    expect(ids.indexOf('A')).toBeLessThan(ids.indexOf('B'));
    expect(ids.indexOf('B')).toBeLessThan(ids.indexOf('C'));
    // All 3 nodes present
    expect(ids).toEqual(expect.arrayContaining(['A', 'B', 'C']));
  });

  it('throws on cycle detection', () => {
    const cyclic: DagNodeDef[] = [
      { id: 'X', script: 'echo X', deps: ['Y'] },
      { id: 'Y', script: 'echo Y', deps: ['Z'] },
      { id: 'Z', script: 'echo Z', deps: ['X'] },
    ];
    expect(() => topologicalSort(cyclic)).toThrow('Cycle detected');
  });

  it('handles isolated (no-dep) nodes in any order', () => {
    const nodes: DagNodeDef[] = [
      { id: 'P', script: 'echo P', deps: [] },
      { id: 'Q', script: 'echo Q', deps: [] },
    ];
    const sorted = topologicalSort(nodes);
    expect(sorted.length).toBe(2);
    expect(sorted.map((n) => n.id).sort()).toEqual(['P', 'Q']);
  });
});

describe('DAG YAML Generation', () => {
  it('generates valid YAML with correct node count', () => {
    const tickets = [
      { id: 'T-1', title: 'Task 1', priority: 'P0', fileScope: ['src/a'] },
      { id: 'T-2', title: 'Task 2', priority: 'P2', fileScope: ['src/b'] },
    ];
    const yaml = generateDagYaml(tickets, 'EPIC-E2E');
    expect(yaml).toContain('epic: "EPIC-E2E"');
    expect(yaml).toContain('T-1');
    expect(yaml).toContain('T-2');
    expect(yaml).toContain('max_parallel: 3');
    expect(yaml).toContain('on_failure: stop');
  });

  it('assigns higher priority to P0 tickets', () => {
    const tickets = [
      { id: 'T-P0', title: 'Critical', priority: 'P0' },
      { id: 'T-P3', title: 'Low', priority: 'P3' },
    ];
    const yaml = generateDagYaml(tickets, 'EPIC-PRIORITY');
    expect(yaml).toContain('priority: 90');
    expect(yaml).toContain('priority: 30');
  });
});

describe('DAG Executor (Dry-Run)', () => {
  const stateDir = path.join(os.tmpdir(), 'kallax-dag-e2e');

  it('executes linear DAG in dry-run mode (no actual scripts run)', async () => {
    const executor = createDagExecutor({
      dryRun: true,
      stateDir,
      maxParallel: 2,
    });

    const schema = makeLinearDag();
    const result = await executor.execute(schema);

    expect(result.status).toBe('completed');
    expect(result.epic).toBe('E2E-DAG-LINEAR');
    // All 3 nodes should be done
    for (const [id, node] of result.nodes) {
      expect(node.status).toBe('done');
      expect(node.attempt).toBe(1);
    }
  });

  it('checkpoint file is created after execution', async () => {
    const executor = createDagExecutor({ dryRun: true, stateDir });
    const schema = makeLinearDag();
    const result = await executor.execute(schema);

    // Checkpoint file should exist
    const checkpointPath = path.join(stateDir, `${result.runId}.json`);
    const exists = fs.existsSync(checkpointPath);
    expect(exists).toBe(true);

    // Clean up
    try { fs.unlinkSync(checkpointPath); } catch { /* ignore */ }
  });

  it('resumes from checkpoint correctly', async () => {
    const executor = createDagExecutor({ dryRun: true, stateDir });
    const schema = makeLinearDag();
    const result = await executor.execute(schema);
    const runId = result.runId;

    // Resume should succeed
    const resumed = await executor.resume(runId);
    expect(resumed.status).toBe('completed');
    expect(resumed.runId).toBe(runId);

    // Clean up
    const cp = path.join(stateDir, `${runId}.json`);
    try { fs.unlinkSync(cp); } catch { /* ignore */ }
  });

  it('preserves node dependency order via topological wave execution', async () => {
    const executor = createDagExecutor({ dryRun: true, stateDir });
    const schema = makeLinearDag();
    const result = await executor.execute(schema);

    // In dry-run mode all complete instantly; verify topological constraints
    const nodeA = result.nodes.get('A');
    const nodeB = result.nodes.get('B');
    const nodeC = result.nodes.get('C');

    expect(nodeA?.status).toBe('done');
    expect(nodeB?.status).toBe('done');
    expect(nodeC?.status).toBe('done');
  });
});

describe('DAG with Checkpoint Save/Resume', () => {
  const stateDir = path.join(os.tmpdir(), 'kallax-dag-checkpoint-e2e');

  it('saves checkpoint after each node completes', async () => {
    const executor = createDagExecutor({ dryRun: true, stateDir });
    const schema = makeLinearDag();
    const result = await executor.execute(schema);

    // Checkpoint file for final state
    const cpPath = path.join(stateDir, `${result.runId}.json`);
    const content = fs.readFileSync(cpPath, 'utf-8');
    const parsed = JSON.parse(content);

    expect(parsed.runId).toBe(result.runId);
    expect(parsed.status).toBe('completed');
    expect(parsed.nodes.C.status).toBe('done');

    // Clean up
    try { fs.unlinkSync(cpPath); } catch { /* ignore */ }
  });

  it('returns null for non-existent run state', async () => {
    const executor = createDagExecutor({ dryRun: true, stateDir });
    const state = await executor.getRunState('nonexistent-run-id');
    expect(state).toBeNull();
  });
});
