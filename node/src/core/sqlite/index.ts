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
} from './types.js';
export { rowToTicket, rowToTask, rowToInstance, rowToMessage } from './types.js';
export { initializeSchema } from './schema.js';
export { createSQLiteManager, getSqliteManager } from './sync-client.js';
