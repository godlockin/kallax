/**
 * KALLAX DAG Scheduler Benchmark
 *
 * Measures throughput of topologicalSort, getReadyTasks, and completeTask
 * at 100 / 500 / 1000 node scales using performance.now() timing.
 */

import { topologocalSort, type DagNodeDef } from '../src/core/dag-generator.js';
import { performance } from 'node:perf_hooks';

// ── Helpers ─────────────────────────────────────────────────────

function buildChainDag(n: number): DagNodeDef[] {
  const nodes: DagNodeDef[] = [];
  for (let i = 0; i < n; i++) {
    nodes.push({
      id: `n${i}`,
      script: 'echo ok',
      deps: i === 0 ? [] : [`n${i - 1}`],
    });
  }
  return nodes;
}

function runBenchmark(label: string, n: number): Record<string, string> {
  const nodes = buildChainDag(n);

  // topologicalSort
  let t0 = performance.now();
  for (let iter = 0; iter < 100; iter++) {
    topologocalSort(nodes);
  }
  const topoMs = ((performance.now() - t0) / 100).toFixed(3);

  // Simulate getReadyTasks + completeTask lifecycle
  const inDegree = new Map<string, number>();
  const dependents = new Map<string, string[]>();
  for (const node of nodes) {
    inDegree.set(node.id, node.deps.length);
    for (const dep of node.deps) {
      const list = dependents.get(dep) ?? [];
      list.push(node.id);
      dependents.set(dep, list);
    }
  }

  // getReadyTasks — initial wave
  t0 = performance.now();
  for (let iter = 0; iter < 100; iter++) {
    const ready: string[] = [];
    for (const [id, deg] of inDegree) {
      if (deg === 0) ready.push(id);
    }
  }
  const readyMs = ((performance.now() - t0) / 100).toFixed(3);

  // completeTask — release all dependents
  t0 = performance.now();
  for (let iter = 0; iter < 100; iter++) {
    // Fresh copy each iteration
    const deg = new Map(inDegree);
    // Traverse chain completing each node
    let currentId = nodes[0].id;
    while (currentId) {
      const nextBatch: string[] = [];
      for (const dep of dependents.get(currentId) ?? []) {
        const d = (deg.get(dep) ?? 1) - 1;
        deg.set(dep, d);
        if (d === 0) nextBatch.push(dep);
      }
      currentId = nextBatch[0] ?? '';
    }
  }
  const completeMs = ((performance.now() - t0) / 100).toFixed(3);

  return { topoMs, readyMs, completeMs };
}

// ── Runner ───────────────────────────────────────────────────────

function main(): void {
  console.log('\n=== KALLAX DAG Scheduler Benchmark (Node) ===\n');
  console.log(`${'Scale'.padEnd(10)} ${'topoSort(ms)'.padEnd(14)} ${'getReady(ms)'.padEnd(14)} ${'complete(ms)'.padEnd(14)}`);
  console.log('-'.repeat(54));

  for (const n of [100, 500, 1000]) {
    const r = runBenchmark(`N=${n}`, n);
    console.log(
      `${String(n).padEnd(10)} ${r.topoMs.padEnd(14)} ${r.readyMs.padEnd(14)} ${r.completeMs.padEnd(14)}`,
    );
  }

  console.log('\n[All DAG scheduler benchmarks completed]\n');
}

main();
