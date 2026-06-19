/**
 * KALLAX Data Adapter — Domain Types (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * DB-first / file-fallback adapter for team collaboration data (phases, epics, tickets).
 * Supports bidirectional sync between SQLite (kallax.db) and jira/ JSON files.
 *
 * Split structure (跟 Rule 8 联合):
 * - types.ts: Domain types + DataAdapter interface (this file)
 * - file-adapter.ts: FileDataAdapter class
 * - sqlite-adapter.ts: SQLiteDataAdapter class
 * - index.ts: createDataAdapter factory + re-exports
 */

import type { KallaxResult } from '../../types/index.js';

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
  status: string;
  assignee?: string;
  priority: string;
  startTime?: string;
  deliveryTime?: string;
}

export interface TeamInstance {
  id: string;
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
