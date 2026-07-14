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
 *   POST /hooks/replay      (Iter 8 武器 5: replay historical events to target session)
 *   GET  /hooks/audit       (Iter 8 武器 5: query the audit log with filters)
 */

import { createServer, type IncomingMessage, type ServerResponse, type Server } from 'node:http';
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { HookContext, HookPhase, HookDispatcher } from './types.js';
import {
  type HookEventsStore,
} from './hook-events-store.js';

export interface HookServerConfig {
  readonly port: number;
  readonly host?: string;
  readonly apiKey?: string;
  /** Optional admin API key. Required for cross-session replay (S-005 hotfix). */
  readonly adminApiKey?: string;
  readonly auditStore?: HookEventsStore;
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
        resolve(raw ? (JSON.parse(raw) as Record<string, unknown>) : {});
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
  let boundPort = config.port;
  const auditStore: HookEventsStore | null = config.auditStore ?? null;

  function isAuthorized(req: IncomingMessage): boolean {
    // S-002 fail-closed: API key 必须存在, 否则 deny 所有 request (治 root cause of auth bypass)
    if (config.apiKey === undefined) {
      logger.error({}, 'KALLAX_HOOK_API_KEY required for /hooks/* endpoints');
      return false;
    }
    const auth = req.headers['authorization'] ?? '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    // EPIC-069-B: adminApiKey bypasses isAuthorized so handleReplay can perform cross-session replay
    if (config.adminApiKey !== undefined && token === config.adminApiKey) return true;
    return token === config.apiKey;
  }

  async function handleReplay(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (!auditStore) {
      sendJson(res, 503, { error: 'audit store not configured' });
      return;
    }
    let body: Record<string, unknown>;
    try {
      body = await parseBody(req);
    } catch (error: unknown) {
      sendJson(res, 400, { error: error instanceof Error ? error.message : String(error) });
      return;
    }

    const targetSessionId = body['targetSessionId'] as string | undefined;
    const sourceSessionId = body['sessionId'] as string | undefined;
    const fromTimestamp = typeof body['fromTimestamp'] === 'number' ? body['fromTimestamp'] : undefined;
    const toTimestamp = typeof body['toTimestamp'] === 'number' ? body['toTimestamp'] : undefined;

    if (targetSessionId === undefined || targetSessionId === '') {
      sendJson(res, 400, { error: 'targetSessionId is required' });
      return;
    }

    // S-005 hotfix: cross-session replay requires admin token. Source session
    // ownership check: caller (Bearer token) must either match the source
    // session, hold the admin API key, or the source session must match the
    // target session (intra-session replay).
    const isCrossSession = sourceSessionId !== undefined && sourceSessionId !== targetSessionId;
    if (isCrossSession) {
      const auth = req.headers['authorization'] ?? '';
      const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
      const isAdmin = config.adminApiKey !== undefined && token === config.adminApiKey;
      const isSourceOwner = token !== '' && token === sourceSessionId;
      if (!isAdmin && !isSourceOwner) {
        logger.warn({ sourceSessionId, targetSessionId }, 'cross-session replay denied: caller lacks ownership of source session');
        sendJson(res, 403, { error: 'cross-session replay requires admin token or source session ownership' });
        return;
      }
    }

    const events = auditStore.query({
      sessionId: sourceSessionId,
      fromTimestamp,
      toTimestamp,
    });

    const replayResults: Array<{
      originalSeq: number;
      hookType: string;
      toolName?: string;
      allowed: boolean;
      reason?: string;
    }> = [];

    for (const event of events) {
      const ctx: HookContext = {
        phase: event.hookType as HookPhase,
        toolName: event.toolName,
        toolParams: (event.metadata?.['toolParams'] as Record<string, unknown> | undefined) ?? undefined,
        ticketId: event.ticketId,
        performerId: event.performerId,
        sessionId: targetSessionId,
        metadata: {
          ...(event.metadata ?? {}),
          replay: {
            sourceSessionId: event.sessionId,
            sourceSeq: event.seq,
            sourceTs: event.ts,
            originalResultCode: event.resultCode,
            originalReason: event.reason,
          },
        },
      };

      const result = await dispatcher.execute(ctx);
      if (result.isErr()) {
        replayResults.push({
          originalSeq: event.seq,
          hookType: event.hookType,
          toolName: event.toolName,
          allowed: false,
          reason: `dispatch error: ${result.error.message}`,
        });
        continue;
      }
      replayResults.push({
        originalSeq: event.seq,
        hookType: event.hookType,
        toolName: event.toolName,
        allowed: result.value.allowed,
        reason: result.value.reason,
      });
    }

    sendJson(res, 200, {
      targetSessionId,
      sourceSessionId: sourceSessionId ?? null,
      totalEvents: events.length,
      replayed: replayResults.length,
      results: replayResults,
    });
  }

