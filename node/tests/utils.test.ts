/**
 * Utils Unit Tests
 * Tests for error-handler, startup-validator, memory-monitor, process-cleanup.
 */

import { describe, it, expect } from 'vitest';
import { KallaxError, KallaxErrorCode } from '../src/types/index.js';
import { getErrorMessage, wrapAsync, wrapSync, combineResults, mapError, isError } from '../src/utils/error-handler.js';
import { validateStartup } from '../src/utils/startup-validator.js';

// ── Error Handler ──────────────────────────────────────────────────────────

describe('getErrorMessage', () => {
  it('extracts message from Error instances', () => {
    expect(getErrorMessage(new Error('test'))).toBe('test');
  });

  it('extracts message from objects with message property', () => {
    expect(getErrorMessage({ message: 'custom' })).toBe('custom');
  });

  it('returns string directly', () => {
    expect(getErrorMessage('string error')).toBe('string error');
  });

  it('returns fallback for unknown types', () => {
    expect(getErrorMessage(42)).toBe('Unknown error');
    expect(getErrorMessage(null)).toBe('Unknown error');
    expect(getErrorMessage(undefined)).toBe('Unknown error');
  });
});

describe('isError', () => {
  it('returns true for Error instances', () => {
    expect(isError(new Error('test'))).toBe(true);
  });

  it('returns false for non-Error values', () => {
    expect(isError('string')).toBe(false);
    expect(isError(42)).toBe(false);
    expect(isError({ message: 'test' })).toBe(false);
  });
});

describe('wrapAsync', () => {
  it('wraps successful async operations', async () => {
    const result = await wrapAsync(async () => 'success');
    expect(result.isOk()).toBe(true);
    if (result.isOk()) expect(result.value).toBe('success');
  });

  it('wraps failed async operations', async () => {
    const result = await wrapAsync(async () => {
      throw new Error('async fail');
    });
    expect(result.isErr()).toBe(true);
    if (result.isErr()) expect(result.error.code).toBe(KallaxErrorCode.INTERNAL_ERROR);
  });

  it('uses custom error code', async () => {
    const result = await wrapAsync(
      async () => { throw new Error('fail'); },
      KallaxErrorCode.DB_ERROR,
    );
    expect(result.isErr()).toBe(true);
    if (result.isErr()) expect(result.error.code).toBe(KallaxErrorCode.DB_ERROR);
  });
});

describe('wrapSync', () => {
  it('wraps successful sync operations', () => {
    const result = wrapSync(() => 'success');
    expect(result.isOk()).toBe(true);
    if (result.isOk()) expect(result.value).toBe('success');
  });

  it('wraps failed sync operations', () => {
    const result = wrapSync(() => {
      throw new Error('sync fail');
    });
    expect(result.isErr()).toBe(true);
  });
});

describe('combineResults', () => {
  it('combines multiple ok results', () => {
    const r1 = wrapSync(() => 'a');
    const r2 = wrapSync(() => 'b');
    const combined = combineResults([r1, r2] as const);
    expect(combined.isOk()).toBe(true);
    if (combined.isOk()) expect(combined.value).toEqual(['a', 'b']);
  });

  it('fails fast on first error', () => {
    const r1 = wrapSync(() => 'a');
    const r2 = wrapSync(() => { throw new Error('fail'); });
    const combined = combineResults([r1, r2] as const);
    expect(combined.isErr()).toBe(true);
  });
});

describe('mapError', () => {
  it('passes through ok results', () => {
    const r = wrapSync(() => 'ok');
    const mapped = mapError(r, {});
    expect(mapped.isOk()).toBe(true);
  });

  it('maps error codes', () => {
    const r = wrapSync(() => { throw new Error('test'); });
    const mapped = mapError(r, { [KallaxErrorCode.INTERNAL_ERROR]: KallaxErrorCode.DB_ERROR });
    expect(mapped.isErr()).toBe(true);
    if (mapped.isErr()) expect(mapped.error.code).toBe(KallaxErrorCode.DB_ERROR);
  });
});

// ── KallaxError ─────────────────────────────────────────────────────────────

describe('KallaxError', () => {
  it('creates error with code and message', () => {
    const e = new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'test message');
    expect(e.code).toBe(KallaxErrorCode.INTERNAL_ERROR);
    expect(e.message).toBe('test message');
    expect(e.name).toBe('KallaxError');
  });

  it('creates error with metadata', () => {
    const e = new KallaxError(KallaxErrorCode.DB_ERROR, 'db fail', {
      metadata: { table: 'tickets' },
    });
    expect(e.metadata['table']).toBe('tickets');
  });

  it('converts to context', () => {
    const e = new KallaxError(KallaxErrorCode.FILE_NOT_FOUND, 'not found');
    const ctx = e.toContext();
    expect(ctx.code).toBe(KallaxErrorCode.FILE_NOT_FOUND);
    expect(ctx.message).toBe('not found');
    expect(ctx.timestamp).toBeGreaterThan(0);
  });

  it('fromUnknown wraps existing KallaxError', () => {
    const original = new KallaxError(KallaxErrorCode.DB_ERROR, 'original');
    const wrapped = KallaxError.fromUnknown(original);
    expect(wrapped).toBe(original);
  });

  it('fromUnknown wraps regular Error', () => {
    const wrapped = KallaxError.fromUnknown(new Error('plain'));
    expect(wrapped.code).toBe(KallaxErrorCode.INTERNAL_ERROR);
    expect(wrapped.message).toBe('plain');
  });

  it('fromUnknown wraps string', () => {
    const wrapped = KallaxError.fromUnknown('string error');
    expect(wrapped.code).toBe(KallaxErrorCode.INTERNAL_ERROR);
    expect(wrapped.message).toBe('string error');
  });
});

// ── Startup Validator ───────────────────────────────────────────────────────

describe('validateStartup', () => {
  it('validates current project successfully', () => {
    const result = validateStartup(process.cwd());
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.allPassed).toBe(true);
      expect(result.value.checks.length).toBeGreaterThan(0);
    }
  });

  it('fails for non-existent directory', () => {
    const result = validateStartup('/nonexistent/path/12345');
    expect(result.isErr()).toBe(true);
  });
});
