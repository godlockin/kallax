/**
 * KALLAX Benchmark Suite — standardized performance tests.
 * Run: npx tsx benchmarks/benchmark-suite.ts
 */
import { performance } from 'node:perf_hooks';

interface BenchResult { name: string; iterations: number; totalMs: number; avgMs: number; minMs: number; maxMs: number; opsPerSec: number; }

function run(fn: () => void, iterations: number): BenchResult {
  const times: number[] = [];
  for (let i = 0; i < iterations; i++) {
    const t0 = performance.now();
    fn();
    times.push(performance.now() - t0);
  }
  const total = times.reduce((a, b) => a + b, 0);
  return { iterations, totalMs: Math.round(total * 100) / 100, avgMs: Math.round((total / iterations) * 1000) / 1000, minMs: Math.round(Math.min(...times) * 1000) / 1000, maxMs: Math.round(Math.max(...times) * 1000) / 1000, opsPerSec: Math.round(iterations / (total / 1000)), name: '' };
}

async function main() {
  console.log('# KALLAX Benchmark Report');
  console.log(`Date: ${new Date().toISOString()}\n`);

  // 1. DAG Scheduler — topological sort on 1000 nodes
  const { topologicalSort } = await import('../src/core/dag-generator.js');
  const nodes = Array.from({ length: 1000 }, (_, i) => ({ id: `n${i}`, script: 'echo ok', deps: i > 0 ? [`n${i - 1}`] : [], description: '' }));
  const dagResult = run(() => topologicalSort(nodes), 50);
  dagResult.name = 'DAG TopoSort (1000 nodes)';
  console.log(`| ${dagResult.name} | ${dagResult.iterations} | ${dagResult.totalMs}ms | ${dagResult.avgMs}ms | ${dagResult.opsPerSec}/s |`);

  // 2. Complexity Analyzer
  const { analyzeComplexity } = await import('../src/core/complexity-analyzer.js');
  const cxResult = run(() => analyzeComplexity({ subtaskCount: 10, dependencyDepth: 5, maxBlockedBy: 3, crossModuleCount: 4, description: '' }), 1000);
  cxResult.name = 'Complexity Analysis';
  console.log(`| ${cxResult.name} | ${cxResult.iterations} | ${cxResult.totalMs}ms | ${cxResult.avgMs}ms | ${cxResult.opsPerSec}/s |`);

  // 3. SQLite CRUD
  const Database = (await import('better-sqlite3')).default;
  const db = new Database(':memory:');
  db.exec('CREATE TABLE b (id TEXT, data TEXT, n INTEGER)');
  db.exec('INSERT INTO b VALUES (1,"test",1),(2,"test2",2),(3,"test3",3)');
  // Warm up
  db.prepare('SELECT * FROM b WHERE id=?').get('1');
  const sqlResult = run(() => {
    db.prepare('INSERT INTO b VALUES (?,?,?)').run('x','data',Date.now());
    db.prepare('SELECT * FROM b WHERE id=?').get('x');
  }, 1000);
  sqlResult.name = 'SQLite INSERT+SELECT';
  db.close();
  console.log(`| ${sqlResult.name} | ${sqlResult.iterations} | ${sqlResult.totalMs}ms | ${sqlResult.avgMs}ms | ${sqlResult.opsPerSec}/s |`);

  // 4. Expert Matcher
  const { createExpertMatcher } = await import('../src/core/expert-matcher.js');
  const matcher = createExpertMatcher();
  for (let i = 0; i < 10; i++) matcher.addAgentProfile({ performerId: `p${i}`, capabilities: ['ts','node','react'], completedTasks: 50, successRate: 0.9, avgCompletionTimeMs: 5000, preferredLanguages: ['ts'], specializedDomains: ['web'], recentTaskIds: [] });
  const emResult = run(() => matcher.findBestMatch(['typescript', 'react'], 'frontend'), 500);
  emResult.name = 'Expert Match (10 agents)';
  console.log(`| ${emResult.name} | ${emResult.iterations} | ${emResult.totalMs}ms | ${emResult.avgMs}ms | ${emResult.opsPerSec}/s |`);

  console.log('\n---');
  console.log(`Node: ${process.version}  Platform: ${process.platform}  Arch: ${process.arch}`);
}
main().catch(console.error);
