//! Database persistence layer for KALLAX.
//!
//! SQLite backend via rusqlite + r2d2 connection pooling.
//! All tables are created by the built-in migration framework.
//!
//! # Connection setup
//! - WAL journal mode for concurrent read performance
//! - Foreign keys enforced at the engine level
//! - Pool capped at 8 connections

mod migrations;

use crate::error::{KallaxError, Result};
use crate::types::*;
use chrono::{DateTime, TimeZone, Utc};
use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite::params;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// SqliteClient
// ---------------------------------------------------------------------------

/// Thread-safe SQLite client backed by an r2d2 connection pool.
#[derive(Clone)]
pub struct SqliteClient {
    pool: Pool<SqliteConnectionManager>,
}

impl SqliteClient {
    /// Open (or create) the SQLite database at `path`, set pragmas, and run
    /// all pending schema migrations.
    pub fn new(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();

        // Ensure parent directory exists
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|e| KallaxError::io(parent, e))?;
        }

        let manager = SqliteConnectionManager::file(&path);
        let pool = Pool::builder()
            .max_size(8)
            .build(manager)
            .map_err(|e| KallaxError::database("create_pool", e))?;

        // Configure connection-level pragmas
        {
            let conn = pool
                .get()
                .map_err(|e| KallaxError::database("get_connection", e))?;
            conn.execute_batch(
                "PRAGMA journal_mode = WAL;
                 PRAGMA foreign_keys = ON;",
            )
            .map_err(|e| KallaxError::database("set_pragmas", e))?;
        }

        let client = Self { pool };
        client.run_migrations()?;
        Ok(client)
    }

    /// Run all pending schema migrations. Returns the number applied.
    pub fn run_migrations(&self) -> Result<u64> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let runner = migrations::MigrationRunner::default();
        runner.run(&conn)
    }

    // -----------------------------------------------------------------------
    // Ticket CRUD
    // -----------------------------------------------------------------------

    /// Insert a new ticket. Errors if the ID already exists.
    pub fn insert_ticket(&self, ticket: &Ticket) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT INTO tickets
                (id, title, description, status, priority,
                 scope, acceptance_criteria, tags, metadata,
                 created_at, updated_at, assigned_to)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            params![
                ticket.id().as_str(),
                ticket.title(),
                ticket.description(),
                ticket.status().as_str(),
                ticket.priority() as i64,
                ser_scope(ticket.scope()),
                ser_strs(ticket.acceptance_criteria()),
                ser_strs(ticket.tags()),
                ser_meta(ticket.metadata()),
                ts_to_str(&ticket.created_at()),
                ts_to_str(&ticket.updated_at()),
                ticket.assigned_to().map(PerformerId::as_str),
            ],
        )
        .map_err(|e| KallaxError::database("insert_ticket", e))?;
        Ok(())
    }

    /// Fetch a single ticket by ID. Returns `NotFound` if it does not exist.
    pub fn get_ticket(&self, id: &str) -> Result<Ticket> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let mut stmt = conn
            .prepare(SELECT_TICKET)
            .map_err(|e| KallaxError::database("prepare_get_ticket", e))?;

        let mut rows = stmt
            .query(params![id])
            .map_err(|e| KallaxError::database("query_get_ticket", e))?;

        match rows
            .next()
            .map_err(|e| KallaxError::database("get_ticket_next", e))?
        {
            Some(row) => ticket_from_row(row),
            None => Err(KallaxError::not_found("ticket", id)),
        }
    }

    /// List tickets, optionally filtered. Ordered by `created_at DESC`.
    pub fn list_tickets(&self, filter: &TicketFilter) -> Result<Vec<Ticket>> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;

        let (sql, param_values) = build_list_sql(filter);
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_list_tickets", e))?;

        let param_refs: Vec<&dyn rusqlite::types::ToSql> =
            param_values.iter().map(|b| b.as_ref()).collect();

        let mut rows = stmt
            .query(param_refs.as_slice())
            .map_err(|e| KallaxError::database("query_list_tickets", e))?;

        let mut tickets = Vec::new();
        while let Some(row) = rows
            .next()
            .map_err(|e| KallaxError::database("list_tickets_next", e))?
        {
            tickets.push(ticket_from_row(row)?);
        }
        Ok(tickets)
    }

    /// Update an existing ticket. Returns `NotFound` if the ID does not exist.
    pub fn update_ticket(&self, ticket: &Ticket) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let rows = conn
            .execute(
                "UPDATE tickets SET
                    title            = ?1,
                    description      = ?2,
                    status           = ?3,
                    priority         = ?4,
                    scope            = ?5,
                    acceptance_criteria = ?6,
                    tags             = ?7,
                    metadata         = ?8,
                    updated_at       = ?9,
                    assigned_to      = ?10
                 WHERE id = ?11",
                params![
                    ticket.title(),
                    ticket.description(),
                    ticket.status().as_str(),
                    ticket.priority() as i64,
                    ser_scope(ticket.scope()),
                    ser_strs(ticket.acceptance_criteria()),
                    ser_strs(ticket.tags()),
                    ser_meta(ticket.metadata()),
                    ts_to_str(&ticket.updated_at()),
                    ticket.assigned_to().map(PerformerId::as_str),
                    ticket.id().as_str(),
                ],
            )
            .map_err(|e| KallaxError::database("update_ticket", e))?;

        if rows == 0 {
            return Err(KallaxError::not_found("ticket", ticket.id().as_str()));
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// TicketFilter
// ---------------------------------------------------------------------------

/// Optional filters for `list_tickets`.
#[derive(Debug, Default)]
pub struct TicketFilter {
    pub status: Option<TicketStatus>,
    pub priority: Option<Priority>,
    pub assigned_to: Option<String>,
    pub limit: Option<usize>,
    pub offset: Option<usize>,
}

// ---------------------------------------------------------------------------
// Query building
// ---------------------------------------------------------------------------

const SELECT_TICKET: &str =
    "SELECT id, title, description, status, priority,
            scope, acceptance_criteria, tags, metadata,
            created_at, updated_at, assigned_to
     FROM tickets";

/// Build a parameterised list query + its bound values.
fn build_list_sql(
    filter: &TicketFilter,
) -> (String, Vec<Box<dyn rusqlite::types::ToSql>>) {
    let mut sql = String::with_capacity(320);
    sql.push_str(SELECT_TICKET);
    sql.push_str(" WHERE 1=1");

    let mut params: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();

    if let Some(ref status) = filter.status {
        sql.push_str(" AND status = ?");
        params.push(Box::new(status.as_str().to_string()));
    }
    if let Some(priority) = filter.priority {
        sql.push_str(" AND priority = ?");
        params.push(Box::new(priority as i64));
    }
    if let Some(ref assigned) = filter.assigned_to {
        sql.push_str(" AND assigned_to = ?");
        params.push(Box::new(assigned.clone()));
    }

    sql.push_str(" ORDER BY created_at DESC");

    if let Some(limit) = filter.limit {
        sql.push_str(" LIMIT ?");
        params.push(Box::new(limit as i64));
    }
    if let Some(offset) = filter.offset {
        sql.push_str(" OFFSET ?");
        params.push(Box::new(offset as i64));
    }

    (sql, params)
}

// ---------------------------------------------------------------------------
// Row → Ticket
// ---------------------------------------------------------------------------

fn ticket_from_row(row: &rusqlite::Row<'_>) -> Result<Ticket> {
    let get_str = |idx: usize| -> Result<String> {
        row.get::<_, String>(idx)
            .map_err(|e| KallaxError::database("get_ticket_row", e))
    };

    let id = TicketId::from_str(get_str(0)?);
    let title = get_str(1)?;
    let description = get_str(2)?;
    let status_str = get_str(3)?;
    let priority_val: i64 = row
        .get::<_, i64>(4)
        .map_err(|e| KallaxError::database("get_ticket_row", e))?;
    let scope_str = get_str(5)?;
    let ac_str = get_str(6)?;
    let tags_str = get_str(7)?;
    let meta_str = get_str(8)?;
    let created_str = get_str(9)?;
    let updated_str = get_str(10)?;
    let assigned_str: Option<String> = row
        .get::<_, Option<String>>(11)
        .map_err(|e| KallaxError::database("get_ticket_row", e))?;

    let status = TicketStatus::from_str(&status_str).ok_or_else(|| {
        KallaxError::database(
            "parse_ticket_status",
            format!("unknown status: '{}'", status_str),
        )
    })?;

    let priority = Priority::from_i64(priority_val).ok_or_else(|| {
        KallaxError::database(
            "parse_ticket_priority",
            format!("unknown priority value: {}", priority_val),
        )
    })?;

    let created_at = str_to_ts(&created_str)?;
    let updated_at = str_to_ts(&updated_str)?;
    let assigned_to = assigned_str.map(PerformerId::from_str);

    Ok(Ticket::from_storage(
        id,
        title,
        description,
        status,
        priority,
        de_scope(&scope_str),
        de_strs(&ac_str),
        de_strs(&tags_str),
        de_meta(&meta_str),
        created_at,
        updated_at,
        assigned_to,
    ))
}

// ---------------------------------------------------------------------------
// Serialisation helpers
// ---------------------------------------------------------------------------

fn ser_scope(scope: &[PathBuf]) -> String {
    serde_json::to_string(scope).unwrap_or_else(|_| "[]".to_string())
}

fn de_scope(s: &str) -> Vec<PathBuf> {
    serde_json::from_str(s).unwrap_or_default()
}

fn ser_strs(v: &[String]) -> String {
    serde_json::to_string(v).unwrap_or_else(|_| "[]".to_string())
}

fn de_strs(s: &str) -> Vec<String> {
    serde_json::from_str(s).unwrap_or_default()
}

fn ser_meta(m: &HashMap<String, serde_json::Value>) -> String {
    serde_json::to_string(m).unwrap_or_else(|_| "{}".to_string())
}

fn de_meta(s: &str) -> HashMap<String, serde_json::Value> {
    serde_json::from_str(s).unwrap_or_default()
}

fn ts_to_str(dt: &DateTime<Utc>) -> String {
    dt.to_rfc3339()
}

fn str_to_ts(s: &str) -> Result<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|e| KallaxError::database("parse_datetime", e))
}

