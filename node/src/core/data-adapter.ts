/**
 * KALLAX Data Adapter
 * DB-first / file-fallback adapter for team collaboration data (phases, epics, tickets).
 * Supports bidirectional sync between SQLite (kallax.db) and jira/ JSON files.
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

// ============================================================================
// Domain Types
// ============================================================================

export interface Phase {
  id: string;
  title: string;
  scope: string;
  status: string;
  startTime?: string;
  deliveryTime?: string;
}

export interface Epic {
  id: string;
  phaseId: string;
  title: string;
  scope: string;
  status: string;
  startTime?: string;
  deliveryTime?: string;
}

export interface ProjectTicket {
  id: string;
  epicId: string;
  title: string;
  type: string;
  priority: string;
  status: string;
  assignee: string | null;
  fileScope?: { includes: string[]; excludes: string[] };
  acceptanceCriteria: string[];
}

export interface TeamInstance {
  instanceId: string;
  role: string;
  status: string;
  branch?: string;
  pid: number;
  heartbeatAt?: number;
  missedCount: number;
}

export interface HeartbeatLog {
  id: number;
  instanceId: string;
  tickAt: number;
  status: string;
}

// ============================================================================
// DataAdapter Interface
// ============================================================================

export interface DataAdapter {
  /** Read a phase by ID */
  readPhase(phaseId: string): KallaxResult<Phase | null>;
  /** Write (upsert) a phase */
  writePhase(phase: Phase): KallaxResult<void>;
  /** Read an epic by ID */
  readEpic(epicId: string): KallaxResult<Epic | null>;
  /** Write (upsert) an epic */
  writeEpic(epic: Epic): KallaxResult<void>;
  /** Read a project ticket by ID */
  readTicket(ticketId: string): KallaxResult<ProjectTicket | null>;
  /** Write (upsert) a project ticket */
  writeTicket(ticket: ProjectTicket): KallaxResult<void>;
  /** Sync all data from JSON files into SQLite (creates/updates records) */
  syncToDb(): KallaxResult<void>;
  /** Sync all data from SQLite into JSON files (overwrites files) */
  syncToFiles(): KallaxResult<void>;
  /** List all phases */
  listPhases(): KallaxResult<Phase[]>;
  /** List all epics (optionally filtered by phase) */
  listEpics(phaseId?: string): KallaxResult<Epic[]>;
  /** List all project tickets (optionally filtered by epic) */
  listTickets(epicId?: string): KallaxResult<ProjectTicket[]>;
  /** Close the adapter (relevant for SQLite adapter) */
  close(): void;
}

// ============================================================================
// File DataAdapter
// ============================================================================

/**
 * Reads/writes team collaboration data from/to jira/ JSON files.
 * Used when kallax.db does not exist.
 */
export class FileDataAdapter implements DataAdapter {
  private readonly jiraDir: string;

  constructor(jiraDir: string) {
    this.jiraDir = jiraDir;
  }

  readPhase(phaseId: string): KallaxResult<Phase | null> {
    try {
      const phasePath = join(this.jiraDir, 'phases', phaseId, 'phase.json');
      if (!existsSync(phasePath)) return ok(null);
      const raw = readFileSync(phasePath, 'utf-8');
      return ok(JSON.parse(raw) as Phase);
    } catch (error: unknown) {
      return err(createDataError('Failed to read phase', error));
    }
  }

