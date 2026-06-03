/**
 * KALLAX HTTP Hook Server — receives agent lifecycle events from Claude Code hooks.
 *
 * Endpoints:
 *   POST /hooks/pre-tool-use
 *   POST /hooks/post-tool-use
 *   POST /hooks/compact
 *   POST /hooks/permission
 *   POST /hooks/session-start
 *   POST /hooks/session-end
 */

import { createServer, type IncomingMessage, type ServerResponse, type Server } from 'node:http';
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { HookContext, HookPhase, HookDispatcher } from './types.js';

export interface HookServerConfig {
  readonly port: number;
  readonly host?: string;
  readonly apiKey?: string;
}

export interface HookServer {
  start: () => Promise<KallaxResult<void>>;
  stop: () => Promise<KallaxResult<void>>;
  getPort: () => number;
  isRunning: () => boolean;
}

const PHASE_MAP: Record<string, HookPhase> = {
  'pre-tool-use': 'pre-tool-use',
  'post-tool-use': 'post-tool-use',
  'compact': 'post-compact',
  'permission': 'pre-permission',
  'session-start': 'session-start',
  'session-end': 'session-end',
};

function parseBody(req: IncomingMessage): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => chunks.push(chunk));
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf-8');
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error('Invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}

function extractPhase(url: string): HookPhase | null {
  const path = url.split('?')[0] ?? '';
  for (const [route, phase] of Object.entries(PHASE_MAP)) {
    if (path.endsWith(route)) {
      return phase;
    }
  }
  return null;
}

function sendJson(res: ServerResponse, statusCode: number, data: Record<string, unknown>): void {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

export function createHookServer(
  dispatcher: HookDispatcher,
  config: HookServerConfig,
): HookServer {
  let server: Server | null = null;
  let running = false;

  async function handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
    // Auth check
    if (config.apiKey) {
      const auth = req.headers['authorization'] ?? '';
      const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
      if (token !== config.apiKey) {
        sendJson(res, 401, { error: 'Unauthorized' });
        return;
      }
    }

    const phase = extractPhase(req.url ?? '/');
    if (!phase) {
      sendJson(res, 404, { error: `Unknown hook endpoint: ${req.url}` });
      return;
    }

    if (req.method !== 'POST') {
      sendJson(res, 405, { error: 'Method not allowed' });
      return;
    }

    try {
      const body = await parseBody(req);

      const ctx: HookContext = {
        phase,
        toolName: body['toolName'] as string | undefined,
        toolParams: body['toolParams'] as Record<string, unknown> | undefined,
        ticketId: body['ticketId'] as string | undefined,
        performerId: body['performerId'] as string | undefined,
        sessionId: body['sessionId'] as string | undefined,
        metadata: (body['metadata'] as Record<string, unknown>) ?? {},
      };

      const result = await dispatcher.execute(ctx);

      if (result.isErr()) {
        logger.error({ phase, error: result.error.message }, 'hook execution error');
        sendJson(res, 500, { error: result.error.message });
        return;
      }

      const hookResult = result.value;
      if (!hookResult.allowed) {
        sendJson(res, 403, {
          allowed: false,
          reason: hookResult.reason ?? 'Blocked by hook',
          warnings: hookResult.warnings,
        });
        return;
      }

      sendJson(res, 200, {
        allowed: true,
        warnings: hookResult.warnings,
        modifiedParams: hookResult.modifiedParams,
        metadata: hookResult.metadata,
      });
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.error({ phase, error: msg }, 'hook handler error');
      sendJson(res, 400, { error: msg });
    }
  }

  return {
    async start(): Promise<KallaxResult<void>> {
      if (running) {
        return ok(undefined);
      }

      return new Promise((resolve) => {
        server = createServer((req, res) => {
          handleRequest(req, res).catch((err: unknown) => {
            logger.error({ error: err instanceof Error ? err.message : String(err) }, 'unhandled hook error');
            if (!res.headersSent) {
              sendJson(res, 500, { error: 'Internal error' });
            }
          });
        });

        server.on('error', (error: Error) => {
          running = false;
          logger.error({ error: error.message }, 'hook server error');
        });

        server.listen(config.port, config.host ?? '127.0.0.1', () => {
          running = true;
          logger.info({ port: config.port, endpoints: Object.keys(PHASE_MAP).length }, 'hook server started');
          resolve(ok(undefined));
        });
      });
    },

    async stop(): Promise<KallaxResult<void>> {
      if (!server || !running) {
        running = false;
        return ok(undefined);
      }

      return new Promise((resolve) => {
        server!.close((error?: Error) => {
          running = false;
          if (error) {
            logger.error({ error: error.message }, 'hook server close error');
            resolve(err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, error.message)));
          } else {
            logger.info({}, 'hook server stopped');
            resolve(ok(undefined));
          }
        });
      });
    },

    getPort(): number {
      return config.port;
    },

    isRunning(): boolean {
      return running;
    },
  };
}
