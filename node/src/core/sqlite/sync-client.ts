/**
 * KALLAX SQLite Sync Client
 * Database initialization, async wrapper, and manager construction
 */

import Database from 'better-sqlite3';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../../types/index.js';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import { registerCleanupHandler } from '../../utils/process-cleanup.js';
import { existsSync, mkdirSync } from 'node:fs';
import { Worker } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';
import type { SQLiteConfig, SQLiteManager } from './types.js';
import { initializeSchema } from './schema.js';
import { createTicketOperations } from './ticket-ops.js';
import { createTaskOperations } from './task-ops.js';
import { createInstanceOperations, createMessageOperations, createCommonOperations } from './instance-message-ops.js';

// Module-level raw database reference for getSqliteManager() compatibility
let rawDb: Database.Database | null = null;

/** Returns the raw better-sqlite3 Database instance. Used by master-election & recovery-manager. */
export function getSqliteManager(): Database.Database {
  if (!rawDb) {
    throw new Error('SQLite database not initialized');
  }
  return rawDb;
}

export function createSQLiteManager(config: SQLiteConfig): KallaxResult<SQLiteManager> {
  let db: Database.Database;

  try {
    // Auto-create directory if needed
    const dbDir = config.path.substring(0, config.path.lastIndexOf('/'));
    if (dbDir && !existsSync(dbDir)) mkdirSync(dbDir, { recursive: true });
    db = new Database(config.path, {
      readonly: config.readonly ?? false,
      verbose: config.verbose === true ? ((sql: string): void => { logger.debug({ sql }, 'sqlite query'); }) as ((message?: unknown, ...additionalArgs: unknown[]) => void) : undefined,
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

  // Store raw database reference
  rawDb = db;

  // Register cleanup handler
  registerCleanupHandler('sqlite', () => {
    db.close();
    logger.info({}, 'sqlite database closed');
  });

  const ticketOps = createTicketOperations(db);
  const taskOps = createTaskOperations(db);
  const instanceOps = createInstanceOperations(db);
  const messageOps = createMessageOperations(db);
  const commonOps = createCommonOperations(db);

  const manager: SQLiteManager = {
    ...ticketOps,
    ...taskOps,
    ...instanceOps,
    ...messageOps,
    ...commonOps,
    async: createAsyncWrapper(db, config.path),
  };

  return ok(manager);
}

// ── Async Worker Wrapper ───────────────────────────────────────────────────

function createAsyncWrapper(_db: Database.Database, dbPath: string): SQLiteManager['async'] {
  let worker: Worker | null = null;
  let nextId = 0;
  const pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();

  function getWorker(): Worker {
    if (worker) return worker;
    const workerPath = fileURLToPath(new URL('./sqlite-worker.js', import.meta.url));
    worker = new Worker(workerPath);
    worker.on('message', (resp: { id: number; result?: unknown; error?: string }) => {
      const p = pending.get(resp.id);
      if (!p) return;
      pending.delete(resp.id);
      if (resp.error !== undefined && resp.error !== '') {
        p.reject(new Error(resp.error));
      } else {
        p.resolve(resp.result);
      }
    });
    worker.on('error', (err: Error) => {
      for (const [, p] of pending) { p.reject(err); }
      pending.clear();
    });
    return worker;
  }

  function call<T>(method: string, ...args: unknown[]): Promise<T> {
    const w = getWorker();
    const id = ++nextId;
    return new Promise<T>((resolve, reject) => {
      pending.set(id, { resolve: resolve as (v: unknown) => void, reject });
      w.postMessage({ id, method, args: [dbPath, ...args] });
    });
  }

  return {
    createTicket: (t) => call('createTicket', t),
    getTicket: (id) => call('getTicket', id),
    updateTicket: (id, u) => call('updateTicket', id, u),
    listTickets: (f) => call('listTickets', f),
    createTask: (t) => call('createTask', t),
    getTask: (id) => call('getTask', id),
    updateTask: (id, u) => call('updateTask', id, u),
    listTasks: (f) => call('listTasks', f),
    claimTask: (tid, pid) => call('claimTask', tid, pid),
    registerInstance: (i) => call('registerInstance', i),
    getInstance: (id) => call('getInstance', id),
    updateInstance: (id, u) => call('updateInstance', id, u),
    listInstances: (f) => call('listInstances', f),
    updateHeartbeat: (id) => call('updateHeartbeat', id),
    getStaleInstances: (t) => call('getStaleInstances', t),
    enqueueMessage: (m) => call('enqueueMessage', m),
    dequeueMessage: (t) => call('dequeueMessage', t),
    peekMessages: (l) => call('peekMessages', l),
    getStats: () => call('getStats'),
  };
}
