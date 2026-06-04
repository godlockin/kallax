/**
 * KALLAX SQLite Ticket Operations
 * Factory function for ticket CRUD
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Ticket } from '../../types/index.js';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { TicketFilter, TicketRow } from './types.js';
import { rowToTicket } from './types.js';

export interface TicketOperations {
  createTicket: (ticket: Ticket) => KallaxResult<void>;
  getTicket: (id: string) => KallaxResult<Ticket | null>;
  updateTicket: (id: string, updates: Partial<Ticket>) => KallaxResult<void>;
  listTickets: (filter?: TicketFilter) => KallaxResult<Ticket[]>;
}

export function createTicketOperations(db: Database.Database): TicketOperations {
  return {
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
  };
}
