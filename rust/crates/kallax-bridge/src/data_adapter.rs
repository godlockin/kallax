//! KALLAX data-adapter Rust bridge.
//!
//! Provides [`DataAdapterBridge`], an r2d2-pooled rusqlite-backed
//! implementation of the Node.js `data-adapter` read/write surface
//! (Phase / Epic / ProjectTicket). The method signatures mirror the
//! `#[napi]` target shape so the same surface can later be exposed
//! directly to Node.js via the napi-rs build pipeline.
//!
//! # Method surface (跟 napi_export 目标一致)
//! - `query(sql, params) -> Vec<Row>` — typed rows, suitable for JSON IPC.
//! - `execute(sql, params) -> u64` — rows changed.
//! - `transaction(operations) -> TransactionOutcome` — atomic batch.
//!
//! # Error handling
//! All operations return `Result<T, BridgeError>`. The bridge never panics,
//! never `unwrap`s, and never silently drops errors (跟 kallax-core 联合).
//!
//! # Split (跟 Rule 8 联合, 跟 node data-adapter 5-sub-file 模式 一致)
//! - `data_adapter.rs` (this file): bridge struct + query/execute/transaction.
//! - `ipc.rs`: IpcRequest / IpcResponse / IpcKind envelope.
//! - `codec.rs`: base64 encoder / decoder (blob columns).

use crate::codec::{base64_decode, base64_encode};
use crate::error::{BridgeError, Result};
use crate::ipc::{IpcKind, IpcRequest, IpcResponse};
use crate::{
    BRIDGE_SCHEMA_SQL, DEFAULT_ACQUIRE_TIMEOUT_MS, DEFAULT_POOL_MAX_SIZE,
    DEFAULT_POOL_MIN_IDLE,
};
use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite::types::{ToSql, ToSqlOutput, ValueRef};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

// ============================================================================
// Public types (crosses IPC boundary via serde)
// ============================================================================

/// A typed SQL value that survives the serde round-trip to JSON.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "value")]
pub enum SqlValue {
    Null,
    Integer(i64),
    Real(f64),
    Text(String),
    Blob(String),
}

impl ToSql for SqlValue {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        match self {
            SqlValue::Null => Ok(ToSqlOutput::Owned(rusqlite::types::Value::Null)),
            SqlValue::Integer(v) => Ok(ToSqlOutput::Owned(rusqlite::types::Value::Integer(*v))),
            SqlValue::Real(v) => Ok(ToSqlOutput::Owned(rusqlite::types::Value::Real(*v))),
            SqlValue::Text(v) => Ok(ToSqlOutput::Owned(rusqlite::types::Value::Text(v.clone()))),
            SqlValue::Blob(b) => {
                let bytes = base64_decode(b).map_err(|e| {
                    rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                        std::io::ErrorKind::InvalidData,
                        e,
                    )))
                })?;
                Ok(ToSqlOutput::Owned(rusqlite::types::Value::Blob(bytes)))
            }
        }
    }
}

/// One row of query results.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Row {
    pub columns: Vec<String>,
    pub values: Vec<SqlValue>,
}

impl Row {
    pub fn new(columns: Vec<String>, values: Vec<SqlValue>) -> Self {
        debug_assert_eq!(columns.len(), values.len(), "Row columns/values length mismatch");
        Self { columns, values }
    }
}

/// Snapshot of pool health (跟 observability 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolStats {
    pub max_size: u32,
    pub size: u32,
    pub idle: u32,
    /// Always 0; r2d2 0.8.x does not expose the waiting-thread count publicly.
    pub waiting: u32,
}

/// Single transaction operation — `Execute` returns rows changed;
/// `Query` returns the rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op")]
pub enum TxOperation {
    #[serde(rename = "execute")]
    Execute { sql: String, params: Vec<SqlValue> },
    #[serde(rename = "query")]
    Query { sql: String, params: Vec<SqlValue> },
}

/// Result envelope for a single transaction operation, preserving order.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum TxResult {
    #[serde(rename = "execute")]
    Execute { changes: u64 },
    #[serde(rename = "query")]
    Query { rows: Vec<Row> },
}

/// Aggregate result for a transaction.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionOutcome {
    pub results: Vec<TxResult>,
}

// ============================================================================
// Bridge
// ============================================================================

