/**
 * KALLAX SQLite Schema
 * Database schema initialization (CREATE TABLE statements)
 */

import Database from 'better-sqlite3';

export function initializeSchema(db: Database.Database): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS tickets (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      status TEXT NOT NULL,
      priority TEXT NOT NULL,
      assignee_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      estimated_minutes INTEGER,
      acceptance_criteria TEXT NOT NULL,
      labels TEXT NOT NULL,
      file_scope TEXT,
      worktree_path TEXT,
      parent_ticket_id TEXT,
      FOREIGN KEY (parent_ticket_id) REFERENCES tickets(id)
    );

    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      ticket_id TEXT NOT NULL,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      performer_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      started_at INTEGER,
      completed_at INTEGER,
      progress INTEGER NOT NULL DEFAULT 0,
      output TEXT,
      error TEXT,
      metadata TEXT,
      FOREIGN KEY (ticket_id) REFERENCES tickets(id)
    );

    CREATE TABLE IF NOT EXISTS instances (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL,
      status TEXT NOT NULL,
      hostname TEXT NOT NULL,
      pid INTEGER NOT NULL,
      started_at INTEGER NOT NULL,
      last_heartbeat INTEGER NOT NULL,
      current_task_id TEXT,
      worktree_path TEXT,
      capabilities TEXT NOT NULL,
      metadata TEXT
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      priority INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      expires_at INTEGER,
      processed_at INTEGER,
      sender_id TEXT,
      target_id TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
    CREATE INDEX IF NOT EXISTS idx_tickets_assignee ON tickets(assignee_id);
    CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
    CREATE INDEX IF NOT EXISTS idx_tasks_performer ON tasks(performer_id);
    CREATE INDEX IF NOT EXISTS idx_tasks_ticket ON tasks(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_instances_role ON instances(role);
    CREATE INDEX IF NOT EXISTS idx_instances_status ON instances(status);
    CREATE INDEX IF NOT EXISTS idx_instances_heartbeat ON instances(last_heartbeat);
    CREATE INDEX IF NOT EXISTS idx_messages_priority ON messages(priority, created_at);
    CREATE INDEX IF NOT EXISTS idx_messages_target ON messages(target_id);

    CREATE TABLE IF NOT EXISTS trace_logs (
      trace_id TEXT PRIMARY KEY,
      timestamp INTEGER NOT NULL,
      actor TEXT NOT NULL,
      action TEXT NOT NULL,
      target TEXT NOT NULL,
      detail TEXT NOT NULL,
      result TEXT NOT NULL,
      parent_trace_id TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_trace_logs_actor ON trace_logs(actor);
    CREATE INDEX IF NOT EXISTS idx_trace_logs_target ON trace_logs(target);
    CREATE INDEX IF NOT EXISTS idx_trace_logs_parent ON trace_logs(parent_trace_id);
    CREATE INDEX IF NOT EXISTS idx_trace_logs_timestamp ON trace_logs(timestamp);

    CREATE TABLE IF NOT EXISTS performer_sessions (
      performer_id TEXT PRIMARY KEY,
      current_task_id TEXT,
      worktree_path TEXT,
      last_commit_hash TEXT,
      checkpoint_data TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_performer_sessions_updated ON performer_sessions(updated_at);
  `);
}
