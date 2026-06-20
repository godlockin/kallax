/**
 * EPIC-060-B Phase 1 Benchmark Task 1: JSON serialize/deserialize (Node.js)
 *
 * Mirrors `rust/crates/kallax-bench/benches/bench_json.rs`.
 * Same payload shape, same iteration counts, same byte throughput per row.
 */
import { performance } from 'node:perf_hooks';

const N_ITERATIONS_SMALL = 1000;
const N_ITERATIONS_MEDIUM = 500;
const N_ITERATIONS_LARGE = 100;
const PAYLOAD_KEY_COUNT_SMALL = 10;
const PAYLOAD_KEY_COUNT_MEDIUM = 50;
const PAYLOAD_KEY_COUNT_LARGE = 200;

function buildPayload(keyCount) {
  const metadata = {};
  for (let i = 0; i < keyCount; i++) {
    metadata[`key_${i}`] = `value_${i}_payload`;
  }
  return {
    id: 'ticket_001',
    name: 'Benchmark Payload',
    email: 'bench@kallax.local',
    tags: Array.from({ length: 5 }, (_, i) => `tag_${i}`),
    metadata,
    score: 99.5,
    active: true,
    created_at: '2026-06-19T00:00:00Z',
  };
}

function benchSerialize() {
  const results = [];
  for (const [size, keyCount, nIters] of [
    ['small', PAYLOAD_KEY_COUNT_SMALL, N_ITERATIONS_SMALL],
    ['medium', PAYLOAD_KEY_COUNT_MEDIUM, N_ITERATIONS_MEDIUM],
    ['large', PAYLOAD_KEY_COUNT_LARGE, N_ITERATIONS_LARGE],
  ]) {
    const payload = buildPayload(keyCount);
    const warmup = JSON.stringify(payload);
    if (!warmup) throw new Error('serialize failed');
    const t0 = performance.now();
    for (let i = 0; i < nIters; i++) {
      JSON.stringify(payload);
    }
    const elapsedMs = performance.now() - t0;
    const totalBytes = warmup.length * nIters;
    results.push({
      task: 'json_serialize',
      size,
      keyCount,
      nIters,
      totalBytes,
      elapsedMs: +elapsedMs.toFixed(3),
      bytesPerSec: Math.round(totalBytes / (elapsedMs / 1000)),
      opsPerSec: Math.round(nIters / (elapsedMs / 1000)),
    });
  }
  return results;
}

function benchDeserialize() {
  const results = [];
  for (const [size, keyCount, nIters] of [
    ['small', PAYLOAD_KEY_COUNT_SMALL, N_ITERATIONS_SMALL],
    ['medium', PAYLOAD_KEY_COUNT_MEDIUM, N_ITERATIONS_MEDIUM],
    ['large', PAYLOAD_KEY_COUNT_LARGE, N_ITERATIONS_LARGE],
  ]) {
    const payload = buildPayload(keyCount);
    const json = JSON.stringify(payload);
    const warmup = JSON.parse(json);
    if (!warmup) throw new Error('deserialize failed');
    const t0 = performance.now();
    for (let i = 0; i < nIters; i++) {
      JSON.parse(json);
    }
    const elapsedMs = performance.now() - t0;
    const totalBytes = json.length * nIters;
    results.push({
      task: 'json_deserialize',
      size,
      keyCount,
      nIters,
      totalBytes,
      elapsedMs: +elapsedMs.toFixed(3),
      bytesPerSec: Math.round(totalBytes / (elapsedMs / 1000)),
      opsPerSec: Math.round(nIters / (elapsedMs / 1000)),
    });
  }
  return results;
}

console.log('=== JSON serialize/deserialize Benchmark (Node.js) ===\n');
const allResults = [...benchSerialize(), ...benchDeserialize()];
for (const r of allResults) {
  console.log(JSON.stringify(r));
}