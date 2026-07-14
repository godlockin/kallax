/**
 * KALLAX Cross-Project Pool
 * Share performers across projects with resource quotas and priority-based rebalancing.
 *
 * Architecture:
 * Each project registers with a max performer quota + priority.
 * Performers are allocated to projects, tracked per-project.
 * Rebalancing redistributes performers from lower-priority to higher-priority projects
 * based on priority and available capacity.
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

// ============================================================================
// Types
// ============================================================================

export interface ProjectConfig {
  readonly projectId: string;
  readonly maxPerformers: number;
  readonly priority: number; // higher = more important
  readonly allowedCapabilities: readonly string[];
}

export interface PoolAllocation {
  readonly projectId: string;
  readonly allocatedPerformers: readonly string[];
  readonly availableSlots: number;
  readonly queueDepth: number;
}

export interface GlobalPoolStats {
  readonly totalProjects: number;
  readonly totalPerformers: number;
  readonly utilizationPercent: number;
}

export interface ProjectPool {
  registerProject(config: ProjectConfig): KallaxResult<void>;
  allocatePerformer(performerId: string, projectId: string): KallaxResult<void>;
  releasePerformer(performerId: string): KallaxResult<void>;
  getProjectAllocation(projectId: string): PoolAllocation;
  getGlobalStats(): GlobalPoolStats;
  rebalance(): void;
}

// ============================================================================
// Internal state
// ============================================================================

interface ProjectState {
  config: ProjectConfig;
  allocatedPerformers: Set<string>;
  queueDepth: number;
}

interface PerformerState {
  performerId: string;
  projectId: string;
  capabilities: readonly string[];
  allocatedAt: number;
}

// ============================================================================
// Implementation
// ============================================================================

export function createProjectPool(): ProjectPool {
  const projects = new Map<string, ProjectState>();
  const performers = new Map<string, PerformerState>();

  function validatePerformerForProject(performerId: string, projectId: string): string | null {
    const project = projects.get(projectId);
    if (project === undefined) {
      return `project not found: ${projectId}`;
    }

    const activeCount = project.allocatedPerformers.size;
    if (activeCount >= project.config.maxPerformers) {
      return `project ${projectId} at capacity (${String(activeCount)}/${String(project.config.maxPerformers)})`;
    }

    // Check capability overlap
    if (project.config.allowedCapabilities.length > 0) {
      const perfState = performers.get(performerId);
      if (perfState !== undefined) {
        const hasCapability = project.config.allowedCapabilities.some((cap) =>
          perfState.capabilities.includes(cap)
        );
        if (!hasCapability) {
          return `performer ${performerId} lacks required capabilities for project ${projectId}`;
        }
      }
    }

    return null;
  }

  return {
    registerProject(config: ProjectConfig): KallaxResult<void> {
      if (config.maxPerformers < 1) {
        return err(
          new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'maxPerformers must be >= 1', {
            metadata: { projectId: config.projectId, maxPerformers: config.maxPerformers },
          })
        );
      }

      if (projects.has(config.projectId)) {
        // Update existing config
        const existing = projects.get(config.projectId);
        if (!existing) return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, `Project ${config.projectId} not found`));
        existing.config = config;

        // If maxPerformers decreased, deallocate excess
        if (existing.allocatedPerformers.size > config.maxPerformers) {
          const excess = Array.from(existing.allocatedPerformers).slice(config.maxPerformers);
          for (const pid of excess) {
            existing.allocatedPerformers.delete(pid);
            performers.delete(pid);
          }
        }

        logger.info({ projectId: config.projectId, maxPerformers: config.maxPerformers, priority: config.priority }, 'project config updated');
      } else {
        projects.set(config.projectId, {
          config,
          allocatedPerformers: new Set(),
          queueDepth: 0,
        });

        logger.info({ projectId: config.projectId, maxPerformers: config.maxPerformers, priority: config.priority }, 'project registered');
      }

      return ok(undefined);
    },

    allocatePerformer(performerId: string, projectId: string): KallaxResult<void> {
      // Check if performer already allocated elsewhere
      const existingAllocation = performers.get(performerId);
      if (existingAllocation !== undefined) {
        if (existingAllocation.projectId === projectId) {
          logger.debug({ performerId, projectId }, 'performer already allocated to this project');
          return ok(undefined);
        }
        return err(
          new KallaxError(KallaxErrorCode.INSTANCE_ALREADY_EXISTS, 'performer already allocated to another project', {
            metadata: { performerId, currentProject: existingAllocation.projectId, targetProject: projectId },
          })
        );
      }

      const validationError = validatePerformerForProject(performerId, projectId);
      if (validationError !== null) {
        return err(
          new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, validationError, {
            metadata: { performerId, projectId },
          })
        );
      }

      const project = projects.get(projectId);
      if (!project) {
        return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, `Project ${projectId} not found`));
      }

      // Actually allocate
      const performerEntry: PerformerState = {
        performerId,
        projectId,
        capabilities: [],
        allocatedAt: Date.now(),
      };

      performers.set(performerId, performerEntry);
      project.allocatedPerformers.add(performerId);

      logger.info(
        { performerId, projectId, allocatedCount: project.allocatedPerformers.size, capacity: project.config.maxPerformers },
        'performer allocated to project'
      );

      return ok(undefined);
    },

    releasePerformer(performerId: string): KallaxResult<void> {
      const perfState = performers.get(performerId);
      if (perfState === undefined) {
        return err(
          new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, 'performer not found in pool', {
            metadata: { performerId },
          })
        );
      }

      const project = projects.get(perfState.projectId);
      if (project !== undefined) {
        project.allocatedPerformers.delete(performerId);
        logger.info({ performerId, projectId: perfState.projectId }, 'performer released from project');
      }

      performers.delete(performerId);
      return ok(undefined);
    },

    getProjectAllocation(projectId: string): PoolAllocation {
      const project = projects.get(projectId);
      if (project === undefined) {
        return {
          projectId,
          allocatedPerformers: [],
          availableSlots: 0,
          queueDepth: 0,
        };
      }

      return {
        projectId: project.config.projectId,
        allocatedPerformers: Array.from(project.allocatedPerformers),
        availableSlots: project.config.maxPerformers - project.allocatedPerformers.size,
        queueDepth: project.queueDepth,
      };
    },

    getGlobalStats(): GlobalPoolStats {
      let totalPerformers = 0;
      let totalCapacity = 0;

      for (const project of projects.values()) {
        totalPerformers += project.allocatedPerformers.size;
        totalCapacity += project.config.maxPerformers;
      }

      const utilizationPercent = totalCapacity > 0
        ? Math.round((totalPerformers / totalCapacity) * 100)
        : 0;

      return {
        totalProjects: projects.size,
        totalPerformers,
        utilizationPercent,
      };
    },

    rebalance(): void {
      if (projects.size < 2) {
        logger.debug({ projectCount: projects.size }, 'rebalance skipped: need at least 2 projects');
        return;
      }

      // Sort projects by priority descending, then by queue depth descending
      const sorted = Array.from(projects.entries())
        .map(([id, state]) => ({ id, state }))
        .sort((a, b) => {
          const priorityDiff = b.state.config.priority - a.state.config.priority;
          if (priorityDiff !== 0) return priorityDiff;
          return b.state.queueDepth - a.state.queueDepth;
        });

      const highPriority = sorted[0];
      const lowPriority = sorted[sorted.length - 1];
      if (!highPriority || !lowPriority) return;

      // Only rebalance if high-priority project has available capacity
      const highAvailableSlots = highPriority.state.config.maxPerformers - highPriority.state.allocatedPerformers.size;
      if (highAvailableSlots <= 0) {
        logger.debug(
          { highPriorityProject: highPriority.id, availableSlots: highAvailableSlots },
          'rebalance skipped: high-priority project has no available slots'
        );
        return;
      }

      // Number of performers to steal from low-priority project
      const stealCount = Math.min(
        highAvailableSlots,
        lowPriority.state.allocatedPerformers.size
      );

      if (stealCount <= 0) {
        logger.debug({ stealCount }, 'rebalance: no performers to redistribute');
        return;
      }

      let movedCount = 0;
      const toMove = Array.from(lowPriority.state.allocatedPerformers).slice(0, stealCount);

      for (const performerId of toMove) {
        const perfState = performers.get(performerId);
        if (perfState === undefined) continue;

        // Move performer from low-priority to high-priority project
        lowPriority.state.allocatedPerformers.delete(performerId);
        highPriority.state.allocatedPerformers.add(performerId);
        perfState.projectId = highPriority.id;
        movedCount++;

        logger.info(
          { performerId, fromProject: lowPriority.id, toProject: highPriority.id },
          'performer redistributed via rebalance'
        );
      }

      logger.info(
        {
          movedCount,
          fromProject: lowPriority.id,
          toProject: highPriority.id,
        },
        'rebalance completed'
      );
    },
  };
}

// Singleton instance
let defaultPool: ProjectPool | null = null;

export function getProjectPool(): ProjectPool {
  defaultPool ??= createProjectPool();
  return defaultPool;
}