  function handleAuditQuery(req: IncomingMessage, res: ServerResponse): void {
    if (auditStore === null) {
      sendJson(res, 503, { error: 'audit store not configured' });
      return;
    }
    const url = new URL(req.url ?? '/', 'http://localhost');
    const sessionId = url.searchParams.get('sessionId') ?? undefined;
    const hookType = url.searchParams.get('hookType') ?? undefined;
    const fromStr = url.searchParams.get('fromTimestamp');
    const toStr = url.searchParams.get('toTimestamp');
    const limitStr = url.searchParams.get('limit');

    const fromTimestamp = fromStr !== null && fromStr !== '' ? Number(fromStr) : undefined;
    const toTimestamp = toStr !== null && toStr !== '' ? Number(toStr) : undefined;
    const limit = limitStr !== null && limitStr !== '' ? Number(limitStr) : undefined;

    // EPIC-070-B1: scope guard — 无 sessionId 调用需 adminApiKey, 避免全量数据外泄
    const auth = req.headers['authorization'] ?? '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const isAdmin = config.adminApiKey !== undefined && token === config.adminApiKey;
    if ((sessionId === undefined || sessionId === '') && !isAdmin) {
      sendJson(res, 403, {
        error: 'sessionId required (or adminApiKey for full-export)',
        hint: 'Pass ?sessionId=<id> for scoped query, or use adminApiKey for full audit',
      });
      return;
    }

    let events = auditStore.query({ sessionId, hookType, fromTimestamp, toTimestamp });
    if (typeof limit === 'number' && limit > 0) {
      events = events.slice(-limit);
    }

    sendJson(res, 200, {
      path: auditStore.path(),
      total: events.length,
      events,
    });
  }

  async function handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
    // Auth check
    if (!isAuthorized(req)) {
      sendJson(res, 401, { error: 'Unauthorized' });
      return;
    }

    const url = req.url ?? '/';
    const path = url.split('?')[0] ?? '';

    // Iter 8 武器 5: /hooks/replay + /hooks/audit (non-phase endpoints)
    if (path.endsWith('/hooks/replay')) {
      if (req.method !== 'POST') {
        sendJson(res, 405, { error: 'Method not allowed' });
        return;
      }
      await handleReplay(req, res);
      return;
    }
    if (path.endsWith('/hooks/audit')) {
      if (req.method !== 'GET') {
        sendJson(res, 405, { error: 'Method not allowed' });
        return;
      }
      handleAuditQuery(req, res);
      return;
    }

    const phase = extractPhase(url);
    if (!phase) {
      sendJson(res, 404, { error: `Unknown hook endpoint: ${url}` });
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
        metadata: (body['metadata'] as Record<string, unknown> | null | undefined) ?? {},
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

      // S-002 fail-closed: 启动时强制 apiKey 必须存在 (治 root cause)
      if (config.apiKey === undefined) {
        const msg = 'KALLAX_HOOK_API_KEY required for hook server to start (fail-closed, S-002)';
        logger.fatal({}, msg);
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, msg)));
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
          // Capture the actual bound port (in case caller passed 0 for OS-assigned)
          const addr = server.address() as { port: number } | null;
          if (addr !== null) {
            boundPort = addr.port;
          }
          const endpoints = Object.keys(PHASE_MAP).length + (auditStore ? 2 : 0);
          logger.info({ port: boundPort, endpoints, auditEnabled: auditStore !== null }, 'hook server started');
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
        const srv = server as Server;
        srv.close((error?: Error) => {
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
      return boundPort;
    },

    isRunning(): boolean {
      return running;
    },
  };
}