/// Thread-safe SQLite bridge backed by an r2d2 connection pool.
#[derive(Clone)]
pub struct DataAdapterBridge {
    db_path: PathBuf,
    pool: Pool<SqliteConnectionManager>,
}

impl DataAdapterBridge {
    /// Open (or create) the SQLite database at `path`, set pragmas, apply the
    /// schema migrations, and return a bridge ready to serve queries.
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();

        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }

        let manager = SqliteConnectionManager::file(&path).with_init(|c| {
            c.execute_batch(
                "PRAGMA journal_mode = WAL;
                 PRAGMA synchronous = NORMAL;
                 PRAGMA foreign_keys = ON;",
            )
        });
        let pool = Pool::builder()
            .max_size(DEFAULT_POOL_MAX_SIZE)
            .min_idle(Some(DEFAULT_POOL_MIN_IDLE))
            .connection_timeout(std::time::Duration::from_millis(DEFAULT_ACQUIRE_TIMEOUT_MS))
            .build(manager)
            .map_err(|e| BridgeError::pool("build_pool", e))?;

        let bridge = Self { db_path: path, pool };
        bridge.apply_schema()?;
        Ok(bridge)
    }

    /// Open an in-memory bridge (used by tests).
    pub fn open_in_memory() -> Result<Self> {
        let manager = SqliteConnectionManager::memory().with_init(|c| {
            c.execute_batch(
                "PRAGMA journal_mode = WAL;
                 PRAGMA synchronous = NORMAL;
                 PRAGMA foreign_keys = ON;",
            )
        });
        let pool = Pool::builder()
            .max_size(DEFAULT_POOL_MAX_SIZE)
            .min_idle(Some(DEFAULT_POOL_MIN_IDLE))
            .connection_timeout(std::time::Duration::from_millis(DEFAULT_ACQUIRE_TIMEOUT_MS))
            .build(manager)
            .map_err(|e| BridgeError::pool("build_pool_in_memory", e))?;
        let bridge = Self {
            db_path: PathBuf::from(":memory:"),
            pool,
        };
        bridge.apply_schema()?;
        Ok(bridge)
    }

    fn apply_schema(&self) -> Result<()> {
        let conn = self.pool.get()?;
        conn.execute_batch(BRIDGE_SCHEMA_SQL)
            .map_err(|e| BridgeError::sql("apply_schema", e))?;
        Ok(())
    }

    /// Path the bridge is bound to. Useful for diagnostics / CLI banner.
    pub fn db_path(&self) -> &Path {
        &self.db_path
    }

    /// Current pool health snapshot.
    pub fn pool_stats(&self) -> PoolStats {
        let state = self.pool.state();
        PoolStats {
            max_size: self.pool.max_size(),
            size: state.connections,
            idle: state.idle_connections,
            waiting: 0,
        }
    }

    /// Run a parameterised `SELECT` and return typed rows.
    pub fn query(&self, sql: &str, params: &[SqlValue]) -> Result<Vec<Row>> {
        if sql.trim().is_empty() {
            return Err(BridgeError::invalid_input("sql", "empty SQL not allowed"));
        }
        let conn = self.pool.get()?;
        let mut stmt = conn.prepare(sql)?;
        let column_count = stmt.column_count();
        let columns: Vec<String> = (0..column_count)
            .map(|i| stmt.column_name(i).unwrap_or("").to_string())
            .collect();

        let rusqlite_params: Vec<&dyn rusqlite::types::ToSql> =
            params.iter().map(|v| v as &dyn rusqlite::types::ToSql).collect();

        let rows_iter = stmt.query_map(rusqlite_params.as_slice(), |row| {
            let mut values = Vec::with_capacity(column_count);
            for i in 0..column_count {
                values.push(row_to_sql_value(row, i));
            }
            Ok(Row::new(columns.clone(), values))
        })?;

        let mut rows = Vec::new();
        for row in rows_iter {
            rows.push(row?);
        }
        Ok(rows)
    }

    /// Run a parameterised `INSERT` / `UPDATE` / `DELETE` and return rows
    /// changed.
    pub fn execute(&self, sql: &str, params: &[SqlValue]) -> Result<u64> {
        if sql.trim().is_empty() {
            return Err(BridgeError::invalid_input("sql", "empty SQL not allowed"));
        }
        let conn = self.pool.get()?;
        let rusqlite_params: Vec<&dyn rusqlite::types::ToSql> =
            params.iter().map(|v| v as &dyn rusqlite::types::ToSql).collect();
        let changes = conn.execute(sql, rusqlite_params.as_slice())?;
        Ok(changes as u64)
    }

    /// Run a batch of operations atomically inside a single transaction.
    pub fn transaction(&self, ops: &[TxOperation]) -> Result<TransactionOutcome> {
        if ops.is_empty() {
            return Err(BridgeError::invalid_input("ops", "empty operation list"));
        }
        let mut conn = self.pool.get()?;
        let tx = conn.transaction()?;

        let mut results = Vec::with_capacity(ops.len());
        for op in ops {
            match op {
                TxOperation::Execute { sql, params } => {
                    if sql.trim().is_empty() {
                        return Err(BridgeError::invalid_input("sql", "empty SQL not allowed"));
                    }
                    let rusqlite_params: Vec<&dyn rusqlite::types::ToSql> =
                        params.iter().map(|v| v as &dyn rusqlite::types::ToSql).collect();
                    let changes = tx.execute(sql, rusqlite_params.as_slice())?;
                    results.push(TxResult::Execute { changes: changes as u64 });
                }
                TxOperation::Query { sql, params } => {
                    if sql.trim().is_empty() {
                        return Err(BridgeError::invalid_input("sql", "empty SQL not allowed"));
                    }
                    let mut stmt = tx.prepare(sql)?;
                    let column_count = stmt.column_count();
                    let columns: Vec<String> = (0..column_count)
                        .map(|i| stmt.column_name(i).unwrap_or("").to_string())
                        .collect();
                    let rusqlite_params: Vec<&dyn rusqlite::types::ToSql> =
                        params.iter().map(|v| v as &dyn rusqlite::types::ToSql).collect();
                    let rows_iter = stmt.query_map(rusqlite_params.as_slice(), |row| {
                        let mut values = Vec::with_capacity(column_count);
                        for i in 0..column_count {
                            values.push(row_to_sql_value(row, i));
                        }
                        Ok(Row::new(columns.clone(), values))
                    })?;
                    let mut rows = Vec::new();
                    for row in rows_iter {
                        rows.push(row?);
                    }
                    results.push(TxResult::Query { rows });
                }
            }
        }

        tx.commit()?;
        Ok(TransactionOutcome { results })
    }

    /// Dispatch an [`IpcRequest`] to the appropriate method and return the
    /// matching [`IpcResponse`]. This is the function the CLI loop and the
    /// future `#[napi]` shim both call.
    pub fn handle(&self, req: IpcRequest) -> IpcResponse {
        let id = req.id;
        let result: Result<serde_json::Value> = match req.kind {
            IpcKind::Ping => Ok(serde_json::Value::Bool(true)),
            IpcKind::PoolStats => match serde_json::to_value(self.pool_stats()) {
                Ok(v) => Ok(v),
                Err(e) => Err(BridgeError::ipc("pool_stats_serialize", e)),
            },
            IpcKind::Query => {
                let sql = req.sql.unwrap_or_default();
                let params = req.params.unwrap_or_default();
                match self.query(&sql, &params) {
                    Ok(rows) => match serde_json::to_value(rows) {
                        Ok(v) => Ok(v),
                        Err(e) => Err(BridgeError::ipc("query_serialize", e)),
                    },
                    Err(e) => Err(e),
                }
            }
            IpcKind::Execute => {
                let sql = req.sql.unwrap_or_default();
                let params = req.params.unwrap_or_default();
                match self.execute(&sql, &params) {
                    Ok(changes) => match serde_json::to_value(changes) {
                        Ok(v) => Ok(v),
                        Err(e) => Err(BridgeError::ipc("execute_serialize", e)),
                    },
                    Err(e) => Err(e),
                }
            }
            IpcKind::Transaction => {
                let ops = req.ops.unwrap_or_default();
                match self.transaction(&ops) {
                    Ok(outcome) => match serde_json::to_value(outcome) {
                        Ok(v) => Ok(v),
                        Err(e) => Err(BridgeError::ipc("transaction_serialize", e)),
                    },
                    Err(e) => Err(e),
                }
            }
        };
        match result {
            Ok(value) => IpcResponse::ok(id, value),
            Err(e) => IpcResponse::err(id, &e),
        }
    }
}

