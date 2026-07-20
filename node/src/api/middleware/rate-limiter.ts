/**
 * KALLAX Rate Limiter
 * Token bucket algorithm with per-route configuration
 */

import type { Request, Response, NextFunction } from 'express';
import { logger } from '../../utils/logger.js';

interface TokenBucket {
  readonly tokens: number;
  readonly lastRefill: number;
}

interface RouteLimitConfig {
  readonly maxTokens: number;
  readonly refillRate: number;
  readonly windowMs: number;
}

const DEFAULT_LIMIT: RouteLimitConfig = {
  maxTokens: 100,
  refillRate: 100 / 60, // 100 tokens per 60 seconds
  windowMs: 60000,
};

const ROUTE_SPECIFIC_LIMITS: ReadonlyMap<string, RouteLimitConfig> = new Map([
  ['/api/tasks', { maxTokens: 50, refillRate: 50 / 60, windowMs: 60000 }],
  ['/api/agents', { maxTokens: 30, refillRate: 30 / 60, windowMs: 60000 }],
  ['/api/workflow', { maxTokens: 20, refillRate: 20 / 60, windowMs: 60000 }],
  ['/api/heartbeat', { maxTokens: 500, refillRate: 500 / 60, windowMs: 60000 }],
]);

const buckets = new Map<string, TokenBucket>();

// Periodic cleanup of stale buckets (every 5 minutes)
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000;
setInterval(() => {
  const now = Date.now();
  let clearedCount = 0;
  for (const [key, bucket] of buckets) {
    if (now - bucket.lastRefill > CLEANUP_INTERVAL_MS) {
      buckets.delete(key);
      clearedCount++;
    }
  }
  if (clearedCount > 0) {
    logger.debug({ cleanedBuckets: clearedCount }, 'rate limiter bucket cleanup');
  }
}, CLEANUP_INTERVAL_MS).unref();

/**
 * Get the applicable rate limit config for a path, along with the matched prefix
 * (or an empty string when the default limit applies). The prefix is used as
 * part of the bucket key so each (IP, route) pair keeps its own token bucket.
 */
function getLimitConfig(path: string): { prefix: string; config: RouteLimitConfig } {
  for (const [prefix, config] of ROUTE_SPECIFIC_LIMITS) {
    if (path.startsWith(prefix)) {
      return { prefix, config };
    }
  }
  return { prefix: '', config: DEFAULT_LIMIT };
}

/**
 * Refill tokens based on elapsed time
 */
function refillBucket(bucket: TokenBucket, config: RouteLimitConfig, now: number): TokenBucket {
  const elapsed = now - bucket.lastRefill;
  const tokensToAdd = elapsed * (config.refillRate / 1000);
  const newTokens = Math.min(bucket.tokens + tokensToAdd, config.maxTokens);
  return { tokens: newTokens, lastRefill: now };
}

/**
 * Clear all rate limit buckets. Use in test setup to avoid cross-test pollution.
 */
export function resetRateLimiter(): void {
  buckets.clear();
}

/**
 * Create rate limiter middleware
 */
export function createRateLimiter() {
  return function rateLimiter(req: Request, res: Response, next: NextFunction): void {
    const ip = req.ip ?? 'unknown';
    const { prefix, config } = getLimitConfig(req.path);
    const key = `${ip}::${prefix}`;
    const now = Date.now();

    let bucket = buckets.get(key);

    // Initialize or refill bucket
    if (bucket === undefined) {
      bucket = { tokens: config.maxTokens, lastRefill: now };
    } else {
      bucket = refillBucket(bucket, config, now);
    }

    // Check if request is allowed
    if (bucket.tokens < 1) {
      const retryAfter = Math.ceil(config.windowMs / 1000);
      res.setHeader('Retry-After', String(retryAfter));
      res.setHeader('X-RateLimit-Limit', String(config.maxTokens));
      res.setHeader('X-RateLimit-Remaining', '0');
      res.setHeader('X-RateLimit-Reset', String(Math.ceil((bucket.lastRefill + config.windowMs) / 1000)));

      logger.warn(
        { ip: key, path: req.path, retryAfter },
        'rate limit exceeded'
      );

      res.status(429).json({
        success: false,
        error: {
          code: 'RATE_LIMITED',
          message: `Too many requests. Retry after ${retryAfter} seconds`,
        },
        timestamp: now,
      });
      return;
    }

    // Consume a token
    bucket = { tokens: bucket.tokens - 1, lastRefill: bucket.lastRefill };
    buckets.set(key, bucket);

    // Set rate limit headers
    res.setHeader('X-RateLimit-Limit', String(config.maxTokens));
    res.setHeader('X-RateLimit-Remaining', String(Math.floor(bucket.tokens)));
    res.setHeader('X-RateLimit-Reset', String(Math.ceil((bucket.lastRefill + config.windowMs) / 1000)));

    next();
  };
}
