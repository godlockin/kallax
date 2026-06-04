-- KALLAX Database Schema v1
-- SQLite DDL — WAL mode and foreign keys set by SqliteClient at connection init.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tickets — core work units
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
    id                  TEXT PRIMARY KEY NOT NULL,
    title               TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',
    status              TEXT NOT NULL DEFAULT 'ready'
                        CHECK(status IN ('ready','in_progress','completed','failed','blocked')),
    priority            INTEGER NOT NULL DEFAULT 1,
    scope               TEXT NOT NULL DEFAULT '[]',
    acceptance_criteria TEXT NOT NULL DEFAULT '[]',
    tags                TEXT NOT NULL DEFAULT '[]',
    metadata            TEXT NOT NULL DEFAULT '{}',
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    assigned_to         TEXT
);
CREATE INDEX IF NOT EXISTS idx_tickets_status       ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_priority     ON tickets(priority);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned     ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at   ON tickets(created_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Execution checkpoints — Saga checkpointing
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS execution_checkpoints (
    id               TEXT PRIMARY KEY NOT NULL,
    ticket_id        TEXT NOT NULL REFERENCES tickets(id),
    checkpoint_type  TEXT NOT NULL,
    state            TEXT NOT NULL DEFAULT '{}',
    created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_checkpoints_ticket ON execution_checkpoints(ticket_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Instances — orchestrator instance registry (Conductor / Performer)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS instances (
    id         TEXT PRIMARY KEY NOT NULL,
    name       TEXT NOT NULL,
    role       TEXT NOT NULL CHECK(role IN ('conductor','performer')),
    status     TEXT NOT NULL DEFAULT 'idle',
    metadata   TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_instances_role   ON instances(role);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Retros — retrospectives / post-mortems
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS retros (
    id         TEXT PRIMARY KEY NOT NULL,
    ticket_id  TEXT NOT NULL REFERENCES tickets(id),
    summary    TEXT NOT NULL,
    learnings  TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_retros_ticket ON retros(ticket_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Trace spans — observability / structured event log
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trace_spans (
    id             TEXT PRIMARY KEY NOT NULL,
    span_name      TEXT NOT NULL,
    parent_span_id TEXT,
    context        TEXT NOT NULL DEFAULT '{}',
    started_at     TEXT NOT NULL,
    ended_at       TEXT,
    duration_ms    INTEGER
);
CREATE INDEX IF NOT EXISTS idx_trace_spans_name  ON trace_spans(span_name);
CREATE INDEX IF NOT EXISTS idx_trace_spans_start ON trace_spans(started_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Knowledge entries — long-term memory
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS knowledge_entries (
    id               TEXT PRIMARY KEY NOT NULL,
    title            TEXT NOT NULL,
    content          TEXT NOT NULL,
    entry_type       TEXT NOT NULL,
    tags             TEXT NOT NULL DEFAULT '[]',
    source_ticket_id TEXT REFERENCES tickets(id),
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_knowledge_type ON knowledge_entries(entry_type);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Performer instances — runtime agent state
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS performer_instances (
    id              TEXT PRIMARY KEY NOT NULL,
    performer_id    TEXT NOT NULL UNIQUE,
    status          TEXT NOT NULL DEFAULT 'idle',
    current_task_id TEXT,
    worktree_path   TEXT,
    heartbeat_at    TEXT NOT NULL,
    registered_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_performer_status ON performer_instances(status);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Instance execution states — state machine persistency
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS instance_execution_states (
    id          TEXT PRIMARY KEY NOT NULL,
    instance_id TEXT NOT NULL REFERENCES instances(id),
    state       TEXT NOT NULL,
    context     TEXT NOT NULL DEFAULT '{}',
    entered_at  TEXT NOT NULL,
    exited_at   TEXT
);
CREATE INDEX IF NOT EXISTS idx_exec_states_instance ON instance_execution_states(instance_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Master lock — distributed lock
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS master_lock (
    lock_name   TEXT PRIMARY KEY NOT NULL,
    holder      TEXT NOT NULL,
    acquired_at TEXT NOT NULL,
    expires_at  TEXT NOT NULL
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. Message history — persistent message queue
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS message_history (
    id           TEXT PRIMARY KEY NOT NULL,
    sender       TEXT NOT NULL,
    recipient    TEXT NOT NULL,
    message_type TEXT NOT NULL,
    payload      TEXT NOT NULL DEFAULT '{}',
    created_at   TEXT NOT NULL,
    delivered    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_messages_recipient  ON message_history(recipient);
CREATE INDEX IF NOT EXISTS idx_messages_undelivered ON message_history(delivered)
    WHERE delivered = 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. DAG runs — workflow execution tracking
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dag_runs (
    id           TEXT PRIMARY KEY NOT NULL,
    dag_name     TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'pending',
    trigger      TEXT NOT NULL,
    started_at   TEXT,
    completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_dag_runs_status ON dag_runs(status);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. DAG node states — per-node state within a DAG run
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dag_node_states (
    id           TEXT PRIMARY KEY NOT NULL,
    dag_run_id   TEXT NOT NULL REFERENCES dag_runs(id),
    node_name    TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'pending',
    task_id      TEXT REFERENCES tickets(id),
    output       TEXT,
    started_at   TEXT,
    completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_dag_nodes_run   ON dag_node_states(dag_run_id);
CREATE INDEX IF NOT EXISTS idx_dag_nodes_status ON dag_node_states(status);