  writePhase(phase: Phase): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'phases', phase.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'phase.json'), JSON.stringify(phase, null, 2), 'utf-8');
      this.updatePhaseIndex(phase);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write phase', error));
    }
  }

  readEpic(epicId: string): KallaxResult<Epic | null> {
    try {
      const epicPath = join(this.jiraDir, 'epics', epicId, 'epic.json');
      if (!existsSync(epicPath)) return ok(null);
      const raw = readFileSync(epicPath, 'utf-8');
      return ok(JSON.parse(raw) as Epic);
    } catch (error: unknown) {
      return err(createDataError('Failed to read epic', error));
    }
  }

  writeEpic(epic: Epic): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'epics', epic.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'epic.json'), JSON.stringify(epic, null, 2), 'utf-8');
      this.updateEpicIndex(epic);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write epic', error));
    }
  }

  readTicket(ticketId: string): KallaxResult<ProjectTicket | null> {
    try {
      const ticketPath = join(this.jiraDir, 'tickets', ticketId, 'ticket.json');
      if (!existsSync(ticketPath)) return ok(null);
      const raw = readFileSync(ticketPath, 'utf-8');
      return ok(JSON.parse(raw) as ProjectTicket);
    } catch (error: unknown) {
      return err(createDataError('Failed to read ticket', error));
    }
  }

  writeTicket(ticket: ProjectTicket): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'tickets', ticket.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'ticket.json'), JSON.stringify(ticket, null, 2), 'utf-8');
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write ticket', error));
    }
  }

  syncToDb(): KallaxResult<void> {
    return ok(undefined); // No-op: no DB to sync to in file mode
  }

  syncToFiles(): KallaxResult<void> {
    return ok(undefined); // No-op: already using files
  }

  listPhases(): KallaxResult<Phase[]> {
    try {
      const index = this.readPhaseIndex();
      const phases: Phase[] = [];
      for (const entry of index.phases) {
        const result = this.readPhase(entry.id);
        if (result.isOk() && result.value) phases.push(result.value);
      }
      return ok(phases);
    } catch (error: unknown) {
      return err(createDataError('Failed to list phases', error));
    }
  }

  listEpics(phaseId?: string): KallaxResult<Epic[]> {
    try {
      const index = this.readEpicIndex();
      let entries = index.epics;
      if (phaseId) entries = entries.filter((e: { id: string; phase: string }) => e.phase === phaseId);
      const epics: Epic[] = [];
      for (const entry of entries) {
        const result = this.readEpic(entry.id);
        if (result.isOk() && result.value && (!phaseId || result.value.phaseId === phaseId)) {
          epics.push(result.value);
        }
      }
      return ok(epics);
    } catch (error: unknown) {
      return err(createDataError('Failed to list epics', error));
    }
  }

  listTickets(epicId?: string): KallaxResult<ProjectTicket[]> {
    try {
      const ticketsDir = join(this.jiraDir, 'tickets');
      if (!existsSync(ticketsDir)) return ok([]);
      const entries = readDirSafe(ticketsDir);
      const tickets: ProjectTicket[] = [];
      for (const entry of entries) {
        const ticketPath = join(ticketsDir, entry, 'ticket.json');
        if (!existsSync(ticketPath)) continue;
        const raw = readFileSync(ticketPath, 'utf-8');
        const ticket = JSON.parse(raw) as ProjectTicket;
        if (!epicId || ticket.epicId === epicId) tickets.push(ticket);
      }
      return ok(tickets);
    } catch (error: unknown) {
      return err(createDataError('Failed to list tickets', error));
    }
  }

  close(): void {
    // No-op for file adapter
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  private readPhaseIndex(): { phases: Array<{ id: string; status: string; start_time: string; delivery_time: string }> } {
    const indexPath = join(this.jiraDir, 'phases', 'phase_index.json');
    if (!existsSync(indexPath)) return { phases: [] };
    return JSON.parse(readFileSync(indexPath, 'utf-8'));
  }

  private updatePhaseIndex(phase: Phase): void {
    const index = this.readPhaseIndex();
    const existing = index.phases.findIndex((p) => p.id === phase.id);
    const entry = { id: phase.id, status: phase.status, start_time: phase.startTime ?? '', delivery_time: phase.deliveryTime ?? '' };
    if (existing >= 0) {
      index.phases[existing] = entry;
    } else {
      index.phases.push(entry);
    }
    writeFileSync(join(this.jiraDir, 'phases', 'phase_index.json'), JSON.stringify(index, null, 2), 'utf-8');
  }

  private readEpicIndex(): { epics: Array<{ id: string; phase: string; status: string; start_time: string; delivery_time: string }> } {
    const indexPath = join(this.jiraDir, 'epics', 'epic_index.json');
    if (!existsSync(indexPath)) return { epics: [] };
    return JSON.parse(readFileSync(indexPath, 'utf-8'));
  }

  private updateEpicIndex(epic: Epic): void {
    const index = this.readEpicIndex();
    const existing = index.epics.findIndex((e) => e.id === epic.id);
    const entry = { id: epic.id, phase: epic.phaseId, status: epic.status, start_time: epic.startTime ?? '', delivery_time: epic.deliveryTime ?? '' };
    if (existing >= 0) {
      index.epics[existing] = entry;
    } else {
      index.epics.push(entry);
    }
    writeFileSync(join(this.jiraDir, 'epics', 'epic_index.json'), JSON.stringify(index, null, 2), 'utf-8');
  }
}

