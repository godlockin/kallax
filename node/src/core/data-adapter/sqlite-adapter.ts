/**
 * SQLite-based DataAdapter implementation (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * Reads/writes team collaboration data to SQLite (kallax.db).
 * Used when the database file exists.
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../../types/index.js';
import type { DataAdapter, Epic, Phase, ProjectTicket } from './types.js';
import { createDataError } from './helpers.js';
import { FileDataAdapter } from './file-adapter.js';
import { logger } from '../../utils/logger.js';
import {
  rowToPhase,
  phaseToRow,
  rowToEpic,
  epicToRow,
  rowToProjectTicket,
  projectTicketToRow,
} from '../sqlite/types.js';
import { initializeTeamSchema } from '../sqlite/schema.js';

/**
 * Reads/writes team collaboration data from/to SQLite (kallax.db).
 * Used when the database file exists.
 */
export class SQLiteDataAdapter implements DataAdapter {
  private readonly db: Database.Database;
  private readonly jiraDir: string;

  constructor(db: Database.Database, jiraDir: string) {
    this.db = db;
    this.jiraDir = jiraDir;
    initializeTeamSchema(db);
  }

  readPhase(phaseId: string): KallaxResult<Phase | null> {
    try {
      const stmt = this.db.prepare('SELECT * FROM phases WHERE id = ?');
      const row = stmt.get(phaseId) as Record<string, unknown> | undefined;
      if (!row) return ok(null);
      return ok(rowToPhase(row as unknown as import('../sqlite/types.js').PhaseRow));
    } catch (error: unknown) {
      return err(createDataError('Failed to read phase from DB', error));
    }
  }

  writePhase(phase: Phase): KallaxResult<void> {
    try {
      const row = phaseToRow(phase);
      const stmt = this.db.prepare(`
        INSERT INTO phases (id, title, scope, status, start_time, delivery_time)
        VALUES (@id, @title, @scope, @status, @start_time, @delivery_time)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          scope = excluded.scope,
          status = excluded.status,
          start_time = excluded.start_time,
          delivery_time = excluded.delivery_time
      `);
      stmt.run(row);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write phase to DB', error));
    }
  }

  readEpic(epicId: string): KallaxResult<Epic | null> {
    try {
      const stmt = this.db.prepare('SELECT * FROM epics WHERE id = ?');
      const row = stmt.get(epicId) as Record<string, unknown> | undefined;
      if (!row) return ok(null);
      return ok(rowToEpic(row as unknown as import('../sqlite/types.js').EpicRow));
    } catch (error: unknown) {
      return err(createDataError('Failed to read epic from DB', error));
    }
  }

  writeEpic(epic: Epic): KallaxResult<void> {
    try {
      const row = epicToRow(epic);
      const stmt = this.db.prepare(`
        INSERT INTO epics (id, phase_id, title, scope, status, start_time, delivery_time)
        VALUES (@id, @phase_id, @title, @scope, @status, @start_time, @delivery_time)
        ON CONFLICT(id) DO UPDATE SET
          phase_id = excluded.phase_id,
          title = excluded.title,
          scope = excluded.scope,
          status = excluded.status,
          start_time = excluded.start_time,
          delivery_time = excluded.delivery_time
      `);
      stmt.run(row);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write epic to DB', error));
    }
  }

  readTicket(ticketId: string): KallaxResult<ProjectTicket | null> {
    try {
      const stmt = this.db.prepare('SELECT * FROM project_tickets WHERE id = ?');
      const row = stmt.get(ticketId) as Record<string, unknown> | undefined;
      if (!row) return ok(null);
      return ok(rowToProjectTicket(row as unknown as import('../sqlite/types.js').ProjectTicketRow));
    } catch (error: unknown) {
      return err(createDataError('Failed to read ticket from DB', error));
    }
  }

