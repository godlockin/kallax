//! Schema migration framework for KALLAX.
//!
//! Tracks applied migrations in a `schema_version` table and runs pending
//! migrations in version order. All migrations are embedded — no external
//! migration files needed at runtime.

use crate::error::{KallaxError, Result};
use rusqlite::Connection;

// ---------------------------------------------------------------------------
// schema_version table (auto-created by MigrationRunner)
// ---------------------------------------------------------------------------
const SCHEMA_VERSION_DDL: &str = "
    CREATE TABLE IF NOT EXISTS schema_version (
        version     INTEGER PRIMARY KEY,
        description TEXT    NOT NULL,
        applied_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );
";

// ---------------------------------------------------------------------------
// Migration trait
// ---------------------------------------------------------------------------

/// A single migration step.
pub trait Migration {
    /// Monotonically increasing version number (1, 2, 3, …).
    fn version(&self) -> u64;

    /// Human-readable description.
    fn description(&self) -> &'static str;

    /// Apply the migration. Receives a `&Connection` that already has
    /// foreign keys and WAL mode configured.
    fn up(&self, conn: &Connection) -> Result<()>;
}

// ---------------------------------------------------------------------------
// MigrationRunner
// ---------------------------------------------------------------------------

/// Runs pending migrations in version order.
pub struct MigrationRunner {
    migrations: Vec<Box<dyn Migration>>,
}

impl MigrationRunner {
    /// Register a migration.
    pub fn register(&mut self, m: Box<dyn Migration>) {
        self.migrations.push(m);
    }

    /// Register migrations from an iterator.
    #[allow(dead_code)] // Reserved for future programmatic migration registration.
    pub fn register_all(&mut self, ms: impl IntoIterator<Item = Box<dyn Migration>>) {
        self.migrations.extend(ms);
    }

    /// Ensure the schema_version table exists, then execute every migration
    /// whose version has not yet been recorded.
    pub fn run(&self, conn: &Connection) -> Result<i64> {
        conn.execute_batch(SCHEMA_VERSION_DDL)
            .map_err(|e| KallaxError::database("create_schema_version_table", e))?;

        let current: i64 = conn
            .query_row(
                "SELECT COALESCE(MAX(version), 0) FROM schema_version",
                [],
                |row| row.get(0),
            )
            .map_err(|e| KallaxError::database("read_current_version", e))?;

        let mut applied = 0i64;
        let mut sorted: Vec<_> = self.migrations.iter().collect();
        sorted.sort_by_key(|m| m.version());

        for m in &sorted {
            if (m.version() as i64) > current {
                tracing::info!("applying migration v{}: {}", m.version(), m.description());
                m.up(conn)?;
                conn.execute(
                    "INSERT INTO schema_version (version, description) VALUES (?1, ?2)",
                    rusqlite::params![m.version() as i64, m.description()],
                )
                .map_err(|e| KallaxError::database("record_migration", e))?;
                applied += 1;
            }
        }

        tracing::info!("migration complete (applied: {})", applied);
        Ok(applied)
    }
}

impl Default for MigrationRunner {
    fn default() -> Self {
        let mut runner = Self {
            migrations: Vec::new(),
        };
        runner.register(Box::new(V0001Initial));
        runner
    }
}

// ---------------------------------------------------------------------------
// Built-in migrations
// ---------------------------------------------------------------------------

/// v1 — creates all 12 tables and indexes.
pub struct V0001Initial;

impl Migration for V0001Initial {
    fn version(&self) -> u64 {
        1
    }
    fn description(&self) -> &'static str {
        "initial schema — 12 tables + indexes"
    }
    fn up(&self, conn: &Connection) -> Result<()> {
        let sql = include_str!("schema.sql");
        conn.execute_batch(sql)
            .map_err(|e| KallaxError::database("migration_v1_initial", e))
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn in_memory_conn() -> Connection {
        let conn = Connection::open_in_memory().expect("create in-memory db");
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;")
            .expect("set pragmas");
        conn
    }

    #[test]
    fn runner_applies_pending() {
        let conn = in_memory_conn();
        let runner = MigrationRunner::default();
        let count = runner.run(&conn).expect("run migrations");
        assert!(count > 0, "should apply at least 1 migration");

        // Second run should apply nothing
        let count2 = runner.run(&conn).expect("re-run migrations");
        assert_eq!(count2, 0, "no new migrations to apply");
    }

    #[test]
    fn all_tables_exist_after_migration() {
        let conn = in_memory_conn();
        MigrationRunner::default()
            .run(&conn)
            .expect("run migrations");

        let tables = [
            "tickets",
            "execution_checkpoints",
            "instances",
            "retros",
            "trace_spans",
            "knowledge_entries",
            "performer_instances",
            "instance_execution_states",
            "master_lock",
            "message_history",
            "dag_runs",
            "dag_node_states",
        ];

        for name in &tables {
            let exists: bool = conn
                .query_row(
                    "SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name=?1",
                    rusqlite::params![name],
                    |row| row.get(0),
                )
                .expect("check table exists");
            assert!(exists, "table '{}' should exist", name);
        }
    }
}
