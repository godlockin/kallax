/**
 * KALLAX Auth Middleware
 * API key validation and role-based access control
 */

import type { Request, Response, NextFunction } from 'express';
import { logger } from '../../utils/logger.js';
import type { EndpointRole } from '../types.js';

const PUBLIC_PATHS = new Set<string>([
  '/health',
  '/live',
  '/ready',
  '/version',
]);

const CONDUCTOR_PATHS = new Set<string>([
  '/api/system/doctor',
  '/api/system/gc',
  '/api/workflow',
]);

/**
 * Extract API key from request header
 */
function extractApiKey(req: Request): string | null {
  const header = req.headers['x-kallax-api-key'];
  if (header === undefined) {
    return null;
  }
  if (Array.isArray(header)) {
    return header[0] ?? null;
  }
  return header;
}

/**
 * Extract role from request header
 */
function extractRole(req: Request): EndpointRole | null {
  const header = req.headers['x-kallax-role'];
  if (header === undefined) {
    return null;
  }
  const value = Array.isArray(header) ? (header[0] ?? null) : header;
  if (value === 'conductor' || value === 'performer' || value === 'admin') {
    return value;
  }
  return null;
}

/**
 * Check if path matches a prefix in the set
 */
function pathMatchesPrefix(path: string, prefixes: Set<string>): boolean {
  for (const prefix of prefixes) {
    if (path === prefix || path.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

/**
 * Create auth middleware
 */
export function createAuthMiddleware(apiKey: string) {
  return function authMiddleware(req: Request, res: Response, next: NextFunction): void {
    // Skip auth for public paths
    const path = req.path;
    if (PUBLIC_PATHS.has(path)) {
      next();
      return;
    }

    // Validate API key
    const key = extractApiKey(req);
    if (key === null) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Missing X-KALLAX-API-Key header',
        },
        timestamp: Date.now(),
      });
      return;
    }

    if (key !== apiKey) {
      logger.warn(
        { ip: req.ip, path, method: req.method },
        'invalid API key attempt'
      );
      res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'Invalid API key',
        },
        timestamp: Date.now(),
      });
      return;
    }

    // Set auth info on request
    const role = extractRole(req);
    req.auth = {
      apiKey: key,
      ...(role !== null ? { role } : {}),
    };

    // Check role for conductor-only paths
    if (pathMatchesPrefix(path, CONDUCTOR_PATHS)) {
      const hasConductorAccess = role === 'conductor' || role === 'admin';
      if (!hasConductorAccess) {
        res.status(403).json({
          success: false,
          error: {
            code: 'FORBIDDEN',
            message: 'Conductor role required for this endpoint',
          },
          timestamp: Date.now(),
        });
        return;
      }
    }

    next();
  };
}

/**
 * Extend Express Request to include auth info
 *
 * `declare global { namespace Express { ... } }` is the only documented way
 * to augment Express's Request type from a module (see @types/express).
 * Converting to module-augmenting interfaces (e.g. `declare module 'express-serve-static-core'`)
 * would still produce an equivalent global side effect, so the namespace
 * pattern is preserved here. Disabled locally because the rule's auto-fix
 * cannot represent this pattern.
 */
/* eslint-disable @typescript-eslint/no-namespace */
declare global {
  namespace Express {
    interface Request {
      auth?: {
        readonly apiKey: string;
        readonly role?: EndpointRole;
      };
    }
  }
}
/* eslint-enable @typescript-eslint/no-namespace */
