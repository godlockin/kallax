/**
 * KALLAX Circuit Breaker
 * Prevent cascading failures with automatic recovery
 */

import { err, ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';

export const CircuitState = {
  CLOSED: 'closed',
  OPEN: 'open',
  HALF_OPEN: 'half_open',
} as const;

export type CircuitState = (typeof CircuitState)[keyof typeof CircuitState];

export interface CircuitBreakerConfig {
  readonly name: string;
  readonly failureThreshold: number;
  readonly successThreshold: number;
  readonly timeoutMs: number;
  readonly resetTimeMs: number;
}

export interface CircuitBreakerStats {
  readonly state: CircuitState;
  readonly failures: number;
  readonly successes: number;
  readonly lastFailure: number | null;
  readonly lastSuccess: number | null;
  readonly totalCalls: number;
  readonly totalFailures: number;
}

export interface CircuitBreaker {
  execute: <T>(operation: () => Promise<T>) => Promise<KallaxResult<T>>;
  getState: () => CircuitState;
  getStats: () => CircuitBreakerStats;
  reset: () => void;
  forceOpen: () => void;
  forceClose: () => void;
}

const DEFAULT_CONFIG: Omit<CircuitBreakerConfig, 'name'> = {
  failureThreshold: 5,
  successThreshold: 2,
  timeoutMs: 30000,
  resetTimeMs: 60000,
};

export function createCircuitBreaker(
  config: Partial<CircuitBreakerConfig> & { name: string }
): CircuitBreaker {
  const finalConfig: CircuitBreakerConfig = { ...DEFAULT_CONFIG, ...config };

  let state: CircuitState = CircuitState.CLOSED;
  let failures = 0;
  let successes = 0;
  let lastFailure: number | null = null;
  let lastSuccess: number | null = null;
  let lastStateChange = Date.now();
  let totalCalls = 0;
  let totalFailures = 0;

  function transitionTo(newState: CircuitState): void {
    if (state !== newState) {
      logger.info(
        { circuitName: finalConfig.name, from: state, to: newState },
        'circuit breaker state transition'
      );
      state = newState;
      lastStateChange = Date.now();

      if (newState === CircuitState.CLOSED) {
        failures = 0;
        successes = 0;
      } else if (newState === CircuitState.HALF_OPEN) {
        successes = 0;
      }
    }
  }

  function shouldAttempt(): boolean {
    switch (state) {
      case CircuitState.CLOSED:
        return true;

      case CircuitState.OPEN: {
        const elapsed = Date.now() - lastStateChange;
        if (elapsed >= finalConfig.resetTimeMs) {
          transitionTo(CircuitState.HALF_OPEN);
          return true;
        }
        return false;
      }

      case CircuitState.HALF_OPEN:
        return true;
    }
  }

  function recordSuccess(): void {
    lastSuccess = Date.now();
    totalCalls++;

    switch (state) {
      case CircuitState.CLOSED:
        failures = 0;
        break;

      case CircuitState.HALF_OPEN:
        successes++;
        if (successes >= finalConfig.successThreshold) {
          transitionTo(CircuitState.CLOSED);
        }
        break;

      case CircuitState.OPEN:
        // Shouldn't happen
        break;
    }
  }

  function recordFailure(): void {
    lastFailure = Date.now();
    totalCalls++;
    totalFailures++;

    switch (state) {
      case CircuitState.CLOSED:
        failures++;
        if (failures >= finalConfig.failureThreshold) {
          transitionTo(CircuitState.OPEN);
        }
        break;

      case CircuitState.HALF_OPEN:
        transitionTo(CircuitState.OPEN);
        break;

      case CircuitState.OPEN:
        // Already open
        break;
    }
  }

  return {
    async execute<T>(operation: () => Promise<T>): Promise<KallaxResult<T>> {
      if (!shouldAttempt()) {
        logger.warn(
          { circuitName: finalConfig.name, state },
          'circuit breaker rejected call'
        );
        return err(
          new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Circuit breaker is open', {
            metadata: { circuitName: finalConfig.name, state },
          })
        );
      }

      try {
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => {
            reject(new Error('Operation timed out'));
          }, finalConfig.timeoutMs);
        });

        const result = await Promise.race([operation(), timeoutPromise]);
        recordSuccess();
        return ok(result);
      } catch (error: unknown) {
        recordFailure();
        const message = error instanceof Error ? error.message : String(error);
        logger.error(
          { circuitName: finalConfig.name, error: message },
          'circuit breaker operation failed'
        );
        return err(
          new KallaxError(KallaxErrorCode.INTERNAL_ERROR, message, {
            cause: error,
            metadata: { circuitName: finalConfig.name },
          })
        );
      }
    },

    getState(): CircuitState {
      // Check for automatic transition from OPEN to HALF_OPEN
      if (state === CircuitState.OPEN) {
        const elapsed = Date.now() - lastStateChange;
        if (elapsed >= finalConfig.resetTimeMs) {
          transitionTo(CircuitState.HALF_OPEN);
        }
      }
      return state;
    },

    getStats(): CircuitBreakerStats {
      return {
        state: this.getState(),
        failures,
        successes,
        lastFailure,
        lastSuccess,
        totalCalls,
        totalFailures,
      };
    },

    reset(): void {
      transitionTo(CircuitState.CLOSED);
      failures = 0;
      successes = 0;
      logger.info({ circuitName: finalConfig.name }, 'circuit breaker reset');
    },

    forceOpen(): void {
      transitionTo(CircuitState.OPEN);
      logger.warn({ circuitName: finalConfig.name }, 'circuit breaker forced open');
    },

    forceClose(): void {
      transitionTo(CircuitState.CLOSED);
      logger.info({ circuitName: finalConfig.name }, 'circuit breaker forced closed');
    },
  };
}

// Registry for managing multiple circuit breakers
const circuitBreakers = new Map<string, CircuitBreaker>();

export function getCircuitBreaker(name: string, config?: Partial<CircuitBreakerConfig>): CircuitBreaker {
  let breaker = circuitBreakers.get(name);
  if (breaker === undefined) {
    breaker = createCircuitBreaker({ name, ...config });
    circuitBreakers.set(name, breaker);
  }
  return breaker;
}

export function getAllCircuitBreakerStats(): Record<string, CircuitBreakerStats> {
  const stats: Record<string, CircuitBreakerStats> = {};
  for (const [name, breaker] of circuitBreakers) {
    stats[name] = breaker.getStats();
  }
  return stats;
}
