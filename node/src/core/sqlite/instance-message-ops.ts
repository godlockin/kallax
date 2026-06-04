/**
 * KALLAX SQLite Instance & Message Operations
 * Factory functions for instance and message CRUD, plus common operations
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Instance, Message } from '../../types/index.js';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { InstanceFilter, InstanceRow, MessageRow, DatabaseStats } from './types.js';
import { rowToInstance, rowToMessage } from './types.js';

export interface InstanceOperations {
  registerInstance: (instance: Instance) => KallaxResult<void>;
  getInstance: (id: string) => KallaxResult<Instance | null>;
  updateInstance: (id: string, updates: Partial<Instance>) => KallaxResult<void>;
  listInstances: (filter?: InstanceFilter) => KallaxResult<Instance[]>;
  updateHeartbeat: (id: string) => KallaxResult<void>;
  getStaleInstances: (thresholdMs: number) => KallaxResult<Instance[]>;
}

export interface MessageOperations {
  enqueueMessage: (message: Message) => KallaxResult<void>;
  dequeueMessage: (targetId?: string) => KallaxResult<Message | null>;
  peekMessages: (limit: number) => KallaxResult<Message[]>;
}

export interface CommonOperations {
  close: () => void;
  getStats: () => DatabaseStats;
}

export function createInstanceOperations(db: Database.Database): InstanceOperations {
  return {
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
  };
}

export function createMessageOperations(db: Database.Database): MessageOperations {
  return {
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
  };
}

export function createCommonOperations(db: Database.Database): CommonOperations {
  return {
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
}
