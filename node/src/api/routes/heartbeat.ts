/**
 * KALLAX Heartbeat Routes
 * POST /api/heartbeat  —  receive Performer heartbeat, update DB
 * GET  /api/heartbeat/status  —  view all Performer heartbeat states
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { InstanceStatus, KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite/index.js';
import type { InstanceRegistry } from '../../core/instance-registry.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { SSEBus } from '../../core/sse-bus.js';
import { createEvent } from '../../core/sse-bus.js';
import { EventType } from '../../types/index.js';
import {
  createSuccessResponse,
  createErrorResponse,
} from '../types.js';

export interface HeartbeatRouteDependencies {
  readonly db: SQLiteManager;
  readonly instanceRegistry: InstanceRegistry;
  readonly taskAssigner: TaskAssigner;
  readonly sseBus: SSEBus;
}

/**
 * Heartbeat payload from performer client
 */
export interface HeartbeatRequestBody {
  readonly performerId: string;
  readonly currentTaskId: string | null;
  readonly status: string;
  readonly timestamp: number;
}

/**
 * Heartbeat status entry returned by GET /status
 */
export interface HeartbeatStatusEntry {
  readonly instanceId: string;
  readonly role: string;
  readonly status: string;
  readonly lastHeartbeat: number;
  readonly currentTaskId: string | null;
  readonly hostname: string;
  readonly pid: number;
  readonly isStale: boolean;
  readonly staleSince: number | null;
  readonly ageSeconds: number;
}

/**
 * Create heartbeat routes with injected dependencies
 */
export function createHeartbeatRoutes(deps: HeartbeatRouteDependencies): Router {
  const router = Router();

  /**
   * POST /api/heartbeat — receive performer heartbeat
   * Updates the instance's lastHeartbeat timestamp and optionally
   * its status and currentTaskId.
   */
  router.post('/', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const body = req.body as HeartbeatRequestBody;

        // Validate required fields
        if (!body.performerId || typeof body.performerId !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'performerId is required' },
            timestamp: Date.now(),
          });
          return;
        }

        // Verify instance exists
        const instanceResult = await deps.instanceRegistry.getById(body.performerId);
        if (instanceResult.isErr()) {
          res.status(500).json(createErrorResponse(instanceResult.error));
          return;
        }

        if (instanceResult.value === null) {
          res.status(404).json({
            success: false,
            error: {
              code: 'INSTANCE_NOT_FOUND',
              message: `Performer ${body.performerId} not found. Register first via POST /api/agents/register`,
            },
            timestamp: Date.now(),
          });
          return;
        }

        // Update heartbeat
        const heartbeatResult = await deps.instanceRegistry.heartbeat(body.performerId);
        if (heartbeatResult.isErr()) {
          res.status(500).json(createErrorResponse(heartbeatResult.error));
          return;
        }

        // Update status if provided and valid
        if (body.status !== undefined && typeof body.status === 'string') {
          if (isValidInstanceStatus(body.status)) {
            const statusResult = await deps.instanceRegistry.updateStatus(
              body.performerId,
              body.status
            );
            if (statusResult.isErr()) {
              logger.warn(
                { instanceId: body.performerId, status: body.status, error: statusResult.error.message },
                'failed to update instance status from heartbeat'
              );
            }
          } else {
            logger.warn(
              { instanceId: body.performerId, status: body.status },
              'invalid status in heartbeat payload'
            );
          }
        }

        // Update current task if provided
        if (body.currentTaskId !== undefined) {
          const taskUpdateResult = deps.db.updateInstance(body.performerId, {
            currentTaskId: body.currentTaskId,
          });
          if (taskUpdateResult.isErr()) {
            logger.warn(
              { instanceId: body.performerId, error: taskUpdateResult.error.message },
              'failed to update current task from heartbeat'
            );
          }
        }

        // Publish heartbeat event
        const event = createEvent(
          EventType.INSTANCE_HEARTBEAT,
          { instanceId: body.performerId, timestamp: Date.now() },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.debug({ instanceId: body.performerId }, 'heartbeat received');

        res.json(createSuccessResponse({
          instanceId: body.performerId,
          lastHeartbeat: Date.now(),
        }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to process heartbeat');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  /**
   * GET /api/heartbeat/status — view all performer heartbeat states
   * Returns each instance with staleness info and age.
   * Query params:
   *   staleOnly=true  —  return only stale instances
   *   thresholdMs=N  —  custom stale threshold (default 60s)
   */
  router.get('/status', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const staleOnly = req.query['staleOnly'] === 'true';
        const thresholdMsStr = req.query['thresholdMs'] as string | undefined;
        const thresholdMs = thresholdMsStr !== undefined
          ? Math.max(1000, parseInt(thresholdMsStr, 10) || 60000)
          : 60000;

        const now = Date.now();

        // Get all instances
        const listResult = deps.db.listInstances({ limit: 200 });
        if (listResult.isErr()) {
          res.status(500).json(createErrorResponse(listResult.error));
          return;
        }

        const instances = listResult.value;

        const statusEntries: HeartbeatStatusEntry[] = [];

        for (const inst of instances) {
          const lastHb = inst.lastHeartbeat;
          const isStale =
            inst.status !== 'shutdown' &&
            now - lastHb > thresholdMs;

          if (staleOnly && !isStale) {
            continue;
          }

          statusEntries.push({
            instanceId: inst.id,
            role: inst.role,
            status: inst.status,
            lastHeartbeat: lastHb,
            currentTaskId: inst.currentTaskId,
            hostname: inst.hostname,
            pid: inst.pid,
            isStale,
            staleSince: isStale ? lastHb + thresholdMs : null,
            ageSeconds: Math.round((now - lastHb) / 1000),
          });
        }

        res.json(createSuccessResponse(statusEntries));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get heartbeat status');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}

/**
 * Check if a string is a valid InstanceStatus
 */
function isValidInstanceStatus(value: string): value is InstanceStatus {
  const validStatuses = Object.values(InstanceStatus) as string[];
  return validStatuses.includes(value);
}
