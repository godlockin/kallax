/**
 * KALLAX Agent/Performer Routes
 * Performer registration, status, and heartbeat
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { InstanceRole, InstanceStatus, KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite-manager.js';
import type { InstanceRegistry } from '../../core/instance-registry.js';
import type { SSEBus } from '../../core/sse-bus.js';
import { createEvent } from '../../core/sse-bus.js';
import { EventType } from '../../types/index.js';
import {
  createSuccessResponse,
  createErrorResponse,
  type RegisterAgentRequest,
  type HeartbeatRequest,
} from '../types.js';

export interface AgentRouteDependencies {
  readonly db: SQLiteManager;
  readonly instanceRegistry: InstanceRegistry;
  readonly sseBus: SSEBus;
}

/**
 * Create agent/performer routes with injected dependencies
 */
export function createAgentRoutes(deps: AgentRouteDependencies): Router {
  const router = Router();

  // GET /api/agents — list all performers
  router.get('/', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const role = req.query['role'] as string | undefined;

        const result = deps.db.listInstances({ limit: 100 });
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const instances = result.value;

        // Apply role filter if specified
        if (role !== undefined) {
          const filtered = instances.filter((i) => i.role === role);
          res.json(createSuccessResponse(filtered));
          return;
        }

        res.json(createSuccessResponse(instances));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to list agents');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // POST /api/agents/register — register a new performer
  router.post('/register', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const body = req.body as RegisterAgentRequest;

        const roleHeader = req.headers['x-kallax-role'];
        const roleStr = Array.isArray(roleHeader) ? (roleHeader[0] ?? 'performer') : (roleHeader ?? 'performer');

        const role: InstanceRole = roleStr === 'conductor'
          ? InstanceRole.CONDUCTOR
          : InstanceRole.PERFORMER;

        const capabilities: string[] = [];
        if (body.capabilities !== undefined && Array.isArray(body.capabilities)) {
          for (const cap of body.capabilities) {
            if (typeof cap === 'string') {
              capabilities.push(cap);
            }
          }
        }

        const result = await deps.instanceRegistry.register(role, capabilities);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const instance = result.value;

        // Publish event
        const event = createEvent(
          EventType.INSTANCE_REGISTERED,
          { instanceId: instance.id, role, name: body.name },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info(
          { instanceId: instance.id, role, name: body.name },
          'agent registered via API'
        );

        res.status(201).json(createSuccessResponse(instance));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to register agent');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/agents/:id — get performer status
  router.get('/:id', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const instanceId = req.params['id'] as string;

        const result = await deps.instanceRegistry.getById(instanceId);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const instance = result.value;
        if (instance === null) {
          res.status(404).json({
            success: false,
            error: { code: 'INSTANCE_NOT_FOUND', message: `Agent ${instanceId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        res.json(createSuccessResponse(instance));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get agent');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // PUT /api/agents/:id/heartbeat — send heartbeat
  router.put('/:id/heartbeat', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const instanceId = req.params['id'] as string;
        const body = req.body as HeartbeatRequest;

        // Verify instance exists
        const instanceResult = await deps.instanceRegistry.getById(instanceId);
        if (instanceResult.isErr()) {
          res.status(500).json(createErrorResponse(instanceResult.error));
          return;
        }

        const instance = instanceResult.value;
        if (instance === null) {
          res.status(404).json({
            success: false,
            error: { code: 'INSTANCE_NOT_FOUND', message: `Agent ${instanceId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        // Update heartbeat
        const heartbeatResult = await deps.instanceRegistry.heartbeat(instanceId);
        if (heartbeatResult.isErr()) {
          res.status(500).json(createErrorResponse(heartbeatResult.error));
          return;
        }

        // Update status if provided
        if (body.status !== undefined && isValidInstanceStatus(body.status)) {
          const statusResult = await deps.instanceRegistry.updateStatus(
            instanceId,
            body.status as InstanceStatus
          );
          if (statusResult.isErr()) {
            logger.warn(
              { instanceId, status: body.status, error: statusResult.error.message },
              'failed to update instance status'
            );
          }
        }

        // Update current task if provided
        if (body.currentTaskId !== undefined) {
          const updateResult = deps.db.updateInstance(instanceId, {
            currentTaskId: body.currentTaskId,
          });
          if (updateResult.isErr()) {
            logger.warn(
              { instanceId, error: updateResult.error.message },
              'failed to update current task'
            );
          }
        }

        // Publish heartbeat event
        const event = createEvent(
          EventType.INSTANCE_HEARTBEAT,
          { instanceId, timestamp: Date.now() },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.debug({ instanceId }, 'heartbeat received via API');

        res.json(createSuccessResponse({
          instanceId,
          lastHeartbeat: Date.now(),
        }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to process heartbeat');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/agents/:id/tasks — get performer's tasks
  router.get('/:id/tasks', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const performerId = req.params['id'] as string;

        // Verify performer exists
        const instanceResult = await deps.instanceRegistry.getById(performerId);
        if (instanceResult.isErr()) {
          res.status(500).json(createErrorResponse(instanceResult.error));
          return;
        }

        if (instanceResult.value === null) {
          res.status(404).json({
            success: false,
            error: { code: 'INSTANCE_NOT_FOUND', message: `Agent ${performerId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        // Get tasks for this performer
        const tasksResult = deps.db.listTasks({ performerId });
        if (tasksResult.isErr()) {
          res.status(500).json(createErrorResponse(tasksResult.error));
          return;
        }

        res.json(createSuccessResponse(tasksResult.value));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get performer tasks');
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
