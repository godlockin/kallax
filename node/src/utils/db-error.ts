/**
 * Database error wrapper — eliminates repetitive try/catch patterns.
 * 144+ identical catch blocks reduced to a single utility.
 */
import { err } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../types/index.js';

/**
 * Wraps a synchronous database operation with standard error handling.
 * Usage: withDbError(() => db.prepare(...).run(...), 'create ticket', { ticketId: id })
 */
export function withDbError<T>(
  fn: () => T,
  operation: string,
  context?: Record<string, unknown>,
): KallaxResult<T> {
  try {
    return { isOk: () => true, isErr: () => false, value: fn(), _unsafeUnwrap: () => fn() } as KallaxResult<T>;
  } catch (error: unknown) {
    return err(
      new KallaxError(KallaxErrorCode.DB_ERROR, `Failed to ${operation}`, {
        cause: error,
        ...(context !== undefined ? { metadata: context } : {}),
      }),
    );
  }
}

// Import ok for proper KallaxResult construction
import { ok } from 'neverthrow';

/**
 * Simplified version that returns ok(value) on success.
 */
export function wrapDb<T>(fn: () => T, operation: string, context?: Record<string, unknown>): KallaxResult<T> {
  try {
    return ok(fn());
  } catch (error: unknown) {
    return err(
      new KallaxError(KallaxErrorCode.DB_ERROR, `Failed to ${operation}`, {
        cause: error,
        ...(context !== undefined ? { metadata: context } : {}),
      }),
    );
  }
}
