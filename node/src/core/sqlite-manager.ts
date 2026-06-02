/**
 * KALLAX SQLite Manager
 * Database operations with proper error handling
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket, Instance, Message } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { registerCleanupHandler } from '../utils/process-cleanup.js';

export interface SQLiteConfig {
  readonly path: string;
  readonly readonly?: boolean;
  readonly verbose?: boolean;
}

export interface SQLiteManager {
  // Ticket operations
  createTicket: (ticket: Ticket) => KallaxResult<void>;
  getTicket: (id: string) => KallaxResult<Ticket | null>;
  updateTicket: (id: string, updates: Partial<Ticket>) => KallaxResult<void>;
  listTickets: (filter?: TicketFilter) => KallaxResult<Ticket[]>;

  // Task operations
  createTask: (task: Task) => KallaxResult<void>;
  getTask: (id: string) => KallaxResult<Task | null>;
  updateTask: (id: string, updates: Partial<Task>) => KallaxResult<void>;
  listTasks: (filter?: TaskFilter) => KallaxResult<Task[]>;
  claimTask: (taskId: string, performerId: string) => KallaxResult<boolean>;

  // Instance operations
  registerInstance: (instance: Instance) => KallaxResult<void>;
  getInstance: (id: string) => KallaxResult<Instance | null>;
  updateInstance: (id: string, updates: Partial<Instance>) => KallaxResult<void>;
  listInstances: (filter?: InstanceFilter) => KallaxResult<Instance[]>;
  updateHeartbeat: (id: string) => KallaxResult<void>;
  getStaleInstances: (thresholdMs: number) => KallaxResult<Instance[]>;

  // Message operations
  enqueueMessage: (message: Message) => KallaxResult<void>;
  dequeueMessage: (targetId?: string) => KallaxResult<Message | null>;
  peekMessages: (limit: number) => KallaxResult<Message[]>;

  // Lifecycle
  close: () => void;
  getStats: () => DatabaseStats;
}

export interface TicketFilter {
  readonly status?: string;
  readonly priority?: string;
  readonly assigneeId?: string;
  readonly limit?: number;
}

export interface TaskFilter {
  readonly status?: string;
  readonly performerId?: string;
  readonly ticketId?: string;
  readonly limit?: number;
}

export interface InstanceFilter {
  readonly role?: string;
  readonly status?: string;
  readonly limit?: number;
}

export interface DatabaseStats {
  readonly ticketCount: number;
  readonly taskCount: number;
  readonly instanceCount: number;
  readonly messageCount: number;
}

export function createSQLiteManager(config: SQLiteConfig): KallaxResult<SQLiteManager> {
  let db: Database.Database;

  try {
    db = new Database(config.path, {
      readonly: config.readonly ?? false,
      verbose: config.verbose === true ? (sql) => logger.debug({ sql }, 'sqlite query') : undefined,
    });

    // Enable WAL mode for better concurrency
    db.pragma('journal_mode = WAL');
    db.pragma('synchronous = NORMAL');
    db.pragma('foreign_keys = ON');

    // Initialize schema
    initializeSchema(db);

    logger.info({ path: config.path }, 'sqlite database initialized');
  } catch (error: unknown) {
    return err(
      new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to initialize database', {
        cause: error,
        metadata: { path: config.path },
      })
    );
  }

  // Register cleanup handler
  registerCleanupHandler('sqlite', () => {
    db.close();
    logger.info({}, 'sqlite database closed');
  });

  const manager: SQLiteManager = {
    createTicket(ticket: Ticket): KallaxResult<void> {
      try {
        const stmt = db.prepare(`
          INSERT INTO tickets (id, title, description, status, priority, assignee_id, created_at, updated_at, estimated_minutes, acceptance_criteria, labels, file_scope, worktree_path, parent_ticket_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        stmt.run(
          ticket.id,
          ticket.title,
          ticket.description,
          ticket.status,
          ticket.priority,
          ticket.assigneeId,
          ticket.createdAt,
          ticket.updatedAt,
          ticket.estimatedMinutes ?? null,
          JSON.stringify(ticket.acceptanceCriteria),
          JSON.stringify(ticket.labels),
          ticket.fileScope !== undefined ? JSON.stringify(ticket.fileScope) : null,
          ticket.worktreePath ?? null,
          ticket.parentTicketId ?? null
        );
        logger.debug({ ticketId: ticket.id }, 'ticket created');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to create ticket', {
            cause: error,
            metadata: { ticketId: ticket.id },
          })
        );
      }
    },

    getTicket(id: string): KallaxResult<Ticket | null> {
      try {
        const stmt = db.prepare('SELECT * FROM tickets WHERE id = ?');
        const row = stmt.get(id) as TicketRow | undefined;
        if (row === undefined) {
          return ok(null);
        }
        return ok(rowToTicket(row));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to get ticket', {
            cause: error,
            metadata: { ticketId: id },
          })
        );
      }
    },

    updateTicket(id: string, updates: Partial<Ticket>): KallaxResult<void> {
      try {
        const setClauses: string[] = [];
        const values: unknown[] = [];

        if (updates.title !== undefined) {
          setClauses.push('title = ?');
          values.push(updates.title);
        }
        if (updates.description !== undefined) {
          setClauses.push('description = ?');
          values.push(updates.description);
        }
        if (updates.status !== undefined) {
          setClauses.push('status = ?');
          values.push(updates.status);
        }
        if (updates.priority !== undefined) {
          setClauses.push('priority = ?');
          values.push(updates.priority);
        }
        if (updates.assigneeId !== undefined) {
          setClauses.push('assignee_id = ?');
          values.push(updates.assigneeId);
        }

        setClauses.push('updated_at = ?');
        values.push(Date.now());
        values.push(id);

        const stmt = db.prepare(`UPDATE tickets SET ${setClauses.join(', ')} WHERE id = ?`);
        stmt.run(...values);
        logger.debug({ ticketId: id }, 'ticket updated');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to update ticket', {
            cause: error,
            metadata: { ticketId: id },
          })
        );
      }
    },

    listTickets(filter?: TicketFilter): KallaxResult<Ticket[]> {
      try {
        let sql = 'SELECT * FROM tickets WHERE 1=1';
        const params: unknown[] = [];

        if (filter?.status !== undefined) {
          sql += ' AND status = ?';
          params.push(filter.status);
        }
        if (filter?.priority !== undefined) {
          sql += ' AND priority = ?';
          params.push(filter.priority);
        }
        if (filter?.assigneeId !== undefined) {
          sql += ' AND assignee_id = ?';
          params.push(filter.assigneeId);
        }
        sql += ' ORDER BY created_at DESC';
        if (filter?.limit !== undefined) {
          sql += ' LIMIT ?';
          params.push(filter.limit);
        }

        const stmt = db.prepare(sql);
        const rows = stmt.all(...params) as TicketRow[];
        return ok(rows.map(rowToTicket));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to list tickets', { cause: error })
        );
      }
    },

    createTask(task: Task): KallaxResult<void> {
      try {
        const stmt = db.prepare(`
          INSERT INTO tasks (id, ticket_id, type, status, performer_id, created_at, updated_at, started_at, completed_at, progress, output, error, metadata)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        stmt.run(
          task.id,
          task.ticketId,
          task.type,
          task.status,
          task.performerId,
          task.createdAt,
          task.updatedAt,
          task.startedAt ?? null,
          task.completedAt ?? null,
          task.progress,
          task.output ?? null,
          task.error ?? null,
          task.metadata !== undefined ? JSON.stringify(task.metadata) : null
        );
        logger.debug({ taskId: task.id }, 'task created');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to create task', {
            cause: error,
            metadata: { taskId: task.id },
          })
        );
      }
    },

    getTask(id: string): KallaxResult<Task | null> {
      try {
        const stmt = db.prepare('SELECT * FROM tasks WHERE id = ?');
        const row = stmt.get(id) as TaskRow | undefined;
        if (row === undefined) {
          return ok(null);
        }
        return ok(rowToTask(row));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to get task', {
            cause: error,
            metadata: { taskId: id },
          })
        );
      }
    },

    updateTask(id: string, updates: Partial<Task>): KallaxResult<void> {
      try {
        const setClauses: string[] = [];
        const values: unknown[] = [];

        if (updates.status !== undefined) {
          setClauses.push('status = ?');
          values.push(updates.status);
        }
        if (updates.performerId !== undefined) {
          setClauses.push('performer_id = ?');
          values.push(updates.performerId);
        }
        if (updates.progress !== undefined) {
          setClauses.push('progress = ?');
          values.push(updates.progress);
        }
        if (updates.startedAt !== undefined) {
          setClauses.push('started_at = ?');
          values.push(updates.startedAt);
        }
        if (updates.completedAt !== undefined) {
          setClauses.push('completed_at = ?');
          values.push(updates.completedAt);
        }
        if (updates.output !== undefined) {
          setClauses.push('output = ?');
          values.push(updates.output);
        }
        if (updates.error !== undefined) {
          setClauses.push('error = ?');
          values.push(updates.error);
        }

        setClauses.push('updated_at = ?');
        values.push(Date.now());
        values.push(id);

        const stmt = db.prepare(`UPDATE tasks SET ${setClauses.join(', ')} WHERE id = ?`);
        stmt.run(...values);
        logger.debug({ taskId: id }, 'task updated');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to update task', {
            cause: error,
            metadata: { taskId: id },
          })
        );
      }
    },

    listTasks(filter?: TaskFilter): KallaxResult<Task[]> {
      try {
        let sql = 'SELECT * FROM tasks WHERE 1=1';
        const params: unknown[] = [];

        if (filter?.status !== undefined) {
          sql += ' AND status = ?';
          params.push(filter.status);
        }
        if (filter?.performerId !== undefined) {
          sql += ' AND performer_id = ?';
          params.push(filter.performerId);
        }
        if (filter?.ticketId !== undefined) {
          sql += ' AND ticket_id = ?';
          params.push(filter.ticketId);
        }
        sql += ' ORDER BY created_at DESC';
        if (filter?.limit !== undefined) {
          sql += ' LIMIT ?';
          params.push(filter.limit);
        }

        const stmt = db.prepare(sql);
        const rows = stmt.all(...params) as TaskRow[];
        return ok(rows.map(rowToTask));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to list tasks', { cause: error })
        );
      }
    },

    claimTask(taskId: string, performerId: string): KallaxResult<boolean> {
      try {
        const stmt = db.prepare(`
          UPDATE tasks
          SET performer_id = ?, status = 'claimed', updated_at = ?, started_at = ?
          WHERE id = ? AND performer_id IS NULL AND status = 'pending'
        `);
        const now = Date.now();
        const result = stmt.run(performerId, now, now, taskId);
        const claimed = result.changes > 0;
        logger.info({ taskId, performerId, claimed }, 'task claim attempt');
        return ok(claimed);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to claim task', {
            cause: error,
            metadata: { taskId, performerId },
          })
        );
      }
    },

    registerInstance(instance: Instance): KallaxResult<void> {
      try {
        const stmt = db.prepare(`
          INSERT OR REPLACE INTO instances (id, role, status, hostname, pid, started_at, last_heartbeat, current_task_id, worktree_path, capabilities, metadata)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        stmt.run(
          instance.id,
          instance.role,
          instance.status,
          instance.hostname,
          instance.pid,
          instance.startedAt,
          instance.lastHeartbeat,
          instance.currentTaskId,
          instance.worktreePath ?? null,
          JSON.stringify(instance.capabilities),
          instance.metadata !== undefined ? JSON.stringify(instance.metadata) : null
        );
        logger.info({ instanceId: instance.id, role: instance.role }, 'instance registered');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to register instance', {
            cause: error,
            metadata: { instanceId: instance.id },
          })
        );
      }
    },

    getInstance(id: string): KallaxResult<Instance | null> {
      try {
        const stmt = db.prepare('SELECT * FROM instances WHERE id = ?');
        const row = stmt.get(id) as InstanceRow | undefined;
        if (row === undefined) {
          return ok(null);
        }
        return ok(rowToInstance(row));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to get instance', {
            cause: error,
            metadata: { instanceId: id },
          })
        );
      }
    },

    updateInstance(id: string, updates: Partial<Instance>): KallaxResult<void> {
      try {
        const setClauses: string[] = [];
        const values: unknown[] = [];

        if (updates.status !== undefined) {
          setClauses.push('status = ?');
          values.push(updates.status);
        }
        if (updates.currentTaskId !== undefined) {
          setClauses.push('current_task_id = ?');
          values.push(updates.currentTaskId);
        }
        if (updates.lastHeartbeat !== undefined) {
          setClauses.push('last_heartbeat = ?');
          values.push(updates.lastHeartbeat);
        }

        values.push(id);

        const stmt = db.prepare(`UPDATE instances SET ${setClauses.join(', ')} WHERE id = ?`);
        stmt.run(...values);
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to update instance', {
            cause: error,
            metadata: { instanceId: id },
          })
        );
      }
    },

    listInstances(filter?: InstanceFilter): KallaxResult<Instance[]> {
      try {
        let sql = 'SELECT * FROM instances WHERE 1=1';
        const params: unknown[] = [];

        if (filter?.role !== undefined) {
          sql += ' AND role = ?';
          params.push(filter.role);
        }
        if (filter?.status !== undefined) {
          sql += ' AND status = ?';
          params.push(filter.status);
        }
        sql += ' ORDER BY started_at DESC';
        if (filter?.limit !== undefined) {
          sql += ' LIMIT ?';
          params.push(filter.limit);
        }

        const stmt = db.prepare(sql);
        const rows = stmt.all(...params) as InstanceRow[];
        return ok(rows.map(rowToInstance));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to list instances', { cause: error })
        );
      }
    },

    updateHeartbeat(id: string): KallaxResult<void> {
      try {
        const stmt = db.prepare('UPDATE instances SET last_heartbeat = ? WHERE id = ?');
        stmt.run(Date.now(), id);
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to update heartbeat', {
            cause: error,
            metadata: { instanceId: id },
          })
        );
      }
    },

    getStaleInstances(thresholdMs: number): KallaxResult<Instance[]> {
      try {
        const threshold = Date.now() - thresholdMs;
        const stmt = db.prepare('SELECT * FROM instances WHERE last_heartbeat < ? AND status != ?');
        const rows = stmt.all(threshold, 'shutdown') as InstanceRow[];
        return ok(rows.map(rowToInstance));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to get stale instances', { cause: error })
        );
      }
    },

    enqueueMessage(message: Message): KallaxResult<void> {
      try {
        const stmt = db.prepare(`
          INSERT INTO messages (id, type, payload, priority, created_at, expires_at, processed_at, sender_id, target_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        stmt.run(
          message.id,
          message.type,
          JSON.stringify(message.payload),
          message.priority,
          message.createdAt,
          message.expiresAt ?? null,
          message.processedAt ?? null,
          message.senderId ?? null,
          message.targetId ?? null
        );
        logger.debug({ messageId: message.id, type: message.type }, 'message enqueued');
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to enqueue message', {
            cause: error,
            metadata: { messageId: message.id },
          })
        );
      }
    },

    dequeueMessage(targetId?: string): KallaxResult<Message | null> {
      try {
        const now = Date.now();
        let sql = `
          SELECT * FROM messages
          WHERE processed_at IS NULL
            AND (expires_at IS NULL OR expires_at > ?)
        `;
        const params: unknown[] = [now];

        if (targetId !== undefined) {
          sql += ' AND (target_id IS NULL OR target_id = ?)';
          params.push(targetId);
        }

        sql += ' ORDER BY priority DESC, created_at ASC LIMIT 1';

        const selectStmt = db.prepare(sql);
        const row = selectStmt.get(...params) as MessageRow | undefined;

        if (row === undefined) {
          return ok(null);
        }

        // Mark as processed
        const updateStmt = db.prepare('UPDATE messages SET processed_at = ? WHERE id = ?');
        updateStmt.run(now, row.id);

        return ok(rowToMessage(row));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to dequeue message', { cause: error })
        );
      }
    },

    peekMessages(limit: number): KallaxResult<Message[]> {
      try {
        const now = Date.now();
        const stmt = db.prepare(`
          SELECT * FROM messages
          WHERE processed_at IS NULL
            AND (expires_at IS NULL OR expires_at > ?)
          ORDER BY priority DESC, created_at ASC
          LIMIT ?
        `);
        const rows = stmt.all(now, limit) as MessageRow[];
        return ok(rows.map(rowToMessage));
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.DB_ERROR, 'Failed to peek messages', { cause: error })
        );
      }
    },

    close(): void {
      db.close();
      logger.info({}, 'sqlite database closed');
    },

    getStats(): DatabaseStats {
      const ticketCount = (db.prepare('SELECT COUNT(*) as count FROM tickets').get() as { count: number }).count;
      const taskCount = (db.prepare('SELECT COUNT(*) as count FROM tasks').get() as { count: number }).count;
      const instanceCount = (db.prepare('SELECT COUNT(*) as count FROM instances').get() as { count: number }).count;
      const messageCount = (db.prepare('SELECT COUNT(*) as count FROM messages WHERE processed_at IS NULL').get() as { count: number }).count;

      return { ticketCount, taskCount, instanceCount, messageCount };
    },
  };

  return ok(manager);
}

// Database row types
interface TicketRow {
  id: string;
  title: string;
  description: string;
  status: string;
  priority: string;
  assignee_id: string | null;
  created_at: number;
  updated_at: number;
  estimated_minutes: number | null;
  acceptance_criteria: string;
  labels: string;
  file_scope: string | null;
  worktree_path: string | null;
  parent_ticket_id: string | null;
}

interface TaskRow {
  id: string;
  ticket_id: string;
  type: string;
  status: string;
  performer_id: string | null;
  created_at: number;
  updated_at: number;
  started_at: number | null;
  completed_at: number | null;
  progress: number;
  output: string | null;
  error: string | null;
  metadata: string | null;
}

interface InstanceRow {
  id: string;
  role: string;
  status: string;
  hostname: string;
  pid: number;
  started_at: number;
  last_heartbeat: number;
  current_task_id: string | null;
  worktree_path: string | null;
  capabilities: string;
  metadata: string | null;
}

interface MessageRow {
  id: string;
  type: string;
  payload: string;
  priority: number;
  created_at: number;
  expires_at: number | null;
  processed_at: number | null;
  sender_id: string | null;
  target_id: string | null;
}

function rowToTicket(row: TicketRow): Ticket {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    status: row.status as Ticket['status'],
    priority: row.priority as Ticket['priority'],
    assigneeId: row.assignee_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    estimatedMinutes: row.estimated_minutes ?? undefined,
    acceptanceCriteria: JSON.parse(row.acceptance_criteria) as string[],
    labels: JSON.parse(row.labels) as string[],
    fileScope: row.file_scope !== null ? (JSON.parse(row.file_scope) as string[]) : undefined,
    worktreePath: row.worktree_path ?? undefined,
    parentTicketId: row.parent_ticket_id ?? undefined,
  };
}

function rowToTask(row: TaskRow): Task {
  return {
    id: row.id,
    ticketId: row.ticket_id,
    type: row.type as Task['type'],
    status: row.status as Task['status'],
    performerId: row.performer_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    startedAt: row.started_at ?? undefined,
    completedAt: row.completed_at ?? undefined,
    progress: row.progress,
    output: row.output ?? undefined,
    error: row.error ?? undefined,
    metadata: row.metadata !== null ? (JSON.parse(row.metadata) as Record<string, unknown>) : undefined,
  };
}

function rowToInstance(row: InstanceRow): Instance {
  return {
    id: row.id,
    role: row.role as Instance['role'],
    status: row.status as Instance['status'],
    hostname: row.hostname,
    pid: row.pid,
    startedAt: row.started_at,
    lastHeartbeat: row.last_heartbeat,
    currentTaskId: row.current_task_id,
    worktreePath: row.worktree_path ?? undefined,
    capabilities: JSON.parse(row.capabilities) as string[],
    metadata: row.metadata !== null ? (JSON.parse(row.metadata) as Record<string, unknown>) : undefined,
  };
}

function rowToMessage(row: MessageRow): Message {
  return {
    id: row.id,
    type: row.type,
    payload: JSON.parse(row.payload) as unknown,
    priority: row.priority,
    createdAt: row.created_at,
    expiresAt: row.expires_at ?? undefined,
    processedAt: row.processed_at ?? undefined,
    senderId: row.sender_id ?? undefined,
    targetId: row.target_id ?? undefined,
  };
}

function initializeSchema(db: Database.Database): void {
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
  `);
}
