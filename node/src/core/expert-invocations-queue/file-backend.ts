/**
 * KALLAX Expert Invocations Queue — L3 File backend (JSONL append-only)
 *
 * EPIC-021-F: last-resort fallback for L2 SQLite.
 * Append-only writes; drain reads all + clears.
 */

import { promises as fs } from 'node:fs';
import { err, ok, type Result } from 'neverthrow';
import {
  ensureDir,
  toInvocation,
  type ExpertInvocation,
} from './types.js';

// ─── L3 File backend ────────────────────────────────────────────────────────

export interface FileBackend {
  readonly append: (inv: ExpertInvocation) => Promise<Result<void, Error>>;
  readonly readAll: () => Promise<Result<readonly ExpertInvocation[], Error>>;
  readonly clear: () => Promise<Result<void, Error>>;
}

export function createFileBackend(filePath: string): FileBackend {
  return {
    async append(inv) {
      try {
        await ensureDir(filePath);
        await fs.appendFile(filePath, `${JSON.stringify(inv)}\n`, 'utf8');
        return ok(undefined);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    async readAll() {
      try {
        await ensureDir(filePath);
        const content = await fs.readFile(filePath, 'utf8');
        if (content.trim().length === 0) return ok([]);
        const lines = content.split('\n').filter((l) => l.trim().length > 0);
        return ok(lines.map((l) => toInvocation(JSON.parse(l) as unknown)));
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    async clear() {
      try {
        await fs.writeFile(filePath, '', 'utf8');
        return ok(undefined);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
  };
}
