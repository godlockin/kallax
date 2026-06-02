/**
 * KALLAX Error Handler
 * Centralized error handling - empty catch blocks PROHIBITED
 */

import { Result, ok, err } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../types/index.js';
import { logger } from './logger.js';

/**
 * Type guard for Error instances
 */
export function isError(value: unknown): value is Error {
  return value instanceof Error;
}

/**
 * Type guard for objects with message property
 */
function hasMessage(value: unknown): value is { message: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    'message' in value &&
    typeof (value as { message: unknown }).message === 'string'
  );
}

/**
 * Safely extract error message from unknown value
 */
export function getErrorMessage(error: unknown): string {
  if (isError(error)) {
    return error.message;
  }
  if (hasMessage(error)) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return 'Unknown error';
}

/**
 * Wrap async operation with error handling
 */
export async function wrapAsync<T>(
  operation: () => Promise<T>,
  errorCode: KallaxErrorCode = KallaxErrorCode.INTERNAL_ERROR
): Promise<KallaxResult<T>> {
  try {
    const result = await operation();
    return ok(result);
  } catch (error: unknown) {
    const kallaxError = KallaxError.fromUnknown(error, errorCode);
    logger.kallaxError(kallaxError);
    return err(kallaxError);
  }
}

/**
 * Wrap sync operation with error handling
 */
export function wrapSync<T>(
  operation: () => T,
  errorCode: KallaxErrorCode = KallaxErrorCode.INTERNAL_ERROR
): KallaxResult<T> {
  try {
    const result = operation();
    return ok(result);
  } catch (error: unknown) {
    const kallaxError = KallaxError.fromUnknown(error, errorCode);
    logger.kallaxError(kallaxError);
    return err(kallaxError);
  }
}

/**
 * Execute operation with retry logic
 */
export async function withRetry<T>(
  operation: () => Promise<T>,
  options: {
    maxAttempts?: number;
    delayMs?: number;
    backoffMultiplier?: number;
    errorCode?: KallaxErrorCode;
    shouldRetry?: (error: unknown, attempt: number) => boolean;
  } = {}
): Promise<KallaxResult<T>> {
  const {
    maxAttempts = 3,
    delayMs = 1000,
    backoffMultiplier = 2,
    errorCode = KallaxErrorCode.INTERNAL_ERROR,
    shouldRetry = () => true,
  } = options;

  let lastError: unknown;
  let currentDelay = delayMs;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const result = await operation();
      return ok(result);
    } catch (error: unknown) {
      lastError = error;

      logger.warn(
        { attempt, maxAttempts, error: getErrorMessage(error) },
        'operation failed, checking retry'
      );

      if (attempt < maxAttempts && shouldRetry(error, attempt)) {
        await sleep(currentDelay);
        currentDelay *= backoffMultiplier;
      }
    }
  }

  const kallaxError = KallaxError.fromUnknown(lastError, errorCode);
  kallaxError.metadata['attempts'] = maxAttempts;
  logger.kallaxError(kallaxError);
  return err(kallaxError);
}

/**
 * Sleep utility
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Combine multiple Results, failing fast on first error
 */
export function combineResults<T extends readonly KallaxResult<unknown>[]>(
  results: T
): KallaxResult<{ [K in keyof T]: T[K] extends KallaxResult<infer U> ? U : never }> {
  const values: unknown[] = [];

  for (const result of results) {
    if (result.isErr()) {
      return err(result.error);
    }
    values.push(result.value);
  }

  return ok(values as { [K in keyof T]: T[K] extends KallaxResult<infer U> ? U : never });
}

/**
 * Map error to different error code
 */
export function mapError<T>(
  result: KallaxResult<T>,
  mapping: Partial<Record<KallaxErrorCode, KallaxErrorCode>>
): KallaxResult<T> {
  if (result.isOk()) {
    return result;
  }

  const newCode = mapping[result.error.code];
  if (newCode !== undefined) {
    return err(new KallaxError(newCode, result.error.message, {
      cause: result.error.cause,
      metadata: result.error.metadata as Record<string, unknown>,
    }));
  }

  return result;
}

/**
 * Log and rethrow pattern for boundaries
 */
export function logAndRethrow(error: unknown, context: Record<string, unknown> = {}): never {
  const kallaxError = KallaxError.fromUnknown(error);
  logger.error({ ...context, error: kallaxError.toContext() }, 'unhandled error at boundary');
  throw kallaxError;
}
