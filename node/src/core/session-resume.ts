/**
 * KALLAX Session Resume
 * Persists performer session state to SQLite so sessions can survive process restart.
 * Stores worktree path, current task, last commit hash, and arbitrary checkpoint data.
 */

import type Database from 'better-sqlite3';

export interface SessionState {
  readonly performerId: string;
  readonly currentTaskId?: string;
  readonly worktreePath?: string;
  readonly lastCommitHash?: string;
  readonly checkpointData: Readonly<Record<string, unknown>>;
}

export interface SessionResume {
  saveCheckpoint: (state: SessionState) => Promise<void>;
  loadCheckpoint: (performerId: string) => Promise<SessionState | null>;
  listSessions: () => Promise<SessionState[]>;
}

interface SessionRow {
  performer_id: string;
  current_task_id: string | null;
  worktree_path: string | null;
  last_commit_hash: string | null;
  checkpoint_data: string;
  updated_at: number;
}

export function createSessionResume(db: Database.Database): SessionResume {
  const upsertStmt = db.prepare(`
    INSERT OR REPLACE INTO performer_sessions
      (performer_id, current_task_id, worktree_path, last_commit_hash, checkpoint_data, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  const loadStmt = db.prepare('SELECT * FROM performer_sessions WHERE performer_id = ?');

  const listStmt = db.prepare('SELECT * FROM performer_sessions ORDER BY updated_at DESC');

  function rowToSession(row: SessionRow): SessionState {
    return {
      performerId: row.performer_id,
      currentTaskId: row.current_task_id ?? undefined,
      worktreePath: row.worktree_path ?? undefined,
      lastCommitHash: row.last_commit_hash ?? undefined,
      checkpointData: JSON.parse(row.checkpoint_data) as Record<string, unknown>,
    };
  }

  return {
    saveCheckpoint(state: SessionState): Promise<void> {
      upsertStmt.run(
        state.performerId,
        state.currentTaskId ?? null,
        state.worktreePath ?? null,
        state.lastCommitHash ?? null,
        JSON.stringify(state.checkpointData),
        Date.now(),
      );
      return Promise.resolve();
    },

    loadCheckpoint(performerId: string): Promise<SessionState | null> {
      const row = loadStmt.get(performerId) as SessionRow | undefined;
      return Promise.resolve(row !== undefined ? rowToSession(row) : null);
    },

    listSessions(): Promise<SessionState[]> {
      const rows = listStmt.all() as SessionRow[];
      return Promise.resolve(rows.map(rowToSession));
    },
  };
}