// ============================================================================
// Helpers
// ============================================================================

fn row_to_sql_value(row: &rusqlite::Row<'_>, idx: usize) -> SqlValue {
    let raw: ValueRef<'_> = match row.get_ref(idx) {
        Ok(v) => v,
        Err(_) => return SqlValue::Null,
    };
    match raw {
        ValueRef::Null => SqlValue::Null,
        ValueRef::Integer(n) => SqlValue::Integer(n),
        ValueRef::Real(n) => SqlValue::Real(n),
        ValueRef::Text(t) => match std::str::from_utf8(t) {
            Ok(s) => SqlValue::Text(s.to_string()),
            Err(_) => SqlValue::Text(String::from_utf8_lossy(t).into_owned()),
        },
        ValueRef::Blob(b) => SqlValue::Blob(base64_encode(b)),
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    fn fresh() -> DataAdapterBridge {
        DataAdapterBridge::open_in_memory().expect("open in-memory bridge")
    }

    #[test]
    fn execute_returns_changes() {
        let bridge = fresh();
        let n = bridge
            .execute(
                "INSERT INTO phases (id, title, scope, status) VALUES (?, ?, ?, ?)",
                &[
                    SqlValue::Text("P-1".into()),
                    SqlValue::Text("Title".into()),
                    SqlValue::Text("scope".into()),
                    SqlValue::Text("active".into()),
                ],
            )
            .expect("insert");
        assert_eq!(n, 1);
    }

    #[test]
    fn query_returns_typed_rows() {
        let bridge = fresh();
        bridge
            .execute(
                "INSERT INTO phases (id, title, scope, status) VALUES (?, ?, ?, ?)",
                &[
                    SqlValue::Text("P-1".into()),
                    SqlValue::Text("T1".into()),
                    SqlValue::Text("s".into()),
                    SqlValue::Text("active".into()),
                ],
            )
            .unwrap();
        bridge
            .execute(
                "INSERT INTO phases (id, title, scope, status) VALUES (?, ?, ?, ?)",
                &[
                    SqlValue::Text("P-2".into()),
                    SqlValue::Text("T2".into()),
                    SqlValue::Text("s".into()),
                    SqlValue::Text("done".into()),
                ],
            )
            .unwrap();

        let rows = bridge
            .query("SELECT id, title FROM phases ORDER BY id", &[])
            .expect("query");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].columns, vec!["id", "title"]);
        assert_eq!(rows[0].values[0], SqlValue::Text("P-1".into()));
        assert_eq!(rows[0].values[1], SqlValue::Text("T1".into()));
    }

    #[test]
    fn transaction_commits_all() {
        let bridge = fresh();
        let ops = vec![
            TxOperation::Execute {
                sql: "INSERT INTO epics (id, phase_id, title, scope, status) VALUES (?, ?, ?, ?, ?)".into(),
                params: vec![
                    SqlValue::Text("E-1".into()),
                    SqlValue::Text("P-1".into()),
                    SqlValue::Text("epic-1".into()),
                    SqlValue::Text("scope".into()),
                    SqlValue::Text("active".into()),
                ],
            },
            TxOperation::Execute {
                sql: "INSERT INTO epics (id, phase_id, title, scope, status) VALUES (?, ?, ?, ?, ?)".into(),
                params: vec![
                    SqlValue::Text("E-2".into()),
                    SqlValue::Text("P-1".into()),
                    SqlValue::Text("epic-2".into()),
                    SqlValue::Text("scope".into()),
                    SqlValue::Text("active".into()),
                ],
            },
        ];
        let outcome = bridge.transaction(&ops).expect("tx");
        assert_eq!(outcome.results.len(), 2);
        let count: i64 = bridge
            .query("SELECT COUNT(*) AS c FROM epics", &[])
            .unwrap()
            .into_iter()
            .next()
            .and_then(|r| match r.values.first()? {
                SqlValue::Integer(n) => Some(*n),
                _ => None,
            })
            .unwrap_or(0);
        assert_eq!(count, 2);
    }

    #[test]
    fn pool_stats_reports_size() {
        let bridge = fresh();
        let stats = bridge.pool_stats();
        assert_eq!(stats.max_size, DEFAULT_POOL_MAX_SIZE);
        assert!(stats.size <= DEFAULT_POOL_MAX_SIZE);
    }

    #[test]
    fn empty_sql_rejected() {
        let bridge = fresh();
        let err = bridge.query("   ", &[]).unwrap_err();
        assert!(matches!(err, BridgeError::InvalidInput { .. }));
    }
}