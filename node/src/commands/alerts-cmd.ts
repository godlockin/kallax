/**
 * KALLAX Alerts Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerAlertsCommands(program: Command, ctx: AppContext): void {
  program
    .command('alerts:list')
    .description('List active system alerts')
    .option('--since <hours>', 'Only alerts from last N hours', '24')
    .action(async (opts?: { since?: string }) => {
      try {
        const sinceHours = parseInt(opts?.['since'] ?? '24', 10);
        const thresholdMs = sinceHours * 3600_000;
        const now = Date.now();
        const alerts: Array<{ type: string; severity: string; message: string; timestamp: number }> = [];

        // 1. Stale instances
        const staleResult = await ctx.instanceRegistry.markStaleInstances(thresholdMs);
        if (staleResult.isOk()) {
          for (const inst of staleResult.value) {
            alerts.push({
              type: 'stale_instance', severity: 'warning',
              message: `Instance ${inst.id} (${inst.role}) stale since ${new Date(inst.lastHeartbeat).toISOString()}`,
              timestamp: now,
            });
          }
        }

        // 2. Failed tasks
        const failedTasks = ctx.db.listTasks({ status: 'failed', limit: 50 });
        if (failedTasks.isOk()) {
          for (const t of failedTasks.value) {
            const age = (now - t.updatedAt) / 3600_000;
            if (age <= sinceHours) {
              alerts.push({
                type: 'failed_task', severity: 'error',
                message: `Task ${t.id} (${t.type}) failed: ${t.error ?? 'unknown'}`,
                timestamp: t.updatedAt,
              });
            }
          }
        }

        // 3. Stale tickets (blocked > threshold)
        const blockedTickets = ctx.db.listTickets({ status: 'blocked', limit: 50 });
        if (blockedTickets.isOk()) {
          for (const t of blockedTickets.value) {
            const age = (now - t.updatedAt) / 3600_000;
            if (age <= sinceHours) {
              alerts.push({
                type: 'blocked_ticket', severity: 'info',
                message: `Ticket ${t.id} blocked since ${new Date(t.updatedAt).toISOString()}`,
                timestamp: t.updatedAt,
              });
            }
          }
        }

        process.stdout.write(JSON.stringify({ alerts, count: alerts.length, sinceHours }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
