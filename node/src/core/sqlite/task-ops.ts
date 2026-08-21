/**
 * KALLAX SQLite Task Operations
 * Factory function for task CRUD
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Task } from '../../types/index.js';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { TaskFilter, TaskRow } from './types.js';
import { rowToTask } from './types.js';

export interface TaskOperations {
  createTask: (task: Task) => KallaxResult<void>;
  getTask: (id: string) => KallaxResult<Task | null>;
  updateTask: (id: string, updates: Partial<Task>) => KallaxResult<void>;
  listTasks: (filter?: TaskFilter) => KallaxResult<Task[]>;
  claimTask: (taskId: string, performerId: string) => KallaxResult<boolean>;
}

export function createTaskOperations(db: Database.Database): TaskOperations {
  return {
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
        if (updates.metadata !== undefined) {
          setClauses.push('metadata = ?');
          values.push(JSON.stringify(updates.metadata));
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
  };
}
