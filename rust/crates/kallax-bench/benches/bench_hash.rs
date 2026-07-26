//! EPIC-060-B Phase 1 Benchmark Task 3: SHA-256 hashing
//!
//! Mirrors `node/bench/bench-hash.js`. Uses sha2 (same crate used by
//! `kallax-core/src/fingerprint.rs:92` for file content fingerprints).

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use sha2::{Digest, Sha256};
use std::hint::black_box;

const PAYLOAD_SIZE_SMALL: usize = 1_024;
const PAYLOAD_SIZE_MEDIUM: usize = 16_384;
const PAYLOAD_SIZE_LARGE: usize = 65_536;
const N_ITERATIONS: usize = 2_000;

fn payload(size: usize) -> Vec<u8> {
    // Deterministic pseudo-random bytes (no RNG dep needed)
    (0..size).map(|i| (i % 251) as u8).collect()
}

fn bench_sha256(c: &mut Criterion) {
    let mut group = c.benchmark_group("sha256_hash");
    for (size, payload_size) in [
        ("small_1kb", PAYLOAD_SIZE_SMALL),
        ("medium_16kb", PAYLOAD_SIZE_MEDIUM),
        ("large_64kb", PAYLOAD_SIZE_LARGE),
    ] {
        let buf = payload(payload_size);
        group.throughput(Throughput::Bytes(payload_size as u64));
        group.bench_with_input(BenchmarkId::from_parameter(size), &N_ITERATIONS, |b, &n| {
            b.iter(|| {
                for _ in 0..n {
                    let mut hasher = Sha256::new();
                    hasher.update(&buf);
                    let digest = hasher.finalize();
                    black_box(digest);
                }
            });
        });
    }
    group.finish();
}

criterion_group!(benches, bench_sha256);
criterion_main!(benches);
