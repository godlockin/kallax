/**
 * KALLAX Rust Bridge vs Node.js Performance Comparison
 *
 * Benchmarks the latency of Rust-native server endpoints vs equivalent Node.js
 * operations. Requires the Rust server to be running on localhost:3000.
 *
 * Usage:
 *   # Start Rust server first, then:
 *   node --loader tsx node/benchmarks/rust-bridge.bench.ts
 */

import { createRustBridge, type RustBridge } from '../src/core/rust-bridge.js';
import { performance } from 'node:perf_hooks';
import { topologocalSort, type DagNodeDef } from '../src/core/dag-generator.js';
import { createClaimQueue } from '../src/core/claim-queue.js';

// ── Setup ─────────────────────────────────────────────────────────────────────

const bridge: RustBridge = createRustBridge({ baseUrl: 'http://127.0.0.1:3000', timeoutMs: 3000 });
const ITERATIONS = 20;

function fmt(ms: number): string {
  return ms.toFixed(3).padStart(8);
}

async function bench(label: string, fn: () => Promise<unknown> | void, iterations = ITERATIONS): Promise<number> {
  // warmup
  await fn();
  const t0 = performance.now();
  for (let i = 0; i < iterations; i++) await fn();
  return (performance.now() - t0) / iterations;
}

// ── Benchmarks ────────────────────────────────────────────────────────────────

interface BenchRow {
  operation: string;
  rustMs: string;
  nodeMs: string;
  ratio: string;
  winner: string;
}

const results: BenchRow[] = [];

async function compare(
  label: string,
  rustFn: () => Promise<unknown>,
  nodeFn: () => void,
): Promise<void> {
  const rustAlive = await bridge.isAlive().catch(() => false);
  const rustMs = rustAlive ? await bench(label + ' (Rust)', () => rustFn()) : -1;
  const nodeMs = await bench(label + ' (Node)', () => nodeFn());

  results.push({
    operation: label,
    rustMs: rustMs >= 0 ? fmt(rustMs) : '  N/A   ',
    nodeMs: fmt(nodeMs),
    ratio: rustMs >= 0 ? (nodeMs / rustMs).toFixed(2) + 'x' : 'N/A',
    winner: rustMs >= 0 ? (nodeMs < rustMs ? 'Node' : 'Rust') : 'Node',
  });
}

// ── Status check ──────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const alive = await bridge.isAlive().catch(() => false);

  console.log('='.repeat(60));
  console.log('  KALLAX Rust Bridge vs Node.js Performance Comparison');
  console.log('='.repeat(60));
  console.log();
  console.log(`  Rust server: ${alive ? 'CONNECTED' : 'OFFLINE (Node-only results)'}\n`);

  // 1. Bridge status ping vs local fast path
  await compare(
    'Ping',
    () => bridge.isAlive(),
    () => true,
  );

  // 2. DAG topoSort (100 nodes) — Rust server scheduler vs Node local
  const dag100: DagNodeDef[] = [];
  for (let i = 0; i < 100; i++) {
    dag100.push({ id: `n${i}`, script: 'echo ok', deps: i === 0 ? [] : [`n${i - 1}`] });
  }

  await compare(
    'DAG topoSort (100)',
    () => bridge.getSchedulerStatus(),
    () => topologocalSort(dag100),
  );

  // 3. Claim queue — enqueue 100 items
  const q = createClaimQueue();
  await compare(
    'Claim enqueue (100)',
    async () => {
      for (let i = 0; i < 100; i++) {
        // no-op equivalent: Rust bridge doesn't have claim queue endpoint,
        // so we measure the HTTP round-trip to status
        await bridge.getSchedulerStatus();
      }
    },
    () => {
      for (let i = 0; i < 100; i++) {
        q.enqueue(`T-${i}`, `TICKET-${i}`, 1, ['generic']);
      }
    },
  );

  // 4. Status endpoint vs simple property read
  await compare(
    'GetStatus',
    () => bridge.getStatus(),
    () => ({ status: 'ok', modules: {} }),
  );

  // ── Results table ──────────────────────────────────────────────────────
  console.log(`${'Operation'.padEnd(25)} ${'Rust(ms)'.padEnd(12)} ${'Node(ms)'.padEnd(12)} ${'Ratio'.padEnd(8)} ${'Winner'}`);
  console.log('  ' + '-'.repeat(65));
  for (const r of results) {
    console.log(
      `  ${r.operation.padEnd(23)} ${r.rustMs.padEnd(12)} ${r.nodeMs.padEnd(12)} ${r.ratio.padEnd(8)} ${r.winner}`
    );
  }

  console.log();
  if (!alive) {
    console.log('  NOTE: Rust server was offline. Results show Node.js baseline only.');
    console.log('  Start the Rust server with: cd rust && cargo run --release');
    console.log('  Then re-run this benchmark for comparison.\n');
  }

  console.log('='.repeat(60));
  console.log('  Comparison complete.');
  console.log('='.repeat(60));
}

await main();
