/**
 * KALLAX Data Adapter — Helpers (跟 v2.7.4 D4 , 跟 Rule 8 )
 * Shared utility functions used by both file-adapter and sqlite-adapter.
 */

import { readdirSync } from 'node:fs';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';

/**
 * Wraps an error into a KallaxError with DB_ERROR code.
 * Used for both file and SQLite adapter error handling.
 */
export function createDataError(message: string, cause: unknown): KallaxError {
  return new KallaxError(KallaxErrorCode.DB_ERROR, message, { cause });
}

/**
 * Safely reads a directory, returning empty array on error.
 * Used to gracefully handle missing directories during file-adapter scans.
 */
export function readDirSafe(dir: string): string[] {
  try {
    return readdirSync(dir);
  } catch {
    return [];
  }
}
