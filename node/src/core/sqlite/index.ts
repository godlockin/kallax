/**
 * KALLAX SQLite Module
 * Re-exports all SQLite database functionality
 */

export type { TraceLogRow, TraceOperations } from './trace-ops.js';
export { createTraceOps } from './trace-ops.js';
export type {
  SQLiteConfig,
  SQLiteManager,
  SQLiteManagerAsync,
  TicketFilter,
  TaskFilter,
  InstanceFilter,
  DatabaseStats,
  PhaseRow,
  EpicRow,
  ProjectTicketRow,
  TeamInstanceRow,
  HeartbeatLogRow,
} from './types.js';
export {
  rowToTicket,
  rowToTask,
  rowToInstance,
  rowToMessage,
  rowToPhase,
  phaseToRow,
  rowToEpic,
  epicToRow,
  rowToProjectTicket,
  projectTicketToRow,
  rowToTeamInstance,
  teamInstanceToRow,
  rowToHeartbeatLog,
  heartbeatLogToRow,
} from './types.js';
export { initializeSchema, initializeTeamSchema, TEAM_SCHEMA_VERSION } from './schema.js';
export { createSQLiteManager, getSqliteManager } from './sync-client.js';
