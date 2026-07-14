/**
 * KALLAX Data Adapter — Factory + Re-exports (跟 v2.7.4 D4 , 跟 Rule 8 )
 *
 * Split structure (跟 Rule 8 ):
 * - types.ts: Domain types + DataAdapter interface
 * - file-adapter.ts: FileDataAdapter class
 * - sqlite-adapter.ts: SQLiteDataAdapter class
 * - index.ts: createDataAdapter factory + re-exports (this file)
 */

import { existsSync } from 'node:fs';
import Database from 'better-sqlite3';
import { logger } from '../../utils/logger.js';
import { FileDataAdapter } from './file-adapter.js';
import { SQLiteDataAdapter } from './sqlite-adapter.js';
import type { DataAdapter } from './types.js';

// Re-export public API
export * from './types.js';
export { FileDataAdapter } from './file-adapter.js';
export { SQLiteDataAdapter } from './sqlite-adapter.js';

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