  writeTicket(ticket: ProjectTicket): KallaxResult<void> {
    try {
      const row = projectTicketToRow(ticket);
      const stmt = this.db.prepare(`
        INSERT INTO project_tickets (id, epic_id, title, type, priority, status, assignee, file_scope, acceptance_criteria)
        VALUES (@id, @epic_id, @title, @type, @priority, @status, @assignee, @file_scope, @acceptance_criteria)
        ON CONFLICT(id) DO UPDATE SET
          epic_id = excluded.epic_id,
          title = excluded.title,
          type = excluded.type,
          priority = excluded.priority,
          status = excluded.status,
          assignee = excluded.assignee,
          file_scope = excluded.file_scope,
          acceptance_criteria = excluded.acceptance_criteria
      `);
      stmt.run(row);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write ticket to DB', error));
    }
  }

  syncToDb(): KallaxResult<void> {
    try {
      const fileAdapter = new FileDataAdapter(this.jiraDir);
      const phasesResult = fileAdapter.listPhases();
      if (phasesResult.isOk()) {
        for (const phase of phasesResult.value) {
          this.writePhase(phase);
        }
      }
      const epicsResult = fileAdapter.listEpics();
      if (epicsResult.isOk()) {
        for (const epic of epicsResult.value) {
          this.writeEpic(epic);
        }
      }
      const ticketsResult = fileAdapter.listTickets();
      if (ticketsResult.isOk()) {
        for (const ticket of ticketsResult.value) {
          this.writeTicket(ticket);
        }
      }
      logger.info({}, 'sync-to-db complete: files → sqlite');
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to sync to DB', error));
    }
  }

  syncToFiles(): KallaxResult<void> {
    try {
      const fileAdapter = new FileDataAdapter(this.jiraDir);
      const phasesResult = this.listPhases();
      if (phasesResult.isOk()) {
        for (const phase of phasesResult.value) {
          fileAdapter.writePhase(phase);
        }
      }
      const epicsResult = this.listEpics();
      if (epicsResult.isOk()) {
        for (const epic of epicsResult.value) {
          fileAdapter.writeEpic(epic);
        }
      }
      const ticketsResult = this.listTickets();
      if (ticketsResult.isOk()) {
        for (const ticket of ticketsResult.value) {
          fileAdapter.writeTicket(ticket);
        }
      }
      logger.info({}, 'sync-to-files complete: sqlite → files');
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to sync to files', error));
    }
  }

  listPhases(): KallaxResult<Phase[]> {
    try {
      const stmt = this.db.prepare('SELECT * FROM phases ORDER BY id');
      const rows = stmt.all() as Record<string, unknown>[];
      return ok(rows.map((r) => rowToPhase(r as unknown as import('../sqlite/types.js').PhaseRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list phases from DB', error));
    }
  }

  listEpics(phaseId?: string): KallaxResult<Epic[]> {
    try {
      let stmt: Database.Statement;
      let rows: Record<string, unknown>[];
      if (phaseId != null) {
        stmt = this.db.prepare('SELECT * FROM epics WHERE phase_id = ? ORDER BY id');
        rows = stmt.all(phaseId) as Record<string, unknown>[];
      } else {
        stmt = this.db.prepare('SELECT * FROM epics ORDER BY id');
        rows = stmt.all() as Record<string, unknown>[];
      }
      return ok(rows.map((r) => rowToEpic(r as unknown as import('../sqlite/types.js').EpicRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list epics from DB', error));
    }
  }

  listTickets(epicId?: string): KallaxResult<ProjectTicket[]> {
    try {
      let stmt: Database.Statement;
      let rows: Record<string, unknown>[];
      if (epicId !== undefined) {
        stmt = this.db.prepare('SELECT * FROM project_tickets WHERE epic_id = ? ORDER BY id');
        rows = stmt.all(epicId) as Record<string, unknown>[];
      } else {
        stmt = this.db.prepare('SELECT * FROM project_tickets ORDER BY id');
        rows = stmt.all() as Record<string, unknown>[];
      }
      return ok(rows.map((r) => rowToProjectTicket(r as unknown as import('../sqlite/types.js').ProjectTicketRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list tickets from DB', error));
    }
  }

  close(): void {
    // DB connection managed externally
  }
}

