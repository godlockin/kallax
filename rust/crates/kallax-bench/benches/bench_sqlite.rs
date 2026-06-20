//! EPIC-060-B Phase 1 Benchmark Task 2: SQLite CRUD
//!
//! Mirrors `node/bench/bench-sqlite.js`. Uses rusqlite (same engine as kallax-engine).
//! Schema is identical to the Node side for fair per-row comparison.

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use rusqlite::{params, Connection};
use std::hint::black_box;

const N_INSERTS_SMALL: usize = 1_000;
const N_INSERTS_MEDIUM: usize = 2_000;
const N_INSERTS_LARGE: usize = 5_000;

const SCHEMA_SQL: &str = "CREATE TABLE IF NOT EXISTS bench (
    id TEXT PRIMARY KEY,
    data TEXT,
    n INTEGER,
    ts INTEGER
)";

const INSERT_SQL: &str = "INSERT INTO bench VALUES (?, ?, ?, ?)";
const SELECT_ALL_SQL: &str = "SELECT id, data, n, ts FROM bench";

// Hold the TempDir so the underlying directory is not removed mid-bench.
struct DbHandle {
    _dir: tempfile::TempDir,
    conn: Connection,
}

fn fresh_handle() -> DbHandle {
    let dir = tempfile::tempdir().expect("tempdir");
    let path = dir.path().join("bench.db");
    let conn = Connection::open(&path).expect("open sqlite");
    conn.execute_batch(SCHEMA_SQL).expect("create schema");
    DbHandle { _dir: dir, conn }
}

fn bench_insert(c: &mut Criterion) {
    let mut group = c.benchmark_group("sqlite_insert");
    for (size, n_rows) in [
        ("small", N_INSERTS_SMALL),
        ("medium", N_INSERTS_MEDIUM),
        ("large", N_INSERTS_LARGE),
    ] {
        group.bench_with_input(BenchmarkId::from_parameter(size), &n_rows, |b, &n| {
            b.iter(|| {
                let handle = fresh_handle();
                {
                    let tx = handle.conn.unchecked_transaction().expect("begin tx");
                    for i in 0..n {
                        tx.execute(
                            INSERT_SQL,
                            params![
                                format!("id_{i}"),
                                format!("payload_data_{i}"),
                                i as i64,
                                1_716_080_400_i64 + i as i64,
                            ],
                        )
                        .expect("insert row");
                    }
                    tx.commit().expect("commit tx");
                }
                black_box(handle);
            });
        });
    }
    group.finish();
}

fn bench_select_all(c: &mut Criterion) {
    let mut group = c.benchmark_group("sqlite_select_all");
    for (size, n_rows) in [
        ("small", N_INSERTS_SMALL),
        ("medium", N_INSERTS_MEDIUM),
        ("large", N_INSERTS_LARGE),
    ] {
        let handle = fresh_handle();
        {
            let tx = handle.conn.unchecked_transaction().expect("begin tx");
            for i in 0..n_rows {
                tx.execute(
                    INSERT_SQL,
                    params![
                        format!("id_{i}"),
                        format!("payload_data_{i}"),
                        i as i64,
                        1_716_080_400_i64 + i as i64,
                    ],
                )
                .expect("seed row");
            }
            tx.commit().expect("commit seed");
        }
        group.bench_with_input(BenchmarkId::from_parameter(size), &n_rows, |b, &_n| {
            b.iter(|| {
                let mut stmt = handle.conn.prepare(SELECT_ALL_SQL).expect("prepare select");
                let rows: Vec<(String, String, i64, i64)> = stmt
                    .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))
                    .expect("query rows")
                    .map(|r| r.expect("row"))
                    .collect();
                black_box(rows);
            });
        });
    }
    group.finish();
}

criterion_group!(benches, bench_insert, bench_select_all);
criterion_main!(benches);