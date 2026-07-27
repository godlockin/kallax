//! EPIC-060-B Phase 1 Benchmark Task 1: JSON serialize/deserialize
//!
//! Mirrors the same workload as `node/bench/bench-json.js` for fair comparison.
//! Uses serde_json (the same crate used by kallax-core).

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

const N_ITERATIONS_SMALL: usize = 1_000;
const N_ITERATIONS_MEDIUM: usize = 500;
const N_ITERATIONS_LARGE: usize = 100;
const PAYLOAD_KEY_COUNT_SMALL: usize = 10;
const PAYLOAD_KEY_COUNT_MEDIUM: usize = 50;
const PAYLOAD_KEY_COUNT_LARGE: usize = 200;

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Payload {
    id: String,
    name: String,
    email: String,
    tags: Vec<String>,
    metadata: HashMap<String, String>,
    score: f64,
    active: bool,
    created_at: String,
}

fn build_payload(key_count: usize) -> Payload {
    let mut metadata = HashMap::with_capacity(key_count);
    for i in 0..key_count {
        metadata.insert(format!("key_{i}"), format!("value_{i}_payload"));
    }
    Payload {
        id: "ticket_001".to_string(),
        name: "Benchmark Payload".to_string(),
        email: "bench@kallax.local".to_string(),
        tags: (0..5).map(|i| format!("tag_{i}")).collect(),
        metadata,
        score: 99.5,
        active: true,
        created_at: "2026-06-19T00:00:00Z".to_string(),
    }
}

fn bench_serialize(c: &mut Criterion) {
    let mut group = c.benchmark_group("json_serialize");
    for (size, key_count, n_iters) in [
        ("small", PAYLOAD_KEY_COUNT_SMALL, N_ITERATIONS_SMALL),
        ("medium", PAYLOAD_KEY_COUNT_MEDIUM, N_ITERATIONS_MEDIUM),
        ("large", PAYLOAD_KEY_COUNT_LARGE, N_ITERATIONS_LARGE),
    ] {
        let payload = build_payload(key_count);
        let bytes = serde_json::to_vec(&payload).expect("serialize payload");
        group.throughput(Throughput::Bytes(bytes.len() as u64));
        group.bench_with_input(BenchmarkId::from_parameter(size), &n_iters, |b, &n| {
            b.iter(|| {
                for _ in 0..n {
                    let _ = serde_json::to_vec(&payload).expect("serialize payload");
                }
            });
        });
    }
    group.finish();
}

fn bench_deserialize(c: &mut Criterion) {
    let mut group = c.benchmark_group("json_deserialize");
    for (size, key_count, n_iters) in [
        ("small", PAYLOAD_KEY_COUNT_SMALL, N_ITERATIONS_SMALL),
        ("medium", PAYLOAD_KEY_COUNT_MEDIUM, N_ITERATIONS_MEDIUM),
        ("large", PAYLOAD_KEY_COUNT_LARGE, N_ITERATIONS_LARGE),
    ] {
        let payload = build_payload(key_count);
        let bytes = serde_json::to_vec(&payload).expect("serialize payload");
        group.throughput(Throughput::Bytes(bytes.len() as u64));
        group.bench_with_input(BenchmarkId::from_parameter(size), &n_iters, |b, &n| {
            b.iter(|| {
                for _ in 0..n {
                    let _: Payload = serde_json::from_slice(&bytes).expect("deserialize payload");
                }
            });
        });
    }
    group.finish();
}

criterion_group!(benches, bench_serialize, bench_deserialize);
criterion_main!(benches);