// ---------------------------------------------------------------------------
// Enum helpers
// ---------------------------------------------------------------------------

impl TicketStatus {
    fn from_str(s: &str) -> Option<Self> {
        match s {
            "ready" => Some(Self::Ready),
            "in_progress" => Some(Self::InProgress),
            "completed" => Some(Self::Completed),
            "failed" => Some(Self::Failed),
            "blocked" => Some(Self::Blocked),
            _ => None,
        }
    }
}

impl Priority {
    fn from_i64(v: i64) -> Option<Self> {
        match v {
            0 => Some(Self::Low),
            1 => Some(Self::Normal),
            2 => Some(Self::High),
            3 => Some(Self::Critical),
            _ => None,
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn test_client() -> SqliteClient {
        SqliteClient::new(":memory:").expect("create in-memory client")
    }

    fn sample_ticket() -> Ticket {
        Ticket::new("Test ticket", "A sample ticket for DB testing")
            .with_priority(Priority::High)
            .with_scope(vec![PathBuf::from("src/main.rs")])
            .with_tags(vec!["test".to_string(), "db".to_string()])
    }

    #[test]
    fn insert_and_get() {
        let client = test_client();
        let ticket = sample_ticket();
        let id = ticket.id().as_str().to_string();

        client.insert_ticket(&ticket).expect("insert");
        let fetched = client.get_ticket(&id).expect("get");
        assert_eq!(fetched.id().as_str(), ticket.id().as_str());
        assert_eq!(fetched.title(), ticket.title());
        assert_eq!(fetched.status(), TicketStatus::Ready);
    }

    #[test]
    fn get_nonexistent_returns_not_found() {
        let client = test_client();
        let err = client.get_ticket("NONEXISTENT").unwrap_err();
        assert!(
            matches!(err, KallaxError::NotFound { .. }),
            "expected NotFound, got: {:?}",
            err
        );
    }

    #[test]
    fn insert_and_list() {
        let client = test_client();
        let t1 = Ticket::new("First", "First ticket");
        let t2 = Ticket::new("Second", "Second ticket");
        client.insert_ticket(&t1).unwrap();
        client.insert_ticket(&t2).unwrap();

        let all = client.list_tickets(&TicketFilter::default()).unwrap();
        assert_eq!(all.len(), 2);
    }

    #[test]
    fn update_ticket() {
        let client = test_client();
        let mut ticket = sample_ticket();
        client.insert_ticket(&ticket).unwrap();

        ticket.assign(PerformerId::new()).unwrap();
        client.update_ticket(&ticket).unwrap();

        let fetched = client.get_ticket(ticket.id().as_str()).unwrap();
        assert_eq!(fetched.status(), TicketStatus::InProgress);
    }

    #[test]
    fn update_nonexistent_returns_not_found() {
        let client = test_client();
        let ticket = sample_ticket();
        let err = client.update_ticket(&ticket).unwrap_err();
        assert!(
            matches!(err, KallaxError::NotFound { .. }),
            "expected NotFound, got: {:?}",
            err
        );
    }

    #[test]
    fn filter_by_status() {
        let client = test_client();
        let mut t = Ticket::new("Will be in progress", "");
        t.assign(PerformerId::new()).unwrap();
        client.insert_ticket(&t).unwrap();
        client
            .insert_ticket(&Ticket::new("Ready one", ""))
            .unwrap();

        let filter = TicketFilter {
            status: Some(TicketStatus::InProgress),
            ..Default::default()
        };
        let results = client.list_tickets(&filter).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].status(), TicketStatus::InProgress);
    }

    #[test]
    fn filter_limit_and_offset() {
        let client = test_client();
        for i in 0..5 {
            let t = Ticket::new(format!("Ticket {}", i), "");
            client.insert_ticket(&t).unwrap();
        }

        let all = client.list_tickets(&TicketFilter::default()).unwrap();
        assert_eq!(all.len(), 5);

        let limited = client
            .list_tickets(&TicketFilter {
                limit: Some(2),
                offset: Some(0),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(limited.len(), 2);
    }
}
