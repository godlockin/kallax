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
mod serialization;

pub(crate) use serialization::{
    de_meta, de_scope, de_strs, ser_meta, ser_scope, ser_strs, str_to_ts, ts_to_str,
};

use crate::error::{KallaxError, Result};
use crate::types::*;
use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite::params;
use std::path::Path;

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
            std::fs::create_dir_all(parent).map_err(|e| KallaxError::io(parent, e))?;
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
    pub fn run_migrations(&self) -> Result<i64> {
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
            .prepare(
                "SELECT id, title, description, status, priority,
                             scope, acceptance_criteria, tags, metadata,
                             created_at, updated_at, assigned_to
                      FROM tickets WHERE id = ?1",
            )
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

    // -----------------------------------------------------------------------
    // Instance CRUD
    // -----------------------------------------------------------------------

    /// Insert a new instance. Errors if the ID already exists.
    pub fn insert_instance(&self, instance: &Instance) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT INTO instances
                (id, name, role, status, metadata, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                instance.id(),
                instance.name(),
                instance.role().as_str(),
                instance.status(),
                ser_meta(instance.metadata()),
                ts_to_str(&instance.created_at()),
                ts_to_str(&instance.updated_at()),
            ],
        )
        .map_err(|e| KallaxError::database("insert_instance", e))?;
        Ok(())
    }

    /// Upsert an instance (INSERT OR REPLACE). Used by session_start dual-write.
    pub fn upsert_instance(&self, instance: &Instance) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT OR REPLACE INTO instances
                (id, name, role, status, metadata, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                instance.id(),
                instance.name(),
                instance.role().as_str(),
                instance.status(),
                ser_meta(instance.metadata()),
                ts_to_str(&instance.created_at()),
                ts_to_str(&instance.updated_at()),
            ],
        )
        .map_err(|e| KallaxError::database("upsert_instance", e))?;
        Ok(())
    }

    /// Fetch a single instance by ID.
    pub fn get_instance(&self, id: &str) -> Result<Instance> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let sql = format!("{} WHERE id = ?1", SELECT_INSTANCE_BASE);
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_get_instance", e))?;
        let mut rows = stmt
            .query(params![id])
            .map_err(|e| KallaxError::database("query_get_instance", e))?;
        match rows
            .next()
            .map_err(|e| KallaxError::database("get_instance_next", e))?
        {
            Some(row) => instance_from_row(row),
            None => Err(KallaxError::not_found("instance", id)),
        }
    }

    /// List instances, optionally filtered by role. Ordered by `created_at DESC`.
    pub fn list_instances(&self, role: Option<InstanceRole>) -> Result<Vec<Instance>> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let (sql, role_param) = match role {
            Some(r) => (
                format!(
                    "{} WHERE role = ?1 ORDER BY created_at DESC",
                    SELECT_INSTANCE_BASE
                ),
                Some(r.as_str().to_string()),
            ),
            None => (
                format!("{} ORDER BY created_at DESC", SELECT_INSTANCE_BASE),
                None,
            ),
        };
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_list_instances", e))?;
        let mut rows = match &role_param {
            Some(v) => stmt
                .query(params![v])
                .map_err(|e| KallaxError::database("query_list_instances", e))?,
            None => stmt
                .query([])
                .map_err(|e| KallaxError::database("query_list_instances", e))?,
        };
        let mut out = Vec::new();
        while let Some(row) = rows
            .next()
            .map_err(|e| KallaxError::database("list_instances_next", e))?
        {
            out.push(instance_from_row(row)?);
        }
        Ok(out)
    }

    /// Update an existing instance. Returns `NotFound` if the ID does not exist.
    pub fn update_instance(&self, instance: &Instance) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let rows = conn
            .execute(
                "UPDATE instances SET
                name       = ?1,
                role       = ?2,
                status     = ?3,
                metadata   = ?4,
                updated_at = ?5
             WHERE id = ?6",
                params![
                    instance.name(),
                    instance.role().as_str(),
                    instance.status(),
                    ser_meta(instance.metadata()),
                    ts_to_str(&instance.updated_at()),
                    instance.id(),
                ],
            )
            .map_err(|e| KallaxError::database("update_instance", e))?;
        if rows == 0 {
            return Err(KallaxError::not_found("instance", instance.id()));
        }
        Ok(())
    }

    // -----------------------------------------------------------------------
    // TraceSpan CRUD (append-only audit log)
    // -----------------------------------------------------------------------

    /// Insert a new trace span. Append-only; use `update_span_end` to close it.
    pub fn insert_span(&self, span: &TraceSpan) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT INTO trace_spans
                (id, span_name, parent_span_id, context, started_at, ended_at, duration_ms)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                span.id(),
                span.span_name(),
                span.parent_span_id(),
                ser_meta(span.context()),
                ts_to_str(&span.started_at()),
                span.ended_at().map(|t| ts_to_str(&t)),
                span.duration_ms(),
            ],
        )
        .map_err(|e| KallaxError::database("insert_span", e))?;
        Ok(())
    }

    /// Close an in-flight span (sets ended_at + duration_ms).
    pub fn update_span_end(&self, span: &TraceSpan) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let rows = conn
            .execute(
                "UPDATE trace_spans SET
                ended_at    = ?1,
                duration_ms = ?2
             WHERE id = ?3",
                params![
                    span.ended_at().map(|t| ts_to_str(&t)),
                    span.duration_ms(),
                    span.id(),
                ],
            )
            .map_err(|e| KallaxError::database("update_span_end", e))?;
        if rows == 0 {
            return Err(KallaxError::not_found("trace_span", span.id()));
        }
        Ok(())
    }

    /// Fetch a single span by ID.
    pub fn get_span(&self, id: &str) -> Result<TraceSpan> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let sql = format!("{} WHERE id = ?1", SELECT_SPAN_BASE);
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_get_span", e))?;
        let mut rows = stmt
            .query(params![id])
            .map_err(|e| KallaxError::database("query_get_span", e))?;
        match rows
            .next()
            .map_err(|e| KallaxError::database("get_span_next", e))?
        {
            Some(row) => span_from_row(row),
            None => Err(KallaxError::not_found("trace_span", id)),
        }
    }

    /// List spans by name, ordered `started_at DESC`. Empty name = list all.
    pub fn list_spans_by_name(
        &self,
        name: Option<&str>,
        limit: Option<usize>,
    ) -> Result<Vec<TraceSpan>> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let mut sql = String::from(SELECT_SPAN_BASE);
        if name.is_some() {
            sql.push_str(" WHERE span_name = ?1");
        }
        sql.push_str(" ORDER BY started_at DESC");
        if let Some(l) = limit {
            sql.push_str(&format!(" LIMIT {}", l as i64));
        }
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_list_spans", e))?;
        let mut rows = match name {
            Some(n) => stmt
                .query(params![n])
                .map_err(|e| KallaxError::database("query_list_spans", e))?,
            None => stmt
                .query([])
                .map_err(|e| KallaxError::database("query_list_spans", e))?,
        };
        let mut out = Vec::new();
        while let Some(row) = rows
            .next()
            .map_err(|e| KallaxError::database("list_spans_next", e))?
        {
            out.push(span_from_row(row)?);
        }
        Ok(out)
    }

    // -----------------------------------------------------------------------
    // DagRun CRUD
    // -----------------------------------------------------------------------

    pub fn insert_dag_run(&self, run: &DagRun) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT INTO dag_runs (id, dag_name, status, trigger, started_at, completed_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                run.id(),
                run.dag_name(),
                run.status().as_str(),
                run.trigger(),
                run.started_at().map(|t| ts_to_str(&t)),
                run.completed_at().map(|t| ts_to_str(&t)),
            ],
        )
        .map_err(|e| KallaxError::database("insert_dag_run", e))?;
        Ok(())
    }

    pub fn update_dag_run(&self, run: &DagRun) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let rows = conn
            .execute(
                "UPDATE dag_runs SET
                dag_name     = ?1,
                status       = ?2,
                trigger      = ?3,
                started_at   = ?4,
                completed_at = ?5
             WHERE id = ?6",
                params![
                    run.dag_name(),
                    run.status().as_str(),
                    run.trigger(),
                    run.started_at().map(|t| ts_to_str(&t)),
                    run.completed_at().map(|t| ts_to_str(&t)),
                    run.id(),
                ],
            )
            .map_err(|e| KallaxError::database("update_dag_run", e))?;
        if rows == 0 {
            return Err(KallaxError::not_found("dag_run", run.id()));
        }
        Ok(())
    }

    pub fn get_dag_run(&self, id: &str) -> Result<DagRun> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let sql = format!("{} WHERE id = ?1", SELECT_DAG_RUN_BASE);
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_get_dag_run", e))?;
        let mut rows = stmt
            .query(params![id])
            .map_err(|e| KallaxError::database("query_get_dag_run", e))?;
        match rows
            .next()
            .map_err(|e| KallaxError::database("get_dag_run_next", e))?
        {
            Some(row) => dag_run_from_row(row),
            None => Err(KallaxError::not_found("dag_run", id)),
        }
    }

    pub fn list_dag_runs(&self, status: Option<DagStatus>) -> Result<Vec<DagRun>> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let (sql, param): (String, Option<String>) = match status {
            Some(s) => (
                format!("{} WHERE status = ?1 ORDER BY id DESC", SELECT_DAG_RUN_BASE),
                Some(s.as_str().to_string()),
            ),
            None => (format!("{} ORDER BY id DESC", SELECT_DAG_RUN_BASE), None),
        };
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_list_dag_runs", e))?;
        let mut rows = match &param {
            Some(v) => stmt
                .query(params![v])
                .map_err(|e| KallaxError::database("query_list_dag_runs", e))?,
            None => stmt
                .query([])
                .map_err(|e| KallaxError::database("query_list_dag_runs", e))?,
        };
        let mut out = Vec::new();
        while let Some(row) = rows
            .next()
            .map_err(|e| KallaxError::database("list_dag_runs_next", e))?
        {
            out.push(dag_run_from_row(row)?);
        }
        Ok(out)
    }

    // -----------------------------------------------------------------------
    // DagNodeState CRUD
    // -----------------------------------------------------------------------

    pub fn insert_dag_node(&self, node: &DagNodeState) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        conn.execute(
            "INSERT INTO dag_node_states
                (id, dag_run_id, node_name, status, task_id, output, started_at, completed_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                node.id(),
                node.dag_run_id(),
                node.node_name(),
                node.status().as_str(),
                node.task_id(),
                node.output(),
                node.started_at().map(|t| ts_to_str(&t)),
                node.completed_at().map(|t| ts_to_str(&t)),
            ],
        )
        .map_err(|e| KallaxError::database("insert_dag_node", e))?;
        Ok(())
    }

    pub fn update_dag_node(&self, node: &DagNodeState) -> Result<()> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let rows = conn
            .execute(
                "UPDATE dag_node_states SET
                node_name    = ?1,
                status       = ?2,
                task_id      = ?3,
                output       = ?4,
                started_at   = ?5,
                completed_at = ?6
             WHERE id = ?7",
                params![
                    node.node_name(),
                    node.status().as_str(),
                    node.task_id(),
                    node.output(),
                    node.started_at().map(|t| ts_to_str(&t)),
                    node.completed_at().map(|t| ts_to_str(&t)),
                    node.id(),
                ],
            )
            .map_err(|e| KallaxError::database("update_dag_node", e))?;
        if rows == 0 {
            return Err(KallaxError::not_found("dag_node_state", node.id()));
        }
        Ok(())
    }

    pub fn list_dag_nodes(&self, dag_run_id: &str) -> Result<Vec<DagNodeState>> {
        let conn = self
            .pool
            .get()
            .map_err(|e| KallaxError::database("get_connection", e))?;
        let sql = format!(
            "{} WHERE dag_run_id = ?1 ORDER BY id ASC",
            SELECT_DAG_NODE_BASE
        );
        let mut stmt = conn
            .prepare(&sql)
            .map_err(|e| KallaxError::database("prepare_list_dag_nodes", e))?;
        let mut rows = stmt
            .query(params![dag_run_id])
            .map_err(|e| KallaxError::database("query_list_dag_nodes", e))?;
        let mut out = Vec::new();
        while let Some(row) = rows
            .next()
            .map_err(|e| KallaxError::database("list_dag_nodes_next", e))?
        {
            out.push(dag_node_from_row(row)?);
        }
        Ok(out)
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

const SELECT_TICKET: &str = "SELECT id, title, description, status, priority,
            scope, acceptance_criteria, tags, metadata,
            created_at, updated_at, assigned_to
     FROM tickets";

const SELECT_INSTANCE_BASE: &str =
    "SELECT id, name, role, status, metadata, created_at, updated_at FROM instances";

const SELECT_SPAN_BASE: &str =
    "SELECT id, span_name, parent_span_id, context, started_at, ended_at, duration_ms
     FROM trace_spans";

const SELECT_DAG_RUN_BASE: &str =
    "SELECT id, dag_name, status, trigger, started_at, completed_at FROM dag_runs";

const SELECT_DAG_NODE_BASE: &str =
    "SELECT id, dag_run_id, node_name, status, task_id, output, started_at, completed_at
     FROM dag_node_states";

/// Build a parameterised list query + its bound values.
fn build_list_sql(filter: &TicketFilter) -> (String, Vec<Box<dyn rusqlite::types::ToSql>>) {
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

fn instance_from_row(row: &rusqlite::Row<'_>) -> Result<Instance> {
    let get_str = |idx: usize| -> Result<String> {
        row.get::<_, String>(idx)
            .map_err(|e| KallaxError::database("get_instance_row", e))
    };
    let id = get_str(0)?;
    let name = get_str(1)?;
    let role_str = get_str(2)?;
    let status = get_str(3)?;
    let meta_str = get_str(4)?;
    let created_str = get_str(5)?;
    let updated_str = get_str(6)?;

    let role = InstanceRole::from_str(&role_str).ok_or_else(|| {
        KallaxError::database(
            "parse_instance_role",
            format!("unknown instance role: '{}'", role_str),
        )
    })?;

    Ok(Instance::from_storage(
        id,
        name,
        role,
        status,
        de_meta(&meta_str),
        str_to_ts(&created_str)?,
        str_to_ts(&updated_str)?,
    ))
}

fn span_from_row(row: &rusqlite::Row<'_>) -> Result<TraceSpan> {
    let map_err = |e: rusqlite::Error| KallaxError::database("get_span_row", e);
    let id: String = row.get(0).map_err(map_err)?;
    let name: String = row.get(1).map_err(map_err)?;
    let parent: Option<String> = row.get(2).map_err(map_err)?;
    let context_str: String = row.get(3).map_err(map_err)?;
    let started_str: String = row.get(4).map_err(map_err)?;
    let ended_str: Option<String> = row.get(5).map_err(map_err)?;
    let duration_ms: Option<i64> = row.get(6).map_err(map_err)?;

    let ended_at = match ended_str {
        Some(s) => Some(str_to_ts(&s)?),
        None => None,
    };

    Ok(TraceSpan::from_storage(
        id,
        name,
        parent,
        de_meta(&context_str),
        str_to_ts(&started_str)?,
        ended_at,
        duration_ms,
    ))
}

fn dag_run_from_row(row: &rusqlite::Row<'_>) -> Result<DagRun> {
    let map_err = |e: rusqlite::Error| KallaxError::database("get_dag_run_row", e);
    let id: String = row.get(0).map_err(map_err)?;
    let dag_name: String = row.get(1).map_err(map_err)?;
    let status_str: String = row.get(2).map_err(map_err)?;
    let trigger: String = row.get(3).map_err(map_err)?;
    let started_str: Option<String> = row.get(4).map_err(map_err)?;
    let completed_str: Option<String> = row.get(5).map_err(map_err)?;

    let status = DagStatus::from_str(&status_str).ok_or_else(|| {
        KallaxError::database(
            "parse_dag_status",
            format!("unknown dag status: '{}'", status_str),
        )
    })?;

    let started_at = match started_str {
        Some(s) => Some(str_to_ts(&s)?),
        None => None,
    };
    let completed_at = match completed_str {
        Some(s) => Some(str_to_ts(&s)?),
        None => None,
    };

    Ok(DagRun::from_storage(
        id,
        dag_name,
        status,
        trigger,
        started_at,
        completed_at,
    ))
}

fn dag_node_from_row(row: &rusqlite::Row<'_>) -> Result<DagNodeState> {
    let map_err = |e: rusqlite::Error| KallaxError::database("get_dag_node_row", e);
    let id: String = row.get(0).map_err(map_err)?;
    let dag_run_id: String = row.get(1).map_err(map_err)?;
    let node_name: String = row.get(2).map_err(map_err)?;
    let status_str: String = row.get(3).map_err(map_err)?;
    let task_id: Option<String> = row.get(4).map_err(map_err)?;
    let output: Option<String> = row.get(5).map_err(map_err)?;
    let started_str: Option<String> = row.get(6).map_err(map_err)?;
    let completed_str: Option<String> = row.get(7).map_err(map_err)?;

    let status = DagStatus::from_str(&status_str).ok_or_else(|| {
        KallaxError::database(
            "parse_dag_status",
            format!("unknown dag status: '{}'", status_str),
        )
    })?;

    let started_at = match started_str {
        Some(s) => Some(str_to_ts(&s)?),
        None => None,
    };
    let completed_at = match completed_str {
        Some(s) => Some(str_to_ts(&s)?),
        None => None,
    };

    Ok(DagNodeState::from_storage(
        id,
        dag_run_id,
        node_name,
        status,
        task_id,
        output,
        started_at,
        completed_at,
    ))
}

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
        client.insert_ticket(&Ticket::new("Ready one", "")).unwrap();

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

    // -------------------------------------------------------------------
    // Instance CRUD tests
    // -------------------------------------------------------------------

    fn sample_instance(id: &str, role: InstanceRole) -> Instance {
        Instance::new(id, format!("name-{}", id), role)
    }

    #[test]
    fn instance_insert_and_get() {
        let client = test_client();
        let inst = sample_instance("INST-1", InstanceRole::Conductor);
        client.insert_instance(&inst).expect("insert");
        let got = client.get_instance("INST-1").expect("get");
        assert_eq!(got.id(), "INST-1");
        assert_eq!(got.role(), InstanceRole::Conductor);
        assert_eq!(got.status(), "idle");
    }

    #[test]
    fn instance_get_nonexistent_returns_not_found() {
        let client = test_client();
        let err = client.get_instance("MISSING").unwrap_err();
        assert!(matches!(err, KallaxError::NotFound { .. }));
    }

    #[test]
    fn instance_insert_and_list() {
        let client = test_client();
        client
            .insert_instance(&sample_instance("I1", InstanceRole::Conductor))
            .unwrap();
        client
            .insert_instance(&sample_instance("I2", InstanceRole::Performer))
            .unwrap();
        let all = client.list_instances(None).unwrap();
        assert_eq!(all.len(), 2);
    }

    #[test]
    fn instance_filter_by_role() {
        let client = test_client();
        client
            .insert_instance(&sample_instance("C1", InstanceRole::Conductor))
            .unwrap();
        client
            .insert_instance(&sample_instance("P1", InstanceRole::Performer))
            .unwrap();
        client
            .insert_instance(&sample_instance("P2", InstanceRole::Performer))
            .unwrap();
        let performers = client
            .list_instances(Some(InstanceRole::Performer))
            .unwrap();
        assert_eq!(performers.len(), 2);
        assert!(performers
            .iter()
            .all(|i| i.role() == InstanceRole::Performer));
    }

    #[test]
    fn instance_update() {
        let client = test_client();
        let mut inst = sample_instance("U1", InstanceRole::Performer);
        client.insert_instance(&inst).unwrap();
        inst.set_status("busy");
        client.update_instance(&inst).unwrap();
        let got = client.get_instance("U1").unwrap();
        assert_eq!(got.status(), "busy");
    }

    #[test]
    fn instance_update_nonexistent_returns_not_found() {
        let client = test_client();
        let inst = sample_instance("NOPE", InstanceRole::Conductor);
        let err = client.update_instance(&inst).unwrap_err();
        assert!(matches!(err, KallaxError::NotFound { .. }));
    }

    #[test]
    fn instance_upsert_replaces() {
        let client = test_client();
        let mut inst = sample_instance("UP1", InstanceRole::Conductor);
        client.upsert_instance(&inst).unwrap();
        inst.set_status("busy");
        client.upsert_instance(&inst).unwrap();
        let got = client.get_instance("UP1").unwrap();
        assert_eq!(got.status(), "busy");
        assert_eq!(client.list_instances(None).unwrap().len(), 1);
    }

    // -------------------------------------------------------------------
    // TraceSpan CRUD tests
    // -------------------------------------------------------------------

    #[test]
    fn span_insert_and_get() {
        let client = test_client();
        let span = TraceSpan::start("SPAN-1", "test.span");
        client.insert_span(&span).unwrap();
        let got = client.get_span("SPAN-1").unwrap();
        assert_eq!(got.id(), "SPAN-1");
        assert_eq!(got.span_name(), "test.span");
        assert!(got.ended_at().is_none());
    }

    #[test]
    fn span_update_end_sets_duration() {
        let client = test_client();
        let mut span = TraceSpan::start("SPAN-END", "closed.span");
        client.insert_span(&span).unwrap();
        span.end();
        client.update_span_end(&span).unwrap();
        let got = client.get_span("SPAN-END").unwrap();
        assert!(got.ended_at().is_some());
        assert!(got.duration_ms().is_some());
    }

    #[test]
    fn span_list_by_name() {
        let client = test_client();
        client.insert_span(&TraceSpan::start("S1", "op.a")).unwrap();
        client.insert_span(&TraceSpan::start("S2", "op.a")).unwrap();
        client.insert_span(&TraceSpan::start("S3", "op.b")).unwrap();

        let a_spans = client.list_spans_by_name(Some("op.a"), None).unwrap();
        assert_eq!(a_spans.len(), 2);
        let all = client.list_spans_by_name(None, None).unwrap();
        assert_eq!(all.len(), 3);
    }

    // -------------------------------------------------------------------
    // DagRun + DagNodeState CRUD tests
    // -------------------------------------------------------------------

    #[test]
    fn dag_run_insert_and_get() {
        let client = test_client();
        let run = DagRun::new("DAG-1", "sprint-dag", "manual");
        client.insert_dag_run(&run).unwrap();
        let got = client.get_dag_run("DAG-1").unwrap();
        assert_eq!(got.dag_name(), "sprint-dag");
        assert_eq!(got.status(), DagStatus::Pending);
    }

    #[test]
    fn dag_run_lifecycle_update() {
        let client = test_client();
        let mut run = DagRun::new("DAG-LIFE", "d", "cron");
        client.insert_dag_run(&run).unwrap();
        run.mark_running();
        client.update_dag_run(&run).unwrap();
        run.mark_completed();
        client.update_dag_run(&run).unwrap();
        let got = client.get_dag_run("DAG-LIFE").unwrap();
        assert_eq!(got.status(), DagStatus::Completed);
        assert!(got.completed_at().is_some());
    }

    #[test]
    fn dag_run_filter_by_status() {
        let client = test_client();
        let mut r1 = DagRun::new("R1", "d", "t");
        r1.mark_running();
        client.insert_dag_run(&r1).unwrap();
        client.insert_dag_run(&DagRun::new("R2", "d", "t")).unwrap();

        let running = client.list_dag_runs(Some(DagStatus::Running)).unwrap();
        assert_eq!(running.len(), 1);
        assert_eq!(running[0].id(), "R1");
    }

    #[test]
    fn dag_node_insert_and_list_by_run() {
        let client = test_client();
        client
            .insert_dag_run(&DagRun::new("DR1", "d", "t"))
            .unwrap();

        client
            .insert_dag_node(&DagNodeState::new("N1", "DR1", "step-a"))
            .unwrap();
        client
            .insert_dag_node(&DagNodeState::new("N2", "DR1", "step-b"))
            .unwrap();

        let nodes = client.list_dag_nodes("DR1").unwrap();
        assert_eq!(nodes.len(), 2);
    }

    #[test]
    fn dag_node_update_completion() {
        let client = test_client();
        client
            .insert_dag_run(&DagRun::new("DR2", "d", "t"))
            .unwrap();
        let mut node = DagNodeState::new("N-DONE", "DR2", "worker");
        client.insert_dag_node(&node).unwrap();
        node.mark_running();
        client.update_dag_node(&node).unwrap();
        node.mark_completed(Some("ok".to_string()));
        client.update_dag_node(&node).unwrap();

        let nodes = client.list_dag_nodes("DR2").unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0].status(), DagStatus::Completed);
        assert_eq!(nodes[0].output(), Some("ok"));
    }
}
