/**
 * KALLAX Degradation Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerDegradationCommands(program: Command, _ctx: AppContext): void {
  program
    .command('system:degradation')
    .description('Show degradation state and tier status')
    .action(async (): Promise<void> => {
      try {
        const { getRecoveryManager } = await import('../core/recovery-manager.js');
        const rm = getRecoveryManager();
        const state = rm.getState();

        process.stdout.write('=== KALLAX Degradation Status ===\n\n');
        process.stdout.write(`Current Tier : ${String(state.currentTier)} (${String(['Degraded','Shell','Node.js','Rust'][state.currentTier])})\n`);
        process.stdout.write(`Target Tier  : ${String(state.targetTier)}\n`);
        process.stdout.write(`Crash Count  : ${String(state.crashCount)}\n\n`);

        process.stdout.write('Tier Status:\n');
        for (const level of [3, 2, 1, 0] as const) {
          const tier = state.tiers[level];
          const icon = tier.healthy ? '✓' : '✗';
          const uptime = tier.degradedAt != null
            ? `degraded at ${new Date(tier.degradedAt).toISOString()}`
            : 'healthy';
          process.stdout.write(`  ${icon} L${String(level)} ${tier.name.padEnd(10)} ${uptime} (probe: ${new Date(tier.lastProbeAt).toISOString()})\n`);
        }

        process.stdout.write('\nUse "kallax system:degradation probe" to force a probe cycle.\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  program
    .command('system:degradation-probe')
    .description('Force degradation probe cycle')
    .action(async (): Promise<void> => {
      try {
        const { getRecoveryManager } = await import('../core/recovery-manager.js');
        const rm = getRecoveryManager();
        await rm.probeAll();
        const state = rm.getState();
        process.stdout.write(`Probe complete. Current tier: ${String(state.currentTier)}\n`);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
