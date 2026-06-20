/**
 * EPIC-060-B Phase 1 Benchmark Task 3: SHA-256 hashing (Node.js)
 *
 * Mirrors `rust/crates/kallax-bench/benches/bench_hash.rs`.
 * Uses node:crypto (same algorithm family as kallax-core/src/fingerprint.rs:92).
 */
import { createHash } from 'node:crypto';
import { performance } from 'node:perf_hooks';

const PAYLOAD_SIZE_SMALL = 1024;
const PAYLOAD_SIZE_MEDIUM = 16384;
const PAYLOAD_SIZE_LARGE = 65536;
const N_ITERATIONS = 2000;

function payload(size) {
  const buf = Buffer.alloc(size);
  for (let i = 0; i < size; i++) {
    buf[i] = i % 251;
  }
  return buf;
}

function benchSha256() {
  const results = [];
  for (const [size, payloadSize] of [
    ['small_1kb', PAYLOAD_SIZE_SMALL],
    ['medium_16kb', PAYLOAD_SIZE_MEDIUM],
    ['large_64kb', PAYLOAD_SIZE_LARGE],
  ]) {
    const buf = payload(payloadSize);
    const warmup = createHash('sha256').update(buf).digest('hex');
    if (!warmup) throw new Error('hash failed');
    const t0 = performance.now();
    for (let i = 0; i < N_ITERATIONS; i++) {
      createHash('sha256').update(buf).digest();
    }
    const elapsedMs = performance.now() - t0;
    const totalBytes = payloadSize * N_ITERATIONS;
    results.push({
      task: 'sha256_hash',
      size,
      payloadSize,
      nIters: N_ITERATIONS,
      totalBytes,
      elapsedMs: +elapsedMs.toFixed(3),
      bytesPerSec: Math.round(totalBytes / (elapsedMs / 1000)),
      opsPerSec: Math.round(N_ITERATIONS / (elapsedMs / 1000)),
    });
  }
  return results;
}

console.log('=== SHA-256 Hash Benchmark (Node.js) ===\n');
const allResults = [...benchSha256()];
for (const r of allResults) {
  console.log(JSON.stringify(r));
}