// ============================================================================
// SQLite DataAdapter
// ============================================================================

import {
  rowToPhase,
  phaseToRow,
  rowToEpic,
  epicToRow,
  rowToProjectTicket,
  projectTicketToRow,
} from './sqlite/types.js';
import { initializeTeamSchema } from './sqlite/schema.js';

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
      return ok(rowToPhase(row as unknown as import('./sqlite/types.js').PhaseRow));
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
      stmt.run(row as unknown as Record<string, unknown>);
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
      return ok(rowToEpic(row as unknown as import('./sqlite/types.js').EpicRow));
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
      stmt.run(row as unknown as Record<string, unknown>);
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
      return ok(rowToProjectTicket(row as unknown as import('./sqlite/types.js').ProjectTicketRow));
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
      stmt.run(row as unknown as Record<string, unknown>);
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
      return ok(rows.map((r) => rowToPhase(r as unknown as import('./sqlite/types.js').PhaseRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list phases from DB', error));
    }
  }

  listEpics(phaseId?: string): KallaxResult<Epic[]> {
    try {
      let stmt: Database.Statement;
      let rows: Record<string, unknown>[];
      if (phaseId) {
        stmt = this.db.prepare('SELECT * FROM epics WHERE phase_id = ? ORDER BY id');
        rows = stmt.all(phaseId) as Record<string, unknown>[];
      } else {
        stmt = this.db.prepare('SELECT * FROM epics ORDER BY id');
        rows = stmt.all() as Record<string, unknown>[];
      }
      return ok(rows.map((r) => rowToEpic(r as unknown as import('./sqlite/types.js').EpicRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list epics from DB', error));
    }
  }

  listTickets(epicId?: string): KallaxResult<ProjectTicket[]> {
    try {
      let stmt: Database.Statement;
      let rows: Record<string, unknown>[];
      if (epicId) {
        stmt = this.db.prepare('SELECT * FROM project_tickets WHERE epic_id = ? ORDER BY id');
        rows = stmt.all(epicId) as Record<string, unknown>[];
      } else {
        stmt = this.db.prepare('SELECT * FROM project_tickets ORDER BY id');
        rows = stmt.all() as Record<string, unknown>[];
      }
      return ok(rows.map((r) => rowToProjectTicket(r as unknown as import('./sqlite/types.js').ProjectTicketRow)));
    } catch (error: unknown) {
      return err(createDataError('Failed to list tickets from DB', error));
    }
  }

  close(): void {
    // DB connection managed externally
  }
}

// ============================================================================
// Factory
// ============================================================================

export interface DataAdapterConfig {
  /** Path to the SQLite database file (e.g. .kallax/kallax.db) */
  dbPath: string;
  /** Path to the jira directory (e.g. ./jira) */
  jiraDir: string;
}

/**
 * Creates a DataAdapter that reads from SQLite if the database file exists,
 * otherwise falls back to reading/writing jira/ JSON files.
 */
export function createDataAdapter(config: DataAdapterConfig): DataAdapter {
  if (existsSync(config.dbPath)) {
    try {
      const db = new Database(config.dbPath);
      db.pragma('journal_mode = WAL');
      db.pragma('synchronous = NORMAL');
      db.pragma('foreign_keys = ON');
      logger.info({ dbPath: config.dbPath }, 'data-adapter: using sqlite');
      return new SQLiteDataAdapter(db, config.jiraDir);
    } catch (error: unknown) {
      logger.warn({ dbPath: config.dbPath, error }, 'data-adapter: sqlite unavailable, falling back to files');
    }
  }
  logger.info({ jiraDir: config.jiraDir }, 'data-adapter: using file fallback');
  return new FileDataAdapter(config.jiraDir);
}

// ============================================================================
// Helpers
// ============================================================================

function createDataError(message: string, cause: unknown): KallaxError {
  return new KallaxError(KallaxErrorCode.DB_ERROR, message, { cause });
}

function readDirSafe(dir: string): string[] {
  try {
    return readdirSync(dir);
  } catch {
    return [];
  }
}
